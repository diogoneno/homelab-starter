# Terraform: Proxmox VMs + Talos machine configs

Providers: [`bpg/proxmox`](https://registry.terraform.io/providers/bpg/proxmox) and
[`siderolabs/talos`](https://registry.terraform.io/providers/siderolabs/talos).

| File | Purpose |
|---|---|
| `versions.tf` | Terraform and provider version constraints |
| `providers.tf` | Proxmox API connection (token from variables) |
| `variables.tf` | Every input, including the `nodes` map (one entry per VM) |
| `main.tf` | Talos ISO download per Proxmox node, the VMs, Talos secrets and machine configs |
| `outputs.tf` | Node summary, paths of the generated configs, `talosconfig` (sensitive) |
| `modules/vm/` | One Proxmox VM sized for Talos (UEFI, q35, VirtIO) |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` (git-ignored) and edit |

## Proxmox API token

Create a user and token with enough rights to create VMs and upload ISOs, for example on a
Proxmox node shell:

```bash
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role Administrator   # or a narrower custom role
pveum user token add terraform@pve homelab --privsep 0   # prints the token secret ONCE
```

Put the token ID (`terraform@pve!homelab`) and secret into `terraform.tfvars`, or export
`TF_VAR_proxmox_api_token_id` and `TF_VAR_proxmox_api_token_secret`.

## Run

```bash
terraform init
terraform plan
terraform apply
terraform output nodes
```

Then follow [`talos/README.md`](../talos/README.md#option-a-terraform-recommended) to apply
the generated configs and bootstrap the cluster.

## What is sensitive

* `terraform.tfstate*`: contains the whole Talos PKI. Git-ignored. Use an encrypted
  remote backend if more than one machine runs Terraform.
* `_out/`: generated machine configs and `talosconfig`. Git-ignored, mode 0600.
* `terraform.tfvars`: the Proxmox token. Git-ignored.

Changing a node's size or adding a node is a variable change plus `terraform apply`. Changing
an existing node's IP also needs the new config applied with `talosctl apply-config`.
