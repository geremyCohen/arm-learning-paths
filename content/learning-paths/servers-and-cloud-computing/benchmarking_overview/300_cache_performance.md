---
title: Cache Performance
weight: 300

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Cache Performance

Cache performance is a critical factor in determining overall system performance. Modern processors have multiple levels of cache (L1, L2, L3) that store frequently accessed data to reduce memory access latency. The effectiveness of these caches depends on factors like size, associativity, line size, and replacement policy, which can vary between architectures.

When comparing Intel/AMD (x86) versus Arm architectures, cache hierarchies can differ significantly in terms of size, organization, and latency. These differences can have substantial performance implications, especially for memory-intensive workloads.

For more detailed information about cache performance, you can refer to:
- [Cache Performance Fundamentals](https://www.cs.cornell.edu/courses/cs3410/2013sp/lecture/18-caches3-w.pdf)
- [CPU Cache Optimization](https://www.intel.com/content/dam/develop/external/us/en/documents/introduction-to-intel-cache-optimization-254438.pdf)
- [Arm Cache Architecture](https://developer.arm.com/documentation/den0024/a/Memory-Ordering/Memory-hierarchy)

## Benchmarking Exercise: Comparing Cache Performance

In this exercise, we'll measure and compare cache performance across Intel/AMD and Arm architectures using various access patterns.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential python3-matplotlib
```

### Step 2: Create Cache Benchmark

Create a file named `cache_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

#define MAX_ARRAY_SIZE (64 * 1024 * 1024)  // 64MB
#define MIN_ARRAY_SIZE (1 * 1024)          // 1KB
#define ITERATIONS 100000000
#define STEP_FACTOR 2

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Sequential access pattern
void sequential_access(int *array, size_t array_size, size_t iterations) {
    size_t i, iter;
    volatile int sum = 0;  // Prevent optimization
    
    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < array_size; i++) {
            sum += array[i];
        }
        
        // Break early for large arrays to keep runtime reasonable
        if (array_size > 1024 * 1024 && iter > iterations / 100) {
            break;
        }
    }
}

// Random access pattern
void random_access(int *array, size_t array_size, int *indices, size_t iterations) {
    size_t i, iter;
    volatile int sum = 0;  // Prevent optimization
    
    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < array_size; i++) {
            sum += array[indices[i]];
        }
        
        // Break early for large arrays to keep runtime reasonable
        if (array_size > 1024 * 1024 && iter > iterations / 100) {
            break;
        }
    }
}

// Strided access pattern
void strided_access(int *array, size_t array_size, size_t stride, size_t iterations) {
    size_t i, iter;
    volatile int sum = 0;  // Prevent optimization
    
    for (iter = 0; iter < iterations; iter++) {
        for (i = 0; i < array_size; i += stride) {
            sum += array[i];
        }
        
        // Break early for large arrays to keep runtime reasonable
        if (array_size > 1024 * 1024 && iter > iterations / 100) {
            break;
        }
    }
}

