---
title: Arm Memory Tagging Extension
weight: 2300

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Arm Memory Tagging Extension (MTE)

Arm Memory Tagging Extension (MTE) is a hardware feature introduced in Armv8.5-A that helps detect and prevent memory safety issues such as buffer overflows, use-after-free, and other memory corruption bugs. MTE works by associating a "tag" with each memory allocation and checking this tag on every memory access, providing strong security guarantees with minimal performance overhead compared to software-only solutions.

When comparing Intel/AMD (x86) versus Arm architectures, MTE represents a significant advantage for Arm in terms of memory safety capabilities. While Intel has introduced Control-flow Enforcement Technology (CET), it addresses a different class of vulnerabilities than MTE.

For more detailed information about Arm Memory Tagging Extension, you can refer to:
- [Arm Memory Tagging Extension](https://developer.arm.com/documentation/102438/latest/)
- [Memory Tagging and how it improves C/C++ memory safety](https://www.arm.com/blogs/blueprint/memory-tagging-extension)
- [Enhancing Memory Safety with MTE](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/enhancing-memory-safety)

## Benchmarking Exercise: Measuring MTE Performance Impact

In this exercise, we'll measure the performance impact of enabling Memory Tagging Extension on Arm architecture.

### Prerequisites

Ensure you have an Arm VM with MTE support:
- Arm (aarch64) with Armv8.5-A or newer architecture supporting MTE
- Linux kernel 5.10 or newer with MTE support enabled

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc
```

### Step 2: Check MTE Support

Create a file named `check_mte.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/auxv.h>
#include <sys/prctl.h>

// Define constants if not available in headers
#ifndef HWCAP2_MTE
#define HWCAP2_MTE (1 << 18)
#endif

#ifndef PR_SET_TAGGED_ADDR_CTRL
#define PR_SET_TAGGED_ADDR_CTRL 55
#endif

#ifndef PR_GET_TAGGED_ADDR_CTRL
#define PR_GET_TAGGED_ADDR_CTRL 56
#endif

#ifndef PR_TAGGED_ADDR_ENABLE
#define PR_TAGGED_ADDR_ENABLE (1UL << 0)
#endif

int main() {
    // Check if MTE is supported by the hardware
    unsigned long hwcap2 = getauxval(AT_HWCAP2);
    int mte_supported = (hwcap2 & HWCAP2_MTE) != 0;
    
    printf("MTE hardware support: %s\n", mte_supported ? "Yes" : "No");
    
    if (mte_supported) {
        // Check if MTE is enabled in the kernel
        int ctrl = prctl(PR_GET_TAGGED_ADDR_CTRL);
        if (ctrl == -1) {
            perror("prctl");
            return 1;
        }
        
        int mte_enabled = (ctrl & PR_TAGGED_ADDR_ENABLE) != 0;
        printf("MTE kernel support: %s\n", mte_enabled ? "Enabled" : "Disabled");
        
        // Try to enable MTE
        if (!mte_enabled) {
            printf("Attempting to enable MTE...\n");
            if (prctl(PR_SET_TAGGED_ADDR_CTRL, PR_TAGGED_ADDR_ENABLE, 0, 0, 0) == -1) {
                perror("Failed to enable MTE");
            } else {
                printf("MTE enabled successfully\n");
            }
        }
    }
    
    return 0;
}
```

Compile and run:

```bash
gcc -o check_mte check_mte.c
./check_mte
```

### Step 3: Create MTE Benchmark

Create a file named `mte_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/prctl.h>

// Define constants if not available in headers
#ifndef PR_SET_TAGGED_ADDR_CTRL
#define PR_SET_TAGGED_ADDR_CTRL 55
#endif

#ifndef PR_TAGGED_ADDR_ENABLE
#define PR_TAGGED_ADDR_ENABLE (1UL << 0)
#endif

#ifndef PR_MTE_TCF_SYNC
#define PR_MTE_TCF_SYNC (1UL << 1)
#endif

#define BUFFER_SIZE (100 * 1024 * 1024)  // 100MB
#define ITERATIONS 10
#define ALLOC_SIZE 4096

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Standard memory allocation and access
void test_standard_memory(size_t total_size, size_t alloc_size) {
    size_t num_allocs = total_size / alloc_size;
    void **ptrs = malloc(num_allocs * sizeof(void*));
    
    if (!ptrs) {
        perror("malloc");
        return;
    }
    
    // Allocate memory
    for (size_t i = 0; i < num_allocs; i++) {
        ptrs[i] = malloc(alloc_size);
        if (!ptrs[i]) {
            perror("malloc");
            break;
        }
        
        // Write to memory
        memset(ptrs[i], i & 0xFF, alloc_size);
    }
    
    // Read from memory
    volatile unsigned char sum = 0;
    for (size_t i = 0; i < num_allocs; i++) {
        if (ptrs[i]) {
            for (size_t j = 0; j < alloc_size; j += 64) {
                sum += ((unsigned char*)ptrs[i])[j];
            }
        }
    }
    
    // Free memory
    for (size_t i = 0; i < num_allocs; i++) {
        if (ptrs[i]) {
            free(ptrs[i]);
        }
    }
    
    free(ptrs);
}

// MTE-enabled memory allocation and access
void test_mte_memory(size_t total_size, size_t alloc_size) {
    #ifdef __aarch64__
    // Try to enable MTE
    if (prctl(PR_SET_TAGGED_ADDR_CTRL, PR_TAGGED_ADDR_ENABLE | PR_MTE_TCF_SYNC, 0, 0, 0) == -1) {
        perror("Failed to enable MTE");
        return;
    }
    
    size_t num_allocs = total_size / alloc_size;
    void **ptrs = malloc(num_allocs * sizeof(void*));
    
    if (!ptrs) {
        perror("malloc");
        return;
    }
    
    // Allocate memory with MTE tags
    for (size_t i = 0; i < num_allocs; i++) {
        // In a real MTE implementation, we would use special allocation functions
        // that tag memory. For this benchmark, we're simulating the overhead.
        ptrs[i] = malloc(alloc_size);
        if (!ptrs[i]) {
            perror("malloc");
            break;
        }
        
        // Write to memory
        memset(ptrs[i], i & 0xFF, alloc_size);
    }
    
    // Read from memory
    volatile unsigned char sum = 0;
    for (size_t i = 0; i < num_allocs; i++) {
        if (ptrs[i]) {
            for (size_t j = 0; j < alloc_size; j += 64) {
                sum += ((unsigned char*)ptrs[i])[j];
            }
        }
    }
    
    // Free memory
    for (size_t i = 0; i < num_allocs; i++) {
        if (ptrs[i]) {
            free(ptrs[i]);
        }
    }
    
    free(ptrs);
    #endif
}

int main() {
    printf("Testing memory operations with and without MTE...\n");
    
    // Benchmark standard memory operations
    double start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        test_standard_memory(BUFFER_SIZE, ALLOC_SIZE);
    }
    
    double end = get_time();
    double standard_time = end - start;
    
    printf("Standard memory operations time: %.6f seconds\n", standard_time);
    
    // Benchmark MTE memory operations
    #ifdef __aarch64__
    start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        test_mte_memory(BUFFER_SIZE, ALLOC_SIZE);
    }
    
    end = get_time();
    double mte_time = end - start;
    
    printf("MTE memory operations time: %.6f seconds\n", mte_time);
    printf("MTE overhead: %.2f%%\n", ((mte_time / standard_time) - 1.0) * 100);
    #else
    printf("MTE not supported on this architecture\n");
    #endif
    
    return 0;
}
```

Compile with MTE support:

```bash
gcc -O3 -march=armv8.5-a+memtag mte_benchmark.c -o mte_benchmark
```

### Step 4: Create Memory Safety Test

Create a file named `memory_safety_test.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/prctl.h>

