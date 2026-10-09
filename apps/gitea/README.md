# Gitea

Self-hosted Git service (repos, issues, pull requests), at `https://gitea.example.internal`.

| | |
|---|---|
| Form | ArgoCD `Application`, official Helm chart `gitea` **10.4.0** (`https://dl.gitea.com/charts/`) |
| Image | chart default for Gitea; bundled PostgreSQL image `tag: latest` (**unpinned on purpose**: older Bitnami tags were withdrawn from Docker Hub) |
| Storage | repos PVC 20Gi + PostgreSQL PVC 5Gi, StorageClass `longhorn` |
| Resources | requests 250m / 512Mi, limits 1 CPU / 512Mi |
| Redis | disabled (single replica uses the in-process cache) |

**Values to change** (VALUES.md): `gitea.example.internal` (ingress host + TLS host),
`admin@example.internal`, PVC sizes in `application.yaml`.

**Secrets (create first, SECRETS.md):**
* `gitea/gitea-admin`: `username`, `password` (the first admin account)
* `gitea/gitea-postgresql`: `password`, `postgres-password`

The chart only knows the database password when it is written inline, so `application.yaml`
passes it to Gitea as `GITEA__DATABASE__PASSWD` from the same Secret PostgreSQL uses.

`passwordMode: initialOnlyNoReset` sets the admin password only when the account is first
created; after that, change it in the UI.

**Sizing:** one replica. The repo volume is ReadWriteOnce, so a second replica could never
mount it, and the strategy is `Recreate` for the same reason. Size the 20Gi for your largest
repositories plus LFS: a full volume fails pushes with "No space left on device".

SSH clone is not exposed; use HTTPS, or add a LoadBalancer Service for port 22.
