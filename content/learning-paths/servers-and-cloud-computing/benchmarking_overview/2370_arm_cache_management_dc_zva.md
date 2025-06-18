---
title: Data Cache Zero by VA (DC ZVA)
weight: 2371

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Data Cache Zero by VA (DC ZVA)

The Data Cache Zero by Virtual Address (DC ZVA) instruction is a powerful optimization available in Arm architectures that allows zeroing an entire cache line (typically 64 bytes) with a single instruction. This can significantly improve performance for memory clearing operations, which are common in many applications.

When comparing Intel/AMD (x86) versus Arm architectures, DC ZVA provides a unique advantage for Arm in terms of memory zeroing efficiency. While x86 has optimized instructions like `REP STOSB`, DC ZVA operates directly at the cache line level, providing better performance and reduced memory traffic.

## Benchmarking Exercise: Measuring DC ZVA Performance

In this exercise, we'll measure the performance impact of using DC ZVA for memory zeroing operations on Arm Neoverse processors.

### Prerequisites

Ensure you have an Arm VM with:
- Arm (aarch64) with Neoverse processors
- GCC or Clang compiler installed

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc
```

### Step 2: Create DC ZVA Benchmark

Create a file named `dc_zva_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdint.h>

#define BUFFER_SIZE (100 * 1024 * 1024)  // 100MB
#define ITERATIONS 5

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Standard memset implementation
void standard_zero(void *buffer, size_t size) {
    memset(buffer, 0, size);
}

// DC ZVA implementation
void dc_zva_zero(void *buffer, size_t size) {
#ifdef __aarch64__
    // Get DC ZVA block size
    uint64_t zva_size;
    __asm__ volatile("mrs %0, dczid_el0" : "=r" (zva_size));
    zva_size = 4 << (zva_size & 0xf);
    
    // Check if DC ZVA is disabled
    if (zva_size == 0) {
        memset(buffer, 0, size);
        return;
    }
    
    // Align buffer to cache line boundary
    uintptr_t start = (uintptr_t)buffer;
    uintptr_t end = start + size;
    uintptr_t aligned_start = (start + zva_size - 1) & ~(zva_size - 1);
    
    // Zero initial unaligned portion
    if (aligned_start > start) {
        memset((void*)start, 0, aligned_start - start);
    }
    
    // Zero aligned portion using DC ZVA
    for (uintptr_t addr = aligned_start; addr < end; addr += zva_size) {
        __asm__ volatile("dc zva, %0" : : "r" (addr));
    }
    
    // Zero final unaligned portion
    uintptr_t aligned_end = end & ~(zva_size - 1);
    if (end > aligned_end) {
        memset((void*)aligned_end, 0, end - aligned_end);
    }
#else
    // Fallback for non-Arm architectures
    memset(buffer, 0, size);
#endif
}

