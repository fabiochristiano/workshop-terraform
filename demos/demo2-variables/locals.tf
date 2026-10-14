locals {
  name_suffix = "demo2-${random_string.suffix.result}"
  name_prefix = "${var.project}-${var.env}"

  common_tags = merge(var.tags, {
    env        = var.env
    project    = var.project
    managed_by = "terraform"
  })
}
