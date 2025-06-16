---
title: Cache Performance
weight: 300

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Cache Performance

Cache performance is a critical factor in determining overall system performance. CPU caches are small, high-speed memory areas that store frequently accessed data to reduce the time needed to fetch data from main memory. Modern processors typically have multiple levels of cache (L1, L2, L3), each with different sizes and access speeds.

When comparing Intel/AMD (x86) versus Arm architectures, cache hierarchies can differ significantly in terms of size, organization, and latency. These differences can have profound effects on application performance, especially for workloads with specific memory access patterns.

For more detailed information about cache performance, you can refer to:
- [CPU Cache Explained](https://www.cloudflare.com/learning/performance/what-is-cpu-cache/)
- [Cache Optimization Techniques](https://software.intel.com/content/www/us/en/develop/articles/cache-optimization-in-applications.html)

## Benchmarking Exercise: Comparing Cache Performance

In this exercise, we'll use LMBench and a custom cache traversal benchmark to measure and compare cache performance across Intel/AMD and Arm systems.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential git python3 python3-matplotlib lmbench
```

### Step 2: Create Cache Traversal Benchmark

Create a file named `cache_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define CACHE_LINE_SIZE 64
#define BILLION 1000000000L

// Function to measure time with nanosecond precision
uint64_t get_ns() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * BILLION + ts.tv_nsec;
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        printf("Usage: %s <array_size_mb> <stride>\n", argv[0]);
        return 1;
    }

    int size_mb = atoi(argv[1]);
    int stride = atoi(argv[2]);
    
    // Convert MB to bytes
    size_t size = (size_t)size_mb * 1024 * 1024;
    size_t elements = size / sizeof(int);
    
    // Allocate memory
    int *array = (int *)malloc(size);
    if (!array) {
        printf("Memory allocation failed\n");
        return 1;
    }
    
    // Initialize array with indices
    for (size_t i = 0; i < elements; i++) {
        array[i] = (i + stride) % elements;
    }
    
    // Warm up the cache
    int index = 0;
    for (int i = 0; i < 1000000; i++) {
        index = array[index];
    }
    
    // Measure traversal time
    uint64_t start_time = get_ns();
    
    // Traverse the array using the indices stored in the array
    // This creates a pointer-chasing pattern that is sensitive to cache performance
    index = 0;
    for (size_t i = 0; i < elements; i++) {
        index = array[index];
    }
    
    uint64_t end_time = get_ns();
    uint64_t elapsed = end_time - start_time;
    
    // Calculate metrics
    double seconds = (double)elapsed / BILLION;
    double bandwidth = (double)elements * sizeof(int) / seconds / (1024 * 1024);
    double ns_per_access = (double)elapsed / elements;
    
    // Print results
    printf("Array size: %d MB\n", size_mb);
    printf("Stride: %d\n", stride);
    printf("Time: %.6f seconds\n", seconds);
    printf("Bandwidth: %.2f MB/s\n", bandwidth);
    printf("Access time: %.2f ns per element\n", ns_per_access);
    
    // Prevent compiler from optimizing away the traversal
    printf("Validation: %d\n", index);
    
    free(array);
    return 0;
}
```

Compile the benchmark:

```bash
gcc -O3 cache_benchmark.c -o cache_benchmark
```

### Step 3: Create Benchmark Script

Create a file named `run_cache_benchmark.sh` with the following content:

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
echo "Cache Information:"
lscpu | grep -i cache
echo ""

# Run LMBench cache latency test
echo "=== Running LMBench Cache Latency Test ==="
lat_mem_rd 64 128

# Run custom cache benchmark with different array sizes
echo "=== Running Custom Cache Traversal Benchmark ==="
echo "Testing different array sizes with stride=1..."

# Create CSV file for results
echo "size_kb,latency_ns" > cache_results.csv

# Test with increasing array sizes to reveal cache hierarchy
for size_kb in 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768; do
  size_mb=$((size_kb / 1024))
  if [ $size_mb -eq 0 ]; then
    size_mb=1
  fi
  
  echo "Testing array size: $size_kb KB"
  ./cache_benchmark $size_mb 1 | tee -a full_results.txt
  
  # Extract access time and add to CSV
  access_time=$(./cache_benchmark $size_mb 1 | grep "Access time" | awk '{print $3}')
  echo "$size_kb,$access_time" >> cache_results.csv
  
  echo ""
done

# Generate plot if Python and matplotlib are available
if command -v python3 &> /dev/null; then
  echo "Generating cache latency plot..."
  python3 - <<EOF
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

# Read data
data = pd.read_csv('cache_results.csv')

# Create plot
plt.figure(figsize=(10, 6))
plt.semilogx(data['size_kb'], data['latency_ns'], '-o')
plt.grid(True, which="both", ls="-")
plt.xlabel('Array Size (KB)')
plt.ylabel('Access Latency (ns)')
plt.title('Memory Access Latency vs Array Size - $(get_arch)')
plt.savefig('cache_latency_plot.png')
print("Plot saved as cache_latency_plot.png")
EOF
fi
```

Make the script executable:

```bash
chmod +x run_cache_benchmark.sh
```

### Step 4: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
./run_cache_benchmark.sh | tee cache_benchmark_results.txt
```

### Step 5: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Cache Hierarchy**: Identify the different cache levels from the latency jumps in the plot.
2. **Cache Sizes**: Compare the effective cache sizes between architectures.
3. **Cache Latencies**: Compare the access times for each cache level.
4. **Memory Latency**: Compare the baseline memory access latency once outside of cache.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Cache Organization**: Arm and x86 processors may have different cache hierarchies and associativity.
- **Cache Coherence Protocols**: Different architectures may implement different cache coherence mechanisms.
- **Prefetching Algorithms**: Processors may have different hardware prefetchers that affect cache performance.
- **Cache Line Size**: While 64 bytes is common, some implementations may have different effective line sizes.

## Relevance to Workloads

Cache performance benchmarking is particularly important for:

1. **Database Systems**: Query execution, index traversal, join operations
2. **High-Performance Computing**: Scientific simulations with complex data structures
3. **Game Engines**: Physics calculations, AI pathfinding, rendering pipelines
4. **Financial Applications**: High-frequency trading, risk analysis
5. **Compiler Optimization**: Understanding target architecture for better code generation

Understanding cache performance differences between architectures helps developers optimize data structures and algorithms for specific platforms, potentially leading to significant performance improvements.

## Knowledge Check

1. If an application shows significantly better performance on a processor with smaller but lower-latency caches compared to one with larger but higher-latency caches, this suggests:
   - A) The application has good temporal locality but poor spatial locality
   - B) The application has poor temporal locality but good spatial locality
   - C) The application's working set fits within the smaller cache
   - D) The application is not cache-sensitive

2. Which access pattern is most likely to benefit from larger cache sizes?
   - A) Sequential access of a large array
   - B) Random access across a large data structure
   - C) Repeated access to a small set of variables
   - D) Streaming data that is processed once and never reused

3. If cache latency measurements show similar patterns but consistently higher latencies on one architecture, what might this indicate?
   - A) The benchmark is biased toward one architecture
   - B) One architecture has a fundamentally higher clock cycle time for cache access
   - C) The operating system is interfering with cache performance
   - D) The memory controller is slower on one architecture

Answers:
1. C) The application's working set fits within the smaller cache
2. B) Random access across a large data structure
3. B) One architecture has a fundamentally higher clock cycle time for cache access