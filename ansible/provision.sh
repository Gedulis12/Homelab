#!/usr/bin/env bash

ansible-galaxy collection install git+https://github.com/k3s-io/k3s-ansible.git
ansible-playbook k3s.orchestration.site -i inventory.yaml --vault-password-file vault-pass.txt --become-password-file become-pass.txt
ansible-playbook playbooks/rpi-setup.yaml -i inventory.yaml
kubectl apply -k ../argocd
