# Cluster provisioning

Using [k3s-ansible](https://github.com/k3s-io/k3s-ansible) playbooks to provision k3s cluster via ansible galaxy.

## Prerequisites

`inventory.yml` file present and populated following the structure provided in [example](https://github.com/k3s-io/k3s-ansible/blob/master/inventory-sample.yml)

`become-password.txt` file present and populated with root password on k3s cluster nodes

`vault-password.txt` file present and populated with ansible-vault password

## Usage

`provision.sh` - provisions new k3s cluster with configuration provided in `inventory.yml`

`reset.sh` - uninstalls k3s cluster

`upgrade.sh` - upgrades k3s version on the cluster nodes with the one provided in `inventory.yml`
