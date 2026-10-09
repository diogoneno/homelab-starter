# Lessons learned

Things that went wrong while running the homelab this starter was extracted from, and what
the repo does about each.

## RWO volume + RollingUpdate = stuck rollout
A Deployment with a ReadWriteOnce PVC and the default `RollingUpdate` strategy starts the new
pod before stopping the old one. The new pod cannot attach the volume the old pod still holds
and waits in `ContainerCreating` forever (`Multi-Attach error`). **Fix:** `strategy: Recreate`
on every single-replica app with an RWO volume (Trilium, Vaultwarden, Gitea). The same reason
rules out HPAs that scale these apps past one replica.

## Tiny default PVCs fill up silently
A Gitea volume sized at 128Mi filled up partway through pushing a large repository and failed
with `No space left on device`. **Fix:** realistic defaults (20Gi repos, 5Gi database) and a
sizing line in every app README. Longhorn volumes can be expanded online
(`allowVolumeExpansion`) if you guessed low.

## `.local` does not work for LAN hostnames
`.local` is reserved for multicast DNS (RFC 6762). systemd-resolved and macOS will not send
`.local` queries to your DNS server, so `gitea.local` only works with an `/etc/hosts` entry on
every client. **Fix:** this repo uses `example.internal`; use a real subdomain you own or
`.internal`.

## Secrets end up in git by default
Helm values with inline passwords, `terraform.tfvars`, Terraform state (which contains the
whole Talos PKI), `talosconfig`, kubeconfigs and generated machine configs all landed in the
original repo's history, because the tools write them next to the code. **Fix:** every chart
here uses `existingSecret`, generated files go to git-ignored `_out/`, `.gitignore` covers
state, tfvars and configs, and CI runs gitleaks on every push.

## Chaos experiments need a blast radius
A Chaos Mesh pod-kill schedule aimed at "all namespaces matching a label" also hit the
services people were using. Chaos tooling is not included here. If you add it, target a
dedicated test namespace, keep the dashboard's authentication on, and do not give it
cluster-admin.

## Path MTU black holes look like TLS failures
On a link with a smaller MTU than 1500 (PPPoE: 1492), large packets vanish while small ones
pass, so image pulls fail with `TLS handshake timeout` and nothing else looks wrong.
**Fix:** `network_mtu` / `mtu:` in the node patches.

## Talos list patches append
Patching a default route into a config that already has one gives the node two default
routes. Render patches with `talosctl machineconfig patch` and read the result before you
apply it to a live node.

## Size for the cluster you have
On a single 4 GiB worker the full app set does not fit: Nextcloud and its PostgreSQL alone
want most of it. Comment apps out in `apps/kustomization.yaml` rather than letting them
crash-loop. An HPA re-scales a Deployment you scaled to zero, so remove the HPA too when you
park an app.
