---
title: Power Efficiency
weight: 700

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Power Efficiency

Power efficiency is a critical metric in modern computing, measuring how effectively a system converts electrical power into computational work. It's typically expressed as performance per watt, which quantifies the amount of useful work accomplished for each unit of energy consumed. As data centers and cloud providers face increasing energy costs and sustainability concerns, power efficiency has become a key factor in platform selection.

When comparing Intel/AMD (x86) versus Arm architectures, power efficiency characteristics can differ significantly due to fundamental design philosophies, instruction set architectures, and optimization targets. Arm architectures were historically designed with power efficiency as a primary goal, while x86 architectures evolved with a focus on raw performance, though both have converged somewhat in recent years.

For more detailed information about power efficiency, you can refer to:
- [Energy Efficiency in Computing](https://www.energy.gov/eere/buildings/energy-efficiency-computing)
- [Power Management in Modern Processors](https://www.anandtech.com/show/14514/examining-intel-ice-lake-microarchitecture-power)

## Benchmarking Exercise: Comparing Power Efficiency

In this exercise, we'll measure and compare power efficiency across Intel/AMD and Arm systems using a combination of performance benchmarks and power monitoring.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential git python3 python3-matplotlib stress-ng sysbench powertop linux-tools-common linux-tools-generic
```

### Step 2: Create Benchmark Script

Create a file named `power_efficiency_benchmark.sh` with the following content:

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

# Display system information
echo "=== System Information ==="
echo "Architecture: $(get_arch)"
echo "CPU Model:"
lscpu | grep "Model name"
echo "CPU Cores: $(nproc)"
echo ""

# Function to measure power consumption (if available)
measure_power() {
  local test_name=$1
  
  echo "=== Measuring power for $test_name ==="
  
  # Try different methods to measure power
  if [ -d "/sys/class/powercap/intel-rapl" ]; then
    echo "Using Intel RAPL for power measurement..."
    
    # Read initial energy values
    initial_values=()
    for domain in /sys/class/powercap/intel-rapl/intel-rapl:*; do
      if [ -f "$domain/energy_uj" ]; then
        initial_values+=("$(cat $domain/energy_uj)")
      fi
    done
    
    # Return function to read final values and calculate power
    measure_power_end() {
      local duration=$1
      local i=0
      
      echo "Power consumption over $duration seconds:"
      for domain in /sys/class/powercap/intel-rapl/intel-rapl:*; do
        if [ -f "$domain/energy_uj" ] && [ $i -lt ${#initial_values[@]} ]; then
          local final_value=$(cat $domain/energy_uj)
          local domain_name=$(cat $domain/name)
          local energy_joules=$(( (final_value - ${initial_values[$i]}) / 1000000 ))
          local power_watts=$(echo "scale=2; $energy_joules / $duration" | bc)
          echo "$domain_name: $power_watts watts"
          i=$((i+1))
        fi
      done
    }
    
  elif [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
    echo "Using CPU frequency scaling for power estimation..."
    
    # Get initial timestamp and frequency
    initial_time=$(date +%s)
    initial_freqs=()
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
      if [ -f "$cpu" ]; then
        initial_freqs+=("$(cat $cpu)")
      fi
    done
    
    # Return function to estimate power based on frequency
    measure_power_end() {
      local duration=$1
      local final_time=$(date +%s)
      local actual_duration=$((final_time - initial_time))
      
      echo "Estimated power consumption over $actual_duration seconds:"
      local total_freq_ghz=0
      local i=0
      
      for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
        if [ -f "$cpu" ] && [ $i -lt ${#initial_freqs[@]} ]; then
          local final_freq=$(cat $cpu)
          local avg_freq=$(( (final_freq + ${initial_freqs[$i]}) / 2 ))
          local freq_ghz=$(echo "scale=3; $avg_freq / 1000000" | bc)
          total_freq_ghz=$(echo "scale=3; $total_freq_ghz + $freq_ghz" | bc)
          i=$((i+1))
        fi
      done
      
      # Rough estimation based on frequency
      # This is a very simplified model and not accurate
      local estimated_power=$(echo "scale=2; $total_freq_ghz * 5" | bc)
      echo "Estimated total CPU power: $estimated_power watts (rough approximation)"
    }
    
  else
    echo "No power measurement capability detected"
    
    measure_power_end() {
      echo "Power measurement not available on this system"
    }
  fi
}

# Function to run a benchmark and measure performance per watt
run_benchmark() {
  local test_name=$1
  local benchmark_cmd=$2
  local duration=$3
  
  echo "=== Running $test_name benchmark ==="
  
  # Start power measurement
  measure_power "$test_name"
  
  # Run the benchmark and capture performance metric
  echo "Running benchmark for $duration seconds..."
  performance=$(eval "$benchmark_cmd" 2>&1)
  
  # End power measurement
  measure_power_end $duration
  
  # Extract and display performance metric
  echo "Performance result:"
  echo "$performance"
  echo ""
}

# Function to run CPU benchmark
run_cpu_benchmark() {
  local threads=$1
  local duration=$2
  
  echo "=== Running CPU benchmark with $threads threads ==="
  
  # Start power measurement
  measure_power "cpu_benchmark_${threads}threads"
  
  # Run sysbench CPU test
  sysbench cpu --threads=$threads --time=$duration run | tee cpu_benchmark_${threads}threads.txt
  
  # End power measurement
  measure_power_end $duration
  
  # Extract events per second
  events_per_second=$(grep "events per second" cpu_benchmark_${threads}threads.txt | awk '{print $4}')
  
  echo "CPU Performance: $events_per_second events per second with $threads threads"
  echo ""
}

# Function to run memory benchmark
run_memory_benchmark() {
  local threads=$1
  local duration=$2
  
  echo "=== Running Memory benchmark with $threads threads ==="
  
  # Start power measurement
  measure_power "memory_benchmark_${threads}threads"
  
  # Run sysbench memory test
  sysbench memory --threads=$threads --memory-block-size=1K --memory-total-size=100G --time=$duration run | tee memory_benchmark_${threads}threads.txt
  
  # End power measurement
  measure_power_end $duration
  
  # Extract operations per second
  ops_per_second=$(grep "transferred" memory_benchmark_${threads}threads.txt | awk '{print $(NF-1)}')
  
  echo "Memory Performance: $ops_per_second MiB/sec with $threads threads"
  echo ""
}

# Function to run fileio benchmark
run_fileio_benchmark() {
  local threads=$1
  local duration=$2
  
  echo "=== Running FileIO benchmark with $threads threads ==="
  
  # Prepare test file
  sysbench fileio --file-total-size=2G prepare
  
  # Start power measurement
  measure_power "fileio_benchmark_${threads}threads"
  
  # Run sysbench fileio test
  sysbench fileio --file-total-size=2G --file-test-mode=rndrw --threads=$threads --time=$duration run | tee fileio_benchmark_${threads}threads.txt
  
  # End power measurement
  measure_power_end $duration
  
  # Extract operations per second
  ops_per_second=$(grep "reads/s:" fileio_benchmark_${threads}threads.txt | awk '{print $2}')
  ops_per_second="$ops_per_second reads/s + $(grep "writes/s:" fileio_benchmark_${threads}threads.txt | awk '{print $2}') writes/s"
  
  echo "FileIO Performance: $ops_per_second with $threads threads"
  echo ""
  
  # Clean up
  sysbench fileio --file-total-size=2G cleanup
}

# Run a series of benchmarks with different thread counts
for threads in 1 $(nproc) $(( $(nproc) / 2 )); do
  run_cpu_benchmark $threads 30
  run_memory_benchmark $threads 30
  run_fileio_benchmark $threads 30
done

# Run stress test to measure maximum power consumption
echo "=== Running stress test to measure maximum power consumption ==="
measure_power "stress_test"
stress-ng --cpu $(nproc) --io 4 --vm 2 --vm-bytes 1G --timeout 60s
measure_power_end 60

echo "All power efficiency benchmarks completed."
```

Make the script executable:

```bash
chmod +x power_efficiency_benchmark.sh
```

### Step 3: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
sudo ./power_efficiency_benchmark.sh | tee power_efficiency_results.txt
```

### Step 4: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Absolute Power Consumption**: Compare the power draw under various workloads.
2. **Performance per Watt**: Compare the computational efficiency for each benchmark.
3. **Scaling Efficiency**: How does power efficiency change with increasing thread count?
4. **Idle Power**: Compare power consumption when the system is idle.
5. **Maximum Power**: Compare peak power consumption under full load.

### Step 5: Additional Power Analysis with PowerTOP

For a more detailed analysis of power consumption, run PowerTOP:

```bash
sudo powertop --html=powertop_report.html
```

This will generate an HTML report with detailed power consumption information that you can analyze.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Instruction Set Efficiency**: Different ISAs may require different numbers of instructions to accomplish the same task.
- **Pipeline Design**: Differences in execution pipeline depth and width affect power consumption.
- **Power Management Features**: Different approaches to power states, frequency scaling, and core gating.
- **Process Technology**: Different manufacturing processes may have different power characteristics.
- **SoC Integration**: Level of integration of components like memory controllers, I/O, and accelerators.

## Relevance to Workloads

Power efficiency benchmarking is particularly important for:

1. **Cloud Infrastructure**: Where energy costs are a significant operational expense
2. **Edge Computing**: Devices with limited power budgets or battery operation
3. **High-Density Computing**: Data centers with power or cooling constraints
4. **Sustainable Computing Initiatives**: Organizations with carbon footprint reduction goals
5. **Mobile and Embedded Systems**: Where battery life is critical

Understanding power efficiency differences between architectures helps you select the optimal platform for energy-sensitive applications and environments, potentially leading to significant operational cost savings and reduced environmental impact.

## Knowledge Check

1. If an Arm system shows 20% lower absolute performance but 30% lower power consumption compared to an x86 system, what can you conclude about its power efficiency?
   - A) The Arm system is less power-efficient
   - B) The Arm system is more power-efficient
   - C) Both systems have equal power efficiency
   - D) Power efficiency cannot be determined from this information

2. Which workload characteristic typically benefits most from Arm's traditional power efficiency advantages?
   - A) Heavy floating-point calculations
   - B) Single-threaded performance-critical tasks
   - C) Throughput-oriented workloads with many parallel threads
   - D) Random memory access patterns

3. When evaluating power efficiency for a web server workload, which metric would be most relevant?
   - A) FLOPS per watt
   - B) Requests handled per watt
   - C) Memory bandwidth per watt
   - D) CPU utilization percentage

Answers:
1. B) The Arm system is more power-efficient
2. C) Throughput-oriented workloads with many parallel threads
3. B) Requests handled per watt