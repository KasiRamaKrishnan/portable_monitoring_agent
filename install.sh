#!/bin/bash

cd monitoring-deploy

# Exit immediately if a command exits with a non-zero status
set -e

echo "🔄 Updating and upgrading system packages..."
sudo apt update -y
sudo apt upgrade -y

echo "📦 Installing dependencies..."
sudo apt install -y software-properties-common

echo "➕ Adding Ansible PPA repository..."
sudo add-apt-repository --yes --update ppa:ansible/ansible

echo "⚙️ Installing Ansible..."
sudo apt install -y ansible

echo "✅ Verifying Ansible installation..."
ansible --version

echo "🛠️ Disabling SSH host key checking..."
# Ensure Ansible config directory exists
mkdir -p ~/.ansible
# Create or update ansible.cfg to disable host key checking
cat <<EOF > ~/.ansible.cfg
[defaults]
host_key_checking = False
EOF

# Also disable host key checking globally via environment variable
if ! grep -q "ANSIBLE_HOST_KEY_CHECKING=False" ~/.bashrc; then
  echo "export ANSIBLE_HOST_KEY_CHECKING=False" >> ~/.bashrc
fi
source ~/.bashrc

echo "🎉 Ansible installation and configuration completed successfully!"


ansible-playbook -i inventory.ini playbooks/playbook-workers.yml
ansible-playbook -i inventory.ini playbooks/playbook-monitor.yml