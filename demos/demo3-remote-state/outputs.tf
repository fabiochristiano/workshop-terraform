output "resource_group_name" {
  description = "Nome do resource group"
  value       = azurerm_resource_group.rg.name
}

output "vnet_name" {
  description = "Nome da rede virtual"
  value       = azurerm_virtual_network.vnet.name
}

output "vnet_id" {
  description = "ID da rede virtual"
  value       = azurerm_virtual_network.vnet.id
}

output "tenant_id" {
  description = "Tenant da identidade autenticada"
  value       = data.azurerm_client_config.current.tenant_id
}
