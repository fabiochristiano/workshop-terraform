module "resource_group" {
  source = "../demo5-modules/modules/resource-group"

  name     = "rg-workshop-dev-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

module "vnet" {
  source = "../demo5-modules/modules/vnet"

  name                = "vnet-workshop-dev-${local.name_suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = ["10.10.0.0/16"]
  tags                = local.common_tags
}

module "subnet" {
  source   = "../demo5-modules/modules/subnet"
  for_each = local.subnets

  name                 = "snet-${each.key}-${local.name_suffix}"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.vnet.name
  address_prefixes     = [each.value]
}
