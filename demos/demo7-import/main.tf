locals {
  name_suffix = "demo7-${var.suffix}"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-workshop-dev-${local.name_suffix}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-workshop-dev-${local.name_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.10.0.0/16"]
  tags                = var.tags
}

resource "azurerm_subnet" "app" {
  name                              = "snet-app-${local.name_suffix}"
  resource_group_name               = azurerm_resource_group.rg.name
  virtual_network_name              = azurerm_virtual_network.vnet.name
  address_prefixes                  = [var.subnet_address_prefix]
  default_outbound_access_enabled   = false
  private_endpoint_network_policies = "Disabled"
}
