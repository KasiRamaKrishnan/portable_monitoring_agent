#!/bin/bash

cd monitoring-deploy

# Exit immediately if a command exits with a non-zero status
set -e

echo "Updating and upgrading system packages..."
sudo apt update -y
sudo apt upgrade -y

echo "Installing software-properties-common..."
sudo apt install -y software-properties-common

echo "Adding Ansible PPA repository..."
sudo add-apt-repository --yes --update ppa:ansible/ansible

echo "Installing Ansible..."
sudo apt install -y ansible

echo "Verifying Ansible installation..."
ansible --version

echo "Ansible installation completed successfully."


sudo apt-get update
sudo apt-get install -y ansible

ansible-playbook -i inventory.ini playbooks/playbook-workers.yml
ansible-playbook -i inventory.ini playbooks/playbook-monitor.yml