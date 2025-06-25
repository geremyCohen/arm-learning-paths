---
title: Arm big.LITTLE and DynamIQ
weight: 2350
layout: learningpathall
---

## Understanding Arm big.LITTLE and DynamIQ

Arm big.LITTLE and its evolution, DynamIQ, are heterogeneous computing architectures that combine high-performance "big" cores with energy-efficient "LITTLE" cores in a single processor. This design allows systems to optimize for both performance and power efficiency by assigning tasks to the most appropriate core type.

When comparing Intel/AMD (x86) versus Arm architectures, this heterogeneous approach represents a significant architectural difference. While Intel has introduced hybrid architectures like Alder Lake with Performance and Efficiency cores, Arm has been refining this approach for over a decade.

For more detailed information about Arm big.LITTLE and DynamIQ, you can refer to:
- [Arm big.LITTLE Technology](https://www.arm.com/why-arm/technologies/big-little)
- [Arm DynamIQ Technology](https://www.arm.com/why-arm/technologies/dynamiq)
- [Heterogeneous Multi-Processing](https://developer.arm.com/documentation/den0022/latest/)

## Benchmarking Exercise

### Prerequisites

Ensure you have:
- Completed the repository setup from the previous chapter
- ARM (aarch64) system with the bench_guide repository cloned

### Step 1: Navigate to Directory

Navigate to the benchmark directory:

```bash
cd bench_guide/2350_arm_big_little
```

### Step 2: Install Dependencies

Run the setup script:

```bash
./setup.sh
```

### Step 3: Run the Benchmark

Execute the benchmark:

```bash
./benchmark.sh
```

### Step 4: Analyze the Results

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Download and Run Setup Script

Download and run the setup script to install required tools:

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/arm_big_little/setup.sh
chmod +x setup.sh
./setup.sh
```

### Step 2: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/arm_big_little/benchmark.sh
chmod +x benchmark.sh
./benchmark.sh | tee arm_big_little_results.txt
```

### Step 3: Analyze the Results Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc cpufrequtils linux-tools-common linux-tools-generic
```

### Step 2: Identify Core Types

Create a file named `identify_cores.sh` with the following content:

Make the script executable and run it:

```bash
chmod +x identify_cores.sh
./identify_cores.sh
```

### Step 6: Run the Benchmark

Execute the benchmark script:

```bash
./run_big_little_benchmark.sh
```

### Step 7: Analyze the Results

When analyzing the results, consider:

1. **Performance Difference**: Compare operations per second between big and LITTLE cores.
2. **Energy Efficiency**: Compare estimated power consumption relative to performance.
3. **Workload Suitability**: Determine which workloads are better suited for each core type.

## Arm-specific Workload Placement Optimizations

Arm architectures offer several optimization techniques to leverage heterogeneous cores effectively:

### 1. Task-Specific Core Affinity

Create a file named `task_affinity.c`:

Compile with:

```bash
gcc -O2 -pthread task_affinity.c -o task_affinity
```

### 2. Key Arm big.LITTLE Optimization Techniques

1. **Workload-Aware Scheduling**:
   ```c
   // For CPU-intensive tasks, use big cores
   cpu_set_t big_core_set;
   CPU_ZERO(&big_core_set);
   CPU_SET(big_core_id, &big_core_set);
   pthread_setaffinity_np(thread, sizeof(cpu_set_t), &big_core_set);
   
   // For I/O or bursty tasks, use LITTLE cores
   cpu_set_t little_core_set;
   CPU_ZERO(&little_core_set);
   CPU_SET(little_core_id, &little_core_set);
   pthread_setaffinity_np(thread, sizeof(cpu_set_t), &little_core_set);
   ```

2. **Energy-Aware Task Partitioning**:
   3. **Dynamic Core Selection**:
   ```c
   // Choose core based on workload characteristics
   int select_optimal_core(task_t* task) {
       if (task->compute_intensity > THRESHOLD) {
           return get_available_big_core();
       } else {
           return get_available_little_core();
       }
   }
   ```

4. **Frequency Scaling Awareness**:
   ```bash
   # Set big cores to performance mode for latency-sensitive tasks
   echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
   
   # Set LITTLE cores to powersave for background tasks
   echo powersave > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
   ```

5. **Asymmetric Multithreading**:
   

These optimizations can help leverage the heterogeneous nature of Arm big.LITTLE and DynamIQ architectures, improving both performance and energy efficiency.

## Relevance to Workloads

Arm big.LITTLE and DynamIQ optimizations are particularly important for:

1. **Mobile Applications**: Balancing performance and battery life
2. **Edge Computing**: Maximizing performance within power constraints
3. **Server Workloads**: Improving energy efficiency in data centers
4. **Mixed Workloads**: Systems running both latency-sensitive and background tasks
5. **IoT Devices**: Extending battery life while maintaining responsiveness

Understanding big.LITTLE architecture helps you:
- Optimize task scheduling for heterogeneous cores
- Balance performance and power consumption
- Design energy-efficient applications
- Improve responsiveness while minimizing energy use