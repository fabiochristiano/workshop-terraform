variable "location" {
  type        = string
  description = "Região do Azure."
  default     = "brazilsouth"
}

variable "tags" {
  type        = map(string)
  description = "Tags comuns ao Resource Group e à VNet."
  default     = {}
}
