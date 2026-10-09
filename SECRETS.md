# Secrets

Nothing secret is stored in this repository. Every credential is either generated on your
machine (Talos PKI, Terraform state), entered by you into a git-ignored file
(`terraform/terraform.tfvars`), or created directly in the cluster with `kubectl` before the
app that needs it syncs.

The manifests reference Secrets **by name and key only**. If a Secret is missing, the pod
stays in `CreateContainerConfigError` until you create it, then starts on its own.

## Kubernetes Secrets you create

Create these after `kubectl` works against the new cluster and **before** (or right after)
you apply `bootstrap/`. The namespace commands are idempotent.

| # | Namespace | Secret name | Keys | Required? | Consumed by |
|---|---|---|---|---|---|
| 1 | `gitea` | `gitea-admin` | `username`, `password` | required | Gitea chart `gitea.admin.existingSecret`: the first admin account |
| 2 | `gitea` | `gitea-postgresql` | `password`, `postgres-password` | required | bundled PostgreSQL (`global.postgresql.auth.existingSecret`) and Gitea (`GITEA__DATABASE__PASSWD`) |
| 3 | `nextcloud` | `nextcloud-admin` | `nextcloud-username`, `nextcloud-password` | required | Nextcloud chart `nextcloud.existingSecret`: the first admin account |
| 4 | `nextcloud` | `nextcloud-db` | `db-username`, `db-password`, `postgres-password` | required | Nextcloud (`externalDatabase.existingSecret`) and bundled PostgreSQL |
| 5 | `monitoring` | `grafana-admin` | `admin-user`, `admin-password` | required | Grafana `admin.existingSecret` (without it Grafana uses a well-known default) |
| 6 | `vaultwarden` | `vaultwarden-admin` | `ADMIN_TOKEN` | optional | Vaultwarden `/admin` panel; the panel stays disabled if the Secret is absent |

### Commands

`openssl rand -base64 24` makes a random password. Run each block once and store the values
in your password manager. Shell history keeps what you type, so put a space before each command
(with `HISTCONTROL=ignorespace`) or use `read -s`.

```bash
# 1 + 2: Gitea
kubectl create namespace gitea --dry-run=client -o yaml | kubectl apply -f -
kubectl -n gitea create secret generic gitea-admin \
  --from-literal=username=gitea_admin \
  --from-literal=password="$(openssl rand -base64 24)"
kubectl -n gitea create secret generic gitea-postgresql \
  --from-literal=password="$(openssl rand -base64 24)" \
  --from-literal=postgres-password="$(openssl rand -base64 24)"

# 3 + 4: Nextcloud
kubectl create namespace nextcloud --dry-run=client -o yaml | kubectl apply -f -
kubectl -n nextcloud create secret generic nextcloud-admin \
  --from-literal=nextcloud-username=admin \
  --from-literal=nextcloud-password="$(openssl rand -base64 24)"
kubectl -n nextcloud create secret generic nextcloud-db \
  --from-literal=db-username=nextcloud \
  --from-literal=db-password="$(openssl rand -base64 24)" \
  --from-literal=postgres-password="$(openssl rand -base64 24)"

# 5: Grafana
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$(openssl rand -base64 24)"

# 6 (optional): Vaultwarden admin panel. Store an Argon2 hash, not the plain token.
#    Generate the hash (it prompts for the token you will type at /admin):
#      docker run --rm -it vaultwarden/server /vaultwarden hash
#    Single quotes matter: the hash contains '$'.
kubectl create namespace vaultwarden --dry-run=client -o yaml | kubectl apply -f -
kubectl -n vaultwarden create secret generic vaultwarden-admin \
  --from-literal=ADMIN_TOKEN='REPLACE_ME_ARGON2_PHC_HASH'
```

Read a value back when you need it, for example:
`kubectl -n gitea get secret gitea-admin -o jsonpath='{.data.password}' | base64 -d; echo`

> The `nextcloud-db` `db-username` must stay `nextcloud`: the bundled PostgreSQL creates that
> user (`postgresql.global.postgresql.auth.username` in `apps/nextcloud/application.yaml`).
> Change both together if you change it.

> Database passwords are only read when PostgreSQL initialises an **empty** volume. Changing the
> Secret later does not change the password inside the database. Change it in PostgreSQL first,
> then update the Secret.

## Secrets created for you (do not commit them)

| What | Where it lives | Notes |
|---|---|---|
| Talos PKI, tokens, cluster secret | Terraform state (`talos_machine_secrets`) or `talos/_out/secrets.yaml` with the manual path | Anyone holding it controls the cluster. Back it up offline. `*.tfstate` and `_out/` are git-ignored. |
| Talos machine configs | `terraform/_out/<node>.yaml` or `talos/_out/*.yaml` | Contain the PKI above. Git-ignored. |
| `talosconfig` | `terraform/_out/talosconfig`, then `~/.talos/config` | Talos API client certificate. Git-ignored. |
| `kubeconfig` | `~/.kube/config` (from `talosctl kubeconfig`) | Cluster-admin client certificate. Git-ignored. |
| ArgoCD admin password | Secret `argocd/argocd-initial-admin-secret` | Read it once, change the password in the UI, then delete the Secret. |
| TLS certificates | Secrets `*-tls` in each app namespace | Issued by cert-manager from the self-signed ClusterIssuer. |

## Values you type into a git-ignored file

| File | Keys | Notes |
|---|---|---|
| `terraform/terraform.tfvars` (copy of `terraform.tfvars.example`) | `proxmox_api_token_id`, `proxmox_api_token_secret` | Proxmox API token. Alternatively export `TF_VAR_proxmox_api_token_id` / `TF_VAR_proxmox_api_token_secret`. |

If your fork is **private**, ArgoCD also needs read access to it: add the repository in the
ArgoCD UI (Settings -> Repositories) with a read-only deploy key or token. Do not commit that
credential either.

## Going further

Creating Secrets by hand is the simplest model and the one this starter uses. When you want the
Secrets themselves in git, encrypted, look at
[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets),
[SOPS](https://github.com/getsops/sops) with age, or
[External Secrets Operator](https://external-secrets.io/) backed by a password manager. The
Secret names and keys above stay the same; only the way they are created changes.