int main(int argc, char *argv[]) {
    int access_pattern = 0;  // 0: sequential, 1: random, 2: strided
    int stride = 16;         // Default stride for strided access
    
    // Parse command line arguments
    if (argc > 1) {
        access_pattern = atoi(argv[1]);
    }
    if (argc > 2) {
        stride = atoi(argv[2]);
    }
    
    printf("Access pattern: %d (0: sequential, 1: random, 2: strided)\n", access_pattern);
    if (access_pattern == 2) {
        printf("Stride: %d\n", stride);
    }
    
    // Allocate maximum array size
    int *array = (int *)malloc(MAX_ARRAY_SIZE * sizeof(int));
    if (!array) {
        perror("malloc");
        return 1;
    }
    
    // Initialize array
    for (size_t i = 0; i < MAX_ARRAY_SIZE; i++) {
        array[i] = i;
    }
    
    // For random access, create index array
    int *indices = NULL;
    if (access_pattern == 1) {
        indices = (int *)malloc(MAX_ARRAY_SIZE * sizeof(int));
        if (!indices) {
            perror("malloc");
            free(array);
            return 1;
        }
        
        // Initialize indices with random values
        for (size_t i = 0; i < MAX_ARRAY_SIZE; i++) {
            indices[i] = rand() % MAX_ARRAY_SIZE;
        }
    }
    
    // Test different array sizes
    printf("Array size (bytes),Access time (ns)\n");
    
    for (size_t array_size = MIN_ARRAY_SIZE; array_size <= MAX_ARRAY_SIZE; array_size *= STEP_FACTOR) {
        size_t elements = array_size / sizeof(int);
        
        // Adjust iterations based on array size to keep runtime reasonable
        size_t adjusted_iterations = ITERATIONS / (array_size / MIN_ARRAY_SIZE);
        if (adjusted_iterations < 10) adjusted_iterations = 10;
        
        // Warm up cache
        if (access_pattern == 0) {
            sequential_access(array, elements, 10);
        } else if (access_pattern == 1) {
            random_access(array, elements, indices, 10);
        } else {
            strided_access(array, elements, stride, 10);
        }
        
        // Measure access time
        double start_time = get_time();
        
        if (access_pattern == 0) {
            sequential_access(array, elements, adjusted_iterations);
        } else if (access_pattern == 1) {
            random_access(array, elements, indices, adjusted_iterations);
        } else {
            strided_access(array, elements, stride, adjusted_iterations);
        }
        
        double end_time = get_time();
        double elapsed = end_time - start_time;
        
        // Calculate average access time in nanoseconds
        double access_time_ns = (elapsed * 1e9) / (elements * adjusted_iterations);
        
        printf("%zu,%.2f\n", array_size, access_time_ns);
    }
    
    // Clean up
    free(array);
    if (indices) free(indices);
    
    return 0;
}
```

Compile the benchmark:

```bash
gcc -O2 cache_benchmark.c -o cache_benchmark
```

### Step 3: Create Benchmark Script

Create a file named `run_cache_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Get architecture
arch=$(uname -m)
echo "Architecture: $arch"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"

# Run sequential access benchmark
echo "Running sequential access benchmark..."
./cache_benchmark 0 > sequential_access.csv

# Run random access benchmark
echo "Running random access benchmark..."
./cache_benchmark 1 > random_access.csv

# Run strided access benchmark with different strides
echo "Running strided access benchmark..."
for stride in 1 2 4 8 16 32 64 128; do
    echo "  Stride: $stride"
    ./cache_benchmark 2 $stride > strided_access_${stride}.csv
done

echo "Benchmark complete. Results saved to CSV files."
```

Make the script executable:

```bash
chmod +x run_cache_benchmark.sh
```

### Step 4: Create Visualization Script

Create a file named `plot_cache_results.py` with the following content:

```python
import matplotlib.pyplot as plt
import numpy as np
import csv
import os

def read_csv(filename):
    sizes = []
    times = []
    
    with open(filename, 'r') as f:
        reader = csv.reader(f)
        next(reader)  # Skip header
        for row in reader:
            sizes.append(int(row[0]))
            times.append(float(row[1]))
    
    return np.array(sizes), np.array(times)

# Plot sequential vs random access
plt.figure(figsize=(10, 6))

if os.path.exists('sequential_access.csv'):
    seq_sizes, seq_times = read_csv('sequential_access.csv')
    plt.plot(seq_sizes, seq_times, 'b-', label='Sequential Access')

if os.path.exists('random_access.csv'):
    rand_sizes, rand_times = read_csv('random_access.csv')
    plt.plot(rand_sizes, rand_times, 'r-', label='Random Access')

plt.xscale('log')
plt.yscale('log')
plt.xlabel('Array Size (bytes)')
plt.ylabel('Access Time (ns)')
plt.title('Cache Performance: Sequential vs Random Access')
plt.legend()
plt.grid(True)
plt.savefig('cache_sequential_vs_random.png')

# Plot strided access
plt.figure(figsize=(10, 6))

strides = [1, 2, 4, 8, 16, 32, 64, 128]
for stride in strides:
    filename = f'strided_access_{stride}.csv'
    if os.path.exists(filename):
        sizes, times = read_csv(filename)
        plt.plot(sizes, times, label=f'Stride {stride}')

