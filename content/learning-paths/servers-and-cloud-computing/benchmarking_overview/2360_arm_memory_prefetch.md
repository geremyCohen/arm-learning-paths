---
title: Arm Memory Prefetch Optimizations
weight: 2360

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Arm Memory Prefetch

Memory prefetching is a technique used to reduce memory latency by fetching data from main memory into caches before it's actually needed. Arm architectures provide specific prefetch instructions that allow software to give hints to the hardware about future memory accesses, which can significantly improve performance for memory-bound applications.

When comparing Intel/AMD (x86) versus Arm architectures, both provide prefetch instructions, but with different syntax and behavior. Understanding these differences can help optimize memory-intensive workloads for each architecture.

For more detailed information about Arm memory prefetch, you can refer to:
- [Arm Architecture Reference Manual](https://developer.arm.com/documentation/ddi0487/latest)
- [Arm Cortex-A Series Programmer's Guide](https://developer.arm.com/documentation/den0024/latest/)
- [Memory System Optimization Guide](https://developer.arm.com/documentation/102529/latest/)

## Benchmarking Exercise: Memory Prefetch Performance

In this exercise, we'll measure and compare the performance impact of using memory prefetch instructions on Arm architecture.

### Prerequisites

Ensure you have an Arm VM:
- Arm (aarch64) architecture

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc
```

### Step 2: Create Memory Prefetch Benchmark

Create a file named `prefetch_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ARRAY_SIZE (100 * 1024 * 1024)  // 100MB
#define STRIDE 64  // Cache line size
#define ITERATIONS 5

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Standard memory access without prefetch
void standard_access(int *array, size_t size) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i += STRIDE/sizeof(int)) {
        sum += array[i];
    }
}

// Memory access with software prefetch
void prefetch_access(int *array, size_t size) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i += STRIDE/sizeof(int)) {
        // Prefetch data 64 elements ahead
        #ifdef __aarch64__
        __builtin_prefetch(&array[i + (64 * STRIDE/sizeof(int))], 0, 3);
        #endif
        
        sum += array[i];
    }
}

// Memory access with multiple prefetch distances
void multi_prefetch_access(int *array, size_t size) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i += STRIDE/sizeof(int)) {
        #ifdef __aarch64__
        // Prefetch at different distances for different cache levels
        __builtin_prefetch(&array[i + (16 * STRIDE/sizeof(int))], 0, 3);  // L1 cache
        __builtin_prefetch(&array[i + (64 * STRIDE/sizeof(int))], 0, 2);  // L2 cache
        __builtin_prefetch(&array[i + (256 * STRIDE/sizeof(int))], 0, 1); // L3 cache
        #endif
        
        sum += array[i];
    }
}

int main() {
    printf("CPU Architecture: %s\n", 
        #ifdef __aarch64__
        "aarch64"
        #else
        "other"
        #endif
    );
    
    // Allocate array
    int *array = (int *)malloc(ARRAY_SIZE);
    if (!array) {
        perror("malloc");
        return 1;
    }
    
    // Initialize array
    for (size_t i = 0; i < ARRAY_SIZE/sizeof(int); i++) {
        array[i] = i;
    }
    
    // Benchmark standard access
    double start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        standard_access(array, ARRAY_SIZE/sizeof(int));
    }
    double end = get_time();
    double standard_time = end - start;
    
    printf("Standard access time: %.6f seconds\n", standard_time);
    
    // Benchmark prefetch access
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        prefetch_access(array, ARRAY_SIZE/sizeof(int));
    }
    end = get_time();
    double prefetch_time = end - start;
    
    printf("Prefetch access time: %.6f seconds\n", prefetch_time);
    printf("Prefetch speedup: %.2fx\n", standard_time / prefetch_time);
    
    // Benchmark multi-prefetch access
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        multi_prefetch_access(array, ARRAY_SIZE/sizeof(int));
    }
    end = get_time();
    double multi_prefetch_time = end - start;
    
    printf("Multi-prefetch access time: %.6f seconds\n", multi_prefetch_time);
    printf("Multi-prefetch speedup: %.2fx\n", standard_time / multi_prefetch_time);
    
    free(array);
    return 0;
}
```

Compile the benchmark:

```bash
gcc -O3 -march=native prefetch_benchmark.c -o prefetch_benchmark
```

### Step 3: Create Stride Prefetch Benchmark

Create a file named `stride_prefetch_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ARRAY_SIZE (100 * 1024 * 1024)  // 100MB
#define ITERATIONS 5

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Access with different strides, without prefetch
void stride_access(int *array, size_t size, size_t stride) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i += stride) {
        sum += array[i];
    }
}

