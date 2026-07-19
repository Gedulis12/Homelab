# Kubernetes (K3S) homelab

[![K3s](https://img.shields.io/badge/k3s-v1.33-ffcc00?logo=k3s&logoColor=white)](https://k3s.io)
[![Cilium](https://img.shields.io/badge/networking-cilium-1793d1?logo=cilium&logoColor=white)](https://cilium.io)
[![ArgoCD](https://img.shields.io/badge/gitops-argocd-ef7b4d?logo=argo&logoColor=white)](https://argo-cd.readthedocs.io)
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.33-326ce5?logo=kubernetes&logoColor=white)](https://kubernetes.io)

K3s cluster with three nodes. All components deployed via ArgoCD.

---

## Hardware

| Host               | CPU                        | Memory     | Storage                                                                              | Networking |
|--------------------|----------------------------|------------|--------------------------------------------------------------------------------------|------------|
| Raspberry Pi 4 B   | Broadcom BCM2711 @ 1.80GHz | 8 GB DDR4  | SSD 128 GB                                                                           | 1 Gb       |
| Old PC Tower       | Intel i5-4570 @ 3.60GHz    | 8 GB DDR3  | SSD 128 GB<br/>WD Red Plus 4TB @ 5400 RPM<br/>Toshiba N300 4TB @ 7200 RPM            | 1 Gb       |
| Intel N200 mini PC | Intel N200 @ 3.70GHz       | 16 GB DDR4 | NVMe SSD 512 GB (served as NFS)                                                      | 1 Gb       |

---

## Networking

- **CNI**: [Cilium](./apps/cilium) with eBPF.
- **LoadBalancer IPs**: Cilium LB IPAM via L2 announcements. Services of type `LoadBalancer` get cluster-internal IPs announced on the LAN.
- **External exposure**: [Gateway API](https://docs.cilium.io/en/latest/network/servicemesh/gateway-api/gateway-api/). Each app exposes itself via an `HTTPRoute` resource attached to the `cilium-shared-gateway` Gateway in `kube-system`.
- **DNS**: [k8s-gateway](./apps/k8s-gateway) resolves `*.g2net.xyz` to Cilium LoadBalancer IPs.
- **Remote access**: [Tailscale Operator](./apps/tailscale) provides access to the cluster network.

---

## Storage

- **Primary storage**: NFS mount from tvinksonas (Old PC Tower) at `/mnt/data` for bulk HDD-backed storage.
- **Fast storage**: NFS mount at `/mnt/fast` for workloads that need faster I/O.
- **Database persistence**: CloudNativePG manages PostgreSQL databases with PVCs backed by NFS. Backups configured per-cluster with scheduled WAL archiving.

Apps mount NFS with `noatime,hard,timeo=600,retrans=2`.

---

## Security & Identity

- **SSO**: [Authentik](./apps/authentik) is the identity provider. Apps integrate via OIDC/OAuth2 where supported.
- **Secrets**: All secrets are committed to Git encrypted as `SealedSecret` resources (Bitnami SealedSecrets). The controller's private key is backed up in Ansible Vault.

---

## Observability

All signals are collected by [Alloy](https://grafana.com/docs/alloy/latest/) (deployed via the `k8s-monitoring-helm` chart) and routed to their respective backends:

| Signal | Backend | Ingestion |
|--------|---------|-----------|
| Metrics | Prometheus / kube-prometheus-stack | Alloy scrapes, remote-writes |
| Logs | Loki | Alloy collects pod logs, pushes via HTTP |
| Traces | Tempo | Alloy receives OTLP, forwards via gRPC |
| Profiles | Pyroscope | Alloy scrapes pprof endpoints + Beyla eBPF |

Apps opt into scraping via annotations:
- **Metrics**: `k8s.grafana.com/scrape: "true"`
- **Profiling**: `profiles.grafana.com/{cpu,memory,goroutine}.scrape: "true"`

Grafana resources (datasources, dashboards, alert rules) are provisioned as CRDs via the [Grafana Operator](./apps/observability/grafana-operator).

---

## Backups

- **Operator**: [k8up](./apps/backup) (restic-based) manages scheduled and on-demand backups.
- **Storage**: Backblaze B2 (credentials stored as a SealedSecret).
- **Schedule**: Configurable per-app via `k8up.io/backup: "true"` annotation.
- **Pre-backup hooks**: Apps with databases run a pre-backup Pod (e.g., `pg_dump` via CloudNativePG hooks) to ensure consistent snapshots.
- **Restoration**: One-off `Backup` / `Restore` custom resources.

---

## Repository structure

```
├── ansible/              # K3s cluster provisioning & upgrade
├── apps/                 # One directory per application (Kustomize base)
│   ├── <name>/
│   │   ├── kustomization.yaml
│   │   ├── values.yaml          # Helm values (for helmCharts-based apps)
│   │   ├── pvc.yaml             # Static PV + PVC (NFS-backed)
│   │   ├── httproute.yaml       # Gateway API route
│   │   ├── sealed-secret.yaml   # Encrypted secrets
│   │   ├── cloudnative-pg.yaml  # PostgreSQL cluster definition
│   │   └── ...                  # App-specific manifests
│   ├── media/                   # Multi-component: jellyfin/, sonarr/, ...
│   └── observability/           # Multi-component: grafana/, loki/, ...
├── argocd/               # ArgoCD installation + Application manifests
│   ├── kustomization.yaml
│   └── apps/                    # One Application per deployed app (auto-discovered)
├── AGENTS.md             # AI-assisted development workflow guide
└── README.md
```

See [AGENTS.md](./AGENTS.md) for CLI commands and AI tooling workflows.

---

## Quick reference

```bash
# Render manifests for an app (how ArgoCD renders them)
kubectl kustomize apps/<name> --enable-helm

# Validate structure without a live cluster
kustomize build apps/<name> --enable-helm

# Cluster provisioning (run from ansible/)
./provision.sh   # bootstrap a new cluster
./upgrade.sh     # upgrade k3s version on nodes
./reset.sh       # tear down k3s from all nodes
```
