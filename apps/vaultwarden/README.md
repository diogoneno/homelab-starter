# Vaultwarden

Lightweight Bitwarden-compatible password manager server, at `https://vaultwarden.example.internal`.
Works with the official Bitwarden browser extensions and apps ("self-hosted" server URL).

| | |
|---|---|
| Form | plain manifests: Namespace, PVC, Deployment (`Recreate`), Service, Ingress with TLS |
| Image | `vaultwarden/server:latest` (**unpinned**); pin a release for controlled upgrades |
| Storage | PVC `vaultwarden-data`, 2Gi, StorageClass `longhorn`, mounted at `/data` (SQLite DB + attachments) |
| Resources | requests 50m CPU / 64Mi, limit 256Mi |

**Values to change** (VALUES.md): `vaultwarden.example.internal` in `ingress.yaml` **and** the
`DOMAIN` env in `vaultwarden.yaml`; PVC size.

**Secrets:** optional `vaultwarden/vaultwarden-admin` with key `ADMIN_TOKEN` (an Argon2 hash)
enables the `/admin` panel. Without it the panel is disabled. See SECRETS.md.

**After you create your account,** set `SIGNUPS_ALLOWED` to `"false"` in `vaultwarden.yaml`
and push. Otherwise anyone who can reach the URL can register. Invite more users from
`/admin` afterwards.

Bitwarden clients require HTTPS. With the self-signed issuer, import the certificate into your
devices' trust store, or switch to an ACME issuer.

Back up `/data` (Longhorn backup target or an export from the client): it is your vault.
