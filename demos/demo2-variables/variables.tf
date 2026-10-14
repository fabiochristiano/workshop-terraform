variable "project" {
  type        = string
  description = "Nome do projeto. Usado no naming dos recursos (apenas letras minúsculas, sem hífen)."
  default     = "workshop"

  validation {
    condition     = can(regex("^[a-z]{3,8}$", var.project))
    error_message = "project deve ter de 3 a 8 letras minúsculas."
  }
}

variable "env" {
  type        = string
  description = "Ambiente: dev ou prd."

  validation {
    condition     = contains(["dev", "prd"], var.env)
    error_message = "env deve ser dev ou prd."
  }
}

variable "location" {
  type        = string
  description = "Região do Azure."
  default     = "brazilsouth"
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionais. São combinadas com as tags padrão em local.common_tags."
  default     = {}
}

variable "address_space" {
  type        = list(string)
  description = "Espaço de endereçamento da VNet."
  default     = ["10.10.0.0/16"]
}
