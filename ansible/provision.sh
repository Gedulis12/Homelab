#!/usr/bin/env bash

ansible-galaxy collection install git+https://github.com/k3s-io/k3s-ansible.git
ansible-playbook k3s.orchestration.site -i inventory.yml --vault-password-file vault-pass.txt --become-password-file become-pass.txt