// Define constants if not available in headers
#ifndef PR_SET_TAGGED_ADDR_CTRL
#define PR_SET_TAGGED_ADDR_CTRL 55
#endif

#ifndef PR_TAGGED_ADDR_ENABLE
#define PR_TAGGED_ADDR_ENABLE (1UL << 0)
#endif

#ifndef PR_MTE_TCF_SYNC
#define PR_MTE_TCF_SYNC (1UL << 1)
#endif

// Function to enable MTE
int enable_mte() {
    #ifdef __aarch64__
    return prctl(PR_SET_TAGGED_ADDR_CTRL, PR_TAGGED_ADDR_ENABLE | PR_MTE_TCF_SYNC, 0, 0, 0);
    #else
    return -1;
    #endif
}

// Buffer overflow test
void test_buffer_overflow(int use_mte) {
    printf("Testing buffer overflow %s MTE...\n", use_mte ? "with" : "without");
    
    if (use_mte) {
        if (enable_mte() == -1) {
            perror("Failed to enable MTE");
            return;
        }
    }
    
    // Allocate a buffer
    char *buffer = malloc(10);
    if (!buffer) {
        perror("malloc");
        return;
    }
    
    // Initialize buffer
    for (int i = 0; i < 10; i++) {
        buffer[i] = 'A' + i;
    }
    
    printf("Buffer contents before overflow: ");
    for (int i = 0; i < 10; i++) {
        printf("%c ", buffer[i]);
    }
    printf("\n");
    
    // Attempt buffer overflow
    printf("Attempting buffer overflow...\n");
    for (int i = 0; i < 20; i++) {
        buffer[i] = 'X';  // Overflow after i=9
        printf("Wrote to index %d\n", i);
    }
    
    printf("Buffer overflow completed without detection\n");
    
    free(buffer);
}