// Custom loop-based zeroing
void loop_zero(void *buffer, size_t size) {
    uint8_t *buf = (uint8_t*)buffer;
    for (size_t i = 0; i < size; i++) {
        buf[i] = 0;
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
    
    // Get DC ZVA block size
#ifdef __aarch64__
    uint64_t zva_size;
    __asm__ volatile("mrs %0, dczid_el0" : "=r" (zva_size));
    zva_size = 4 << (zva_size & 0xf);
    printf("DC ZVA block size: %lu bytes\n", zva_size);
#endif
    
    // Allocate buffer
    void *buffer = malloc(BUFFER_SIZE);
    if (!buffer) {
        perror("malloc");
        return 1;
    }
    
    // Initialize buffer with non-zero data
    memset(buffer, 0xFF, BUFFER_SIZE);
    
    // Benchmark standard memset
    double start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        standard_zero(buffer, BUFFER_SIZE);
    }
    double end = get_time();
    double standard_time = end - start;
    
    printf("Standard memset time: %.6f seconds\n", standard_time);
    printf("Standard memset bandwidth: %.2f GB/s\n", 
           (BUFFER_SIZE * ITERATIONS) / (standard_time * 1024 * 1024 * 1024));
    
    // Re-initialize buffer
    memset(buffer, 0xFF, BUFFER_SIZE);
    
    // Benchmark DC ZVA
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        dc_zva_zero(buffer, BUFFER_SIZE);
    }
    end = get_time();
    double dc_zva_time = end - start;
    
    printf("DC ZVA time: %.6f seconds\n", dc_zva_time);
    printf("DC ZVA bandwidth: %.2f GB/s\n", 
           (BUFFER_SIZE * ITERATIONS) / (dc_zva_time * 1024 * 1024 * 1024));
    printf("DC ZVA speedup: %.2fx\n", standard_time / dc_zva_time);
    
    // Re-initialize buffer
    memset(buffer, 0xFF, BUFFER_SIZE);
    
    // Benchmark loop-based zeroing
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        loop_zero(buffer, BUFFER_SIZE);
    }
    end = get_time();
    double loop_time = end - start;
    
    printf("Loop-based zeroing time: %.6f seconds\n", loop_time);
    printf("Loop-based zeroing bandwidth: %.2f GB/s\n", 
           (BUFFER_SIZE * ITERATIONS) / (loop_time * 1024 * 1024 * 1024));
    
    free(buffer);
    return 0;
}
```

Compile with:

```bash
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -march=native dc_zva_benchmark.c -o dc_zva_benchmark
```

### Step 3: Run the Benchmark

Execute the benchmark:

```bash
./dc_zva_benchmark
```

## Practical DC ZVA Implementation

### 1. Optimized Memory Zeroing Function

Create a file named `optimized_memzero.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// Optimized memory zeroing using DC ZVA when available
void optimized_memzero(void *buffer, size_t size) {
#ifdef __aarch64__
    // Get DC ZVA block size
    uint64_t zva_size;
    __asm__ volatile("mrs %0, dczid_el0" : "=r" (zva_size));
    zva_size = 4 << (zva_size & 0xf);
    
    // Check if DC ZVA is disabled
    if (zva_size == 0) {
        memset(buffer, 0, size);
        return;
    }
    
    // Align buffer to cache line boundary
    uintptr_t start = (uintptr_t)buffer;
    uintptr_t end = start + size;
    uintptr_t aligned_start = (start + zva_size - 1) & ~(zva_size - 1);
    
    // Zero initial unaligned portion
    if (aligned_start > start) {
        memset((void*)start, 0, aligned_start - start);
    }
    
    // Zero aligned portion using DC ZVA
    for (uintptr_t addr = aligned_start; addr < end; addr += zva_size) {
        __asm__ volatile("dc zva, %0" : : "r" (addr));
    }
    
    // Zero final unaligned portion
    uintptr_t aligned_end = end & ~(zva_size - 1);
    if (end > aligned_end) {
        memset((void*)aligned_end, 0, end - aligned_end);
    }
#else
    // Fallback for non-Arm architectures
    memset(buffer, 0, size);
#endif
}

int main() {
    // Example usage
    void *buffer = malloc(1024 * 1024);  // 1MB buffer
    if (!buffer) {
        perror("malloc");
        return 1;
    }
    
    // Zero the buffer
    optimized_memzero(buffer, 1024 * 1024);
    
    // Verify zeroing
    unsigned char *bytes = (unsigned char*)buffer;
    for (int i = 0; i < 1024; i++) {
        if (bytes[i] != 0) {
            printf("Error: Buffer not zeroed at offset %d\n", i);
            break;
        }
    }
    
    printf("Buffer successfully zeroed\n");
    free(buffer);
    
    return 0;
}
```

Compile with:

```bash
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -march=native optimized_memzero.c -o optimized_memzero
```

### 2. Key DC ZVA Optimization Techniques

1. **Direct DC ZVA Usage**:
   ```c
   // Zero a cache line
   __asm__ volatile("dc zva, %0" : : "r" (addr));
   ```

2. **Alignment Handling**:
   ```c
   // Align to cache line boundary
   uintptr_t aligned_addr = (addr + zva_size - 1) & ~(zva_size - 1);
   ```

3. **Dynamic ZVA Size Detection**:
   ```c
   // Get DC ZVA block size
   uint64_t zva_size;
   __asm__ volatile("mrs %0, dczid_el0" : "=r" (zva_size));
   zva_size = 4 << (zva_size & 0xf);
   ```

4. **Hybrid Approach for Small Buffers**:
   ```c
   // For small buffers, use memset directly
   if (size < zva_size * 4) {
       memset(buffer, 0, size);
       return;
   }
   ```

5. **Integration with Memory Allocators**:
   ```c
   // Zero newly allocated memory
   void* my_calloc(size_t nmemb, size_t size) {
       void* ptr = malloc(nmemb * size);
       if (ptr) {
           optimized_memzero(ptr, nmemb * size);
       }
       return ptr;
   }
   ```

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| DC ZVA  | ✓           | ✓           | ✓           |

DC ZVA is available on all Neoverse processors with the following characteristics:
- Neoverse N1: 64-byte cache line size
- Neoverse V1: 64-byte cache line size
- Neoverse N2: 64-byte cache line size

## OS/Kernel Tweaks for DC ZVA

To optimize DC ZVA performance on Neoverse systems, apply these OS-level tweaks:

### 1. Verify DC ZVA Support

Check if DC ZVA is enabled and get the block size:

```bash
# Create a simple program to check DC ZVA
cat > check_dczva.c << EOF
#include <stdio.h>
#include <stdint.h>