// Access with different strides, with prefetch
void stride_prefetch_access(int *array, size_t size, size_t stride) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i += stride) {
        #ifdef __aarch64__
        // Prefetch ahead by 16 elements
        if (i + (16 * stride) < size) {
            __builtin_prefetch(&array[i + (16 * stride)], 0, 3);
        }
        #endif
        
        sum += array[i];
    }
}

int main() {
    // Allocate array
    int *array = (int *)malloc(ARRAY_SIZE);
    if (!array) {
        perror("malloc");
        return 1;
    }
    
    // Initialize array
    for (size_t i = 0; i < ARRAY_SIZE/sizeof(int); i++) {
        array[i] = i;
    }
    
    printf("Stride,Standard Time (s),Prefetch Time (s),Speedup\n");
    
    // Test different strides
    for (size_t stride = 1; stride <= 64; stride *= 2) {
        // Benchmark standard access
        double start = get_time();
        for (int i = 0; i < ITERATIONS; i++) {
            stride_access(array, ARRAY_SIZE/sizeof(int), stride);
        }
        double end = get_time();
        double standard_time = end - start;
        
        // Benchmark prefetch access
        start = get_time();
        for (int i = 0; i < ITERATIONS; i++) {
            stride_prefetch_access(array, ARRAY_SIZE/sizeof(int), stride);
        }
        end = get_time();
        double prefetch_time = end - start;
        
        double speedup = standard_time / prefetch_time;
        
        printf("%zu,%.6f,%.6f,%.2f\n", stride, standard_time, prefetch_time, speedup);
    }
    
    free(array);
    return 0;
}
```

Compile the stride benchmark:

```bash
gcc -O3 -march=native stride_prefetch_benchmark.c -o stride_prefetch_benchmark
```

### Step 4: Create Benchmark Script

Create a file named `run_prefetch_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Get architecture
arch=$(uname -m)
echo "Architecture: $arch"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"

# Run prefetch benchmark
echo "Running prefetch benchmark..."
./prefetch_benchmark | tee prefetch_results.txt

# Run stride prefetch benchmark
echo "Running stride prefetch benchmark..."
./stride_prefetch_benchmark | tee stride_prefetch_results.txt

echo "Benchmark complete. Results saved to text files."
```

Make the script executable:

```bash
chmod +x run_prefetch_benchmark.sh
```

### Step 5: Run the Benchmark

Execute the benchmark script:

```bash
./run_prefetch_benchmark.sh
```

### Step 6: Analyze the Results

When analyzing the results, consider:

1. **Prefetch Impact**: Compare the performance with and without prefetch instructions.
2. **Prefetch Distance**: Determine the optimal prefetch distance for your workload.
3. **Stride Sensitivity**: Analyze how different memory access patterns affect prefetch effectiveness.

## Arm-specific Prefetch Optimizations

Arm architectures offer several optimization techniques to improve memory prefetch performance:

### 1. Arm-specific Prefetch Instructions

Create a file named `arm_prefetch_types.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ARRAY_SIZE (50 * 1024 * 1024)  // 50MB
#define ITERATIONS 5

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

#ifdef __aarch64__
// Different types of prefetch on Arm
void prefetch_for_read(void* addr) {
    __asm__ volatile("prfm pldl1keep, [%0]\n" : : "r" (addr));
}

void prefetch_for_write(void* addr) {
    __asm__ volatile("prfm pstl1keep, [%0]\n" : : "r" (addr));
}

void prefetch_for_read_stream(void* addr) {
    __asm__ volatile("prfm pldl1strm, [%0]\n" : : "r" (addr));
}