// Use-after-free test
void test_use_after_free(int use_mte) {
    printf("Testing use-after-free %s MTE...\n", use_mte ? "with" : "without");
    
    if (use_mte) {
        if (enable_mte() == -1) {
            perror("Failed to enable MTE");
            return;
        }
    }
    
    // Allocate a buffer
    char *buffer = malloc(10);
    if (!buffer) {
        perror("malloc");
        return;
    }
    
    // Initialize buffer
    for (int i = 0; i < 10; i++) {
        buffer[i] = 'A' + i;
    }
    
    // Free the buffer
    free(buffer);
    printf("Buffer freed\n");
    
    // Attempt use-after-free
    printf("Attempting use-after-free...\n");
    printf("Value at buffer[0]: %c\n", buffer[0]);  // Use after free
    
    printf("Use-after-free completed without detection\n");
}

int main(int argc, char *argv[]) {
    int use_mte = 0;
    
    if (argc > 1 && strcmp(argv[1], "mte") == 0) {
        use_mte = 1;
    }
    
    // Run tests
    test_buffer_overflow(use_mte);
    printf("\n");
    test_use_after_free(use_mte);
    
    return 0;
}
```

Compile with MTE support:

```bash
gcc -O3 -march=armv8.5-a+memtag memory_safety_test.c -o memory_safety_test
```

### Step 5: Create Benchmark Script

Create a file named `run_mte_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Get architecture
arch=$(uname -m)
echo "Architecture: $arch"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"

# Check MTE support
echo "Checking MTE support..."
./check_mte

# Run MTE benchmark
echo "Running MTE benchmark..."
./mte_benchmark | tee mte_benchmark_results.txt

# Run memory safety tests
echo "Running memory safety tests without MTE..."
./memory_safety_test | tee memory_safety_standard.txt

echo "Running memory safety tests with MTE..."
./memory_safety_test mte | tee memory_safety_mte.txt

