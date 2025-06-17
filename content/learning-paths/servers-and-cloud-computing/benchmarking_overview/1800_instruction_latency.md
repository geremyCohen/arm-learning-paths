---
title: Instruction Latency and Throughput
weight: 1800

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Instruction Latency and Throughput

Instruction latency refers to the time it takes for a single instruction to complete, while instruction throughput measures how many instructions can be executed per unit of time. These metrics are fundamental to understanding processor performance at the lowest level and can vary significantly between architectures.

When comparing Intel/AMD (x86) versus Arm architectures, instruction latency and throughput characteristics differ due to variations in pipeline design, execution units, and microarchitectural implementation. These differences can have substantial performance implications, especially for compute-intensive applications.

For more detailed information about instruction latency and throughput, you can refer to:
- [Agner Fog's Instruction Tables](https://www.agner.org/optimize/instruction_tables.pdf)
- [Arm Cortex-A Series Programmer's Guide](https://developer.arm.com/documentation/den0024/latest/)
- [Intel Optimization Reference Manual](https://software.intel.com/content/www/us/en/develop/download/intel-64-and-ia-32-architectures-optimization-reference-manual.html)

## Benchmarking Exercise: Comparing Instruction Latency and Throughput

In this exercise, we'll measure and compare the latency and throughput of common instructions across Intel/AMD and Arm architectures.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential gcc
```

### Step 2: Create Instruction Latency Benchmark

Create a file named `latency_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ITERATIONS 100000000
#define WARMUP_ITERATIONS 1000000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Measure integer add latency (dependent chain)
uint64_t measure_int_add_latency() {
    uint64_t a = 1;
    
    // Warmup
    for (int i = 0; i < WARMUP_ITERATIONS; i++) {
        a = a + 1;
    }
    
    double start = get_time();
    
    // Create a dependency chain to measure latency
    for (int i = 0; i < ITERATIONS; i++) {
        a = a + 1;  // Each operation depends on the previous result
    }
    
    double end = get_time();
    double elapsed = end - start;
    double latency_ns = (elapsed * 1e9) / ITERATIONS;
    
    printf("Integer Add Latency: %.2f ns\n", latency_ns);
    return a;  // Prevent optimization
}

// Measure integer multiply latency (dependent chain)
uint64_t measure_int_mul_latency() {
    uint64_t a = 1;
    
    // Warmup
    for (int i = 0; i < WARMUP_ITERATIONS; i++) {
        a = a * 7;
    }
    
    double start = get_time();
    
    // Create a dependency chain to measure latency
    for (int i = 0; i < ITERATIONS; i++) {
        a = a * 7;  // Each operation depends on the previous result
    }
    
    double end = get_time();
    double elapsed = end - start;
    double latency_ns = (elapsed * 1e9) / ITERATIONS;
    
    printf("Integer Multiply Latency: %.2f ns\n", latency_ns);
    return a;  // Prevent optimization
}

// Measure floating-point add latency (dependent chain)
double measure_float_add_latency() {
    double a = 1.0;
    
    // Warmup
    for (int i = 0; i < WARMUP_ITERATIONS; i++) {
        a = a + 0.1;
    }
    
    double start = get_time();
    
    // Create a dependency chain to measure latency
    for (int i = 0; i < ITERATIONS; i++) {
        a = a + 0.1;  // Each operation depends on the previous result
    }
    
    double end = get_time();
    double elapsed = end - start;
    double latency_ns = (elapsed * 1e9) / ITERATIONS;
    
    printf("Float Add Latency: %.2f ns\n", latency_ns);
    return a;  // Prevent optimization
}

// Measure floating-point multiply latency (dependent chain)
double measure_float_mul_latency() {
    double a = 1.0;
    
    // Warmup
    for (int i = 0; i < WARMUP_ITERATIONS; i++) {
        a = a * 1.01;
    }
    
    double start = get_time();
    
    // Create a dependency chain to measure latency
    for (int i = 0; i < ITERATIONS; i++) {
        a = a * 1.01;  // Each operation depends on the previous result
    }
    
    double end = get_time();
    double elapsed = end - start;
    double latency_ns = (elapsed * 1e9) / ITERATIONS;
    
    printf("Float Multiply Latency: %.2f ns\n", latency_ns);
    return a;  // Prevent optimization
}

int main() {
    printf("CPU Architecture: %s\n", 
        #ifdef __x86_64__
        "x86_64"
        #elif defined(__aarch64__)
        "aarch64"
        #else
        "unknown"
        #endif
    );
    
    // Measure instruction latencies
    volatile uint64_t result1 = measure_int_add_latency();
    volatile uint64_t result2 = measure_int_mul_latency();
    volatile double result3 = measure_float_add_latency();
    volatile double result4 = measure_float_mul_latency();
    
    // Prevent compiler from optimizing away the calculations
    printf("Results (to prevent optimization): %lu %lu %.6f %.6f\n", 
           result1, result2, result3, result4);
    
    return 0;
}
```

### Step 3: Create Instruction Throughput Benchmark

Create a file named `throughput_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ITERATIONS 100000000
#define WARMUP_ITERATIONS 1000000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Measure integer add throughput (independent operations)
void measure_int_add_throughput() {
    uint64_t a = 1, b = 2, c = 3, d = 4;
    
    // Warmup
    for (int i = 0; i < WARMUP_ITERATIONS; i++) {
        a += 1;
        b += 1;
        c += 1;
        d += 1;
    }
    
    double start = get_time();
    
    // Independent operations to measure throughput
    for (int i = 0; i < ITERATIONS; i++) {
        a += 1;  // Independent operations
        b += 1;
        c += 1;
        d += 1;
    }
    
    double end = get_time();
    double elapsed = end - start;
    double ops_per_second = (ITERATIONS * 4) / elapsed;
    double throughput_ns = (elapsed * 1e9) / (ITERATIONS * 4);
    
    printf("Integer Add Throughput: %.2f operations/ns (%.2f GOPS)\n", 
           1.0 / throughput_ns, ops_per_second / 1e9);
    printf("Results: %lu %lu %lu %lu\n", a, b, c, d);  // Prevent optimization
}

// Measure integer multiply throughput (independent operations)
void measure_int_mul_throughput() {
    uint64_t a = 1, b = 2, c = 3, d = 4;
    
    // Warmup
    for (int i = 0; i < WARMUP_ITERATIONS; i++) {
        a *= 7;
        b *= 7;
        c *= 7;
        d *= 7;
    }
    
    double start = get_time();
    
    // Independent operations to measure throughput
    for (int i = 0; i < ITERATIONS; i++) {
        a *= 7;  // Independent operations
        b *= 7;
        c *= 7;
        d *= 7;
    }
    
    double end = get_time();
    double elapsed = end - start;
    double ops_per_second = (ITERATIONS * 4) / elapsed;
    double throughput_ns = (elapsed * 1e9) / (ITERATIONS * 4);
    
    printf("Integer Multiply Throughput: %.2f operations/ns (%.2f GOPS)\n", 
           1.0 / throughput_ns, ops_per_second / 1e9);
    printf("Results: %lu %lu %lu %lu\n", a, b, c, d);  // Prevent optimization
}

// Measure floating-point add throughput (independent operations)
void measure_float_add_throughput() {
    double a = 1.0, b = 2.0, c = 3.0, d = 4.0;
    
    // Warmup
    for (int i = 0; i < WARMUP_ITERATIONS; i++) {
        a += 0.1;
        b += 0.1;
        c += 0.1;
        d += 0.1;
    }
    
    double start = get_time();
    
    // Independent operations to measure throughput
    for (int i = 0; i < ITERATIONS; i++) {
        a += 0.1;  // Independent operations
        b += 0.1;
        c += 0.1;
        d += 0.1;
    }
    
    double end = get_time();
    double elapsed = end - start;
    double ops_per_second = (ITERATIONS * 4) / elapsed;
    double throughput_ns = (elapsed * 1e9) / (ITERATIONS * 4);
    
    printf("Float Add Throughput: %.2f operations/ns (%.2f GFLOPS)\n", 
           1.0 / throughput_ns, ops_per_second / 1e9);
    printf("Results: %.6f %.6f %.6f %.6f\n", a, b, c, d);  // Prevent optimization
}

// Measure floating-point multiply throughput (independent operations)
void measure_float_mul_throughput() {
    double a = 1.0, b = 2.0, c = 3.0, d = 4.0;
    
    // Warmup
    for (int i = 0; i < WARMUP_ITERATIONS; i++) {
        a *= 1.01;
        b *= 1.01;
        c *= 1.01;
        d *= 1.01;
    }
    
    double start = get_time();
    
    // Independent operations to measure throughput
    for (int i = 0; i < ITERATIONS; i++) {
        a *= 1.01;  // Independent operations
        b *= 1.01;
        c *= 1.01;
        d *= 1.01;
    }
    
    double end = get_time();
    double elapsed = end - start;
    double ops_per_second = (ITERATIONS * 4) / elapsed;
    double throughput_ns = (elapsed * 1e9) / (ITERATIONS * 4);
    
    printf("Float Multiply Throughput: %.2f operations/ns (%.2f GFLOPS)\n", 
           1.0 / throughput_ns, ops_per_second / 1e9);
    printf("Results: %.6f %.6f %.6f %.6f\n", a, b, c, d);  // Prevent optimization
}

int main() {
    printf("CPU Architecture: %s\n", 
        #ifdef __x86_64__
        "x86_64"
        #elif defined(__aarch64__)
        "aarch64"
        #else
        "unknown"
        #endif
    );
    
    // Measure instruction throughput
    measure_int_add_throughput();
    measure_int_mul_throughput();
    measure_float_add_throughput();
    measure_float_mul_throughput();
    
    return 0;
}
```

### Step 4: Create Benchmark Script

Create a file named `run_instruction_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Get architecture and CPU info
arch=$(uname -m)
echo "Architecture: $arch"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "CPU Frequency: $(lscpu | grep 'CPU MHz' | cut -d: -f2 | xargs) MHz"

# Compile benchmarks
echo "Compiling benchmarks..."
gcc -O3 latency_benchmark.c -o latency_benchmark
gcc -O3 throughput_benchmark.c -o throughput_benchmark

# Run latency benchmark
echo "Running instruction latency benchmark..."
./latency_benchmark | tee latency_results.txt

# Run throughput benchmark
echo "Running instruction throughput benchmark..."
./throughput_benchmark | tee throughput_results.txt

# Extract and format results
echo "Instruction,Latency (ns)" > latency_summary.csv
grep "Integer Add Latency" latency_results.txt | awk '{print "Integer Add," $4}' >> latency_summary.csv
grep "Integer Multiply Latency" latency_results.txt | awk '{print "Integer Multiply," $4}' >> latency_summary.csv
grep "Float Add Latency" latency_results.txt | awk '{print "Float Add," $4}' >> latency_summary.csv
grep "Float Multiply Latency" latency_results.txt | awk '{print "Float Multiply," $4}' >> latency_summary.csv

echo "Instruction,Throughput (ops/ns),GOPS/GFLOPS" > throughput_summary.csv
grep "Integer Add Throughput" throughput_results.txt | awk '{print "Integer Add," $4, $6}' | sed 's/(//' >> throughput_summary.csv
grep "Integer Multiply Throughput" throughput_results.txt | awk '{print "Integer Multiply," $4, $6}' | sed 's/(//' >> throughput_summary.csv
grep "Float Add Throughput" throughput_results.txt | awk '{print "Float Add," $4, $6}' | sed 's/(//' >> throughput_summary.csv
grep "Float Multiply Throughput" throughput_results.txt | awk '{print "Float Multiply," $4, $6}' | sed 's/(//' >> throughput_summary.csv

echo "Benchmark complete. Results saved to latency_summary.csv and throughput_summary.csv"
```

Make the script executable:

```bash
chmod +x run_instruction_benchmark.sh
```

### Step 5: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
./run_instruction_benchmark.sh
```

### Step 6: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Instruction Latency**: Compare the time it takes for a single instruction to complete.
2. **Instruction Throughput**: Compare how many instructions can be executed per unit of time.
3. **Integer vs. Floating-Point**: Compare the relative performance of integer and floating-point operations.
4. **Operation Complexity**: Compare how performance scales with operation complexity (add vs. multiply).

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Pipeline Design**: Different architectures have different pipeline depths and widths.
- **Execution Units**: The number and capability of execution units affect throughput.
- **Superscalar Execution**: The ability to execute multiple instructions in parallel.
- **Out-of-Order Execution**: The ability to reorder instructions to maximize throughput.
- **Clock Speed**: The base clock speed affects raw instruction performance.

## Relevance to Workloads

Instruction latency and throughput benchmarking is particularly important for:

1. **Compute-Intensive Applications**: Scientific computing, simulations, rendering
2. **Low-Latency Systems**: High-frequency trading, real-time control systems
3. **Compiler Optimization**: Instruction scheduling and code generation
4. **Algorithm Design**: Selecting optimal algorithms for specific architectures
5. **Performance-Critical Loops**: Optimizing inner loops in performance-sensitive code

Understanding instruction performance differences between architectures helps you optimize code for better performance by:
- Selecting appropriate instructions for critical operations
- Structuring code to maximize instruction-level parallelism
- Avoiding operations with high latency in critical paths
- Balancing latency and throughput considerations

## Knowledge Check

1. If an application shows higher integer operation throughput on one architecture but higher floating-point throughput on another, what might be the most appropriate optimization strategy?
   - A) Always use the architecture with higher integer performance
   - B) Always use the architecture with higher floating-point performance
   - C) Profile the application to determine whether integer or floating-point operations dominate
   - D) Rewrite the application to use only the operation type that performs best on each architecture

2. Which factor most directly affects instruction latency?
   - A) Memory bandwidth
   - B) Pipeline depth
   - C) Cache size
   - D) Number of CPU cores

3. If an application has many dependent calculations (where each operation depends on the result of the previous one), which metric is most important to optimize for?
   - A) Instruction throughput
   - B) Instruction latency
   - C) Memory bandwidth
   - D) Cache size

Answers:
1. C) Profile the application to determine whether integer or floating-point operations dominate
2. B) Pipeline depth
3. B) Instruction latency