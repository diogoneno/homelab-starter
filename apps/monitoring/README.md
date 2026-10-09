# Monitoring: kube-prometheus-stack

Prometheus, Alertmanager, Grafana, node-exporter and kube-state-metrics with the standard
Kubernetes dashboards and alerts. Grafana at `https://grafana.example.internal`.

| | |
|---|---|
| Form | Namespace (privileged PSA, node-exporter needs host access) + ArgoCD `Application`, chart `kube-prometheus-stack` **62.3.1** |
| Prometheus | retention 10d, request 256Mi, limit 1000Mi, no PVC (data is lost on restart; add `storageSpec` for persistence) |
| Grafana | request 50Mi, limit 200Mi |

**Values to change** (VALUES.md): `grafana.example.internal` (two places in
`application.yaml`).

**Secrets (create first, SECRETS.md):** `monitoring/grafana-admin` with `admin-user`,
`admin-password`. Without it Grafana falls back to the chart's well-known default password.

Prometheus and Alertmanager have no authentication, so they get no ingress. Reach them with:

```bash
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 9090
kubectl -n monitoring port-forward svc/kube-prometheus-stack-alertmanager 9093
```

## Scraping machines outside the cluster

Add jobs under `prometheus.prometheusSpec.additionalScrapeConfigs` in `application.yaml`, for
example node-exporter and an NVIDIA GPU exporter on other hosts:

```yaml
additionalScrapeConfigs:
  - job_name: node-remote
    static_configs:
      - targets: ['192.0.2.50:9100']
        labels:
          host: example-host-1
  - job_name: gpu
    static_configs:
      - targets: ['192.0.2.51:9835']
        labels:
          host: example-host-2
```

Test reachability **from a pod in the cluster** (e.g. `kubectl run -it --rm curl --image=curlimages/curl -- curl -s -o /dev/null -w '%{http_code}' http://192.0.2.50:9100/metrics`),
not from your workstation: firewalls often treat the two differently.
