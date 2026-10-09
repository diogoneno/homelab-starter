variable "node_name" {
  type        = string
  description = "Proxmox node that hosts the VM."
}

variable "vm_id" {
  type        = number
  description = "Proxmox VM ID."
}

variable "name" {
  type        = string
  description = "VM name."
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "iso_file" {
  type        = string
  description = "Proxmox file ID of the ISO to attach (datastore:iso/name.iso)."
  default     = "none"
}

variable "disk_size" {
  type        = number
  description = "Size of the OS disk in GB."
  default     = 20
}

variable "disk_datastore" {
  type        = string
  description = "Datastore for the OS and EFI disks."
  default     = "local-lvm"
}

variable "bridge" {
  type        = string
  description = "Proxmox network bridge."
  default     = "vmbr0"
}
