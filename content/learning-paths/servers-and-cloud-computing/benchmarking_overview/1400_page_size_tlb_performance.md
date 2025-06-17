---
title: Page Size and TLB Performance
weight: 1400

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Page Size and TLB Performance

Page size is a fundamental parameter in virtual memory systems that determines how memory is divided and managed. The Translation Lookaside Buffer (TLB) is a CPU cache that stores recent virtual-to-physical address translations, significantly accelerating memory access. Both page size and TLB characteristics can vary between architectures and have profound effects on application performance.

When comparing Intel/AMD (x86) versus Arm architectures, differences in page size support, TLB size, and memory management unit (MMU) design can impact memory-intensive workloads. Understanding these differences helps optimize applications for specific architectures and identify potential performance bottlenecks.

For more detailed information about page size and TLB performance, you can refer to:
- [Virtual Memory and Page Tables](https://www.kernel.org/doc/gorman/html/understand/understand006.html)
- [TLB Performance Analysis](https://www.cs.cornell.edu/courses/cs6120/2019fa/blog/tlb-performance/)
- [Huge Pages and Performance](https://www.kernel.org/doc/html/latest/admin-guide/mm/hugetlbpage.html)

## Benchmarking Exercise: Comparing Page Size and TLB Performance

In this exercise, we'll measure and compare TLB performance and the impact of different page sizes across Intel/AMD and Arm architectures.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential git python3 python3-matplotlib gnuplot linux-tools-common linux-tools-generic
```

### Step 2: Create TLB Benchmark

Create a file named `tlb_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>

#define BILLION 1000000000L

// Function to measure time with nanosecond precision
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Function to create a linked list for pointer chasing
void create_linked_list(void **array, size_t size, size_t stride) {
    size_t i;
    for (i = 0; i < size - stride; i += stride) {
        array[i] = &array[i + stride];
    }
    // Make it circular
    array[i] = &array[0];
}

// Function to traverse the linked list
size_t traverse_linked_list(void **array, size_t iterations) {
    void **p = &array[0];
    size_t i;
    
    for (i = 0; i < iterations; i++) {
        p = *p;
    }
    
    // Return a value based on p to prevent compiler optimization
    return (size_t)p;
}

int main(int argc, char *argv[]) {
    size_t array_size_mb = 64;  // Default array size in MB
    size_t stride = 16;         // Default stride in elements (64 bytes assuming 4-byte elements)
    size_t iterations = 100000000; // Default number of iterations
    int use_huge_pages = 0;     // Default: don't use huge pages
    
    // Parse command line arguments
    if (argc > 1) array_size_mb = atoi(argv[1]);
    if (argc > 2) stride = atoi(argv[2]);
    if (argc > 3) iterations = atoi(argv[3]);
    if (argc > 4) use_huge_pages = atoi(argv[4]);
    
    // Calculate array size in elements (assuming 4-byte elements)
    size_t array_size = (array_size_mb * 1024 * 1024) / sizeof(void*);
    
    printf("Array size: %zu MB (%zu elements)\n", array_size_mb, array_size);
    printf("Stride: %zu elements (%zu bytes)\n", stride, stride * sizeof(void*));
    printf("Iterations: %zu\n", iterations);
    printf("Using %s pages\n", use_huge_pages ? "huge" : "standard");
    
    // Allocate memory
    void **array;
    if (use_huge_pages) {
        // Try to use huge pages
        array = mmap(NULL, array_size * sizeof(void*), 
                    PROT_READ | PROT_WRITE, 
                    MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB, 
                    -1, 0);
        if (array == MAP_FAILED) {
            perror("mmap with huge pages failed");
            printf("Falling back to standard pages\n");
            array = malloc(array_size * sizeof(void*));
            if (!array) {
                perror("malloc");
                return 1;
            }
        }
    } else {
        // Use standard pages
        array = malloc(array_size * sizeof(void*));
        if (!array) {
            perror("malloc");
            return 1;
        }
    }
    
    // Create linked list for pointer chasing
    create_linked_list(array, array_size, stride);
    
    // Warm up
    traverse_linked_list(array, 1000);
    
    // Benchmark
    double start_time = get_time();
    size_t result = traverse_linked_list(array, iterations);
    double end_time = get_time();
    
    double elapsed = end_time - start_time;
    double accesses_per_second = iterations / elapsed;
    double ns_per_access = (elapsed * BILLION) / iterations;
    
    printf("Time: %.6f seconds\n", elapsed);
    printf("Accesses per second: %.2f million\n", accesses_per_second / 1000000);
    printf("Time per access: %.2f ns\n", ns_per_access);
    printf("Result (to prevent optimization): %zu\n", result);
    
    // Clean up
    if (use_huge_pages) {
        munmap(array, array_size * sizeof(void*));
    } else {
        free(array);
    }
    
    return 0;
}
```

Compile the benchmark:

```bash
gcc -O2 tlb_benchmark.c -o tlb_benchmark -lm
```

### Step 3: Create Page Fault Benchmark

Create a file named `page_fault_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <fcntl.h>

#define BILLION 1000000000L

// Function to measure time with nanosecond precision
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

int main(int argc, char *argv[]) {
    size_t file_size_mb = 1024;  // Default file size in MB
    size_t access_pattern = 0;   // 0: sequential, 1: random
    size_t iterations = 10000;   // Default number of iterations
    
    // Parse command line arguments
    if (argc > 1) file_size_mb = atoi(argv[1]);
    if (argc > 2) access_pattern = atoi(argv[2]);
    if (argc > 3) iterations = atoi(argv[3]);
    
    // Calculate file size in bytes
    size_t file_size = file_size_mb * 1024 * 1024;
    
    printf("File size: %zu MB\n", file_size_mb);
    printf("Access pattern: %s\n", access_pattern ? "random" : "sequential");
    printf("Iterations: %zu\n", iterations);
    
    // Create a temporary file
    char filename[] = "/tmp/page_fault_benchmark_XXXXXX";
    int fd = mkstemp(filename);
    if (fd == -1) {
        perror("mkstemp");
        return 1;
    }
    
    // Extend the file to the desired size
    if (ftruncate(fd, file_size) == -1) {
        perror("ftruncate");
        close(fd);
        unlink(filename);
        return 1;
    }
    
    // Memory map the file
    char *map = mmap(NULL, file_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (map == MAP_FAILED) {
        perror("mmap");
        close(fd);
        unlink(filename);
        return 1;
    }
    
    // Generate random access indices if needed
    size_t *indices = NULL;
    if (access_pattern) {
        indices = malloc(iterations * sizeof(size_t));
        if (!indices) {
            perror("malloc");
            munmap(map, file_size);
            close(fd);
            unlink(filename);
            return 1;
        }
        
        // Initialize random number generator
        srand(time(NULL));
        
        // Generate random indices
        for (size_t i = 0; i < iterations; i++) {
            indices[i] = (size_t)rand() % (file_size - 1);
        }
    }
    
    // Advise the kernel to not cache the pages
    if (madvise(map, file_size, MADV_DONTNEED) == -1) {
        perror("madvise");
    }
    
    // Benchmark
    double start_time = get_time();
    
    volatile char dummy = 0;
    if (access_pattern) {
        // Random access
        for (size_t i = 0; i < iterations; i++) {
            dummy += map[indices[i]];
        }
    } else {
        // Sequential access
        size_t step = file_size / iterations;
        if (step == 0) step = 1;
        
        for (size_t i = 0; i < file_size; i += step) {
            dummy += map[i];
        }
    }
    
    double end_time = get_time();
    
    double elapsed = end_time - start_time;
    double accesses_per_second = iterations / elapsed;
    double ms_per_access = (elapsed * 1000) / iterations;
    
    printf("Time: %.6f seconds\n", elapsed);
    printf("Accesses per second: %.2f\n", accesses_per_second);
    printf("Time per access: %.6f ms\n", ms_per_access);
    printf("Dummy value (to prevent optimization): %d\n", dummy);
    
    // Clean up
    if (access_pattern) {
        free(indices);
    }
    munmap(map, file_size);
    close(fd);
    unlink(filename);
    
    return 0;
}
```

Compile the benchmark:

```bash
gcc -O2 page_fault_benchmark.c -o page_fault_benchmark -lm
```

### Step 4: Create Benchmark Script

Create a file named `page_size_tlb_benchmark.sh` with the following content:

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
echo "Page Size Information:"
getconf PAGE_SIZE
echo "Huge Page Information:"
grep Huge /proc/meminfo
echo ""

# Function to run TLB benchmark
run_tlb_benchmark() {
  local array_size=$1
  local stride=$2
  local iterations=$3
  local huge_pages=$4
  local description="$array_size MB array, $stride stride, ${huge_pages} huge pages"
  
  echo "=== Running TLB Benchmark: $description ==="
  ./tlb_benchmark $array_size $stride $iterations $huge_pages | tee tlb_benchmark_${array_size}_${stride}_${huge_pages}.txt
  
  # Extract results
  local ns_per_access=$(grep "Time per access" tlb_benchmark_${array_size}_${stride}_${huge_pages}.txt | awk '{print $4}')
  
  # Save result
  echo "$array_size,$stride,$huge_pages,$ns_per_access" >> tlb_results.csv
  
  echo ""
}

# Function to run page fault benchmark
run_page_fault_benchmark() {
  local file_size=$1
  local access_pattern=$2
  local iterations=$3
  local description="$file_size MB file, $([ $access_pattern -eq 0 ] && echo "sequential" || echo "random") access"
  
  echo "=== Running Page Fault Benchmark: $description ==="
  ./page_fault_benchmark $file_size $access_pattern $iterations | tee page_fault_benchmark_${file_size}_${access_pattern}.txt
  
  # Extract results
  local ms_per_access=$(grep "Time per access" page_fault_benchmark_${file_size}_${access_pattern}.txt | awk '{print $4}')
  
  # Save result
  echo "$file_size,$access_pattern,$iterations,$ms_per_access" >> page_fault_results.csv
  
  echo ""
}

# Function to check and enable huge pages
setup_huge_pages() {
  local nr_hugepages=20
  
  echo "=== Setting up huge pages ==="
  
  # Check if we have permission to set huge pages
  if [ -w /proc/sys/vm/nr_hugepages ]; then
    echo "Setting nr_hugepages to $nr_hugepages"
    echo $nr_hugepages | sudo tee /proc/sys/vm/nr_hugepages
    
    # Verify
    echo "Current huge page settings:"
    grep Huge /proc/meminfo
  else
    echo "No permission to set huge pages. Running as root or with sudo may be required."
    echo "Current huge page settings:"
    grep Huge /proc/meminfo
  fi
  
  echo ""
}

# Function to get TLB information
get_tlb_info() {
  echo "=== TLB Information ==="
  
  if [[ "$(get_arch)" == "Intel/AMD (x86_64)" ]]; then
    # For x86_64, try to use cpuid
    if command -v cpuid &> /dev/null; then
      echo "TLB information from cpuid:"
      cpuid | grep -i tlb
    else
      echo "cpuid not available. Install with: sudo apt install cpuid"
    fi
  else
    # For Arm, there's no easy way to get TLB info from user space
    echo "TLB information not directly accessible on Arm architecture."
    echo "Check CPU documentation for TLB specifications."
  fi
  
  echo ""
}

# Initialize CSV files
echo "array_size_mb,stride,huge_pages,ns_per_access" > tlb_results.csv
echo "file_size_mb,access_pattern,iterations,ms_per_access" > page_fault_results.csv

# Get TLB information
get_tlb_info

# Setup huge pages
setup_huge_pages

# Run TLB benchmarks with different array sizes (to test different levels of TLB)
# Standard pages
run_tlb_benchmark 1 16 10000000 0    # Small array (L1 TLB)
run_tlb_benchmark 4 16 10000000 0    # Medium array (L2 TLB)
run_tlb_benchmark 64 16 10000000 0   # Large array (beyond TLB)
run_tlb_benchmark 256 16 10000000 0  # Very large array

# Different strides to test spatial locality
run_tlb_benchmark 64 1 10000000 0    # Adjacent elements
run_tlb_benchmark 64 4 10000000 0    # 16-byte stride
run_tlb_benchmark 64 16 10000000 0   # 64-byte stride
run_tlb_benchmark 64 64 10000000 0   # 256-byte stride
run_tlb_benchmark 64 256 10000000 0  # 1024-byte stride

# Huge pages (if available)
run_tlb_benchmark 64 16 10000000 1   # Large array with huge pages
run_tlb_benchmark 256 16 10000000 1  # Very large array with huge pages

# Run page fault benchmarks
run_page_fault_benchmark 128 0 1000  # Sequential access
run_page_fault_benchmark 128 1 1000  # Random access
run_page_fault_benchmark 512 0 1000  # Larger file, sequential
run_page_fault_benchmark 512 1 1000  # Larger file, random

# Generate plots if gnuplot is available
if command -v gnuplot &> /dev/null; then
  echo "Generating plots..."
  
  # TLB array size plot
  gnuplot -e "set term png; set output 'tlb_array_size.png'; \
              set title 'TLB Performance vs Array Size'; \
              set xlabel 'Array Size (MB)'; \
              set ylabel 'Access Time (ns)'; \
              set logscale x; \
              plot 'tlb_results.csv' using 1:4 with linespoints title 'Access Time'"
  
  # TLB stride plot
  gnuplot -e "set term png; set output 'tlb_stride.png'; \
              set title 'TLB Performance vs Stride'; \
              set xlabel 'Stride (elements)'; \
              set ylabel 'Access Time (ns)'; \
              set logscale x; \
              plot 'tlb_results.csv' using 2:4 with linespoints title 'Access Time'"
  
  # Page fault plot
  gnuplot -e "set term png; set output 'page_fault.png'; \
              set title 'Page Fault Performance'; \
              set xlabel 'File Size (MB)'; \
              set ylabel 'Access Time (ms)'; \
              set logscale y; \
              plot 'page_fault_results.csv' using 1:4 with linespoints title 'Access Time'"
fi

echo "Page size and TLB benchmarks completed."
```

Make the script executable:

```bash
chmod +x page_size_tlb_benchmark.sh
```

### Step 5: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
sudo ./page_size_tlb_benchmark.sh | tee page_size_tlb_benchmark_results.txt
```

### Step 6: Analyze the Results

Compare the results from both architectures, focusing on:

1. **TLB Performance**: Compare access times for different array sizes and strides.
2. **Page Size Impact**: Compare performance with standard pages versus huge pages.
3. **Page Fault Handling**: Compare page fault handling efficiency for sequential and random access patterns.
4. **TLB Coverage**: Identify the point at which performance degrades due to TLB misses.
5. **Spatial Locality**: Analyze how stride size affects performance on each architecture.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **TLB Size and Levels**: Different architectures may have different TLB sizes and hierarchies.
- **Page Size Support**: x86 typically supports 4KB, 2MB, and 1GB pages, while Arm may support 4KB, 16KB, 64KB, and larger pages.
- **MMU Design**: Different approaches to memory management unit implementation.
- **Cache Line Size**: Interaction between page size, TLB, and cache line size.
- **Hardware Prefetching**: Different prefetching strategies may affect page fault handling.

## Relevance to Workloads

Page size and TLB performance benchmarking is particularly important for:

1. **Large Memory Applications**: Databases, in-memory caches, big data processing
2. **Memory-Mapped File Processing**: Log analysis, data mining, content indexing
3. **Virtualization**: Hypervisors, container runtimes, nested virtualization
4. **High-Performance Computing**: Scientific simulations with large datasets
5. **Memory-Intensive Web Services**: Search engines, recommendation systems

Understanding page size and TLB differences between architectures helps you optimize memory-intensive applications, potentially leading to significant performance improvements through appropriate page size selection and memory access pattern optimization.

## Advanced Optimization: Huge Pages

For production environments, consider these huge page optimization techniques:

1. **Transparent Huge Pages (THP)**: Enable automatic huge page allocation with `echo always > /sys/kernel/mm/transparent_hugepage/enabled`

2. **Static Huge Pages**: Allocate huge pages at boot time by setting `vm.nr_hugepages` in `/etc/sysctl.conf`

3. **Application-Specific Allocation**: Use `mmap()` with `MAP_HUGETLB` flag or `libhugetlbfs` for explicit huge page allocation

4. **Database Optimization**: Configure databases like MySQL, PostgreSQL, or MongoDB to use huge pages

5. **JVM Optimization**: Use `-XX:+UseLargePages` for Java applications

## Knowledge Check

1. If an application shows significantly better performance with huge pages on one architecture but minimal improvement on another, what might this suggest?
   - A) The application has a memory leak
   - B) One architecture has a smaller or less efficient TLB
   - C) The operating system is not properly configured
   - D) The benchmark is not measuring correctly

2. Which access pattern is most likely to benefit from a larger TLB?
   - A) Sequential access to a small array
   - B) Random access across a very large memory region
   - C) Accessing the same few memory locations repeatedly
   - D) Streaming through memory with no reuse

3. If page fault handling is significantly faster on one architecture for sequential access but similar for random access, what might this indicate?
   - A) The architecture has better prefetching capabilities
   - B) The page size is larger on that architecture
   - C) The benchmark is not measuring page faults correctly
   - D) The file system is more efficient on that architecture

Answers:
1. B) One architecture has a smaller or less efficient TLB
2. B) Random access across a very large memory region
3. A) The architecture has better prefetching capabilities