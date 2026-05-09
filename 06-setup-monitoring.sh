#!/bin/bash
# 06-setup-monitoring.sh
# Target: Measurement Node
# OS: Ubuntu 20.04
# Description: Installs Prometheus, Grafana, and K6 on the measurement node.

set -eo pipefail

echo "========================================="
echo " Setting up Measurement Node             "
echo "========================================="

if [ -z "$MASTER_IP" ]; then
    echo "ERROR: MASTER_IP environment variable is not set."
    echo "Please set it: export MASTER_IP=your_master_node_ip"
    exit 1
fi

# 1. Install Docker (needed for Prometheus/Grafana)
echo "[1/4] Installing Docker..."
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose
sudo systemctl enable --now docker

# 2. Create Prometheus config
echo "[2/4] Creating Prometheus config..."
mkdir -p monitoring
cat <<EOF > monitoring/prometheus.yml
global:
  scrape_interval: 5s

scrape_configs:
  - job_name: 'openfaas'
    static_configs:
      - targets: ['$MASTER_IP:31112'] # Assuming OpenFaaS Gateway is on NodePort 31112
EOF

# 3. Create Docker Compose file for Prometheus and Grafana
echo "[3/4] Creating Docker Compose for Prometheus and Grafana..."
cat <<EOF > monitoring/docker-compose.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    restart: unless-stopped
EOF

# 4. Install K6 Load Testing Tool
echo "[4/4] Installing K6..."
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update -y
sudo apt-get install k6 -y

# Start Monitoring Services
echo "Starting Prometheus and Grafana..."
cd monitoring
sudo docker-compose up -d

echo "==================================================================================="
echo " Measurement Node setup complete!"
echo " Grafana is running at http://localhost:3000 (admin/admin)"
echo " Prometheus is running at http://localhost:9090"
echo " K6 is installed and ready."
echo "==================================================================================="
