CONFIGURAÇÃO DE INFRAESTRUTURA - USUÁRIOS LINUX + CHAVES SSH
Base: /usr/local/sysadmin

COMANDOS (executar como root):

sudo mkdir -p /usr/local/sysadmin/{ssh,users,logs}

sudo touch /usr/local/sysadmin/ssh/ssh-key-rotation.sh
sudo touch /usr/local/sysadmin/ssh/ssh-inventory.ndjson
sudo touch /usr/local/sysadmin/ssh/ssh-inventory.csv
sudo touch /usr/local/sysadmin/users/create-user-linux.sh
sudo touch /usr/local/sysadmin/users/exclude-user-linux.sh
sudo touch /usr/local/sysadmin/users/ssh-token-generate.sh
sudo touch /usr/local/sysadmin/logs/linux-user-provision.log
sudo touch /usr/local/sysadmin/logs/ssh-key-rotation.log

sudo chown -R root:root /usr/local/sysadmin
sudo chmod -R 700 /usr/local/sysadmin
sudo chmod 700 /usr/local/sysadmin/ssh/*.sh
sudo chmod 700 /usr/local/sysadmin/users/*.sh
sudo chmod 600 /usr/local/sysadmin/ssh/*.ndjson
sudo chmod 600 /usr/local/sysadmin/ssh/*.csv
sudo chmod 600 /usr/local/sysadmin/logs/*.log

sudo id djangoctl >/dev/null 2>&1 || sudo useradd -r -m -s /usr/sbin/nologin djangoctl

sudo visudo -f /etc/sudoers.d/sysadmin-django

# Dentro do arquivo cole exatamente:
Defaults!/usr/local/sysadmin/users/ssh-token-generate.sh !requiretty
djangoctl ALL=(root) NOPASSWD: /usr/local/sysadmin/users/ssh-token-generate.sh

sudo visudo -c

NO settings.py DO DJANGO (adicionar):

SYSADMIN = {
    "ROOT": "/usr/local/sysadmin",
    "PROVISION_SCRIPT": "/usr/local/sysadmin/users/ssh-token-generate.sh",
    "SSH_INVENTORY_NDJSON": "/usr/local/sysadmin/ssh/ssh-inventory.ndjson",
    "SERVICE_USER": "djangoctl",
}
