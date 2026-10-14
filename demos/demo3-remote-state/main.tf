resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_prefix}-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.name_prefix}-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = var.address_space
  tags                = local.common_tags
}
