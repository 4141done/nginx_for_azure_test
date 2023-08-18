# This is the resource that hold everything else we are going to stand up
resource "azurerm_resource_group" "example" {
  name     = var.name
  location = var.location

  tags = var.tags
}

# Public IP for NGINX for Azure to use
resource "azurerm_public_ip" "example" {
  name                = var.name
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  sku                 = "Standard"
  allocation_method   = "Static"
}

# This is the overarching network in which everything will exist
resource "azurerm_virtual_network" "example" {
  name                = var.name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]

  tags = var.tags
}

# This subnet is to allow the container application environment
# to assign addresses in this range.
resource "azurerm_subnet" "container-app-subnet" {
  name                 = "${var.name}-container-env"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.0.0/21"]
}

# Dedicated subnet for NGINX as a Service for Azure
# It is delegated so may not be assigned to other resource types
resource "azurerm_subnet" "example" {
  name                 = "${var.name}-nginx"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.0.8.0/24"]
  delegation {
    name = "nginx"
    service_delegation {
      name = "NGINX.NGINXPLUS/nginxDeployments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# WARNING: This opens up the network security group
# to allow traffic to deployment from anywhere.
resource "azurerm_network_security_group" "example" {
  name                = var.name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = var.name
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.example.id
  network_security_group_id = azurerm_network_security_group.example.id
}

# Another security group allowing broad access
# This will be assigned to the container app subnet to try
# to do a bonehead test to see if the nginx for azure service can
# use it as an upstream
resource "azurerm_network_security_group" "app_nsg" {
  name                = "${var.name}-app-network-security-group"
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name

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

resource "azurerm_user_assigned_identity" "example" {
  location            = azurerm_resource_group.example.location
  name                = var.name
  resource_group_name = azurerm_resource_group.example.name

  tags = var.tags
}