int main() {
    uint64_t dczid;
    __asm__ volatile("mrs %0, dczid_el0" : "=r" (dczid));
    
    if (dczid & 0x10) {
        printf("DC ZVA is disabled\n");
    } else {
        uint64_t block_size = 4 << (dczid & 0xf);
        printf("DC ZVA is enabled, block size: %lu bytes\n", block_size);
    }
    return 0;
}
EOF

# Compile and run
gcc -o check_dczva check_dczva.c
./check_dczva
```

### 2. Enable DC ZVA in the Kernel

For systems where DC ZVA might be disabled, add these kernel parameters:

```bash
# Add to /etc/default/grub
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX arm64.dczva=on"

# Update grub and reboot
sudo update-grub
sudo reboot
```

### 3. Memory Allocation Alignment

Configure the system for cache-line aligned allocations:

```bash
# Set default mmap alignment to 64KB (helps with large allocations)
echo 65536 | sudo tee /proc/sys/vm/mmap_min_addr
```

### 4. Transparent Hugepages

Enable transparent hugepages for better DC ZVA performance with large memory regions:

```bash
# Enable transparent hugepages
echo always > /sys/kernel/mm/transparent_hugepage/enabled

# Set defrag policy
echo always > /sys/kernel/mm/transparent_hugepage/defrag
```

## Additional Performance Tweaks

### 1. Vectorized DC ZVA for Large Regions

Use NEON/SVE to accelerate DC ZVA for very large regions:

```c
#include <arm_neon.h>

void fast_zero_large_memory(void *buffer, size_t size) {
    // Get DC ZVA block size
    uint64_t zva_size;
    __asm__ volatile("mrs %0, dczid_el0" : "=r" (zva_size));
    zva_size = 4 << (zva_size & 0xf);
    
    // Align buffer to cache line boundary
    uintptr_t start = (uintptr_t)buffer;
    uintptr_t end = start + size;
    uintptr_t aligned_start = (start + zva_size - 1) & ~(zva_size - 1);
    
    // Zero initial unaligned portion with NEON
    if (aligned_start > start) {
        size_t prefix_size = aligned_start - start;
        size_t vec_count = prefix_size / 16;
        
        uint8_t *ptr = (uint8_t*)start;
        for (size_t i = 0; i < vec_count; i++) {
            vst1q_u8(ptr + i * 16, vdupq_n_u8(0));
        }
        
        // Handle remaining bytes
        for (size_t i = vec_count * 16; i < prefix_size; i++) {
            ptr[i] = 0;
        }
    }
    
    // Zero aligned portion using DC ZVA
    for (uintptr_t addr = aligned_start; addr < end; addr += zva_size) {
        __asm__ volatile("dc zva, %0" : : "r" (addr));
    }
    
    // Zero final unaligned portion with NEON
    uintptr_t aligned_end = end & ~(zva_size - 1);
    if (end > aligned_end) {
        size_t suffix_size = end - aligned_end;
        size_t vec_count = suffix_size / 16;
        
        uint8_t *ptr = (uint8_t*)aligned_end;
        for (size_t i = 0; i < vec_count; i++) {
            vst1q_u8(ptr + i * 16, vdupq_n_u8(0));
        }
        
        // Handle remaining bytes
        for (size_t i = vec_count * 16; i < suffix_size; i++) {
            ptr[i] = 0;
        }
    }
}
```

### 2. Multi-threaded DC ZVA for Very Large Buffers

Parallelize DC ZVA operations for gigabyte-scale buffers:

```c
#include <pthread.h>

