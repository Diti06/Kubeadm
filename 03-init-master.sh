#!/bin/bash
# 03-init-master.sh
# Target: Master Node Only
# OS: Ubuntu 20.04
# Description: Initializes the Kubernetes cluster and installs the Calico CNI plugin.

set -eo pipefail

echo "========================================="
echo " Initializing Kubernetes Master Node     "
echo "========================================="

if [ -z "$INTERNAL_IP" ]; then
    echo "ERROR: INTERNAL_IP environment variable is not set."
    echo "Because of the dual-network isolation, you must specify the IP address of the Master node that is on the WORKER LAN."
    echo "Please run 'ip a' or 'ifconfig' to find the IP that connects to the workers."
    echo "Then set it: export INTERNAL_IP=your_master_internal_ip"
    exit 1
fi

# 1. Initialize Kubeadm
# The pod network CIDR 192.168.0.0/16 is the default required by Calico.
echo "[1/4] Running kubeadm init..."
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=$INTERNAL_IP

# 2. Setup kubeconfig for the current user
echo "[2/4] Setting up kubeconfig for user: $USER..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 3. Install Calico CNI plugin
echo "[3/4] Installing Calico CNI (v3.26.1 for K8s 1.27+ compatibility)..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# 4. Generate Join Command for Worker Nodes
echo "[4/4] Generating join command for workers..."
JOIN_COMMAND=$(kubeadm token create --print-join-command)

echo "==================================================================================="
echo " Master Node Initialized Successfully!"
echo " "
echo " IMPORTANT: Run the following command on all 3 Worker Nodes to join them to the cluster:"
echo " "
echo " sudo $JOIN_COMMAND"
echo " "
echo " We have also saved this command to '04-join-workers.sh' in the current directory."
echo "==================================================================================="

# Automatically generate the script for workers
cat <<EOF > 04-join-workers.sh
#!/bin/bash
# 04-join-workers.sh
# Target: Worker Nodes Only
# Description: Joins the worker node to the Kubernetes cluster.

set -eo pipefail

echo "Joining cluster..."
sudo $JOIN_COMMAND

echo "Successfully executed join command!"
EOF

chmod +x 04-join-workers.sh
