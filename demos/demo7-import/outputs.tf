output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "subnet_id" {
  value = azurerm_subnet.app.id
}

output "subnet_address_prefixes" {
  value = azurerm_subnet.app.address_prefixes
}
