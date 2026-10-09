# Values to replace

Every site-specific value in this repo is a placeholder. Network addresses use the
documentation range `192.0.2.0/24` (TEST-NET-1, RFC 5737), which is never routed, so a value
you forgot to change fails loudly instead of hitting a real machine. Names use
`example.internal` (`.internal` is reserved for private use).

Find everything still left to change with:

```bash
grep -rnE 'REPLACE_ME|example\.internal|192\.0\.2\.|pve-node-|node-(cp|worker)-' \
  --exclude=VALUES.md --exclude-dir=.git .
```

| # | Placeholder | What to put there | Where it appears |
|---|---|---|---|
| 1 | `https://pve.example.internal:8006/` | URL of your Proxmox VE API | `terraform/terraform.tfvars.example`, `terraform/variables.tf` (description) |
| 2 | `REPLACE_ME_PROXMOX_TOKEN_ID` | Proxmox API token ID, `user@realm!tokenname` (secret: tfvars only) | `terraform/terraform.tfvars.example` |
| 3 | `REPLACE_ME_PROXMOX_TOKEN_SECRET` | Proxmox API token secret (secret: tfvars only) | `terraform/terraform.tfvars.example` |
| 4 | `pve-node-1`, `pve-node-2` | Names of your Proxmox nodes (`pvecm nodes` or the web UI) | `terraform/terraform.tfvars.example`, `terraform/variables.tf` (default) |
| 5 | `local` | Datastore that accepts ISO images, on every node used | `iso_datastore` in `terraform/terraform.tfvars.example` |
| 6 | `local-lvm` | Datastore for VM disks (LVM-thin, ZFS, ...) | `disk_datastore` per node in `terraform/terraform.tfvars.example` |
| 7 | `vmbr0` | Proxmox bridge on your node LAN | `network_bridge` in `terraform/terraform.tfvars.example` |
| 8 | `100`, `201`, `202` | Free Proxmox VM IDs | `vm_id` per node in `terraform/terraform.tfvars.example` |
| 9 | `node-cp-1`, `node-worker-1`, `node-worker-2` | Hostnames for your Talos nodes (also the VM names) | `terraform/terraform.tfvars.example`, `terraform/variables.tf`, `talos/patches/nodes/*.yaml`, `talos/reference/*.yaml` |
| 10 | `192.0.2.11` | Static IP of the control-plane node | `terraform/terraform.tfvars.example`, `talos/patches/nodes/node-cp-1.yaml`, `talos/reference/*.yaml`, `talos/README.md` |
| 11 | `192.0.2.21`, `192.0.2.22` | Static IPs of the workers | `terraform/terraform.tfvars.example`, `talos/patches/nodes/node-worker-*.yaml` |
| 12 | `https://192.0.2.11:6443` | Kubernetes API endpoint: control-plane IP (or a VIP) on 6443 | `cluster_endpoint` in `terraform/terraform.tfvars.example`, `talos/README.md` |
| 13 | `192.0.2.1` | Default gateway of the node LAN | `network_gateway` in tfvars, `talos/patches/nodes/*.yaml` |
| 14 | `192.0.2.53` | DNS server(s) for the nodes | `nameservers` in tfvars, `talos/patches/nodes/*.yaml` |
| 15 | `24` | Prefix length of the node LAN | `network_prefix_length` in tfvars, `/24` in `talos/patches/nodes/*.yaml` |
| 16 | `1500` | Interface MTU (lower, e.g. 1492, behind PPPoE) | `network_mtu` in tfvars, `talos/patches/nodes/*.yaml` |
| 17 | `192.0.2.200-192.0.2.210` | Free range on the node LAN, outside your DHCP pool, for LoadBalancer IPs | `bootstrap/platform/metallb/ip-pool.yaml` |
| 18 | `REPLACE_ME_SCHEMATIC_ID` | Image Factory schematic ID for `talos/schematic.yaml` (not secret) | `talos_installer_image` in tfvars, `talos/README.md`, `talos/reference/*.yaml` |
| 19 | `v1.7.6` | Talos version (ISO, installer and generated config must match) | `terraform/variables.tf`, tfvars, `talos/README.md` |
| 20 | `homelab` | Cluster name | `cluster_name` in tfvars, `talos/README.md` |
| 21 | `/dev/sda` | Disk Talos installs to inside the VM | `terraform/variables.tf`, `talos/patches/common.yaml` |
| 22 | `10.244.0.0/16`, `10.96.0.0/12` | Pod and Service CIDRs; change only if they overlap your LAN | `talos/patches/controlplane.yaml` |
| 23 | `REPLACE_ME_GIT_REPO_URL` | HTTPS (or SSH) URL of **your fork** of this repo | `bootstrap/root-app.yaml`, `bootstrap/platform-app.yaml` |
| 24 | `example.internal` | Your LAN domain; each app gets `<app>.example.internal` | `bootstrap/argocd-ingress.yaml`, `apps/trilium/ingress.yaml`, `apps/vaultwarden/{vaultwarden,ingress}.yaml`, `apps/gitea/application.yaml`, `apps/nextcloud/application.yaml`, `apps/monitoring/application.yaml` |
| 25 | `admin@example.internal` | E-mail address for the Gitea admin account | `apps/gitea/application.yaml` |
| 26 | `longhorn` (StorageClass) | StorageClass for app volumes; keep unless you use another provisioner | every `apps/*` PVC / `storageClass` value |
| 27 | `"1"` (Longhorn replicas) | Replicas per volume; set to your number of storage nodes (max 3) | `bootstrap/platform/longhorn/application.yaml` |
| 28 | PVC sizes (`5Gi`, `2Gi`, `20Gi`, `10Gi`, ...) | Disk you want per app | `apps/*/` (see each app README) |
| 29 | `REPLACE_ME_ARGON2_PHC_HASH` | Argon2 hash of your Vaultwarden admin token (optional) | `SECRETS.md` command only; never in a manifest |
| 30 | `REPLACE_ME_TALOS_*`, `REPLACE_ME_K8S_*`, `REPLACE_ME_ETCD_*` | **Nothing. Do not fill these in.** They mark where `talosctl gen config` / Terraform put generated tokens, keys and certificates. | `talos/reference/*.yaml` (read-only illustrations) |

DNS: point `*.example.internal` (or one entry per app) at the IP MetalLB gives
`ingress-nginx-controller` (`kubectl -n ingress-nginx get svc`). Avoid `.local`: it is reserved
for mDNS and most resolvers will not send it to your DNS server.
