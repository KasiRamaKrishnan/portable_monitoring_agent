ssh -i ~/.ssh/id_rsa azureuser@<publicIP of Monitoring Node>

ssh -i ~/id_rsa azureuser@10.0.1.4
ssh -i ~/id_rsa azureuser@10.0.1.6

sudo apt-get update
sudo apt-get install -y ansible

ansible-playbook -i inventory.ini playbooks/playbook-workers.yml
ansible-playbook -i inventory.ini playbooks/playbook-monitor.yml