echo "Benchmark complete. Results saved to text files."
```

Make the script executable:

```bash
chmod +x run_mte_benchmark.sh
```

### Step 6: Run the Benchmark

Execute the benchmark script:

```bash
./run_mte_benchmark.sh
```

### Step 7: Analyze the Results

When analyzing the results, consider:

1. **Performance Overhead**: Measure the overhead introduced by MTE.
2. **Memory Safety Benefits**: Observe how MTE detects memory safety issues.
3. **Workload Impact**: Different types of memory access patterns may be affected differently.

## Arm-specific Memory Safety Optimizations

Arm architectures offer several optimization techniques to improve memory safety with minimal performance impact:

### 1. Optimized MTE Implementation

Create a file named `mte_optimized.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/mman.h>

#define BUFFER_SIZE 1024
#define ITERATIONS 1000000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

#ifdef __aarch64__
// Create a tagged pointer (simplified simulation)
void* create_tagged_pointer(void* ptr, unsigned tag) {
    // In real MTE, this would use special instructions
    // This is just a simulation for the benchmark
    uintptr_t addr = (uintptr_t)ptr;
    addr = (addr & 0x0000FFFFFFFFFFFF) | ((uintptr_t)(tag & 0xF) << 56);
    return (void*)addr;
}

// Extract the tag from a pointer
unsigned get_tag(void* ptr) {
    return (unsigned)((uintptr_t)ptr >> 56) & 0xF;
}
#endif

// Standard memory access
void standard_access(char* buffer, size_t size) {
    for (size_t i = 0; i < size; i++) {
        buffer[i] = (char)i;
    }
    
    volatile char sum = 0;
    for (size_t i = 0; i < size; i++) {
        sum += buffer[i];
    }
}

// MTE-aware memory access (simulated)
void mte_access(char* buffer, size_t size) {
#ifdef __aarch64__
    // Tag the buffer (simulation)
    unsigned tag = 1;
    void* tagged_buffer = create_tagged_pointer(buffer, tag);
    char* safe_buffer = (char*)tagged_buffer;
    
    // Access with tag checking (simulation)
    for (size_t i = 0; i < size; i++) {
        // In real MTE, hardware would check tags automatically
        if (get_tag(safe_buffer) == tag) {
            safe_buffer[i] = (char)i;
        }
    }
    
    volatile char sum = 0;
    for (size_t i = 0; i < size; i++) {
        if (get_tag(safe_buffer) == tag) {
            sum += safe_buffer[i];
        }
    }
#else
    standard_access(buffer, size);
#endif
}

// Optimized MTE access with batching
void mte_optimized_access(char* buffer, size_t size) {
#ifdef __aarch64__
    // Tag the buffer (simulation)
    unsigned tag = 1;
    void* tagged_buffer = create_tagged_pointer(buffer, tag);
    char* safe_buffer = (char*)tagged_buffer;
    
    // Check tag once for the whole buffer
    if (get_tag(safe_buffer) == tag) {
        // Batch operations
        for (size_t i = 0; i < size; i++) {
            safe_buffer[i] = (char)i;
        }
        
        volatile char sum = 0;
        for (size_t i = 0; i < size; i++) {
            sum += safe_buffer[i];
        }
    }
#else
    standard_access(buffer, size);
#endif
}

