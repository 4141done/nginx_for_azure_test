provider "azurerm" {
  features {}
}

module "prerequisites" {
  source   = "./prerequisites"
  location = var.location
  name     = var.name
  tags     = var.tags
}

# The actual nginx as a service for azure deployment
resource "azurerm_nginx_deployment" "primary" {
  name                     = var.name
  resource_group_name      = module.prerequisites.resource_group_name
  sku                      = var.sku
  location                 = var.location
  diagnose_support_enabled = true

  identity {
    type         = "UserAssigned"
    identity_ids = [module.prerequisites.managed_identity_id]
  }

  frontend_public {
    ip_address = [module.prerequisites.public_ip_address_id]
  }

  network_interface {
    subnet_id = module.prerequisites.subnet_id
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "primary" {
  scope                = azurerm_nginx_deployment.primary.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = module.prerequisites.managed_identity_principal_id
}

#######################
# AZURE CONTAINER APP
#######################

# This subnet is to allow the container application environment
# to assign addresses in this range.
resource "azurerm_subnet" "container-app-subnet" {
  name                 = "${var.name}-container-env"
  resource_group_name  = module.prerequisites.resource_group_name
  virtual_network_name = module.prerequisites.vnet_name
  address_prefixes     = ["10.0.0.0/21"]
}

# Network security group allowing broad access
# This will be assigned to the container app subnet to try
# to do a bonehead test to see if the nginx for azure service can
# use it as an upstream
resource "azurerm_network_security_group" "app_nsg" {
  name                = "${var.name}-app-network-security-group"
  location            = var.location
  resource_group_name = module.prerequisites.resource_group_name

  security_rule {
    name                   = "nginx-for-azure-to-container-apps"
    priority               = 100
    direction              = "Inbound"
    access                 = "Allow"
    protocol               = "Tcp"
    source_port_range      = "*"
    destination_port_range = "*"
    source_address_prefix  = "*"
    # source_address_prefix      = azurerm_subnet.example.address_prefixes[0]
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "app-nsg" {
  subnet_id                 = azurerm_subnet.container-app-subnet.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
}

# This is required for the azurerm_container_app_environment below
resource "azurerm_log_analytics_workspace" "example" {
  name                = "javier-example-01"
  location            = var.location
  resource_group_name = module.prerequisites.resource_group_name
  sku                 = "PerGB2018"
}

# This is a container for container app deployments
resource "azurerm_container_app_environment" "example" {
  name                           = "javier-example-environment"
  location                       = var.location
  resource_group_name            = module.prerequisites.resource_group_name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.example.id
  infrastructure_subnet_id       = azurerm_subnet.container-app-subnet.id
  internal_load_balancer_enabled = true
}

# A private DNS zone matching the environment default domain must
# be created, and then a "*" A record added to provide DNS lookup
# for any container apps in that Container App Environment.
# Ref: step https://learn.microsoft.com/en-us/azure/dns/private-dns-privatednszone
resource "azurerm_private_dns_zone" "example" {
  name                = azurerm_container_app_environment.example.default_domain
  resource_group_name = module.prerequisites.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "example" {
  name                  = "${var.name}-vnet-priv-dns-link"
  resource_group_name   = module.prerequisites.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.example.name
  virtual_network_id    = module.prerequisites.vnet_id
}

resource "azurerm_private_dns_a_record" "example" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.example.name
  resource_group_name = module.prerequisites.resource_group_name
  ttl                 = 30
  records             = [azurerm_container_app_environment.example.static_ip_address]
}

# Ideally we don't do this in terraform
# Deployments of the application should be handled by other tooling
resource "azurerm_container_app" "example" {
  name                         = "example-basic-jevans-20"
  container_app_environment_id = azurerm_container_app_environment.example.id
  resource_group_name          = module.prerequisites.resource_group_name
  revision_mode                = "Single"

  template {
    container {
      name   = "my-containerapp"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = "0.5"
      memory = "1Gi"
    }
  }

  # THIS MUST BE ADDED AFTER THE CONTAINERAPP IS CREATED
  # Comment it out when you are first standing up the infrastructure.
  # https://github.com/hashicorp/terraform-provider-azurerm/issues/20435
  # ingress {
  #   external_enabled           = true
  #   target_port                = 80
  #   allow_insecure_connections = true
  #   traffic_weight {
  #     # https://github.com/hashicorp/terraform-provider-azurerm/issues/20435
  #     latest_revision = true
  #     percentage      = 100
  #   }
  # }
}

####################
# NETWORK DEBUG VM
###################
resource "azurerm_network_interface" "example" {
  name                = "n4a-debug-box-nic"
  location            = var.location
  resource_group_name = module.prerequisites.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.prerequisites.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

### You can do things like
# az vm run-command invoke --resource-group jevans-test-2 --name n4a-debug-box-machine --command-id RunShellScript --scripts "dig @168.63.129.16 example-basic-jevans-20--u0krkt9.redmeadow-0e932dd0.eastus2.azurecontainerapps.io"
resource "azurerm_linux_virtual_machine" "example" {
  name                = "n4a-debug-box-machine"
  resource_group_name = module.prerequisites.resource_group_name
  location            = var.location
  size                = "Standard_A1_v2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}



