locals {
  name_suffix = "demo6-${random_string.suffix.result}"
  common_tags = merge(var.tags, {
    env        = "dev"
    project    = "workshop"
    managed_by = "terraform"
  })

  subnets = {
    app  = "10.10.1.0/24"
    data = "10.10.2.0/24"
  }
}
