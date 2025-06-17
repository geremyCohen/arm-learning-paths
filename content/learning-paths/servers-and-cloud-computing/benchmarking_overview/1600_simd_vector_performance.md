---
title: SIMD/Vector Instruction Performance
weight: 1600

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding SIMD/Vector Instruction Performance

Single Instruction, Multiple Data (SIMD) or vector instructions allow processors to perform the same operation on multiple data elements simultaneously, significantly accelerating data-parallel workloads. These instructions are crucial for performance-intensive applications like multimedia processing, scientific computing, and machine learning.

When comparing Intel/AMD (x86) versus Arm architectures, SIMD capabilities differ significantly:
- x86 processors use SSE, AVX, AVX2, and AVX-512 instruction sets
- Arm processors use NEON and SVE (Scalable Vector Extension) instruction sets

These architectural differences affect vector width, supported operations, and overall performance characteristics.

For more detailed information about SIMD/Vector instructions, you can refer to:
- [Intel Intrinsics Guide](https://software.intel.com/sites/landingpage/IntrinsicsGuide/)
- [Arm NEON Intrinsics Reference](https://developer.arm.com/architectures/instruction-sets/simd-isas/neon/intrinsics)
- [Arm SVE Documentation](https://developer.arm.com/documentation/100891/latest/)

## Benchmarking Exercise: Comparing SIMD/Vector Performance

In this exercise, we'll measure and compare SIMD/Vector instruction performance across Intel/AMD and Arm architectures using various vector operations.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential gcc g++ python3-matplotlib
```

### Step 2: Create Vector Addition Benchmark

Create a file named `vector_add.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

// Architecture-specific headers
#ifdef __x86_64__
#include <immintrin.h>
#elif defined(__aarch64__)
#include <arm_neon.h>
#endif

#define ARRAY_SIZE 10000000
#define ITERATIONS 100

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Scalar addition
void add_scalar(float *a, float *b, float *c, int size) {
    for (int i = 0; i < size; i++) {
        c[i] = a[i] + b[i];
    }
}

// SIMD addition for x86
#ifdef __x86_64__
void add_simd_x86(float *a, float *b, float *c, int size) {
    int i = 0;
    
    // Process 8 elements at a time using AVX
    #ifdef __AVX__
    for (; i <= size - 8; i += 8) {
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);
        __m256 vc = _mm256_add_ps(va, vb);
        _mm256_storeu_ps(&c[i], vc);
    }
    #endif
    
    // Process 4 elements at a time using SSE
    #ifdef __SSE__
    for (; i <= size - 4; i += 4) {
        __m128 va = _mm_loadu_ps(&a[i]);
        __m128 vb = _mm_loadu_ps(&b[i]);
        __m128 vc = _mm_add_ps(va, vb);
        _mm_storeu_ps(&c[i], vc);
    }
    #endif
    
    // Process remaining elements
    for (; i < size; i++) {
        c[i] = a[i] + b[i];
    }
}
#endif

// SIMD addition for Arm
#ifdef __aarch64__
void add_simd_arm(float *a, float *b, float *c, int size) {
    int i = 0;
    
    // Process 4 elements at a time using NEON
    for (; i <= size - 4; i += 4) {
        float32x4_t va = vld1q_f32(&a[i]);
        float32x4_t vb = vld1q_f32(&b[i]);
        float32x4_t vc = vaddq_f32(va, vb);
        vst1q_f32(&c[i], vc);
    }
    
    // Process remaining elements
    for (; i < size; i++) {
        c[i] = a[i] + b[i];
    }
}
#endif

int main(int argc, char *argv[]) {
    int use_simd = 0;
    if (argc > 1) {
        use_simd = atoi(argv[1]);
    }
    
    // Allocate arrays
    float *a = (float *)aligned_alloc(32, ARRAY_SIZE * sizeof(float));
    float *b = (float *)aligned_alloc(32, ARRAY_SIZE * sizeof(float));
    float *c = (float *)aligned_alloc(32, ARRAY_SIZE * sizeof(float));
    
    if (!a || !b || !c) {
        perror("aligned_alloc");
        return 1;
    }
    
    // Initialize arrays
    for (int i = 0; i < ARRAY_SIZE; i++) {
        a[i] = (float)rand() / RAND_MAX;
        b[i] = (float)rand() / RAND_MAX;
        c[i] = 0.0f;
    }
    
    // Warm up
    if (use_simd) {
        #ifdef __x86_64__
        add_simd_x86(a, b, c, ARRAY_SIZE);
        #elif defined(__aarch64__)
        add_simd_arm(a, b, c, ARRAY_SIZE);
        #else
        add_scalar(a, b, c, ARRAY_SIZE);
        #endif
    } else {
        add_scalar(a, b, c, ARRAY_SIZE);
    }
    
    // Benchmark
    double start_time = get_time();
    
    for (int iter = 0; iter < ITERATIONS; iter++) {
        if (use_simd) {
            #ifdef __x86_64__
            add_simd_x86(a, b, c, ARRAY_SIZE);
            #elif defined(__aarch64__)
            add_simd_arm(a, b, c, ARRAY_SIZE);
            #else
            add_scalar(a, b, c, ARRAY_SIZE);
            #endif
        } else {
            add_scalar(a, b, c, ARRAY_SIZE);
        }
    }
    
    double end_time = get_time();
    double elapsed = end_time - start_time;
    double elements_per_second = (double)ARRAY_SIZE * ITERATIONS / elapsed;
    
    printf("Mode: %s\n", use_simd ? "SIMD" : "Scalar");
    printf("Time: %.6f seconds\n", elapsed);
    printf("Elements processed per second: %.2f million\n", elements_per_second / 1000000);
    
    // Verify result (prevent optimization)
    float sum = 0.0f;
    for (int i = 0; i < ARRAY_SIZE; i += 1000) {
        sum += c[i];
    }
    printf("Checksum: %f\n", sum);
    
    // Clean up
    free(a);
    free(b);
    free(c);
    
    return 0;
}
```

### Step 3: Create Vector Multiply-Add Benchmark

Create a file named `vector_fma.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

// Architecture-specific headers
#ifdef __x86_64__
#include <immintrin.h>
#elif defined(__aarch64__)
#include <arm_neon.h>
#endif

#define ARRAY_SIZE 10000000
#define ITERATIONS 100

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Scalar FMA
void fma_scalar(float *a, float *b, float *c, float *d, int size) {
    for (int i = 0; i < size; i++) {
        d[i] = a[i] * b[i] + c[i];
    }
}

// SIMD FMA for x86
#ifdef __x86_64__
void fma_simd_x86(float *a, float *b, float *c, float *d, int size) {
    int i = 0;
    
    // Process 8 elements at a time using AVX
    #ifdef __FMA__
    for (; i <= size - 8; i += 8) {
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);
        __m256 vc = _mm256_loadu_ps(&c[i]);
        __m256 vd = _mm256_fmadd_ps(va, vb, vc);
        _mm256_storeu_ps(&d[i], vd);
    }
    #elif defined(__AVX__)
    for (; i <= size - 8; i += 8) {
        __m256 va = _mm256_loadu_ps(&a[i]);
        __m256 vb = _mm256_loadu_ps(&b[i]);
        __m256 vc = _mm256_loadu_ps(&c[i]);
        __m256 vmul = _mm256_mul_ps(va, vb);
        __m256 vd = _mm256_add_ps(vmul, vc);
        _mm256_storeu_ps(&d[i], vd);
    }
    #endif
    
    // Process 4 elements at a time using SSE
    #ifdef __SSE__
    for (; i <= size - 4; i += 4) {
        __m128 va = _mm_loadu_ps(&a[i]);
        __m128 vb = _mm_loadu_ps(&b[i]);
        __m128 vc = _mm_loadu_ps(&c[i]);
        __m128 vmul = _mm_mul_ps(va, vb);
        __m128 vd = _mm_add_ps(vmul, vc);
        _mm_storeu_ps(&d[i], vd);
    }
    #endif
    
    // Process remaining elements
    for (; i < size; i++) {
        d[i] = a[i] * b[i] + c[i];
    }
}
#endif

// SIMD FMA for Arm
#ifdef __aarch64__
void fma_simd_arm(float *a, float *b, float *c, float *d, int size) {
    int i = 0;
    
    // Process 4 elements at a time using NEON
    for (; i <= size - 4; i += 4) {
        float32x4_t va = vld1q_f32(&a[i]);
        float32x4_t vb = vld1q_f32(&b[i]);
        float32x4_t vc = vld1q_f32(&c[i]);
        float32x4_t vd = vfmaq_f32(vc, va, vb);
        vst1q_f32(&d[i], vd);
    }
    
    // Process remaining elements
    for (; i < size; i++) {
        d[i] = a[i] * b[i] + c[i];
    }
}
#endif

int main(int argc, char *argv[]) {
    int use_simd = 0;
    if (argc > 1) {
        use_simd = atoi(argv[1]);
    }
    
    // Allocate arrays
    float *a = (float *)aligned_alloc(32, ARRAY_SIZE * sizeof(float));
    float *b = (float *)aligned_alloc(32, ARRAY_SIZE * sizeof(float));
    float *c = (float *)aligned_alloc(32, ARRAY_SIZE * sizeof(float));
    float *d = (float *)aligned_alloc(32, ARRAY_SIZE * sizeof(float));
    
    if (!a || !b || !c || !d) {
        perror("aligned_alloc");
        return 1;
    }
    
    // Initialize arrays
    for (int i = 0; i < ARRAY_SIZE; i++) {
        a[i] = (float)rand() / RAND_MAX;
        b[i] = (float)rand() / RAND_MAX;
        c[i] = (float)rand() / RAND_MAX;
        d[i] = 0.0f;
    }
    
    // Warm up
    if (use_simd) {
        #ifdef __x86_64__
        fma_simd_x86(a, b, c, d, ARRAY_SIZE);
        #elif defined(__aarch64__)
        fma_simd_arm(a, b, c, d, ARRAY_SIZE);
        #else
        fma_scalar(a, b, c, d, ARRAY_SIZE);
        #endif
    } else {
        fma_scalar(a, b, c, d, ARRAY_SIZE);
    }
    
    // Benchmark
    double start_time = get_time();
    
    for (int iter = 0; iter < ITERATIONS; iter++) {
        if (use_simd) {
            #ifdef __x86_64__
            fma_simd_x86(a, b, c, d, ARRAY_SIZE);
            #elif defined(__aarch64__)
            fma_simd_arm(a, b, c, d, ARRAY_SIZE);
            #else
            fma_scalar(a, b, c, d, ARRAY_SIZE);
            #endif
        } else {
            fma_scalar(a, b, c, d, ARRAY_SIZE);
        }
    }
    
    double end_time = get_time();
    double elapsed = end_time - start_time;
    double elements_per_second = (double)ARRAY_SIZE * ITERATIONS / elapsed;
    double gflops = 2.0 * elements_per_second / 1000000000; // 2 operations per element (multiply and add)
    
    printf("Mode: %s\n", use_simd ? "SIMD" : "Scalar");
    printf("Time: %.6f seconds\n", elapsed);
    printf("Elements processed per second: %.2f million\n", elements_per_second / 1000000);
    printf("GFLOPS: %.2f\n", gflops);
    
    // Verify result (prevent optimization)
    float sum = 0.0f;
    for (int i = 0; i < ARRAY_SIZE; i += 1000) {
        sum += d[i];
    }
    printf("Checksum: %f\n", sum);
    
    // Clean up
    free(a);
    free(b);
    free(c);
    free(d);
    
    return 0;
}
```

### Step 4: Create Benchmark Script

Create a file named `run_simd_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Get architecture and CPU info
arch=$(uname -m)
echo "Architecture: $arch"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"

# Check for SIMD support
echo "SIMD Support:"
if [ "$arch" = "x86_64" ]; then
    lscpu | grep -E 'sse|avx|fma'
elif [ "$arch" = "aarch64" ]; then
    lscpu | grep -E 'neon|sve|asimd'
fi

# Compile with different optimization levels
echo "Compiling benchmarks..."

# Vector addition
gcc -O3 vector_add.c -o vector_add_scalar
gcc -O3 -march=native vector_add.c -o vector_add_simd

# Vector FMA
gcc -O3 vector_fma.c -o vector_fma_scalar
gcc -O3 -march=native vector_fma.c -o vector_fma_simd

# Initialize results file
echo "operation,mode,time,elements_per_second,gflops" > simd_results.csv

# Run vector addition benchmarks
echo "Running vector addition benchmarks..."
./vector_add_scalar 0 | tee vector_add_scalar.txt
./vector_add_simd 1 | tee vector_add_simd.txt

# Extract and save results
time_scalar=$(grep "Time:" vector_add_scalar.txt | awk '{print $2}')
eps_scalar=$(grep "Elements processed per second:" vector_add_scalar.txt | awk '{print $5}')

time_simd=$(grep "Time:" vector_add_simd.txt | awk '{print $2}')
eps_simd=$(grep "Elements processed per second:" vector_add_simd.txt | awk '{print $5}')

echo "add,scalar,$time_scalar,$eps_scalar,N/A" >> simd_results.csv
echo "add,simd,$time_simd,$eps_simd,N/A" >> simd_results.csv

# Run vector FMA benchmarks
echo "Running vector FMA benchmarks..."
./vector_fma_scalar 0 | tee vector_fma_scalar.txt
./vector_fma_simd 1 | tee vector_fma_simd.txt

# Extract and save results
time_scalar=$(grep "Time:" vector_fma_scalar.txt | awk '{print $2}')
eps_scalar=$(grep "Elements processed per second:" vector_fma_scalar.txt | awk '{print $5}')
gflops_scalar=$(grep "GFLOPS:" vector_fma_scalar.txt | awk '{print $2}')

time_simd=$(grep "Time:" vector_fma_simd.txt | awk '{print $2}')
eps_simd=$(grep "Elements processed per second:" vector_fma_simd.txt | awk '{print $5}')
gflops_simd=$(grep "GFLOPS:" vector_fma_simd.txt | awk '{print $2}')

echo "fma,scalar,$time_scalar,$eps_scalar,$gflops_scalar" >> simd_results.csv
echo "fma,simd,$time_simd,$eps_simd,$gflops_simd" >> simd_results.csv

echo "Benchmark complete. Results saved to simd_results.csv"

# Calculate speedups
scalar_add=$(grep "add,scalar" simd_results.csv | cut -d, -f4)
simd_add=$(grep "add,simd" simd_results.csv | cut -d, -f4)
add_speedup=$(echo "scale=2; $simd_add / $scalar_add" | bc)

scalar_fma=$(grep "fma,scalar" simd_results.csv | cut -d, -f4)
simd_fma=$(grep "fma,simd" simd_results.csv | cut -d, -f4)
fma_speedup=$(echo "scale=2; $simd_fma / $scalar_fma" | bc)

echo "Vector Add SIMD Speedup: ${add_speedup}x"
echo "Vector FMA SIMD Speedup: ${fma_speedup}x"
```

Make the script executable:

```bash
chmod +x run_simd_benchmark.sh
```

### Step 5: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
./run_simd_benchmark.sh
```

### Step 6: Analyze the Results

Compare the results from both architectures, focusing on:

1. **SIMD Speedup**: Compare the performance improvement from scalar to SIMD on each architecture.
2. **Operation Efficiency**: Compare how efficiently each architecture handles different vector operations.
3. **GFLOPS**: Compare the floating-point operations per second for compute-intensive operations.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Vector Width**: x86 AVX supports 256-bit vectors (8 floats), while Arm NEON supports 128-bit vectors (4 floats).
- **Instruction Set Features**: Different instruction sets support different operations with varying efficiency.
- **Hardware Implementation**: The physical implementation of SIMD units affects performance.
- **Compiler Optimization**: Compiler auto-vectorization capabilities may differ between architectures.

## Relevance to Workloads

SIMD/Vector performance benchmarking is particularly important for:

1. **Image and Video Processing**: Filters, encoders, decoders
2. **Scientific Computing**: Simulations, numerical analysis
3. **Machine Learning**: Training and inference operations
4. **Audio Processing**: Filters, encoders, effects
5. **Computer Graphics**: Rendering, physics simulations

Understanding SIMD/Vector performance differences between architectures helps you optimize code for better performance by:
- Selecting appropriate vector widths and operations
- Using architecture-specific intrinsics when necessary
- Structuring data for efficient vector processing
- Considering auto-vectorization capabilities of compilers

## Knowledge Check

1. If an application shows a 4x speedup with SIMD on x86 but only a 2x speedup on Arm, what might be the most likely cause?
   - A) The compiler is not optimizing correctly for Arm
   - B) The x86 processor has wider SIMD registers (256-bit AVX vs 128-bit NEON)
   - C) The application is not memory-bound
   - D) The benchmark is not measuring correctly

2. Which type of data layout is most efficient for SIMD processing?
   - A) Array of Structures (AoS)
   - B) Structure of Arrays (SoA)
   - C) Linked lists
   - D) Hash tables

3. When would auto-vectorization by the compiler be least effective?
   - A) Simple loops with independent iterations
   - B) Loops with complex control flow and data dependencies
   - C) Array operations with regular access patterns
   - D) Mathematical operations on contiguous data

Answers:
1. B) The x86 processor has wider SIMD registers (256-bit AVX vs 128-bit NEON)
2. B) Structure of Arrays (SoA)
3. B) Loops with complex control flow and data dependencies