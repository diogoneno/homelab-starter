locals {
  proxmox_nodes = toset([for n in values(var.nodes) : n.proxmox_node])
  iso_url       = var.talos_image_url != "" ? var.talos_image_url : "https://github.com/siderolabs/talos/releases/download/${var.talos_version}/metal-amd64.iso"

  # Patches shared by every node (Longhorn mounts, install disk). See talos/patches/.
  common_patch       = file("${path.module}/../talos/patches/common.yaml")
  controlplane_patch = file("${path.module}/../talos/patches/controlplane.yaml")
  worker_patch       = file("${path.module}/../talos/patches/worker.yaml")
}

# ---------------------------------------------------------------------------
# 1. Talos boot ISO, downloaded once onto every Proxmox node that hosts a VM.
# ---------------------------------------------------------------------------

resource "proxmox_download_file" "talos_iso" {
  for_each = local.proxmox_nodes

  node_name    = each.value
  content_type = "iso"
  datastore_id = var.iso_datastore
  url          = local.iso_url
  file_name    = "talos-${var.talos_version}-amd64.iso"
}

# ---------------------------------------------------------------------------
# 2. The VMs.
# ---------------------------------------------------------------------------

module "node" {
  source   = "./modules/vm"
  for_each = var.nodes

  name           = each.key
  node_name      = each.value.proxmox_node
  vm_id          = each.value.vm_id
  cpu_cores      = each.value.cpu_cores
  memory_mb      = each.value.memory_mb
  disk_datastore = each.value.disk_datastore
  disk_size      = each.value.disk_size_gb
  bridge         = var.network_bridge
  iso_file       = proxmox_download_file.talos_iso[each.value.proxmox_node].id
}

# ---------------------------------------------------------------------------
# 3. Talos PKI and machine configs. talos_machine_secrets holds the cluster CA,
#    tokens and keys. It lives ONLY in Terraform state, which must never be
#    committed (see .gitignore). Use a remote backend if you share state.
# ---------------------------------------------------------------------------

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "node" {
  for_each = var.nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = each.value.role
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  talos_version    = var.talos_version

  config_patches = [
    local.common_patch,
    each.value.role == "controlplane" ? local.controlplane_patch : local.worker_patch,
    yamlencode({
      machine = {
        install = merge(
          { disk = var.install_disk },
          var.talos_installer_image != "" ? { image = var.talos_installer_image } : {},
        )
        network = {
          hostname    = each.key
          nameservers = var.nameservers
          interfaces = [{
            interface = "ens18"
            dhcp      = false
            mtu       = var.network_mtu
            addresses = ["${each.value.ip_address}/${var.network_prefix_length}"]
            routes = [{
              network = "0.0.0.0/0"
              gateway = var.network_gateway
            }]
          }]
        }
      }
    }),
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for n in values(var.nodes) : n.ip_address if n.role == "controlplane"]
  nodes                = [for n in values(var.nodes) : n.ip_address]
}

# Written to a git-ignored directory so `talosctl apply-config` can use them.
resource "local_sensitive_file" "machine_config" {
  for_each = var.nodes

  content         = data.talos_machine_configuration.node[each.key].machine_configuration
  filename        = "${path.module}/${var.talos_output_dir}/${each.key}.yaml"
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/${var.talos_output_dir}/talosconfig"
  file_permission = "0600"
}
