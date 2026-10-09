# Nextcloud

File sync and share, calendar and contacts, at `https://nextcloud.example.internal`.

| | |
|---|---|
| Form | ArgoCD `Application`, official Helm chart `nextcloud` **6.0.0** (`https://nextcloud.github.io/helm/`) |
| Image | chart default for Nextcloud; bundled PostgreSQL image `tag: latest` (**unpinned on purpose**, see apps/gitea) |
| Database | bundled PostgreSQL (`internalDatabase.enabled: false` + `externalDatabase.type: postgresql`), not the chart's SQLite default |
| Storage | data PVC 10Gi + PostgreSQL PVC 2Gi, StorageClass `longhorn` |
| Resources | requests 250m / 512Mi, limits 1 CPU / 1Gi |

**Values to change** (VALUES.md): `nextcloud.example.internal` in both `nextcloud.host` and
the ingress TLS host; PVC sizes.

**Secrets (create first, SECRETS.md):**
* `nextcloud/nextcloud-admin`: `nextcloud-username`, `nextcloud-password`
* `nextcloud/nextcloud-db`: `db-username` (= `nextcloud`), `db-password`, `postgres-password`

`offline.config.php` turns off the update checker and internet-connectivity checks, for
LAN-only installs. Delete it if your instance has internet access and you want the app store.

**Sizing:** Nextcloud is the heaviest app here. On a cluster with a single small worker
(4 GiB), comment it out in `apps/kustomization.yaml` rather than squeezing it in. Uploads are
limited to 512 MiB per request by the ingress (`proxy-body-size`); the desktop client chunks
larger files.
