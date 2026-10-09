# Trilium Notes

Hierarchical note-taking / personal knowledge base, served at `https://trilium.example.internal`.

| | |
|---|---|
| Form | plain manifests: Namespace, PVC, Deployment (`Recreate`), Service, Ingress |
| Image | `zadam/trilium:latest` (**unpinned**, as in the original homelab). Upstream development continues as TriliumNext (`triliumnext/notes`); pin a tag you have tested. |
| Storage | PVC `trilium-data`, 5Gi, StorageClass `longhorn`, mounted at `/home/node/trilium-data` |
| Resources | requests 100m CPU / 256Mi, limit 1Gi |

**Values to change** (VALUES.md): `trilium.example.internal` in `ingress.yaml`; PVC size and
StorageClass in `trilium.yaml`.

**Secrets:** none. You set the password in the web UI on first visit, so open it right after
the first sync.

The ingress allows 1 GiB uploads (`proxy-body-size`) for attachments and imports.
