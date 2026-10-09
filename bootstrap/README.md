# Bootstrap: ArgoCD and the cluster platform

After this step ArgoCD owns the cluster: every later change is a git commit.

```
bootstrap/
├── kustomization.yaml     # kubectl apply -k bootstrap/  (run once)
├── platform-app.yaml      # Application "platform" -> bootstrap/platform/
├── root-app.yaml          # Application "apps"     -> apps/   (app-of-apps)
├── argocd-ingress.yaml    # ArgoCD UI at argocd.example.internal
└── platform/
    ├── cert-manager/      # chart v1.15.3 + self-signed ClusterIssuer
    ├── ingress-nginx/     # chart 4.11.2
    ├── metallb/           # chart 0.14.8 + IPAddressPool / L2Advertisement
    ├── longhorn/          # chart 1.7.1 (default StorageClass "longhorn") + daily snapshots
    └── metrics-server/    # chart 3.12.1 (kubectl top, HPAs)
```

## 1. Install ArgoCD

ArgoCD is installed once from its upstream manifest. It is not in `apps/` because it cannot
install itself.

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.3/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server
```

(v2.12.3 is an example pin; any current 2.x release works. Pin whatever you install.)

## 2. Point ArgoCD at your fork

Replace `REPLACE_ME_GIT_REPO_URL` in `platform-app.yaml` and `root-app.yaml` with your fork's
URL, set your domain in `argocd-ingress.yaml`, commit and push. If the fork is private, add
it under ArgoCD Settings -> Repositories first (see SECRETS.md).

## 3. Set the MetalLB range

Edit `platform/metallb/ip-pool.yaml` so the range is free on your LAN and outside your DHCP
pool. Commit and push.

## 4. Create the Secrets, then apply

Create the Secrets in [SECRETS.md](../SECRETS.md), then:

```bash
kubectl apply -k bootstrap/
```

ArgoCD now syncs `platform` (sync wave -10) and `apps` (wave 0). Charts install their CRDs, and
the custom resources (`IPAddressPool`, `ClusterIssuer`, `RecurringJob`) carry
`SkipDryRunOnMissingResource=true`, so the first sync retries until the CRDs exist. Expect a
few minutes of `Progressing` and one or two retries.

```bash
kubectl -n argocd get applications          # wait for Synced / Healthy
kubectl -n ingress-nginx get svc ingress-nginx-controller   # EXTERNAL-IP = first MetalLB address
```

## 5. Log in

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

User `admin`. Change the password under User Info, then
`kubectl -n argocd delete secret argocd-initial-admin-secret`.

## Platform notes

* **Longhorn** needs the Talos extensions from `talos/schematic.yaml` and the kubelet mount in
  `talos/patches/common.yaml`. Its UI has **no authentication**, so it has no ingress here;
  use `kubectl -n longhorn-system port-forward svc/longhorn-frontend 8080:80`.
* **Longhorn replicas** default to 1 (`persistence.defaultClassReplicaCount`). With one copy,
  losing the storage node's disk loses the data. Raise it when you have more storage nodes.
* **Snapshots are not backups.** `daily-snapshot` keeps 7 snapshots on the same disks.
  Configure a Longhorn backup target (NFS or S3) for off-node copies.
* **cert-manager** issues self-signed certificates. For browser-trusted ones add an ACME
  ClusterIssuer (Let's Encrypt, DNS-01) for a domain you own and change the
  `cert-manager.io/cluster-issuer` annotations.
* **metrics-server** runs with `--kubelet-insecure-tls` because Talos kubelets use
  self-signed serving certificates by default.
