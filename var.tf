variable "location" {
  description = "Region where the resources are created."
  default     = "northeurope"
}

variable "ip_restrictions" {
    default = ["10.0.0.1"]
}



