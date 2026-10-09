terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  node_name = var.node_name
  vm_id     = var.vm_id
  name      = var.name
  machine   = "q35"
  bios      = "ovmf"

  efi_disk {
    datastore_id = var.disk_datastore
    file_format  = "raw"
    type         = "4m"
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  # Boot the disk first; on a blank disk OVMF falls through to the Talos ISO.
  boot_order = ["scsi0", "ide3"]

  memory {
    dedicated = var.memory_mb
  }

  network_device {
    bridge = var.bridge
  }

  disk {
    datastore_id = var.disk_datastore
    file_format  = "raw"
    interface    = "scsi0"
    size         = var.disk_size
  }

  scsi_hardware = "virtio-scsi-single"

  cdrom {
    file_id   = var.iso_file
    interface = "ide3"
  }

  operating_system {
    type = "l26"
  }

  # Talos does not ship the QEMU guest agent unless you add the extension.
  agent {
    enabled = false
  }
}
