---
title: NUMA-Aware Scheduling for Neoverse
weight: 2350
layout: learningpathall
---

## Understanding NUMA on Arm Neoverse

Non-Uniform Memory Access (NUMA) is a memory architecture used in multi-socket server systems where memory access time depends on the memory location relative to the processor. In Arm Neoverse-based servers, particularly multi-socket configurations, NUMA awareness is critical for performance optimization.

Neoverse processors in cloud environments use homogeneous cores with NUMA domains across sockets. Understanding and optimizing for this architecture is essential for cloud computing workloads.

For more detailed information about NUMA on Arm servers, you can refer to:
- [Arm Neoverse Platform Architecture](https://developer.arm.com/documentation/102136/latest/)
- [NUMA Best Practices](https://developer.arm.com/documentation/102528/latest/)
- [Optimizing for Multi-Socket Arm Servers](https://community.arm.com/arm-community-blogs/b/infrastructure-solutions-blog)

## Benchmarking Exercise

### Prerequisites

Ensure you have:
- Completed the repository setup from the previous chapter
- ARM (aarch64) system with the bench_guide repository cloned

### Step 1: Navigate to Directory

Navigate to the benchmark directory:

```bash
cd bench_guide/2350_arm_numa_aware
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
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/arm_numa_aware/setup.sh
chmod +x setup.sh
./setup.sh
```

### Step 2: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/arm_numa_aware/benchmark.sh
chmod +x benchmark.sh
./benchmark.sh | tee arm_numa_aware_results.txt
```

### Step 3: Analyze the Results Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc numactl hwloc
```

### Step 2: Detect NUMA Topology

Create a file named `detect_numa.sh` with the following content:

Make the script executable and run it:

```bash
chmod +x detect_numa.sh
./detect_numa.sh
```

### Step 5: Run the Benchmark

Execute the benchmark script:

```bash
./run_numa_benchmark.sh
```

## Neoverse-specific NUMA Optimizations

Arm Neoverse processors in multi-socket configurations require specific NUMA optimizations:

### 1. Memory Allocation with NUMA Awareness

Create a file named `numa_alloc.c`:

Compile with:

```bash
# See: ../2400_compiler_optimizations.md#combined-optimizations
gcc -O3 numa_alloc.c -o numa_alloc -lnuma
```

### 2. Key Neoverse NUMA Optimization Techniques

1. **NUMA-Aware Memory Allocation**:
   ```c
   #include <numa.h>
   
   // Allocate memory on the local NUMA node
   void* local_memory = numa_alloc_local(size);
   
   // Allocate memory on a specific NUMA node
   void* node_memory = numa_alloc_onnode(size, node);
   
   // Allocate memory interleaved across all NUMA nodes
   void* interleaved_memory = numa_alloc_interleaved(size);
   ```

2. **Thread Placement**:
   ```c
   #include <numa.h>
   #include <pthread.h>
   
   // Pin thread to CPUs in a specific NUMA node
   void pin_to_node(int node) {
       struct bitmask *node_cpus = numa_allocate_cpumask();
       numa_node_to_cpus(node, node_cpus);
       numa_sched_setaffinity(0, node_cpus);
       numa_free_cpumask(node_cpus);
   }
   ```

3. **Memory Policy**:
   ```c
   #include <numaif.h>
   
   // Set memory policy for the current thread
   // MPOL_BIND: Use only the specified nodes
   // MPOL_PREFERRED: Prefer the specified node
   // MPOL_INTERLEAVE: Interleave allocations
   unsigned long nodemask = 1UL << node;
   set_mempolicy(MPOL_PREFERRED, &nodemask, sizeof(unsigned long) * 8);
   ```

4. **First-Touch Policy**:
   ```c
   // Memory is allocated on the NUMA node of the thread that first touches it
   void initialize_memory(float *array, size_t size) {
       #pragma omp parallel for
       for (size_t i = 0; i < size; i++) {
           array[i] = 0.0f;  // First touch
       }
   }
   ```

5. **NUMA-Aware Data Partitioning**:
   These NUMA optimizations are critical for Neoverse-based multi-socket servers in cloud environments, where memory access latency can significantly impact performance.

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| NUMA Support | ✓ (multi-socket) | ✓ (multi-socket) | ✓ (multi-socket) |
| MPAM | ✓ | ✓ | ✓ |

NUMA optimizations are applicable to all Neoverse processors in multi-socket configurations:
- Neoverse N1/V1/N2: All support NUMA in multi-socket server configurations
- All Neoverse processors support Memory Partitioning and Monitoring (MPAM) for resource partitioning

## OS/Kernel Tweaks for NUMA on Neoverse

To maximize NUMA performance on Neoverse servers, apply these OS-level tuning parameters:

### 1. Basic NUMA Settings

```bash
# Enable automatic NUMA balancing (kernel-level optimization)
echo 1 > /proc/sys/kernel/numa_balancing

# Set NUMA balancing scan delay (milliseconds)
echo 1000 > /proc/sys/kernel/numa_balancing_scan_delay_ms

# Set NUMA balancing scan period (milliseconds)
echo 1000 > /proc/sys/kernel/numa_balancing_scan_period_min_ms

# Configure zone reclaim mode (0=off, 1=on)
echo 0 > /proc/sys/vm/zone_reclaim_mode
```

### 2. Kernel Boot Parameters

Add these parameters to your kernel command line in `/etc/default/grub`:

```bash
# Add to GRUB_CMDLINE_LINUX
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX numa=on numa_balancing=1 transparent_hugepage=always"

# Update grub and reboot
sudo update-grub
sudo reboot
```

### 3. Process-Specific NUMA Policies

Run applications with specific NUMA policies:

```bash
# Run with local allocation policy
numactl --localalloc ./your_application

# Run with memory interleaved across all nodes
numactl --interleave=all ./your_application

# Run on specific NUMA node
numactl --cpunodebind=0 --membind=0 ./your_application

# Run with preferred node (soft binding)
numactl --preferred=0 ./your_application
```

### 4. Transparent Hugepages

Enable transparent hugepages for better NUMA performance:

```bash
# Enable transparent hugepages
echo always > /sys/kernel/mm/transparent_hugepage/enabled

# Enable NUMA-aware hugepages
echo advise > /sys/kernel/mm/transparent_hugepage/defrag
```

### Tuning Trade-offs

| Parameter | Performance Impact | When to Use | When to Avoid |
|-----------|-------------------|------------|--------------|
| `numa_balancing=1` | Medium (+) | Most workloads | Very latency-sensitive apps |
| `zone_reclaim_mode=0` | High (+) | Most workloads | Memory-constrained systems |
| `zone_reclaim_mode=1` | Medium (-) | High memory pressure | Low-latency requirements |
| `numactl --preferred` | Medium (+) | Single-threaded apps | Multi-threaded apps |
| `numactl --interleave` | Low (+) | Random access patterns | Sequential access patterns |

## Additional Performance Tweaks

### 1. NUMA-Aware Thread Placement

Explicitly place threads on the same NUMA node as their data:

### 2. First-Touch Memory Initialization

Initialize memory from the thread that will use it to ensure NUMA locality:

### 3. NUMA-Aware Memory Allocation

Use NUMA-specific allocation functions:

```c
#include <numa.h>

// Allocate memory on local node
void* local_alloc = numa_alloc_local(size);

// Allocate memory on specific node
void* node_alloc = numa_alloc_onnode(size, node);

// Allocate memory interleaved across all nodes
void* interleaved_alloc = numa_alloc_interleaved(size);

// Free NUMA memory
numa_free(ptr, size);
```

These tweaks can provide an additional 20-50% performance improvement for NUMA-sensitive workloads on multi-socket Neoverse servers.

## Further Reading

- [Arm Neoverse N1 System Development Platform](https://developer.arm.com/documentation/101489/latest/)
- [Arm Neoverse NUMA Best Practices](https://community.arm.com/arm-community-blogs/b/infrastructure-solutions-blog/posts/numa-aware-scheduling-on-arm-servers)
- [Arm Memory Partitioning and Monitoring (MPAM)](https://developer.arm.com/documentation/den0063/latest/)
- [Linux NUMA Policy Documentation](https://www.kernel.org/doc/html/latest/admin-guide/mm/numa_memory_policy.html)
- [Optimizing Memory Access on Arm Servers](https://www.arm.com/blogs/blueprint/memory-access-arm-servers)

## Relevance to Cloud Computing Workloads

NUMA-aware scheduling is particularly important for cloud computing on multi-socket Neoverse systems:

1. **Database Workloads**: OLTP and OLAP database operations
2. **In-Memory Computing**: Redis, Memcached, Apache Ignite
3. **Virtualization**: Hypervisors and VM placement
4. **Container Orchestration**: Kubernetes pod scheduling
5. **High-Performance Computing**: MPI applications, scientific simulations

Understanding NUMA characteristics on Neoverse helps you:
- Optimize memory access patterns for multi-socket systems
- Reduce cross-socket communication overhead
- Improve memory bandwidth utilization
- Balance workloads across NUMA domains
- Maximize performance per watt in data center environments