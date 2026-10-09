# ---------------------------------------------------------------------------
# Proxmox API access. Put real values in terraform.tfvars (git-ignored) or in
# TF_VAR_* environment variables. Never commit them.
# ---------------------------------------------------------------------------

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox VE API URL, e.g. https://pve.example.internal:8006/"
}

variable "proxmox_api_token_id" {
  type        = string
  description = "API token ID in the form user@realm!tokenname."
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "API token secret (UUID shown once when the token is created)."
  sensitive   = true
}

variable "proxmox_insecure" {
  type        = bool
  description = "Skip TLS verification of the Proxmox API (self-signed certificate)."
  default     = true
}

variable "iso_datastore" {
  type        = string
  description = "Proxmox datastore that accepts ISO images on every node used."
  default     = "local"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox bridge the VMs attach to."
  default     = "vmbr0"
}

# ---------------------------------------------------------------------------
# Talos / cluster
# ---------------------------------------------------------------------------

variable "talos_version" {
  type        = string
  description = "Talos release used for the boot ISO and for the generated machine configs. Bump both together."
  default     = "v1.7.6"
}

variable "talos_image_url" {
  type        = string
  description = "Boot ISO URL. Leave empty to use the vanilla metal ISO from GitHub; set it to an Image Factory URL to bake in extensions (see talos/schematic.yaml)."
  default     = ""
}

variable "cluster_name" {
  type        = string
  description = "Kubernetes cluster name."
  default     = "homelab"
}

variable "cluster_endpoint" {
  type        = string
  description = "Kubernetes API endpoint: the control-plane node IP (or a VIP) on port 6443."
  default     = "https://192.0.2.11:6443"
}

variable "network_gateway" {
  type        = string
  description = "Default gateway for the node network."
  default     = "192.0.2.1"
}

variable "network_prefix_length" {
  type        = number
  description = "Prefix length of the node network (24 for a /24)."
  default     = 24
}

variable "nameservers" {
  type        = list(string)
  description = "DNS servers the nodes use."
  default     = ["192.0.2.53"]
}

variable "network_mtu" {
  type        = number
  description = "Node interface MTU. 1500 for most LANs; lower it (e.g. 1492) behind PPPoE."
  default     = 1500
}

variable "talos_installer_image" {
  type        = string
  description = "Installer image written to disk. Longhorn needs the iscsi-tools and util-linux-tools extensions, so use an Image Factory installer built from talos/schematic.yaml: factory.talos.dev/installer/<schematic-id>:<talos_version>. Empty = vanilla installer (Longhorn will NOT work)."
  default     = ""
}

variable "install_disk" {
  type        = string
  description = "Disk Talos installs itself to inside the VM."
  default     = "/dev/sda"
}

variable "talos_output_dir" {
  type        = string
  description = "Where the generated machine configs and talosconfig are written. Git-ignored; contains secrets."
  default     = "_out"
}

# ---------------------------------------------------------------------------
# Nodes. One entry per VM. The map key becomes the VM name and the node hostname.
# ---------------------------------------------------------------------------

variable "nodes" {
  description = "Talos VMs to create, keyed by hostname."
  type = map(object({
    role           = string # "controlplane" or "worker"
    proxmox_node   = string # Proxmox node that hosts the VM
    vm_id          = number
    ip_address     = string # static IPv4 address, without prefix length
    cpu_cores      = number
    memory_mb      = number
    disk_datastore = string
    disk_size_gb   = number
  }))

  default = {
    "node-cp-1" = {
      role           = "controlplane"
      proxmox_node   = "pve-node-1"
      vm_id          = 100
      ip_address     = "192.0.2.11"
      cpu_cores      = 4
      memory_mb      = 8192
      disk_datastore = "local-lvm"
      disk_size_gb   = 20
    }
    "node-worker-1" = {
      role           = "worker"
      proxmox_node   = "pve-node-2"
      vm_id          = 201
      ip_address     = "192.0.2.21"
      cpu_cores      = 8
      memory_mb      = 8192
      disk_datastore = "local-lvm"
      disk_size_gb   = 200
    }
    "node-worker-2" = {
      role           = "worker"
      proxmox_node   = "pve-node-1"
      vm_id          = 202
      ip_address     = "192.0.2.22"
      cpu_cores      = 8
      memory_mb      = 8192
      disk_datastore = "local-lvm"
      disk_size_gb   = 20
    }
  }

  validation {
    condition     = alltrue([for n in values(var.nodes) : contains(["controlplane", "worker"], n.role)])
    error_message = "Each node role must be \"controlplane\" or \"worker\"."
  }

  validation {
    condition     = length([for n in values(var.nodes) : n if n.role == "controlplane"]) >= 1
    error_message = "At least one node must have role \"controlplane\"."
  }
}