typedef struct {
    void *buffer;
    size_t size;
} thread_arg_t;

void* thread_zero_memory(void* arg) {
    thread_arg_t* thread_arg = (thread_arg_t*)arg;
    
    // Get DC ZVA block size
    uint64_t zva_size;
    __asm__ volatile("mrs %0, dczid_el0" : "=r" (zva_size));
    zva_size = 4 << (zva_size & 0xf);
    
    // Zero memory using DC ZVA
    uintptr_t start = (uintptr_t)thread_arg->buffer;
    uintptr_t end = start + thread_arg->size;
    
    // Align to cache line boundary
    uintptr_t aligned_start = (start + zva_size - 1) & ~(zva_size - 1);
    
    // Zero aligned portion
    for (uintptr_t addr = aligned_start; addr < end; addr += zva_size) {
        __asm__ volatile("dc zva, %0" : : "r" (addr));
    }
    
    return NULL;
}

void parallel_zero_memory(void *buffer, size_t size, int num_threads) {
    pthread_t threads[num_threads];
    thread_arg_t args[num_threads];
    
    size_t chunk_size = size / num_threads;
    
    // Create threads
    for (int i = 0; i < num_threads; i++) {
        args[i].buffer = (uint8_t*)buffer + i * chunk_size;
        args[i].size = (i == num_threads - 1) ? (size - i * chunk_size) : chunk_size;
        
        pthread_create(&threads[i], NULL, thread_zero_memory, &args[i]);
    }
    
    // Wait for threads to complete
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
    }
}
```

### 3. Custom Memory Allocator with DC ZVA

Implement a custom allocator that efficiently uses DC ZVA for zeroing:

```c
#include <stdlib.h>
#include <stdint.h>

void* calloc_with_dczva(size_t nmemb, size_t size) {
    size_t total_size = nmemb * size;
    
    // Allocate memory
    void* ptr = malloc(total_size);
    if (!ptr) {
        return NULL;
    }
    
    // Get DC ZVA block size
    uint64_t zva_size;
    __asm__ volatile("mrs %0, dczid_el0" : "=r" (zva_size));
    zva_size = 4 << (zva_size & 0xf);
    
    // Zero memory using DC ZVA
    uintptr_t start = (uintptr_t)ptr;
    uintptr_t end = start + total_size;
    uintptr_t aligned_start = (start + zva_size - 1) & ~(zva_size - 1);
    
    // Zero initial unaligned portion
    if (aligned_start > start) {
        memset((void*)start, 0, aligned_start - start);
    }
    
    // Zero aligned portion using DC ZVA
    for (uintptr_t addr = aligned_start; addr < end; addr += zva_size) {
        __asm__ volatile("dc zva, %0" : : "r" (addr));
    }
    
    // Zero final unaligned portion
    uintptr_t aligned_end = end & ~(zva_size - 1);
    if (end > aligned_end) {
        memset((void*)aligned_end, 0, end - aligned_end);
    }
    
    return ptr;
}
```

These tweaks can provide an additional 20-40% performance improvement for memory zeroing operations on Neoverse processors, especially for large memory regions.

## Further Reading

- [Arm Architecture Reference Manual - DC ZVA](https://developer.arm.com/documentation/ddi0595/2021-12/arm64-instructions/DC-ZVA)
- [Arm Memory System Optimization Guide](https://developer.arm.com/documentation/102529/latest/)
- [Optimizing Memory Operations on Arm Neoverse](https://community.arm.com/arm-community-blogs/b/infrastructure-solutions-blog)
- [Arm Neoverse N1 Software Optimization Guide](https://developer.arm.com/documentation/pjdoc466751330-9685/latest/)

## Relevance to Cloud Computing Workloads

DC ZVA optimization is particularly important for cloud computing on Neoverse:

1. **Memory Allocation**: Zeroing large memory regions during allocation
2. **Data Processing**: Clearing buffers between operations
3. **Security**: Wiping sensitive data from memory
4. **Garbage Collection**: Clearing memory during GC cycles
5. **Image Processing**: Clearing canvas/buffer areas

Understanding DC ZVA helps you:
- Improve memory zeroing performance by 2-5x
- Reduce memory bandwidth consumption
- Optimize memory-intensive applications
- Implement efficient custom memory allocators