plt.xscale('log')
plt.yscale('log')
plt.xlabel('Array Size (bytes)')
plt.ylabel('Access Time (ns)')
plt.title('Cache Performance: Strided Access')
plt.legend()
plt.grid(True)
plt.savefig('cache_strided_access.png')

print("Plots saved as cache_sequential_vs_random.png and cache_strided_access.png")
```

### Step 5: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
./run_cache_benchmark.sh
```

### Step 6: Visualize the Results

Run the visualization script:

```bash
python3 plot_cache_results.py
```

### Step 7: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Cache Size Identification**: Look for "steps" in the access time graph, which indicate transitions between cache levels.
2. **Cache Latency**: Compare the access times within each cache level.
3. **Cache Hierarchy Impact**: Analyze how different access patterns affect performance on each architecture.
4. **Stride Sensitivity**: Determine how each architecture handles different stride sizes.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Cache Sizes**: Different architectures have different L1, L2, and L3 cache sizes.
- **Cache Line Size**: The size of a cache line affects how data is fetched from memory.
- **Cache Associativity**: Higher associativity can reduce conflict misses but may increase lookup time.
- **Prefetching**: Different architectures implement different prefetching strategies, which can affect sequential and strided access patterns.

## Arm-specific Optimizations

Arm architectures offer several optimization techniques to improve cache performance:

### 1. Memory Prefetch Optimizations

Create a file named `arm_prefetch.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ARRAY_SIZE (64 * 1024 * 1024)  // 64MB
#define ITERATIONS 10

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Standard sequential access
void standard_access(int *array, size_t size) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i++) {
        sum += array[i];
    }
}

// Arm-optimized access with prefetch
void prefetch_access(int *array, size_t size) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i++) {
        // Prefetch data 64 elements ahead
        #ifdef __aarch64__
        __builtin_prefetch(&array[i + 64], 0, 3);
        #endif
        
        sum += array[i];
    }
}

// Arm-optimized access with multiple prefetch distances
void multi_prefetch_access(int *array, size_t size) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i++) {
        #ifdef __aarch64__
        // Prefetch at different distances for different cache levels
        __builtin_prefetch(&array[i + 16], 0, 3);  // L1 cache
        __builtin_prefetch(&array[i + 64], 0, 2);  // L2 cache
        __builtin_prefetch(&array[i + 256], 0, 1); // L3 cache
        #endif
        
        sum += array[i];
    }
}

int main() {
    // Allocate array
    int *array = (int *)malloc(ARRAY_SIZE * sizeof(int));
    if (!array) {
        perror("malloc");
        return 1;
    }
    
    // Initialize array
    for (size_t i = 0; i < ARRAY_SIZE; i++) {
        array[i] = i;
    }
    
    // Test standard access
    double start = get_time();
    for (int iter = 0; iter < ITERATIONS; iter++) {
        standard_access(array, ARRAY_SIZE);
    }
    double end = get_time();
    
    printf("Standard access time: %.6f seconds\n", end - start);
    
    // Test prefetch access
    start = get_time();
    for (int iter = 0; iter < ITERATIONS; iter++) {
        prefetch_access(array, ARRAY_SIZE);
    }
    end = get_time();
    
    printf("Prefetch access time: %.6f seconds\n", end - start);
    
    // Test multi-prefetch access
    start = get_time();
    for (int iter = 0; iter < ITERATIONS; iter++) {
        multi_prefetch_access(array, ARRAY_SIZE);
    }
    end = get_time();
    
    printf("Multi-prefetch access time: %.6f seconds\n", end - start);
    
    free(array);
    return 0;
}
```

Compile with:

```bash
gcc -O3 -march=native arm_prefetch.c -o arm_prefetch
```

### 2. Arm Cache Management Instructions