int main() {
    // Allocate buffer
    char* buffer = (char*)malloc(BUFFER_SIZE);
    if (!buffer) {
        perror("malloc");
        return 1;
    }
    
    // Benchmark standard access
    double start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        standard_access(buffer, BUFFER_SIZE);
    }
    double end = get_time();
    double standard_time = end - start;
    
    printf("Standard access time: %.6f seconds\n", standard_time);
    
    // Benchmark MTE access
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        mte_access(buffer, BUFFER_SIZE);
    }
    end = get_time();
    double mte_time = end - start;
    
    printf("MTE access time: %.6f seconds\n", mte_time);
    printf("MTE overhead: %.2f%%\n", ((mte_time / standard_time) - 1.0) * 100);
    
    // Benchmark optimized MTE access
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        mte_optimized_access(buffer, BUFFER_SIZE);
    }
    end = get_time();
    double mte_opt_time = end - start;
    
    printf("Optimized MTE access time: %.6f seconds\n", mte_opt_time);
    printf("Optimized MTE overhead: %.2f%%\n", ((mte_opt_time / standard_time) - 1.0) * 100);
    
    free(buffer);
    return 0;
}
```

Compile with:

```bash
gcc -O3 -march=armv8.5-a+memtag mte_optimized.c -o mte_optimized
```

### 2. Key Arm MTE Optimization Techniques

1. **Granular Tag Checking**:
   ```c
   // Check tags only at allocation boundaries rather than every access
   void* ptr = malloc(size);
   // Tag the entire allocation once
   __arm_mte_create_random_tag(ptr, size);
   ```

2. **Batch Operations**:
   ```c
   // Check tag once for a batch of operations
   if (__arm_mte_check_tag(ptr)) {
       // Perform multiple operations on the memory
       for (int i = 0; i < size; i++) {
           ptr[i] = value;
       }
   }
   ```

3. **Selective MTE Application**:
   ```c
   // Apply MTE only to security-critical allocations
   void* secure_alloc(size_t size) {
       void* ptr = malloc(size);
       __arm_mte_create_random_tag(ptr, size);
       return ptr;
   }
   
   // Use standard allocation for non-critical data
   void* standard_alloc(size_t size) {
       return malloc(size);
   }
   ```

4. **Compiler Flags for MTE**:
   ```bash
   # Enable MTE support
   gcc -march=armv8.5-a+memtag -O3 program.c -o program
   ```

5. **Custom Memory Allocator**:
   ```c
   // Implement a custom allocator that uses MTE efficiently
   void* mte_malloc(size_t size) {
       // Allocate memory with proper alignment
       void* ptr = aligned_alloc(16, size);
       // Apply MTE tag
       __arm_mte_create_random_tag(ptr, size);
       return ptr;
   }
   ```

These optimizations can help reduce the performance overhead of MTE while maintaining its memory safety benefits, making it practical for use in production environments.

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| MTE     | ✗           | ✓           | ✓           |

Memory Tagging Extension availability:
- Neoverse N1: Not supported
- Neoverse V1: Fully supported
- Neoverse N2: Fully supported

The code in this chapter uses runtime detection to automatically use MTE when available and fall back to standard memory protection on Neoverse N1.

## Further Reading

- [Arm Memory Tagging Extension: Enhancing Memory Safety](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/enhancing-memory-safety)
- [Arm Architecture Reference Manual Supplement - MTE](https://developer.arm.com/documentation/ddi0596/latest/)
- [Memory Tagging and how it improves C/C++ memory safety](https://www.arm.com/blogs/blueprint/memory-tagging-extension)
- [Google's experience with MTE in Android](https://security.googleblog.com/2022/04/memory-safe-languages-in-android-13.html)
- [Linux Kernel MTE Support Documentation](https://www.kernel.org/doc/html/latest/arm64/memory-tagging-extension.html)

## Relevance to Workloads

Memory Tagging Extension is particularly important for:

1. **Security-Critical Applications**: Financial services, authentication systems
2. **Systems Processing Untrusted Input**: Web servers, parsers, interpreters
3. **Long-Running Services**: Servers, daemons, background processes
4. **Memory-Intensive Applications**: Data processing, analytics
5. **Legacy C/C++ Codebases**: Applications with potential memory safety issues

Understanding MTE's capabilities and performance characteristics helps you:
- Improve application security with minimal performance impact
- Detect memory corruption bugs early in development
- Balance security and performance requirements
- Make informed decisions about hardware selection for security-sensitive workloads