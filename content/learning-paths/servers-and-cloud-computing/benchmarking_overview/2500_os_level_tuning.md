---
title: OS-Level Tuning for Neoverse
weight: 2500

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding OS-Level Tuning for Neoverse

Operating system tuning plays a crucial role in maximizing the performance of Arm Neoverse processors in cloud environments. By configuring kernel parameters, CPU governors, and interrupt handling, you can significantly improve throughput, reduce latency, and enhance power efficiency without modifying application code.

For more detailed information about OS-level tuning for Neoverse, you can refer to:
- [Arm Neoverse Platform Optimization Guide](https://developer.arm.com/documentation/102042/latest/)
- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/)
- [Tuning Linux for Arm Servers](https://community.arm.com/arm-community-blogs/b/infrastructure-solutions-blog)

## Benchmarking Exercise: Measuring OS Tuning Impact

In this exercise, we'll measure the performance impact of different OS-level tuning parameters on Arm Neoverse processors.

### Prerequisites

Ensure you have an Arm VM with:
- Arm (aarch64) with Neoverse processors
- Root access to modify system parameters
- Linux kernel 5.4 or newer

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y linux-tools-common linux-tools-generic cpufrequtils sysstat numactl
```

### Step 2: Create CPU Governor Test Script

Create a file named `test_cpu_governors.sh` with the following content:

```bash
#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Function to run a CPU-intensive workload
run_workload() {
    echo "Running CPU workload..."
    stress-ng --cpu 4 --timeout 30s --metrics-brief
}

# Function to measure power and performance
measure_performance() {
    local governor=$1
    
    echo "Setting CPU governor to $governor..."
    cpupower frequency-set -g $governor
    
    # Wait for governor to take effect
    sleep 2
    
    # Show current settings
    echo "Current CPU frequency settings:"
    cpupower frequency-info | grep "current CPU frequency"
    
    # Run workload and measure
    echo "Starting benchmark with $governor governor..."
    
    # Capture system stats during test
    sar -u 1 30 > "sar_${governor}.txt" &
    sar_pid=$!
    
    # Run the workload
    run_workload > "workload_${governor}.txt"
    
    # Wait for sar to finish
    wait $sar_pid
    
    # Extract average CPU usage
    avg_cpu=$(grep "Average" "sar_${governor}.txt" | tail -1 | awk '{print 100-$8}')
    
    # Extract bogo ops from stress-ng
    bogo_ops=$(grep "bogo ops" "workload_${governor}.txt" | awk '{print $10}')
    
    echo "$governor,$avg_cpu,$bogo_ops" >> governor_results.csv
    
    echo "Completed test with $governor governor"
    echo "Average CPU usage: $avg_cpu%"
    echo "Performance score: $bogo_ops bogo ops"
    echo ""
}

# Main script
echo "CPU Governor Performance Test"
echo "============================"

# Check if stress-ng is installed
if ! command -v stress-ng &> /dev/null; then
    echo "Installing stress-ng..."
    apt-get update && apt-get install -y stress-ng
fi

# Check if cpupower is available
if ! command -v cpupower &> /dev/null; then
    echo "Installing cpupower..."
    apt-get update && apt-get install -y linux-tools-common linux-tools-generic
fi

# Initialize results file
echo "governor,avg_cpu_usage,bogo_ops" > governor_results.csv

# Test different governors
available_governors=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)
echo "Available governors: $available_governors"

for governor in performance powersave ondemand conservative schedutil; do
    if echo "$available_governors" | grep -q "$governor"; then
        measure_performance $governor
    else
        echo "Governor $governor not available, skipping"
    fi
done

echo "Tests complete. Results saved to governor_results.csv"
```

Make the script executable:

```bash
chmod +x test_cpu_governors.sh
```

### Step 3: Create Interrupt Affinity Test Script

Create a file named `test_irq_affinity.sh` with the following content:

```bash
#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Function to show current IRQ affinity
show_irq_affinity() {
    echo "Current IRQ affinity settings:"
    echo "-----------------------------"
    
    # Find network interfaces
    interfaces=$(ls /sys/class/net/ | grep -v "lo")
    
    for iface in $interfaces; do
        echo "Interface: $iface"
        
        # Find IRQs for this interface
        irqs=$(grep "$iface" /proc/interrupts | awk '{print $1}' | tr -d :)
        
        for irq in $irqs; do
            echo -n "  IRQ $irq: "
            cat /proc/irq/$irq/smp_affinity
        done
    done
    
    echo ""
}