void prefetch_for_write_stream(void* addr) {
    __asm__ volatile("prfm pstl1strm, [%0]\n" : : "r" (addr));
}
#endif

// Standard read access
void standard_read(int *array, size_t size) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i += 16) {
        sum += array[i];
    }
}

// Prefetched read access
void prefetched_read(int *array, size_t size) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i += 16) {
        #ifdef __aarch64__
        // Prefetch ahead
        if (i + 256 < size) {
            prefetch_for_read(&array[i + 256]);
        }
        #endif
        
        sum += array[i];
    }
}

// Stream prefetched read access
void stream_prefetched_read(int *array, size_t size) {
    volatile int sum = 0;
    
    for (size_t i = 0; i < size; i += 16) {
        #ifdef __aarch64__
        // Prefetch ahead with streaming hint
        if (i + 256 < size) {
            prefetch_for_read_stream(&array[i + 256]);
        }
        #endif
        
        sum += array[i];
    }
}

// Standard write access
void standard_write(int *array, size_t size) {
    for (size_t i = 0; i < size; i += 16) {
        array[i] = i;
    }
}

// Prefetched write access
void prefetched_write(int *array, size_t size) {
    for (size_t i = 0; i < size; i += 16) {
        #ifdef __aarch64__
        // Prefetch ahead
        if (i + 256 < size) {
            prefetch_for_write(&array[i + 256]);
        }
        #endif
        
        array[i] = i;
    }
}

