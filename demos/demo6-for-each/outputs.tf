output "resource_group_name" {
  value = module.resource_group.name
}

output "vnet_name" {
  value = module.vnet.name
}

output "subnet_ids" {
  value = { for name, subnet in module.subnet : name => subnet.id }
}