# Function to set IRQ affinity
set_irq_affinity() {
    local mode=$1
    
    echo "Setting IRQ affinity to $mode mode..."
    
    # Find network interfaces
    interfaces=$(ls /sys/class/net/ | grep -v "lo")
    
    # Get CPU count
    cpu_count=$(nproc)
    
    for iface in $interfaces; do
        echo "Setting affinity for interface: $iface"
        
        # Find IRQs for this interface
        irqs=$(grep "$iface" /proc/interrupts | awk '{print $1}' | tr -d :)
        
        irq_count=0
        for irq in $irqs; do
            case $mode in
                "distribute")
                    # Distribute IRQs across all CPUs
                    cpu_mask=$(printf "%x" $((1 << (irq_count % cpu_count))))
                    ;;
                "consolidate")
                    # Consolidate IRQs to CPU 0
                    cpu_mask="1"
                    ;;
                "isolate")
                    # Isolate IRQs to the last CPU
                    cpu_mask=$(printf "%x" $((1 << (cpu_count - 1))))
                    ;;
                *)
                    echo "Unknown mode: $mode"
                    return 1
                    ;;
            esac
            
            echo $cpu_mask > /proc/irq/$irq/smp_affinity
            echo "  IRQ $irq set to CPU mask: $cpu_mask"
            
            irq_count=$((irq_count + 1))
        done
    done
    
    echo "IRQ affinity set to $mode mode"
}

# Function to run network benchmark
run_network_benchmark() {
    local mode=$1
    
    echo "Running network benchmark with $mode IRQ affinity..."
    
    # Use iperf3 if available, otherwise use netperf
    if command -v iperf3 &> /dev/null; then
        # Start iperf3 server in background
        iperf3 -s &
        server_pid=$!
        
        # Wait for server to start
        sleep 2
        
        # Run client benchmark
        iperf3 -c localhost -t 10 -J > "iperf_${mode}.json"
        
        # Kill server
        kill $server_pid
        
        # Extract throughput
        throughput=$(grep -o '"bits_per_second":[0-9.]*' "iperf_${mode}.json" | head -1 | cut -d: -f2)
        
    elif command -v netperf &> /dev/null; then
        # Start netserver in background
        netserver
        
        # Run benchmark
        netperf -H localhost -l 10 > "netperf_${mode}.txt"
        
        # Extract throughput
        throughput=$(grep -o '[0-9.]* *$' "netperf_${mode}.txt" | tr -d ' ')
    else
        echo "Neither iperf3 nor netperf found. Installing iperf3..."
        apt-get update && apt-get install -y iperf3
        
        # Recursive call after installing iperf3
        run_network_benchmark $mode
        return
    fi
    
    # Save results
    echo "$mode,$throughput" >> irq_results.csv
    
    echo "Network benchmark complete for $mode IRQ affinity"
    echo "Throughput: $throughput bits/sec"
    echo ""
}

# Main script
echo "IRQ Affinity Performance Test"
echo "============================"

# Initialize results file
echo "mode,throughput" > irq_results.csv

# Show initial IRQ affinity
show_irq_affinity

# Test different IRQ affinity settings
for mode in distribute consolidate isolate; do
    set_irq_affinity $mode
    run_network_benchmark $mode
done

# Restore distributed IRQ affinity
set_irq_affinity distribute

echo "Tests complete. Results saved to irq_results.csv"
```

Make the script executable:

```bash
chmod +x test_irq_affinity.sh
```

### Step 4: Create NUMA Policy Test Script

Create a file named `test_numa_policy.sh` with the following content:

```bash
#!/bin/bash

# Check if NUMA is available
if ! command -v numactl &> /dev/null; then
    echo "numactl not found. Installing..."
    sudo apt-get update && sudo apt-get install -y numactl