Create a file named `arm_cache_management.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ARRAY_SIZE (16 * 1024 * 1024)  // 16MB
#define ITERATIONS 10

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Standard array initialization
void standard_init(int *array, size_t size) {
    for (size_t i = 0; i < size; i++) {
        array[i] = i;
    }
}

// Arm-optimized initialization with cache management
void cache_managed_init(int *array, size_t size) {
    for (size_t i = 0; i < size; i++) {
        array[i] = i;
        
        // Every 4096 elements (16KB), clean the cache line
        if ((i & 0xFFF) == 0) {
            #ifdef __aarch64__
            // Clean data cache by virtual address to point of coherency
            __asm__ volatile("dc cvac, %0" : : "r" (&array[i]) : "memory");
            #endif
        }
    }
    
    #ifdef __aarch64__
    // Data synchronization barrier
    __asm__ volatile("dsb ish" : : : "memory");
    #endif
}

// Benchmark function
void benchmark_access(int *array, size_t size) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i++) {
        sum += array[i];
    }
}

int main() {
    // Allocate array
    int *array = (int *)malloc(ARRAY_SIZE * sizeof(int));
    if (!array) {
        perror("malloc");
        return 1;
    }
    
    // Test standard initialization and access
    double start = get_time();
    standard_init(array, ARRAY_SIZE);
    double mid = get_time();
    for (int iter = 0; iter < ITERATIONS; iter++) {
        benchmark_access(array, ARRAY_SIZE);
    }
    double end = get_time();
    
    printf("Standard initialization time: %.6f seconds\n", mid - start);
    printf("Standard access time: %.6f seconds\n", end - mid);
    
    // Test cache-managed initialization and access
    start = get_time();
    cache_managed_init(array, ARRAY_SIZE);
    mid = get_time();
    for (int iter = 0; iter < ITERATIONS; iter++) {
        benchmark_access(array, ARRAY_SIZE);
    }
    end = get_time();
    
    printf("Cache-managed initialization time: %.6f seconds\n", mid - start);
    printf("Cache-managed access time: %.6f seconds\n", end - mid);
    
    free(array);
    return 0;
}
```

Compile with:

```bash
gcc -O3 -march=native arm_cache_management.c -o arm_cache_management
```

### 3. Key Arm Cache Optimization Techniques

1. **Prefetch Instructions**: Use Arm-specific prefetch instructions to reduce cache miss penalties:
   ```c
   // Prefetch for read
   __builtin_prefetch(addr, 0, 3);  // 0 = read, 3 = high temporal locality
   
   // Prefetch for write
   __builtin_prefetch(addr, 1, 3);  // 1 = write
   ```

2. **Cache Line Alignment**: Align data structures to cache line boundaries (typically 64 bytes):
   ```c
   struct aligned_data {
       int data[16];  // 64 bytes (assuming 4-byte ints)
   } __attribute__((aligned(64)));
   ```

3. **Cache Management Instructions**: Use Arm-specific cache management instructions:
   ```c
   // Clean data cache by virtual address
   __asm__ volatile("dc cvac, %0" : : "r" (addr));
   
   // Invalidate data cache by virtual address
   __asm__ volatile("dc ivac, %0" : : "r" (addr));
   
   // Data synchronization barrier
   __asm__ volatile("dsb ish");
   ```

4. **Non-temporal Loads and Stores**: For streaming data that won't be reused:
   ```c
   // On newer Arm processors with SVE
   #ifdef __ARM_FEATURE_SVE
   #include <arm_sve.h>
   
   void stream_store(float *dst, float *src, int size) {
       for (int i = 0; i < size; i += svcntw()) {
           svbool_t pg = svwhilelt_b32(i, size);
           svfloat32_t data = svld1(pg, &src[i]);
           svst1_f32(pg, &dst[i]);  // Non-temporal store
       }
   }
   #endif
   ```

These optimizations can significantly improve cache performance on Arm architectures, especially for memory-intensive workloads.

## Relevance to Workloads

Cache performance benchmarking is particularly important for:

1. **Data Processing Applications**: Database systems, analytics engines
2. **Scientific Computing**: Simulations, numerical analysis
3. **Media Processing**: Image and video processing
4. **Machine Learning**: Training and inference operations
5. **Game Engines**: Physics simulations, rendering

Understanding cache performance differences between architectures helps you optimize code for better performance by:
- Structuring data to maximize spatial locality
- Organizing algorithms to maximize temporal locality
- Selecting appropriate data structures and access patterns
- Tuning algorithms to match the cache hierarchy of the target architecture