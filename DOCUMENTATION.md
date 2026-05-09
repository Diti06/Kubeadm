# CloudLab Kubernetes & OpenFaaS Benchmark Reproduction

This repository contains the complete, automated implementation designed to reproduce the performance benchmarking experiments detailed in the paper: **"Kubernetes in Action: Exploring the Performance of Kubernetes Distributions in the Cloud"**.

Specifically, this setup reproduces the **Kubeadm distribution** benchmarks running **OpenFaaS**, utilizing **Docker** as the container runtime over a **Xen Paravirtualized (PV)** environment.

---

## 1. Architecture & Topology Overview

The experiment relies on a **5-Node Architecture** with a strict **Dual-Network Isolation Layer**.

### Hardware Specifications
- **Nodes**: 5 (1 Master, 3 Workers, 1 Measurement Node)
- **Hardware Type**: `c6620` (Hardcoded as per the paper)
- **Virtualization**: `XenVM` (Paravirtualization enabled for 0% emulation overhead and direct hardware access)
- **OS**: Ubuntu 20.04

### Dual-Network Isolation
To ensure the heavy HTTP load from the measurement node does not artificially bottleneck internal Kubernetes heartbeat/control-plane traffic, the Master node bridges two physical networks:
1. **Cluster LAN (10.10.1.X)**: Connects the Master (`10.10.1.1`) to the 3 Worker nodes (`10.10.1.2`, `10.10.1.3`, `10.10.1.4`).
2. **Measurement Link (10.10.2.X)**: A direct Point-to-Point link connecting the Master (`10.10.2.1`) to the Measurement Node (`10.10.2.2`).

---

## 2. File Directory Breakdown

### CloudLab Provisioning
- **`profile.py`**: The `geni-lib` Python script used to instantiate the experiment on CloudLab. It provisions the `c6620` XenVMs, builds the dual-network topology, and automatically runs `git clone` on startup to pull these scripts into every node.

### Node Setup & Execution Scripts
- **`01-setup-docker.sh`**: Installs Docker and configures the `systemd` cgroup driver (critical for Kubeadm compatibility).
- **`02-setup-kubeadm.sh`**: Disables swap memory, loads iptables routing modules, and installs Kubeadm, Kubelet, and Kubectl (v1.27).
- **`03-init-master.sh`**: Initializes the Kubernetes Control Plane. It explicitly binds the API server to the internal Cluster LAN to maintain isolation. Deploys Calico CNI and auto-generates the worker join script.
- **`04-join-workers.sh`**: (Auto-generated dynamically by script 03) Contains the secure token for workers to join the cluster.
- **`05-deploy-openfaas.sh`**: Installs Helm, deploys OpenFaaS, and auto-generates the Python factorial function. It builds the Docker image, pushes it to your registry, and deploys the function to the cluster.
- **`06-setup-monitoring.sh`**: Installs K6, Prometheus, and Grafana on the Measurement node via Docker Compose.
- **`07-benchmark.js` / `run-benchmark.sh`**: The K6 Load Testing script representing the "Breakpoint Test." It ramps Virtual Users (VUs) from 0 up to 20,000 over a 30-minute period.

---

## 3. Critical Pre-requisites (Before Implementation)

Before you launch the CloudLab profile or run a single script, you must take care of the following:

1. **Upload to GitHub**: You must upload all of these scripts to a public GitHub repository. When you instantiate `profile.py` in CloudLab, it will ask for this URL so the nodes can automatically download the scripts on boot.
2. **Docker Hub Account**: Because you have a multi-node cluster, the Master node will build the Python factorial function, but the Worker nodes need a place to download (pull) it from. You must have an active Docker Hub account.
3. **Review Hardware Availability**: `c6620` machines are highly sought after on CloudLab. If the profile fails to instantiate due to lack of resources, you may need to edit `profile.py` to remove `node.hardware_type = "c6620"` to allow generic hardware allocation.

---

## 4. Execution Guide & Cautions (During Implementation)

> **Execution Order is Strict**: You must run the scripts in exact numerical order. Failure to do so will result in broken dependencies.

### Step 1: Base Installations
On **ALL 4 Kubernetes Nodes** (1 Master, 3 Workers), execute:
```bash
cd /local/setup
chmod +x *.sh
./01-setup-docker.sh
./02-setup-kubeadm.sh
```

### Step 2: Master Initialization
On the **Master Node ONLY**, you must export the internal LAN IP before running the init script so Kubernetes doesn't bind to the measurement network:
```bash
export INTERNAL_IP=10.10.1.1
./03-init-master.sh
```

### Step 3: Worker Join
On **ALL 3 Worker Nodes**, execute the auto-generated join script:
```bash
./04-join-workers.sh
```

### Step 4: OpenFaaS Deployment
On the **Master Node ONLY**, log into Docker so the script can push your function image to the registry:
```bash
docker login
export DOCKER_USERNAME=your_dockerhub_username
./05-deploy-openfaas.sh
```
*Wait for the script to finish and verify the gateway is up by running `kubectl get pods -n openfaas`.*

### Step 5: Monitoring & Benchmarking
On the **Measurement Node ONLY**, point the scripts to the Master's measurement interface (`10.10.2.1`):
```bash
export MASTER_IP=10.10.2.1
./06-setup-monitoring.sh
./run-benchmark.sh
```

### Step 6: Viewing Results
- The K6 script will output the RPS and latency results directly to the terminal and to `k6-results.json`.
- You can access Grafana by navigating your local web browser to the public IP of the Measurement node on port `3000` (e.g., `http://<measurement-public-ip>:3000`). Credentials: `admin` / `admin`.