fi

# Check if system has NUMA nodes
numa_nodes=$(numactl --hardware | grep "available:" | awk '{print $2}')
if [ "$numa_nodes" -lt 2 ]; then
    echo "This system has only $numa_nodes NUMA node(s). NUMA testing requires at least 2 nodes."
    exit 1
fi

# Function to run memory-intensive workload
run_memory_benchmark() {
    local policy=$1
    local size=4G  # 4GB memory test
    
    echo "Running memory benchmark with $policy policy..."
    
    # Run sysbench memory test with specified NUMA policy
    case $policy in
        "local")
            numactl --localalloc sysbench memory --memory-block-size=1M --memory-total-size=$size run > "sysbench_${policy}.txt"
            ;;
        "interleave")
            numactl --interleave=all sysbench memory --memory-block-size=1M --memory-total-size=$size run > "sysbench_${policy}.txt"
            ;;
        "preferred")
            numactl --preferred=0 sysbench memory --memory-block-size=1M --memory-total-size=$size run > "sysbench_${policy}.txt"
            ;;
        "bind")
            numactl --membind=0 sysbench memory --memory-block-size=1M --memory-total-size=$size run > "sysbench_${policy}.txt"
            ;;
        *)
            sysbench memory --memory-block-size=1M --memory-total-size=$size run > "sysbench_${policy}.txt"
            ;;
    esac
    
    # Extract performance metrics
    throughput=$(grep "transferred" "sysbench_${policy}.txt" | awk '{print $(NF-1)}')
    latency=$(grep "avg:" "sysbench_${policy}.txt" | awk '{print $2}')
    
    # Save results
    echo "$policy,$throughput,$latency" >> numa_results.csv
    
    echo "Memory benchmark complete for $policy policy"
    echo "Throughput: $throughput MiB/sec"
    echo "Latency: $latency ms"
    echo ""
}

# Main script
echo "NUMA Policy Performance Test"
echo "==========================="

# Check if sysbench is installed
if ! command -v sysbench &> /dev/null; then
    echo "Installing sysbench..."
    sudo apt-get update && sudo apt-get install -y sysbench
fi

# Show NUMA topology
echo "NUMA Topology:"
numactl --hardware

# Initialize results file
echo "policy,throughput,latency" > numa_results.csv

# Test different NUMA policies
for policy in default local interleave preferred bind; do
    run_memory_benchmark $policy
done

echo "Tests complete. Results saved to numa_results.csv"
```

Make the script executable:

```bash
chmod +x test_numa_policy.sh
```

### Step 5: Run the Benchmarks

Execute the benchmark scripts (requires root privileges):

```bash
sudo ./test_cpu_governors.sh
sudo ./test_irq_affinity.sh
sudo ./test_numa_policy.sh
```

## Key Neoverse OS-Level Tuning Techniques

### 1. CPU Frequency Governor Selection

```bash
# View available governors
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors

# Set performance governor for all CPUs
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" > $cpu
done

# Set schedutil governor (good balance of performance and efficiency)
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "schedutil" > $cpu
done
```

### 2. Interrupt Affinity Optimization

```bash
# View current IRQ assignments
cat /proc/interrupts

# Set IRQ affinity for a specific interrupt
echo "1" > /proc/irq/42/smp_affinity  # Assign to CPU 0
echo "4" > /proc/irq/42/smp_affinity  # Assign to CPU 2

# Distribute network IRQs across CPUs
for irq in $(grep eth0 /proc/interrupts | awk '{print $1}' | tr -d :); do
    mask=$((1 << (irq % $(nproc))))
    printf "%x" $mask > /proc/irq/$irq/smp_affinity
done
```

### 3. NUMA Memory Policy

```bash
# Run application with local memory allocation
numactl --localalloc ./application

# Run application with memory interleaved across all nodes
numactl --interleave=all ./application

# Run application with memory bound to specific node
numactl --membind=0 ./application

# Run application with CPUs bound to specific node
numactl --cpunodebind=0 ./application
```

### 4. Transparent Hugepages

```bash
# Check current THP settings
cat /sys/kernel/mm/transparent_hugepage/enabled

