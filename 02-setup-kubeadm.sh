#!/bin/bash
# 02-setup-kubeadm.sh
# Target: Master and Worker Nodes
# OS: Ubuntu 20.04
# Description: Configures networking, disables swap, and installs kubeadm, kubelet, and kubectl (v1.27.x).

set -eo pipefail

echo "========================================="
echo " Installing Kubernetes Components        "
echo "========================================="

# 1. Disable swap (CRITICAL: kubelet will fail to start if swap is enabled)
echo "[1/4] Disabling swap..."
sudo swapoff -a
# Keep swap off after reboot
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 2. Configure networking modules and sysctl
echo "[2/4] Configuring networking for Kubernetes..."
# Load required modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

# 3. Add Kubernetes repository (v1.27)
echo "[3/4] Adding Kubernetes repository..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.27/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg --yes

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.27/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 4. Install kubelet, kubeadm and kubectl
echo "[4/4] Installing kubelet, kubeadm, and kubectl..."
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
# Mark them as hold to prevent automatic accidental upgrades that could break the cluster
sudo apt-mark hold kubelet kubeadm kubectl

# Enable kubelet service
sudo systemctl enable --now kubelet

echo "========================================="
echo " Kubernetes components installed!"
echo "========================================="
