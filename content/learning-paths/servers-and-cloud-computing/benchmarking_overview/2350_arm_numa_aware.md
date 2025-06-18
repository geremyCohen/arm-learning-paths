---
title: NUMA-Aware Scheduling for Neoverse
weight: 2350

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding NUMA on Arm Neoverse

Non-Uniform Memory Access (NUMA) is a memory architecture used in multi-socket server systems where memory access time depends on the memory location relative to the processor. In Arm Neoverse-based servers, particularly multi-socket configurations, NUMA awareness is critical for performance optimization.

Neoverse processors in cloud environments use homogeneous cores with NUMA domains across sockets. Understanding and optimizing for this architecture is essential for cloud computing workloads.

For more detailed information about NUMA on Arm servers, you can refer to:
- [Arm Neoverse Platform Architecture](https://developer.arm.com/documentation/102136/latest/)
- [NUMA Best Practices](https://developer.arm.com/documentation/102528/latest/)
- [Optimizing for Multi-Socket Arm Servers](https://community.arm.com/arm-community-blogs/b/infrastructure-solutions-blog)

## Benchmarking Exercise: NUMA-Aware Scheduling on Neoverse

In this exercise, we'll measure and compare performance with and without NUMA-aware scheduling on multi-socket Arm Neoverse systems.

### Prerequisites

Ensure you have an Arm server with:
- Multiple Neoverse processors/sockets
- Linux with NUMA support
- numactl utility installed

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc numactl hwloc
```

### Step 2: Detect NUMA Topology

Create a file named `detect_numa.sh` with the following content:

```bash
#!/bin/bash

echo "CPU Architecture: $(uname -m)"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"

echo -e "\nNUMA Node Information:"
numactl --hardware

echo -e "\nDetailed Topology:"
if command -v lstopo-no-graphics &> /dev/null; then
    lstopo-no-graphics --no-io
else
    lscpu | grep -i "numa\|socket\|core\|thread"
fi

echo -e "\nNeoverse Detection:"
lscpu | grep -i neoverse
```

Make the script executable and run it:

```bash
chmod +x detect_numa.sh
./detect_numa.sh
```

### Step 3: Create NUMA Benchmark

Create a file named `numa_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include <numa.h>
#include <numaif.h>

#define BUFFER_SIZE (1024 * 1024 * 1024)  // 1GB
#define ITERATIONS 5
#define MAX_NUMA_NODES 8

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Thread argument structure
typedef struct {
    int thread_id;
    int numa_node;
    unsigned char *buffer;
    size_t buffer_size;
    double elapsed_time;
} thread_arg_t;

// Thread function for memory bandwidth test
void* memory_bandwidth_test(void* arg) {
    thread_arg_t* thread_arg = (thread_arg_t*)arg;
    unsigned char *buffer = thread_arg->buffer;
    size_t buffer_size = thread_arg->buffer_size;
    
    // Pin thread to a CPU in the specified NUMA node
    if (thread_arg->numa_node >= 0) {
        struct bitmask *node_cpus = numa_allocate_cpumask();
        numa_node_to_cpus(thread_arg->numa_node, node_cpus);
        
        // Find first CPU in this NUMA node
        int cpu = -1;
        for (int i = 0; i < numa_num_configured_cpus(); i++) {
            if (numa_bitmask_isbitset(node_cpus, i)) {
                cpu = i;
                break;
            }
        }
        
        if (cpu >= 0) {
            cpu_set_t cpuset;
            CPU_ZERO(&cpuset);
            CPU_SET(cpu, &cpuset);
            pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
            printf("Thread %d running on CPU %d (NUMA node %d)\n", 
                   thread_arg->thread_id, cpu, thread_arg->numa_node);
        }
        
        numa_free_cpumask(node_cpus);
    }
    
    // Memory bandwidth test
    double start = get_time();
    
    // Write test
    for (int iter = 0; iter < ITERATIONS; iter++) {
        for (size_t i = 0; i < buffer_size; i += 64) {  // Cache line size
            buffer[i] = (unsigned char)i;
        }
    }
    
    // Read test
    volatile unsigned char sum = 0;
    for (int iter = 0; iter < ITERATIONS; iter++) {
        for (size_t i = 0; i < buffer_size; i += 64) {  // Cache line size
            sum += buffer[i];
        }
    }
    
    double end = get_time();
    thread_arg->elapsed_time = end - start;
    
    printf("Thread %d: Time: %.6f seconds, Bandwidth: %.2f GB/s\n", 
           thread_arg->thread_id, thread_arg->elapsed_time,
           (2.0 * buffer_size * ITERATIONS) / (thread_arg->elapsed_time * 1024 * 1024 * 1024));
    
    return NULL;
}

int main() {
    // Check if NUMA is available
    if (numa_available() == -1) {
        printf("NUMA not available\n");
        return 1;
    }
    
    int num_nodes = numa_num_configured_nodes();
    printf("Number of NUMA nodes: %d\n", num_nodes);
    
    if (num_nodes < 2) {
        printf("This benchmark requires at least 2 NUMA nodes\n");
        return 1;
    }
    
    // Limit to MAX_NUMA_NODES
    if (num_nodes > MAX_NUMA_NODES) {
        num_nodes = MAX_NUMA_NODES;
        printf("Limiting to %d NUMA nodes\n", num_nodes);
    }
    
    // Allocate thread arguments
    thread_arg_t thread_args[MAX_NUMA_NODES];
    pthread_t threads[MAX_NUMA_NODES];
    
    printf("\n--- Local Memory Access (NUMA-aware) ---\n");
    
    // Create threads with local memory access
    for (int i = 0; i < num_nodes; i++) {
        thread_args[i].thread_id = i;
        thread_args[i].numa_node = i;
        
        // Allocate memory on the local NUMA node
        thread_args[i].buffer_size = BUFFER_SIZE / num_nodes;
        thread_args[i].buffer = numa_alloc_onnode(thread_args[i].buffer_size, i);
        
        if (!thread_args[i].buffer) {
            perror("numa_alloc_onnode");
            return 1;
        }
        
        pthread_create(&threads[i], NULL, memory_bandwidth_test, &thread_args[i]);
    }
    
    // Wait for threads to complete
    double total_local_time = 0.0;
    for (int i = 0; i < num_nodes; i++) {
        pthread_join(threads[i], NULL);
        total_local_time += thread_args[i].elapsed_time;
        numa_free(thread_args[i].buffer, thread_args[i].buffer_size);
    }
    
    double avg_local_time = total_local_time / num_nodes;
    printf("Average local memory access time: %.6f seconds\n", avg_local_time);
    
    printf("\n--- Remote Memory Access (NUMA-unaware) ---\n");
    
    // Create threads with remote memory access
    for (int i = 0; i < num_nodes; i++) {
        thread_args[i].thread_id = i;
        thread_args[i].numa_node = i;
        
        // Allocate memory on the remote NUMA node
        int remote_node = (i + 1) % num_nodes;
        thread_args[i].buffer_size = BUFFER_SIZE / num_nodes;
        thread_args[i].buffer = numa_alloc_onnode(thread_args[i].buffer_size, remote_node);
        
        if (!thread_args[i].buffer) {
            perror("numa_alloc_onnode");
            return 1;
        }
        
        printf("Thread %d accessing memory on NUMA node %d\n", i, remote_node);
        pthread_create(&threads[i], NULL, memory_bandwidth_test, &thread_args[i]);
    }
    
    // Wait for threads to complete
    double total_remote_time = 0.0;
    for (int i = 0; i < num_nodes; i++) {
        pthread_join(threads[i], NULL);
        total_remote_time += thread_args[i].elapsed_time;
        numa_free(thread_args[i].buffer, thread_args[i].buffer_size);
    }
    
    double avg_remote_time = total_remote_time / num_nodes;
    printf("Average remote memory access time: %.6f seconds\n", avg_remote_time);
    
    // Calculate NUMA penalty
    double numa_penalty = (avg_remote_time / avg_local_time) - 1.0;
    printf("\nNUMA penalty: %.2f%%\n", numa_penalty * 100);
    
    return 0;
}
```

Compile with NUMA support:

```bash
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -pthread numa_benchmark.c -o numa_benchmark -lnuma
```

### Step 4: Create Benchmark Script

Create a file named `run_numa_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Check if numactl is available
if ! command -v numactl &> /dev/null; then
    echo "numactl not found. Please install it with: sudo apt install numactl"
    exit 1
fi

# Get NUMA information
echo "NUMA Topology:"
numactl --hardware

# Run NUMA benchmark
echo -e "\nRunning NUMA benchmark..."
./numa_benchmark | tee numa_benchmark_results.txt

# Run with different NUMA policies
echo -e "\nRunning with local policy..."
numactl --localalloc ./numa_benchmark | tee numa_local_results.txt

echo -e "\nRunning with interleave policy..."
numactl --interleave=all ./numa_benchmark | tee numa_interleave_results.txt

echo "Benchmark complete. Results saved to text files."
```

Make the script executable:

```bash
chmod +x run_numa_benchmark.sh
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

```c
#include <stdio.h>
#include <stdlib.h>
#include <numa.h>
#include <numaif.h>
#include <unistd.h>
#include <time.h>

#define SIZE (1024 * 1024 * 1024)  // 1GB

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

int main() {
    // Check if NUMA is available
    if (numa_available() == -1) {
        printf("NUMA not available\n");
        return 1;
    }
    
    int num_nodes = numa_num_configured_nodes();
    printf("Number of NUMA nodes: %d\n", num_nodes);
    
    // Get current NUMA node
    int cpu = sched_getcpu();
    int node = numa_node_of_cpu(cpu);
    printf("Current CPU: %d, NUMA node: %d\n", cpu, node);
    
    // Standard allocation
    printf("\nTesting standard allocation...\n");
    double start = get_time();
    void *standard_mem = malloc(SIZE);
    double end = get_time();
    printf("Allocation time: %.6f seconds\n", end - start);
    
    // Touch pages to measure access time
    start = get_time();
    for (size_t i = 0; i < SIZE; i += 4096) {
        ((char*)standard_mem)[i] = 1;
    }
    end = get_time();
    printf("Page touch time: %.6f seconds\n", end - start);
    
    // Get NUMA policy for this memory
    int status = -1;
    get_mempolicy(&status, NULL, 0, standard_mem, MPOL_F_NODE | MPOL_F_ADDR);
    printf("Memory allocated on node: %d\n", status);
    
    free(standard_mem);
    
    // NUMA local allocation
    printf("\nTesting NUMA local allocation...\n");
    start = get_time();
    void *local_mem = numa_alloc_onnode(SIZE, node);
    end = get_time();
    printf("Allocation time: %.6f seconds\n", end - start);
    
    // Touch pages to measure access time
    start = get_time();
    for (size_t i = 0; i < SIZE; i += 4096) {
        ((char*)local_mem)[i] = 1;
    }
    end = get_time();
    printf("Page touch time: %.6f seconds\n", end - start);
    
    numa_free(local_mem, SIZE);
    
    // NUMA interleaved allocation
    printf("\nTesting NUMA interleaved allocation...\n");
    start = get_time();
    void *interleaved_mem = numa_alloc_interleaved(SIZE);
    end = get_time();
    printf("Allocation time: %.6f seconds\n", end - start);
    
    // Touch pages to measure access time
    start = get_time();
    for (size_t i = 0; i < SIZE; i += 4096) {
        ((char*)interleaved_mem)[i] = 1;
    }
    end = get_time();
    printf("Page touch time: %.6f seconds\n", end - start);
    
    numa_free(interleaved_mem, SIZE);
    
    return 0;
}
```

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
   ```c
   // Partition data by NUMA node
   void process_data_numa_aware(float *data, size_t size) {
       int num_nodes = numa_num_configured_nodes();
       size_t chunk_size = size / num_nodes;
       
       #pragma omp parallel
       {
           int node = numa_node_of_cpu(sched_getcpu());
           size_t start = node * chunk_size;
           size_t end = (node == num_nodes - 1) ? size : (node + 1) * chunk_size;
           
           // Process local chunk
           for (size_t i = start; i < end; i++) {
               data[i] = process(data[i]);
           }
       }
   }
   ```

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

```c
#include <numa.h>
#include <pthread.h>

// Function to pin thread to the NUMA node containing a memory address
void pin_to_memory_node(void* addr) {
    int node = numa_node_of_addr(addr);
    if (node >= 0) {
        struct bitmask *node_mask = numa_allocate_nodemask();
        numa_bitmask_setbit(node_mask, node);
        numa_sched_setaffinity(0, node_mask);
        numa_free_nodemask(node_mask);
    }
}

// Usage in thread function
void* thread_func(void* arg) {
    // Pin thread to the NUMA node containing the data
    pin_to_memory_node(arg);
    
    // Process data
    // ...
    
    return NULL;
}
```

### 2. First-Touch Memory Initialization

Initialize memory from the thread that will use it to ensure NUMA locality:

```c
#include <pthread.h>
#include <numa.h>

// Thread argument structure
typedef struct {
    float *data;
    size_t start;
    size_t end;
} thread_arg_t;

// Thread function for initialization
void* init_thread(void* arg) {
    thread_arg_t* thread_arg = (thread_arg_t*)arg;
    
    // Initialize data (first touch)
    for (size_t i = thread_arg->start; i < thread_arg->end; i++) {
        thread_arg->data[i] = 0.0f;
    }
    
    return NULL;
}

// NUMA-aware initialization
void numa_aware_init(float *data, size_t size) {
    int num_nodes = numa_num_configured_nodes();
    pthread_t threads[num_nodes];
    thread_arg_t args[num_nodes];
    
    size_t chunk_size = size / num_nodes;
    
    // Create initialization threads
    for (int i = 0; i < num_nodes; i++) {
        args[i].data = data;
        args[i].start = i * chunk_size;
        args[i].end = (i == num_nodes - 1) ? size : (i + 1) * chunk_size;
        
        // Bind thread to NUMA node
        pthread_attr_t attr;
        pthread_attr_init(&attr);
        
        struct bitmask *node_mask = numa_allocate_nodemask();
        numa_bitmask_setbit(node_mask, i);
        numa_bind(node_mask);
        numa_free_nodemask(node_mask);
        
        pthread_create(&threads[i], &attr, init_thread, &args[i]);
        pthread_attr_destroy(&attr);
    }
    
    // Wait for initialization to complete
    for (int i = 0; i < num_nodes; i++) {
        pthread_join(threads[i], NULL);
    }
}
```

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