output "nodes" {
  description = "VM name -> Proxmox node, VM ID, role and intended static IP."
  value = {
    for name, n in var.nodes : name => {
      proxmox_node = n.proxmox_node
      vm_id        = module.node[name].vm_id
      role         = n.role
      ip_address   = n.ip_address
    }
  }
}

output "machine_config_files" {
  description = "Generated Talos machine configs (contain secrets; git-ignored)."
  value       = { for name, f in local_sensitive_file.machine_config : name => f.filename }
}

output "talosconfig" {
  description = "talosctl client config. Read with: terraform output -raw talosconfig > ~/.talos/config"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}
