# Main Terraform secrets file.
# ---

variable "pve_api_token" {
  type      = string
  sensitive = true
}

variable "ciuser" {
  type      = string
  sensitive = true
}

variable "cipass" {
  type      = string
  sensitive = true
}

variable "cissh" {
  type      = string
  sensitive = true
}
