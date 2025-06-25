---
title: Mixed Workload Performance
weight: 2100
layout: learningpathall
---

## Understanding Mixed Workload Performance

In real-world environments, systems rarely run a single type of workload. Instead, they typically execute a mix of applications with different resource requirements, creating contention for shared resources like CPU cores, caches, memory bandwidth, and I/O. Understanding how different architectures handle these mixed workloads is crucial for predicting real-world performance.

When comparing Intel/AMD (x86) versus Arm architectures, mixed workload performance can vary significantly due to differences in resource allocation, cache hierarchies, memory controllers, and scheduling mechanisms. These architectural differences can lead to varying levels of interference between concurrent applications.

For more detailed information about mixed workload performance, you can refer to:
- [Performance Isolation in Multi-tenant Environments](https://www.usenix.org/conference/osdi18/presentation/boucher)
- [Resource Contention in Multicore Systems](https://dl.acm.org/doi/10.1145/2451116.2451125)
- [Workload Characterization](https://www.intel.com/content/www/us/en/developer/articles/technical/workload-characterization-guidelines.html)

## Benchmarking Exercise

### Prerequisites

Ensure you have:
- Completed the repository setup from the previous chapter
- Two Ubuntu systems with the bench_guide repository cloned

### Step 1: Navigate to Directory

Navigate to the benchmark directory:

```bash
cd bench_guide/2100_mixed_workload
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
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/mixed_workload/setup.sh
chmod +x setup.sh
./setup.sh
```

### Step 2: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/mixed_workload/benchmark.sh
chmod +x benchmark.sh
./benchmark.sh | tee mixed_workload_results.txt
```

### Step 3: Analyze the Results Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential gcc g++ python3-matplotlib stress-ng sysbench fio
```

### Step 5: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
sudo ./run_contention_benchmark.sh
```

### Step 6: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Workload Interference**: Compare how much one workload type affects another.
2. **Resource Contention**: Compare the impact of shared vs. non-shared resources.
3. **Scalability Under Contention**: Compare how performance scales with increasing thread count under contention.
4. **False Sharing Impact**: Compare the performance impact of false sharing.
5. **Fairness**: Compare the standard deviation of thread performance to assess fairness.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Cache Coherence Protocol**: Different approaches to maintaining cache coherence can affect contention.
- **Memory Controller Design**: Different memory controller implementations can handle concurrent access differently.
- **Scheduler Implementation**: Different CPU schedulers may prioritize workloads differently.
- **Resource Partitioning**: Some architectures may have better isolation between cores or threads.

## Arm-specific Optimizations

Arm architectures offer several optimization techniques to improve mixed workload performance:

### 1. Arm-optimized Workload Isolation

Create a file named `arm_workload_isolation.c`:

Compile with:

```bash
gcc -O3 -pthread arm_workload_isolation.c -o arm_workload_isolation
```

Run with different isolation modes:

```bash
# No isolation
./arm_workload_isolation 0

# With isolation
./arm_workload_isolation 1
```

### 2. Arm-optimized Memory Allocation

Create a file named `arm_memory_allocation.c`:

Compile with:

```bash
gcc -O3 -pthread arm_memory_allocation.c -o arm_memory_allocation
```

### 3. Key Arm Mixed Workload Optimization Techniques

1. **Workload Isolation on Arm big.LITTLE/DynamIQ Systems**:
   - Place compute-intensive workloads on big cores
   - Place I/O or memory-bound workloads on LITTLE cores
   - Use `sched_setaffinity()` to control placement

2. **Memory Allocator Optimization**:
   - Consider using jemalloc instead of glibc malloc:
   ```bash
   # Install jemalloc
   sudo apt install libjemalloc-dev
   
   # Compile with jemalloc
   gcc -O3 program.c -o program -ljemalloc
   
   # Run with jemalloc
   LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so ./program
   ```

3. **NUMA Awareness for Multi-socket Arm Systems**:
   ```c
   #include <numa.h>
   
   // Allocate memory on the local NUMA node
   void* local_memory = numa_alloc_local(size);
   
   // Allocate memory on a specific NUMA node
   void* node_memory = numa_alloc_onnode(size, node);
   ```

4. **Cache Partitioning with Cache Coloring**:
   ```c
   // Allocate memory aligned to cache line size
   void* buffer = aligned_alloc(64, size);
   
   // Access with stride to use different cache sets
   for (int i = 0; i < size; i += 4096) {
       buffer[i] = value;
   }
   ```

5. **I/O Optimization for Mixed Workloads**:
   ```c
   // Set I/O priority for different threads
   #include <sys/resource.h>
   
   // For background I/O threads
   ioprio_set(IOPRIO_WHO_PROCESS, pid, 
              IOPRIO_PRIO_VALUE(IOPRIO_CLASS_IDLE, 0));
   
   // For critical I/O threads
   ioprio_set(IOPRIO_WHO_PROCESS, pid, 
              IOPRIO_PRIO_VALUE(IOPRIO_CLASS_RT, 0));
   ```

These optimizations can significantly improve mixed workload performance on Arm architectures by reducing resource contention and improving isolation between different types of workloads.

## Relevance to Workloads

Mixed workload performance benchmarking is particularly important for:

1. **Virtualized Environments**: Multiple VMs sharing physical resources
2. **Container Platforms**: Multiple containers running on the same host
3. **Database Servers**: OLTP and OLAP workloads running concurrently
4. **Web Servers**: Handling diverse request types simultaneously
5. **Multi-tenant Systems**: Multiple users or applications sharing resources

Understanding mixed workload performance differences between architectures helps you:
- Design more efficient multi-tenant environments
- Predict performance in real-world scenarios with mixed workloads
- Implement appropriate resource isolation mechanisms
- Make informed decisions about workload placement and scheduling

## Knowledge Check

1. If a CPU-intensive workload shows minimal degradation when running alongside a memory-intensive workload on one architecture but significant degradation on another, what might this suggest?
   - A) The first architecture has better isolation between CPU and memory subsystems
   - B) The second architecture has a larger cache
   - C) The operating system is not properly optimized
   - D) The benchmark is not measuring correctly

2. Which resource contention pattern typically shows the largest performance difference between x86 and Arm architectures?
   - A) CPU contention with no sharing
   - B) Memory contention with shared data
   - C) False sharing between threads
   - D) I/O contention

3. If an architecture shows high standard deviation in per-thread performance under contention, what might this indicate?
   - A) The architecture has more CPU cores
   - B) The architecture has unfair resource allocation under contention
   - C) The benchmark is not running long enough
   - D) The operating system is not properly configured

Answers:
1. A) The first architecture has better isolation between CPU and memory subsystems
2. C) False sharing between threads
3. B) The architecture has unfair resource allocation under contention