int main() {
    // Allocate array
    int *array = (int *)malloc(ARRAY_SIZE);
    if (!array) {
        perror("malloc");
        return 1;
    }
    
    // Initialize array
    for (size_t i = 0; i < ARRAY_SIZE/sizeof(int); i++) {
        array[i] = i;
    }
    
    // Benchmark standard read
    double start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        standard_read(array, ARRAY_SIZE/sizeof(int));
    }
    double end = get_time();
    double standard_read_time = end - start;
    
    printf("Standard read time: %.6f seconds\n", standard_read_time);
    
    // Benchmark prefetched read
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        prefetched_read(array, ARRAY_SIZE/sizeof(int));
    }
    end = get_time();
    double prefetched_read_time = end - start;
    
    printf("Prefetched read time: %.6f seconds\n", prefetched_read_time);
    printf("Read prefetch speedup: %.2fx\n", standard_read_time / prefetched_read_time);
    
    // Benchmark stream prefetched read
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        stream_prefetched_read(array, ARRAY_SIZE/sizeof(int));
    }
    end = get_time();
    double stream_read_time = end - start;
    
    printf("Stream prefetched read time: %.6f seconds\n", stream_read_time);
    printf("Stream read prefetch speedup: %.2fx\n", standard_read_time / stream_read_time);
    
    // Benchmark standard write
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        standard_write(array, ARRAY_SIZE/sizeof(int));
    }
    end = get_time();
    double standard_write_time = end - start;
    
    printf("Standard write time: %.6f seconds\n", standard_write_time);
    
    // Benchmark prefetched write
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        prefetched_write(array, ARRAY_SIZE/sizeof(int));
    }
    end = get_time();
    double prefetched_write_time = end - start;
    
    printf("Prefetched write time: %.6f seconds\n", prefetched_write_time);
    printf("Write prefetch speedup: %.2fx\n", standard_write_time / prefetched_write_time);
    
    free(array);
    return 0;
}
```

Compile with:

```bash
gcc -O3 -march=native arm_prefetch_types.c -o arm_prefetch_types
```

### 2. Key Arm Prefetch Optimization Techniques

1. **Prefetch Types**: Arm provides different prefetch types for different access patterns:
   ```c
   // Load prefetch (for reads)
   __asm__ volatile("prfm pldl1keep, [%0]\n" : : "r" (addr));
   
   // Store prefetch (for writes)
   __asm__ volatile("prfm pstl1keep, [%0]\n" : : "r" (addr));
   
   // Stream prefetch (for sequential access)
   __asm__ volatile("prfm pldl1strm, [%0]\n" : : "r" (addr));
   ```

2. **Cache Level Targeting**: Prefetch to specific cache levels:
   ```c
   // Prefetch to L1 cache
   __asm__ volatile("prfm pldl1keep, [%0]\n" : : "r" (addr));
   
   // Prefetch to L2 cache
   __asm__ volatile("prfm pldl2keep, [%0]\n" : : "r" (addr));
   
   // Prefetch to L3 cache
   __asm__ volatile("prfm pldl3keep, [%0]\n" : : "r" (addr));
   ```

3. **Prefetch Distance Tuning**: Adjust prefetch distance based on workload:
   ```c
   // For small, random accesses
   __builtin_prefetch(addr + 16, 0, 3);  // Short distance
   
   // For large, sequential accesses
   __builtin_prefetch(addr + 64, 0, 2);  // Medium distance
   
   // For very large, streaming accesses
   __builtin_prefetch(addr + 256, 0, 1);  // Long distance
   ```

4. **Software Pipelining with Prefetch**:
   ```c
   void optimized_copy(int* src, int* dst, size_t size) {
       // Prefetch first batch
       for (size_t i = 0; i < 16 && i < size; i += 4) {
           __builtin_prefetch(&src[i + 64], 0, 3);
       }
       
       // Process with prefetching ahead
       for (size_t i = 0; i < size; i += 4) {
           // Prefetch next batch
           if (i + 128 < size) {
               __builtin_prefetch(&src[i + 128], 0, 3);
           }
           
           // Process current batch
           dst[i] = src[i];
           dst[i+1] = src[i+1];
           dst[i+2] = src[i+2];
           dst[i+3] = src[i+3];
       }
   }
   ```

5. **Combining Prefetch with NEON/SVE**:
   ```c
   #include <arm_neon.h>
   
   void vector_add_with_prefetch(float* a, float* b, float* c, size_t size) {
       for (size_t i = 0; i < size; i += 4) {
           // Prefetch ahead
           __builtin_prefetch(&a[i + 64], 0, 3);
           __builtin_prefetch(&b[i + 64], 0, 3);
           
           // Process current elements with NEON
           float32x4_t va = vld1q_f32(&a[i]);
           float32x4_t vb = vld1q_f32(&b[i]);
           float32x4_t vc = vaddq_f32(va, vb);
           vst1q_f32(&c[i], vc);
       }
   }
   ```

These prefetch optimizations can significantly improve memory-bound application performance on Arm architectures, often providing 1.2-2x speedups for streaming access patterns.

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| Prefetch Instructions | ✓ | ✓ | ✓ |
| PRFM Variants | ✓ | ✓ | ✓ |
| Hardware Prefetchers | ✓ | ✓ (Enhanced) | ✓ (Enhanced) |

Memory Prefetch availability:
- Neoverse N1: Full support for software prefetch instructions
- Neoverse V1: Enhanced hardware prefetchers + software prefetch
- Neoverse N2: Enhanced hardware prefetchers + software prefetch

All code examples in this chapter work on all Neoverse processors.

## Further Reading

- [Arm Architecture Reference Manual - Prefetch Memory](https://developer.arm.com/documentation/ddi0487/latest/)
- [Arm Neoverse N1 Software Optimization Guide](https://developer.arm.com/documentation/pjdoc466751330-9685/latest/)
- [Arm Memory System Optimization Guide](https://developer.arm.com/documentation/102529/latest/)
- [Prefetch Hints in the Arm Architecture](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/prefetch-hints-in-the-arm-architecture)
- [Optimizing Memory Access Patterns for Arm Servers](https://www.arm.com/blogs/blueprint/memory-access-arm-servers)

## Relevance to Workloads

Memory prefetch optimization is particularly important for:

1. **Data Processing Applications**: Database systems, analytics engines
2. **Media Processing**: Video encoding/decoding, image processing
3. **Scientific Computing**: Simulations, numerical analysis
4. **Machine Learning**: Training and inference operations
5. **File Processing**: Compression, encryption, transcoding

Understanding memory prefetch capabilities helps you:
- Reduce memory latency for predictable access patterns
- Optimize data-intensive applications
- Improve cache utilization
- Balance memory bandwidth and computational throughput