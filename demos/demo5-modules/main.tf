module "resource_group" {
  source = "./modules/resource-group"

  name     = "rg-workshop-dev-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

module "vnet" {
  source = "./modules/vnet"

  name                = "vnet-workshop-dev-${local.name_suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  address_space       = ["10.10.0.0/16"]
  tags                = local.common_tags
}

module "subnet_app" {
  source = "./modules/subnet"

  name                 = "snet-app-${local.name_suffix}"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

module "subnet_data" {
  source = "./modules/subnet"

  name                 = "snet-data-${local.name_suffix}"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.vnet.name
  address_prefixes     = ["10.10.2.0/24"]
}
