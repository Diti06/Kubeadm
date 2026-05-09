#!/bin/bash
# run-benchmark.sh
# Target: Measurement Node
# Description: Wrapper to run the K6 benchmark and output results to a file.

if [ -z "$MASTER_IP" ]; then
    echo "ERROR: MASTER_IP environment variable is not set."
    echo "Please set it: export MASTER_IP=your_master_node_ip"
    exit 1
fi

echo "Starting 30-minute K6 Breakpoint Test against Master Node: $MASTER_IP"
echo "Results will be saved to k6-results.json"

k6 run -e MASTER_IP=$MASTER_IP --out json=k6-results.json 07-benchmark.js

echo "Benchmark finished!"
