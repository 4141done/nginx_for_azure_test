output "ip_address" {
  description = "IP address of NGINXaaS deployment."
  value       = azurerm_nginx_deployment.primary.ip_address
}

output "containerapp_ip" {
  description = "FQDN of the containerapp"
  value       = azurerm_container_app.example.latest_revision_fqdn
}

output "containerapp_name" {
  description = "Name of the containerapp"
  value       = azurerm_container_app.example.latest_revision_name
}

output "containerapp_env_static_ip" {
  description = "the static ip of the container app env which holds the container apps"
  value       = azurerm_container_app_environment.example.static_ip_address
}

output "containerapp_env_dns_address" {
  description = "the dns address of the container app env which holds the container apps"
  value       = azurerm_container_app_environment.example.platform_reserved_dns_ip_address
}

output "containerapp_env_default_domain" {
  description = "the default domain for the container app env. All apps will be prepended to this"
  value       = azurerm_container_app_environment.example.default_domain
}

output "debug_vm_public_ip_address" {
  description = "public IP of debug vm"
  value       = azurerm_linux_virtual_machine.example.public_ip_address
}

output "dns_a_record_fqdn" {
  description = "FQDN of the dns a record pointing to the container app"
  value       = azurerm_private_dns_a_record.example.fqdn
}

