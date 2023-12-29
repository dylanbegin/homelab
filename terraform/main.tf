# Main Terraform build plan.
# ---
terraform {
  required_providers {
    proxmox   = {
      source  = "bpg/proxmox"
      version = ">= 0.39.0"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://${var.common.pveurl}"
  api_token = var.pve_api_token
  insecure  = true
}
