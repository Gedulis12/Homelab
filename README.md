# Homelab

## Hardware

- Raspberry Pi 4 model B
  - RAM: `8 GB`
  - SSD: `128GB`

- Old PC Tower
  - RAM: `8 GB`
  - CPU: `Intel i5-4570 @ 3.60GHz`
  - SSD: `128 GB`
  - HDD: `WD Red Plus 4TB @ 5400 RPM`

- Networking
 - 1 Gb via unmanaged switch and off the shelf TP-Link SOHO router.

## Features

- [X] automatic k3s provisioning via [Ansible](https://docs.ansible.com/ansible/latest/index.html)
- [X] application installation and management using [GitOps](https://about.gitlab.com/topics/gitops/) principles via [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) app-of-apps pattern
- [X] [Kubernetes](https://kubernetes.io/) manifests declared using [Kustomize](https://kustomize.io/)
- [ ] persistent storage managed via [Longhorn](https://longhorn.io/)
- [ ] App updates raised by automatic PRs (approval needed)
- [X] Automatic DNS management via coreDNS
- [X] Automatic certificate management via cert-manager
- [ ] Monitoring and alerting via [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [ ] Single sign-on

