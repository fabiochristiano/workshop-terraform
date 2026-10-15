variable "suffix" {
  description = "Sufixo dos recursos criados manualmente; manter o mesmo após importar."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{4}$", var.suffix))
    error_message = "Use exatamente 4 caracteres minúsculos ou numéricos."
  }
}

variable "location" {
  description = "Região do RG e da VNet existentes."
  type        = string
  default     = "brazilsouth"
}

variable "tags" {
  description = "Tags desejadas no RG e na VNet; subnets não recebem tags."
  type        = map(string)
}

variable "subnet_address_prefix" {
  description = "Prefixo da subnet app dentro de 10.10.0.0/16."
  type        = string
}
