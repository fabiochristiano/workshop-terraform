output "resource_group_name" {
  value = module.resource_group.name
}

output "vnet_name" {
  value = module.vnet.name
}

output "subnet_app_id" {
  value = module.subnet_app.id
}

output "subnet_data_id" {
  value = module.subnet_data.id
}
