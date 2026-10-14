locals {
  name_suffix = "demo5-${random_string.suffix.result}"
  common_tags = merge(var.tags, {
    env        = "dev"
    project    = "workshop"
    managed_by = "terraform"
  })
}
