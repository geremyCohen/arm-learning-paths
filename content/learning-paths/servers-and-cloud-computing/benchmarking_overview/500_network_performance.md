---
title: Network Performance
weight: 500

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Network Performance

Network performance is a critical metric for systems that communicate over networks, including web servers, microservices, distributed databases, and cloud applications. Key network performance metrics include throughput (bandwidth), latency, packet processing rate, and connection handling capacity.

When comparing Intel/AMD (x86) versus Arm architectures, network performance can vary due to differences in network interface integration, interrupt handling, memory bandwidth, and CPU efficiency for packet processing. These architectural differences can significantly impact applications with heavy network requirements.

For more detailed information about network performance, you can refer to:
- [Network Performance Analysis](https://www.brendangregg.com/blog/2018-03-22/tcp-tracepoints.html)
- [Understanding Network Throughput vs Latency](https://www.networkcomputing.com/networking/understanding-throughput-vs-latency)

## Benchmarking Exercise: Comparing Network Performance

In this exercise, we'll use common networking tools to measure and compare network performance across Intel/AMD and Arm systems.

### Prerequisites

Ensure you have two pairs of VMs (four VMs total):
- One pair running on Intel/AMD (x86_64) - server and client
- One pair running on Arm (aarch64) - server and client

All VMs should be in the same network environment with similar network configurations for fair comparison.

### Step 1: Install Required Tools

Run the following commands on all four VMs:

```bash
sudo apt update
sudo apt install -y iperf3 netperf sockperf nload tcpdump
```

### Step 2: Create Benchmark Script

Create a file named `network_benchmark.sh` on both client VMs with the following content:

```bash
#!/bin/bash

# Function to get architecture
get_arch() {
  arch=$(uname -m)
  if [[ "$arch" == "x86_64" ]]; then
    echo "Intel/AMD (x86_64)"
  elif [[ "$arch" == "aarch64" ]]; then
    echo "Arm (aarch64)"
  else
    echo "Unknown architecture: $arch"
  fi
}

# Check if server IP is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <server_ip>"
  exit 1
fi

SERVER_IP=$1

# Display system information
echo "=== System Information ==="
echo "Architecture: $(get_arch)"
echo "CPU Model:"
lscpu | grep "Model name"
echo "Network Information:"
ip addr | grep -E "inet |ether"
echo ""

# Function to run iperf3 test
run_iperf3_test() {
  local test_name=$1
  local extra_args=$2
  
  echo "=== Running iperf3 $test_name test ==="
  iperf3 -c $SERVER_IP -t 10 -J $extra_args | tee iperf3_${test_name}.json
  echo ""
}

# Function to run netperf test
run_netperf_test() {
  local test_name=$1
  local test_type=$2
  local extra_args=$3
  
  echo "=== Running netperf $test_name test ==="
  netperf -H $SERVER_IP -t $test_type $extra_args
  echo ""
}

# Function to run sockperf test
run_sockperf_test() {
  local test_name=$1
  local test_type=$2
  local extra_args=$3
  
  echo "=== Running sockperf $test_name test ==="
  sockperf $test_type -i $SERVER_IP --tcp -t 10 $extra_args
  echo ""
}

# TCP Throughput Tests
echo "=== TCP Throughput Tests ==="
run_iperf3_test "tcp_upload" ""
run_iperf3_test "tcp_download" "-R"
run_iperf3_test "tcp_parallel" "-P 10"

# UDP Tests
echo "=== UDP Tests ==="
run_iperf3_test "udp" "-u -b 1G"

# TCP_RR (Request/Response) Test
echo "=== TCP Request/Response Tests ==="
run_netperf_test "tcp_rr" "TCP_RR" ""

# TCP_CRR (Connect/Request/Response) Test
echo "=== TCP Connect/Request/Response Tests ==="
run_netperf_test "tcp_crr" "TCP_CRR" ""

# Latency Tests
echo "=== Latency Tests ==="
run_sockperf_test "ping_pong" "ping-pong" ""
run_sockperf_test "under_load" "under-load" "--mps=10000"

echo "All network tests completed."
```

Make the script executable:

```bash
chmod +x network_benchmark.sh
```

### Step 3: Start Server Processes

On both server VMs, start the required server processes:

```bash
# Start iperf3 server
iperf3 -s &

# Start netperf server
netserver &

# Start sockperf server
sockperf server --tcp &
```

### Step 4: Run the Benchmark

Execute the benchmark script on both client VMs, pointing to their respective architecture-matched server:

```bash
# Replace SERVER_IP with the actual IP of your server VM
./network_benchmark.sh SERVER_IP | tee network_benchmark_results.txt
```

### Step 5: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Throughput**: Compare maximum bandwidth achieved in both directions.
2. **Latency**: Compare minimum, average, and maximum latency.
3. **Request/Response Performance**: Compare transactions per second for TCP_RR and TCP_CRR tests.
4. **Connection Handling**: Compare connection establishment rates.
5. **Parallel Connection Performance**: Compare how performance scales with multiple parallel connections.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Network Stack Implementation**: Different architectures may have different optimizations in their TCP/IP stack.
- **Interrupt Processing**: Efficiency of interrupt handling for network packets.
- **Memory Bandwidth**: Impact on packet buffer processing.
- **CPU Efficiency**: Instructions per cycle for network processing tasks.
- **Cache Utilization**: How effectively the cache hierarchy is used during network operations.

## Relevance to Workloads

Network performance benchmarking is particularly important for:

1. **Web Servers**: Nginx, Apache, Node.js handling many concurrent connections
2. **API Gateways**: Processing and routing large numbers of requests
3. **Microservices**: Service-to-service communication in distributed applications
4. **Content Delivery Networks**: Serving static content with minimal latency
5. **Database Clusters**: Replication and sharding communication
6. **Real-time Applications**: Gaming servers, video conferencing, financial trading

Understanding network performance differences between architectures helps you select the optimal platform for network-intensive applications and properly tune network configurations for maximum performance.

## Advanced Analysis: Packet Processing Efficiency

For a deeper understanding of architectural differences in network performance, you can analyze CPU utilization during network tests:

```bash
# On the server, while running iperf3 test
mpstat -P ALL 1 | tee cpu_usage_during_network_test.txt
```

This can reveal differences in how efficiently each architecture processes network packets, which is especially important for high-throughput or low-latency applications.

## Knowledge Check

1. If TCP throughput is similar between architectures but one shows significantly better request/response performance, what might this indicate?
   - A) The network interface card is better on one system
   - B) One architecture has more efficient interrupt handling or context switching
   - C) The network connection is unstable
   - D) The benchmark is not measuring correctly

2. Which network workload is most likely to show architectural differences rather than being limited by network bandwidth?
   - A) Large file transfers using TCP
   - B) Streaming video over UDP
   - C) Small packet processing with many connections
   - D) Simple ping tests measuring round-trip time

3. If CPU utilization is significantly lower on one architecture while achieving the same network throughput, this suggests:
   - A) The network driver is malfunctioning
   - B) The architecture is more efficient at packet processing
   - C) The network test isn't pushing the system hard enough
   - D) The operating system is throttling network performance

Answers:
1. B) One architecture has more efficient interrupt handling or context switching
2. C) Small packet processing with many connections
3. B) The architecture is more efficient at packet processing