# Enable THP (always)
echo "always" > /sys/kernel/mm/transparent_hugepage/enabled

# Enable THP (madvise - only for applications that request it)
echo "madvise" > /sys/kernel/mm/transparent_hugepage/enabled

# Disable THP
echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
```

### 5. I/O Scheduler Tuning

```bash
# View available schedulers
cat /sys/block/sda/queue/scheduler

# Set deadline scheduler (good for SSDs)
echo "deadline" > /sys/block/sda/queue/scheduler

# Set noop scheduler (minimal overhead)
echo "noop" > /sys/block/sda/queue/scheduler

# Set read-ahead buffer size (KB)
echo 256 > /sys/block/sda/queue/read_ahead_kb
```

## OS Tuning Trade-offs

| Tuning Parameter | Performance Impact | Power Impact | Latency Impact | Stability Impact |
|------------------|-------------------|--------------|----------------|-----------------|
| CPU Governor: performance | High (+) | High (-) | Low (+) | None |
| CPU Governor: powersave | High (-) | High (+) | High (-) | None |
| CPU Governor: schedutil | Medium (+) | Medium (+) | Medium (+) | None |
| IRQ Affinity: distribute | Medium (+) | Low (-) | Medium (+) | None |
| IRQ Affinity: consolidate | Low (-) | Medium (+) | High (-) | None |
| NUMA: local | High (+) | Low (+) | Medium (+) | None |
| NUMA: interleave | Medium (+) | Low (-) | Low (+) | None |
| THP: always | High (+) | Low (-) | Variable | Low (-) |
| THP: madvise | Medium (+) | None | None | None |

## When to Use Each Tuning Parameter

1. **Latency-Sensitive Workloads**:
   - CPU Governor: performance
   - IRQ Affinity: distribute or isolate
   - NUMA Policy: local or bind
   - THP: madvise or never

2. **Throughput-Oriented Workloads**:
   - CPU Governor: schedutil
   - IRQ Affinity: distribute
   - NUMA Policy: interleave
   - THP: always

3. **Power-Constrained Environments**:
   - CPU Governor: powersave or schedutil
   - IRQ Affinity: consolidate
   - NUMA Policy: local
   - THP: madvise

4. **Mixed Workloads**:
   - CPU Governor: schedutil
   - IRQ Affinity: distribute
   - NUMA Policy: local
   - THP: madvise

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| CPU Governors | ✓ | ✓ | ✓ |
| IRQ Affinity | ✓ | ✓ | ✓ |
| NUMA Policies | ✓ | ✓ | ✓ |
| Transparent Hugepages | ✓ | ✓ | ✓ |
| I/O Schedulers | ✓ | ✓ | ✓ |

All OS-level tuning techniques in this chapter work on all Neoverse processors.

## Further Reading

- [Linux CPUFreq Governors](https://www.kernel.org/doc/html/latest/admin-guide/pm/cpufreq.html)
- [Linux IRQ Affinity](https://www.kernel.org/doc/Documentation/IRQ-affinity.txt)
- [Linux NUMA Memory Policy](https://www.kernel.org/doc/html/latest/admin-guide/mm/numa_memory_policy.html)
- [Transparent Hugepages](https://www.kernel.org/doc/html/latest/admin-guide/mm/transhuge.html)
- [Linux I/O Schedulers](https://www.kernel.org/doc/Documentation/block/switching-sched.txt)

## Relevance to Cloud Computing Workloads

OS-level tuning is particularly important for cloud computing on Neoverse:

1. **Performance Consistency**: Proper tuning reduces performance variability
2. **Resource Utilization**: Optimized settings improve hardware utilization
3. **Multi-tenant Efficiency**: NUMA and IRQ tuning improve isolation between workloads
4. **Power Efficiency**: Governor selection impacts energy consumption and costs
5. **Latency Reduction**: IRQ and scheduler tuning can significantly reduce tail latencies

Understanding OS-level tuning helps you:
- Maximize performance per dollar in cloud environments
- Improve application responsiveness and predictability
- Reduce infrastructure costs through better resource utilization
- Balance performance and power efficiency requirements