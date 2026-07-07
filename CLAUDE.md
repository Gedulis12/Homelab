# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo is a GitOps homelab: a K3s Kubernetes cluster running across three nodes (a Raspberry Pi 4B, an old PC tower, and an Intel N200 mini PC), provisioned with Ansible and deployed declaratively via ArgoCD. There is no application source code here — every change is a Kubernetes manifest, Helm values file, or Ansible playbook.

## Repository layout

- `ansible/` — cluster provisioning (k3s install/upgrade/reset) using the `k3s-ansible` Galaxy collection.
- `apps/` — one directory per application/component, each a self-contained Kustomize base.
- `argocd/` — ArgoCD's own install plus one `Application` manifest per app in `argocd/apps/`, all managed by a root `app-of-apps` Application (App of Apps pattern).

## Common commands

There is no build/test/lint tooling — validation means rendering manifests and checking they apply cleanly.

```bash
# Render a single app's manifests (matches how ArgoCD renders them — helm plugin required for apps with helmCharts)
kubectl kustomize apps/<app> --enable-helm

# Validate structure without a live cluster
kustomize build apps/<app> --enable-helm

# Apply directly (bypassing ArgoCD, e.g. for bootstrap or debugging)
kubectl apply -k apps/<app>

# Cluster provisioning (run from ansible/)
./provision.sh   # bootstrap a new cluster + install Cilium + ArgoCD
./upgrade.sh     # upgrade k3s version on nodes
./reset.sh       # tear down k3s from all nodes
```

`provision.sh` requires `inventory.yaml`, `become-pass.txt` (root password), and `vault-pass.txt` (ansible-vault password) in `ansible/` — none of these are committed.

## Architecture

### App structure (`apps/<name>/`)

Each app is an independent Kustomize base (`kustomization.yaml`) deployed to its own namespace. Common building blocks, mixed and matched per app:

- **`helmCharts:`** in `kustomization.yaml` pulls a Helm chart inline (e.g. `cilium`, `authentik`, `k8up`/`backup`, `tailscale`) with a sibling `values.yaml`. Vendored chart sources sometimes appear under `charts/` (fetched by kustomize, not hand-maintained).
- **Plain manifests** (`deployment.yaml`, `service.yaml`, `pvc.yaml`, `httproute.yaml`) for simpler apps with no upstream chart (e.g. `linkding`, `thelounge`, `it-tools`, `homepage`).
- **`patches:`** (JSON6902 or strategic merge) layered on top of a helm chart or remote resource to tweak generated objects — e.g. adding a `k8s.grafana.com/scrape` annotation to a Service, or editing controller args.
- Apps with a database include a `cloudnative-pg.yaml` defining a CloudNativePG `Cluster`. Storage-backed clusters typically pair a `Cluster` with a static `PersistentVolume` pointing at an NFS path (see `apps/maistokainos/cloudnative-pg.yaml`), since the cluster has no dynamic NFS provisioner.
- Apps needing scheduled backups pair a `Schedule` (recurring, `k8up.io/v1`) and/or one-off `Backup` resource, referencing the shared `backup-secret` (restic password + B2 credentials) created by the `backup` app. Apps whose data needs a consistent pre-backup step add a `pre-backup-pod.yaml`.
- Multi-component apps (e.g. `media/`) nest one subdirectory per component (`jellyfin/`, `sonarr/`, `radarr/`, `qbittorrent/`, `prowlarr/`), each listed as a `resources:` entry in the parent kustomization, sharing one namespace.
- `env.conf` + `configMapGenerator` is used for plain (non-secret) environment configuration (see `maistokainos`).

### Secrets

All secrets are committed to git, encrypted as `SealedSecret` resources (bitnami `sealed-secrets` controller decrypts them cluster-side). Never commit a plain `Secret` with real data — only `SealedSecret` output (`kubeseal`) or `secret.yaml` template files that describe shape without real values. The sealed-secrets controller's private key is itself ansible-vault-encrypted at `ansible/playbooks/vars/sealed-secret-key.yaml`.

### Networking

- Cilium is the CNI, providing both LB IPAM (via L2 announcements, for `LoadBalancer` Services) and Gateway API support for external exposure — most apps expose themselves via an `HTTPRoute` (`httproute.yaml`), not `Ingress`.
- `k8s-gateway` handles DNS for exposed services; Tailscale operator provides remote access into the cluster network.

### Observability

Grafana/Loki/Prometheus/Tempo/Pyroscope stack under `apps/observability/`, fed by Alloy (`k8s-monitoring-helm`). Grafana resources (dashboards, alerts, datasources) are provisioned as CRDs via the Grafana Operator, not the Grafana UI. Apps opt into scraping via annotations: `k8s.grafana.com/scrape: "true"` (metrics) and `profiles.grafana.com/{cpu,memory,goroutine}.scrape: "true"` (continuous profiling).

### Storage

Persistent storage is an NFS mount from the N200's NVMe SSD (`192.168.0.222`, exported paths under `/mnt/fast`). PVs reference NFS paths directly rather than going through a dynamic provisioner; a `local-storage` StorageClass exists for node-local volumes.

### ArgoCD wiring

Adding a new app requires two things: the app's Kustomize base under `apps/<name>/`, and a corresponding `Application` manifest in `argocd/apps/<name>.yaml` (copy an existing one, pointing `source.path` at `apps/<name>`). The root `app-of-apps` Application watches `argocd/apps/` and syncs everything in it automatically (`prune: true`, `selfHeal: true`) — new `Application` files are picked up without manual `argocd app create`. The ArgoCD kustomization itself sets `kustomize.buildOptions: --enable-helm` cluster-wide via a patch to `argocd-cm`, so ArgoCD can render apps using `helmCharts:`.
