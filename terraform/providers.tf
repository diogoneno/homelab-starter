provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  # Most homelab Proxmox hosts use the self-signed certificate created at install time.
  # Set to false once the API endpoint has a certificate your machine trusts.
  insecure = var.proxmox_insecure
}

provider "talos" {}
