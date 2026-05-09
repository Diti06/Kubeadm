"""
CloudLab Profile: Kubernetes & OpenFaaS Dual-Network Topology (Xen VM)
Hardware: Hardcoded to c6620
Nodes: 1 Master, 3 Workers, 1 Measurement Node
"""

import geni.portal as portal
import geni.rspec.pg as pg
import geni.rspec.igext as ig

# Create a Portal context.
pc = portal.Context()

# Create a Request object to start building the RSpec.
request = pc.makeRequestRSpec()

# Define a customizable parameter for the GitHub Repository
pc.defineParameter(
    "github_repo",
    "GitHub Repository URL",
    portal.ParameterType.STRING,
    "https://github.com/your-username/your-repo-name.git",
    "The URL of your GitHub repository containing the 01 to 07 setup scripts. "
    "This will be automatically cloned into /local/setup on every node during boot."
)

# Bind and verify parameters.
params = pc.bindParameters()

# The automated startup command to pull your scripts
setup_command = "mkdir -p /local/setup && git clone {} /local/setup".format(params.github_repo)

# Helper function to create a Xen VM node with c6620 hardware
def create_xen_node(name):
    # Use XenVM as required by the paper to evaluate PV vs HVM
    node = ig.XenVM(name)
    # We want exclusive access to the underlying hardware
    node.exclusive = True
    # Hardcode to c6620 machines as per the paper's experimental setup
    node.hardware_type = "c6620"
    # Use standard Ubuntu 20.04 image
    node.disk_image = "urn:publicid:IDN+emulab.net+image+emulab-ops:UBUNTU20-64-STD"
    # Add the automated script cloning service
    node.addService(pg.Execute(shell="bash", command=setup_command))
    return node

# ==========================================
# 1. NODE DEFINITIONS
# ==========================================
master = create_xen_node("master")
request.addResource(master)

measurement = create_xen_node("measurement")
request.addResource(measurement)

workers = []
for i in range(3):
    worker = create_xen_node("worker{}".format(i))
    workers.append(worker)
    request.addResource(worker)

# ==========================================
# 2. DUAL-NETWORK TOPOLOGY DEFINITION
# ==========================================

# Network A: The Internal Cluster LAN (Master <--> Workers)
cluster_lan = pg.LAN("cluster-net")

# Add Master's 1st interface to the Cluster LAN
iface_master_cluster = master.addInterface("if1")
iface_master_cluster.addAddress(pg.IPv4Address("10.10.1.1", "255.255.255.0"))
cluster_lan.addInterface(iface_master_cluster)

# Add Workers to the Cluster LAN
for i, worker in enumerate(workers):
    iface_worker = worker.addInterface("if1")
    # IP assignments: 10.10.1.2, 10.10.1.3, 10.10.1.4
    iface_worker.addAddress(pg.IPv4Address("10.10.1.{}".format(i+2), "255.255.255.0"))
    cluster_lan.addInterface(iface_worker)

request.addResource(cluster_lan)


# Network B: The Measurement Isolation Link (Master <--> Measurement)
measure_link = pg.Link("measure-net")

# Add Master's 2nd interface to the Measurement Link
iface_master_measure = master.addInterface("if2")
iface_master_measure.addAddress(pg.IPv4Address("10.10.2.1", "255.255.255.0"))
measure_link.addInterface(iface_master_measure)

# Add Measurement node's interface to the Measurement Link
iface_measurement = measurement.addInterface("if1")
iface_measurement.addAddress(pg.IPv4Address("10.10.2.2", "255.255.255.0"))
measure_link.addInterface(iface_measurement)

request.addResource(measure_link)

# ==========================================
# 3. PRINT RSPEC
# ==========================================
pc.printRequestRSpec(request)
