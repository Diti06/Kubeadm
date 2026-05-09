#!/bin/bash
# 05-deploy-openfaas.sh
# Target: Master Node
# OS: Ubuntu 20.04
# Description: Installs Helm, deploys OpenFaaS, and creates the Python factorial function.

set -eo pipefail

echo "========================================="
echo " Deploying OpenFaaS & Factorial Function "
echo "========================================="

# Ensure DOCKER_USERNAME is set because OpenFaaS needs to push the built image to a registry 
# so that the worker nodes can pull it.
if [ -z "$DOCKER_USERNAME" ]; then
    echo "ERROR: DOCKER_USERNAME environment variable is not set."
    echo "Worker nodes need to pull the function image from a registry."
    echo "Please set it: export DOCKER_USERNAME=your_dockerhub_username"
    echo "Make sure you are logged in via 'docker login' as well."
    exit 1
fi

# 1. Install Helm
echo "[1/6] Installing Helm..."
if ! command -v helm &> /dev/null; then
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
else
    echo "Helm is already installed."
fi

# 2. Add OpenFaaS Helm repo and install OpenFaaS
echo "[2/6] Deploying OpenFaaS via Helm..."
helm repo add openfaas https://openfaas.github.io/faas-netes/
helm repo update

# We use create-namespace and generateBasicAuth=false for easier load testing, 
# or keep auth and export the password. We will keep auth disabled for raw performance testing.
helm upgrade openfaas --install openfaas/openfaas \
    --namespace openfaas \
    --create-namespace \
    --set functionNamespace=openfaas-fn \
    --set generateBasicAuth=false \
    --set rbac=false

# 3. Wait for OpenFaaS Gateway to be ready
echo "[3/6] Waiting for OpenFaaS gateway to rollout..."
kubectl rollout status -n openfaas deploy/gateway --timeout=3m

# 4. Install FaaS CLI
echo "[4/6] Installing faas-cli..."
if ! command -v faas-cli &> /dev/null; then
    curl -sL https://cli.openfaas.com | sudo sh
else
    echo "faas-cli is already installed."
fi

# Set the OpenFaaS URL
export OPENFAAS_URL=http://127.0.0.1:31112

# 5. Create the Factorial Function
echo "[5/6] Creating Python 3 Factorial function..."
mkdir -p openfaas-functions
cd openfaas-functions
faas-cli template store pull python3
faas-cli new factorial --lang python3 --prefix="${DOCKER_USERNAME}"

# Write the factorial logic
cat << 'EOF' > factorial/handler.py
import sys
import math

def handle(req):
    """handle a request to the function
    Args:
        req (str): request body
    """
    try:
        # We calculate factorial of 500 as described in the paper to place pressure on the CPU.
        num = 500
        result = math.factorial(num)
        return f"Factorial of {num} calculated successfully. Length of result: {len(str(result))}"
    except Exception as e:
        return str(e)
EOF

# 6. Build, Push, and Deploy
echo "[6/6] Building, Pushing, and Deploying the Factorial function..."
faas-cli up -f factorial.yml

echo "==================================================================================="
echo " OpenFaaS and Factorial Function deployed!"
echo " Test it manually: curl http://127.0.0.1:31112/function/factorial"
echo "==================================================================================="
