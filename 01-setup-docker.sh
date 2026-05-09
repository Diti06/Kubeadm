#!/bin/bash
# 01-setup-docker.sh
# Target: Master and Worker Nodes
# OS: Ubuntu 20.04
# Description: Installs Docker and configures the cgroup driver to systemd (required by Kubernetes).

set -eo pipefail

echo "========================================="
echo " Installing Docker Container Runtime     "
echo "========================================="

# 1. Update and install prerequisites
echo "[1/5] Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common

# 2. Add Docker's official GPG key
echo "[2/5] Adding Docker GPG key..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

# 3. Set up the repository
echo "[3/5] Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 4. Install Docker Engine
echo "[4/5] Installing Docker Engine..."
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. Configure Docker to use systemd as the cgroup driver (CRITICAL for Kubeadm)
echo "[5/5] Configuring Docker daemon..."
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "========================================="
echo " Docker installation completed successfully!"
echo "========================================="
