#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

echo "==> Updating System Packages..."
apt-get update && apt-get upgrade -y

echo "==> Installing Core Utilities..."
apt-get install -y curl wget git htop net-tools unzip jq vim tmux ufw

echo "==> Creating devops_user..."
if id "devops_user" &>/dev/null; then
    echo "User already exists"
else
    useradd -m -s /bin/bash devops_user
    echo "devops_user:Password123!" | chpasswd
    usermod -aG sudo devops_user
fi

echo "==> Securing SSH (Disabling Root Login)..."
sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

echo "==> Configuring UFW Firewall..."
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp

echo "==> Fresh Server Setup Complete! 🚀"
