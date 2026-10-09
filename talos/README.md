# Talos Linux on Proxmox

[Talos](https://www.talos.dev/) is an immutable, API-only Linux built for Kubernetes: no SSH,
no shell, no package manager. Every node is defined by one YAML **machine config**. This
directory holds everything needed to produce those configs **without committing any secret**.

```
talos/
├── schematic.yaml        # Image Factory extensions Longhorn needs (iscsi-tools, util-linux-tools)
├── patches/
│   ├── common.yaml       # every node: Longhorn kubelet mount, install disk
│   ├── controlplane.yaml # control plane: pod/service CIDRs, scheduling
│   ├── worker.yaml       # workers: role label
│   └── nodes/            # one per node: hostname, static IP, gateway, DNS, MTU
└── reference/            # what a generated config looks like, all secrets replaced. READ ONLY.
```

Generated configs, `secrets.yaml` and `talosconfig` go to `_out/`, which is git-ignored.

## Proxmox VM layout

The default layout (from `terraform/terraform.tfvars.example`) is three VMs across two
Proxmox nodes:

| VM name | Role | Proxmox node | VM ID | vCPU | RAM | Disk | Static IP |
|---|---|---|---|---|---|---|---|
| `node-cp-1` | control plane (etcd, API server) | `pve-node-1` | 100 | 4 | 8 GiB | 20 GB | `192.0.2.11` |
| `node-worker-1` | worker, **storage** (holds Longhorn data) | `pve-node-2` | 201 | 8 | 8 GiB | 200 GB | `192.0.2.21` |
| `node-worker-2` | worker, general | `pve-node-1` | 202 | 8 | 8 GiB | 20 GB | `192.0.2.22` |

Every VM: `q35` machine, OVMF (UEFI) with a 4 MB EFI disk, `host` CPU type, VirtIO SCSI
single controller, one VirtIO NIC on `vmbr0`, Talos ISO on `ide3`, boot order disk then ISO,
QEMU guest agent off.

Minimum that still works: one control plane with `allowSchedulingOnControlPlanes: true`
(in `patches/controlplane.yaml`) and 8 GiB RAM, or a 4 GiB worker running only a few apps.
Longhorn's data lives on the worker disks, so size the storage worker for your volumes.

## Option A: Terraform (recommended)

`terraform/` creates the VMs, generates the cluster secrets and renders one machine config per
node from the patches here plus the `nodes` variable.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit: see VALUES.md
terraform init
terraform apply
```

Result: VMs booted from the Talos ISO in **maintenance mode** (DHCP address, waiting for a
config), plus `terraform/_out/<node>.yaml` and `terraform/_out/talosconfig`.

Then apply each config once. Find each VM's temporary DHCP address on its Proxmox console:

```bash
talosctl apply-config --insecure --nodes <dhcp-ip-of-node-cp-1>     --file _out/node-cp-1.yaml
talosctl apply-config --insecure --nodes <dhcp-ip-of-node-worker-1> --file _out/node-worker-1.yaml
talosctl apply-config --insecure --nodes <dhcp-ip-of-node-worker-2> --file _out/node-worker-2.yaml
```

Each node installs to disk, reboots and comes up on its static IP. Continue at
[Bootstrap](#bootstrap-both-options).

> The cluster PKI lives in Terraform state. Keep state out of git (`.gitignore` covers it) and
> back it up somewhere safe, or use a remote backend with encryption.

## Option B: talosctl by hand

Create the VMs any way you like (Terraform with the `talos_*` resources removed, or the
Proxmox UI using the layout above), then:

```bash
# 1. Image with the extensions Longhorn needs. Returns {"id":"<schematic-id>"}.
curl -sX POST --data-binary @talos/schematic.yaml https://factory.talos.dev/schematics
#    Boot ISO:  https://factory.talos.dev/image/<schematic-id>/v1.7.6/metal-amd64.iso

# 2. Cluster secrets (CA keys, tokens). Keep this file safe; it IS the cluster.
mkdir -p talos/_out
talosctl gen secrets -o talos/_out/secrets.yaml

# 3. Machine configs with the shared patches.
talosctl gen config homelab https://192.0.2.11:6443 \
  --with-secrets talos/_out/secrets.yaml \
  --install-image factory.talos.dev/installer/REPLACE_ME_SCHEMATIC_ID:v1.7.6 \
  --config-patch @talos/patches/common.yaml \
  --config-patch-control-plane @talos/patches/controlplane.yaml \
  --config-patch-worker @talos/patches/worker.yaml \
  --output talos/_out
#    -> talos/_out/controlplane.yaml, talos/_out/worker.yaml, talos/_out/talosconfig

# 4. Apply to each node in maintenance mode, adding its own network patch.
talosctl apply-config --insecure --nodes <dhcp-ip> --file talos/_out/controlplane.yaml \
  --config-patch @talos/patches/nodes/node-cp-1.yaml
talosctl apply-config --insecure --nodes <dhcp-ip> --file talos/_out/worker.yaml \
  --config-patch @talos/patches/nodes/node-worker-1.yaml
talosctl apply-config --insecure --nodes <dhcp-ip> --file talos/_out/worker.yaml \
  --config-patch @talos/patches/nodes/node-worker-2.yaml
```

To check a patch before you apply it, render the result locally:
`talosctl machineconfig patch talos/_out/worker.yaml --patch @talos/patches/nodes/node-worker-1.yaml`.

## Bootstrap (both options)

```bash
export TALOSCONFIG=$PWD/terraform/_out/talosconfig   # or talos/_out/talosconfig
talosctl config endpoint 192.0.2.11
talosctl config node 192.0.2.11

talosctl bootstrap                 # ONCE, on one control-plane node only: starts etcd
talosctl health                    # wait until every check passes
talosctl kubeconfig ~/.kube/config # merges the admin kubeconfig; never commit it
kubectl get nodes -o wide
```

## Gotchas

* **List patches append.** Talos merges lists by appending. A patch that adds a default route
  to a config that already has one produces two `0.0.0.0/0` routes. Configs fresh from
  `gen config` have `machine.network: {}`, so the node patches here are safe for them; check
  with `talosctl machineconfig patch` before patching a live node's config.
* **ISO, installer and config version must match** (`v1.7.6` throughout). Upgrade with
  `talosctl upgrade --image factory.talos.dev/installer/<schematic-id>:<new-version>`, one node
  at a time, then `talosctl upgrade-k8s`.
* **No extensions = no Longhorn.** The vanilla installer lacks `iscsiadm`; Longhorn volumes
  then never attach. Use the Image Factory installer from `schematic.yaml`.
* **Interface name.** `ens18` is the first VirtIO NIC on a Proxmox q35 VM. Check with
  `talosctl get links --insecure --nodes <dhcp-ip>` if yours differs.
* **MTU.** If `docker pull`-style image pulls hang at the TLS handshake while small requests
  work, the path MTU is smaller than the interface MTU (common behind PPPoE). Set 1492.
