# Kubernetes (K3S) homelab

## Hardware

| Host               | CPU                        | Memory     | Storage                                                                              | Networking |
|--------------------|----------------------------|------------|--------------------------------------------------------------------------------------|------------|
| Raspberry Pi 4 B   | Broadcom BCM2711 @ 1.80Ghz | 8 Gb DDR4  | SSD 128 GB                                                                           | 1 GB       |
| Old PC Tower       | Intel i5-4570 @ 3.60GHz    | 8 Gb DDR3  | <p>SSD 128 GB</p><p>WD Red Plus 4TB @ 5400 RPM</p><p>Toshiba N300 4TB @ 7200 RPM</p> | 1 GB       |
| Intel n200 mini pc | Intel n200 @ 3.70GHz       | 16 Gb DDR4 | SSD 512 GB                                                                           | 1 GB       |


## Features

### Cluster and application deployment
- K3S cluster provisioning via [Ansible](./ansible)
- All [applications](./apps) are declaratively deployed via [ArgoCD](./argocd)

### Storage
- Persistent storage aquired via NFS mount `/mnt/fast` on n200s NVMe ssd

### Networking
- [Cilium](./apps/cilium) used as a CNI.
  - [LB IPAM](https://docs.cilium.io/en/stable/network/lb-ipam/) via [L2 Announcments](https://docs.cilium.io/en/stable/network/l2-announcements/#l2-announcements) used to acquire ip addressess for `LoadBalancer` Services
  - [Gateway API](https://docs.cilium.io/en/latest/network/servicemesh/gateway-api/gateway-api/) used to expose services externally
- DNS for exposed services managed via [k8s-gateway](./apps/k8s-gateway/)
- Remote access to exposed services and local network is enabled via [tailscale operator](./apps/tailscale/)

### Observability
- [Grafana](./apps/observability/grafana) for dashboards and alerts
- All [grafana resources](./apps/observability/grafana-resources/) are provisioned via [Grafana opeartor](./apps/observability/grafana-operator/)
- [Loki](./apps/observability/loki/) for logs
- [Prometheus](./apps/observability/prometheus/) for metrics
- [Tempo](./apps/observability/tempo/) for traces
- [Pyroscope](./apps/observability/pyroscope/) for profiles
- All observability signals collected using alloy deployed as [k8s-monitoring-helm](./apps/observability/k8s-monitoring-helm/)

### Backups
- Automatic backups managed via [k8up](./apps/backup)

### Certificates
- Automatic certificate management via [cert-manager](./apps/cert-manager)

### Secrets
- All secrets are commited to version controll. Secrets are encrypted with the help of [kubeseal](https://github.com/bitnami-labs/sealed-secrets?tab=readme-ov-file#kubeseal) and managed by [sealed secrets](./apps/sealed-secrets/) operator

### Resource utilization
- Automatically spreading Memory and CPU utilization evenly accross nodes via [descheduler](./apps/descheduler)
