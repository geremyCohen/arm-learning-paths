---
title: Floating-Point Performance
weight: 800

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Floating-Point Performance

Floating-point performance measures a system's ability to perform calculations with non-integer numbers, which is crucial for scientific computing, machine learning, graphics rendering, and financial modeling. Floating-point operations per second (FLOPS) is a common metric used to quantify this capability.

When comparing Intel/AMD (x86) versus Arm architectures, floating-point performance can vary significantly due to differences in floating-point unit (FPU) design, SIMD (Single Instruction, Multiple Data) capabilities, and instruction set extensions. Historically, x86 platforms had an advantage in floating-point performance, but modern Arm architectures have made significant strides with advanced SIMD capabilities like NEON and SVE (Scalable Vector Extension).

For more detailed information about floating-point performance, you can refer to:
- [Understanding Floating-Point Arithmetic](https://docs.oracle.com/cd/E19957-01/806-3568/ncg_goldberg.html)
- [SIMD Architecture and Performance Comparison](https://www.anandtech.com/show/16315/the-ampere-altra-review/5)

## Benchmarking Exercise: Comparing Floating-Point Performance

In this exercise, we'll use various benchmarks to measure and compare floating-point performance across Intel/AMD and Arm systems.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential git cmake python3 python3-matplotlib gnuplot libopenblas-dev liblapack-dev
```

### Step 2: Build and Install LINPACK Benchmark

LINPACK is a widely used benchmark for measuring floating-point computing power:

```bash
# Clone HPL (High-Performance LINPACK)
git clone https://github.com/icl-utk-edu/hpl.git
cd hpl

# Copy the make template
cp setup/Make.Linux_PII_CBLAS Make.linux

# Edit the Make.linux file to use OpenBLAS
cat > Make.linux << 'EOF'
SHELL        = /bin/sh
CD           = cd
CP           = cp
LN_S         = ln -s
MKDIR        = mkdir
RM           = /bin/rm -f
TOUCH        = touch
ARCH         = linux
TOPdir       = $(HOME)/hpl
INCdir       = $(TOPdir)/include
BINdir       = $(TOPdir)/bin/$(ARCH)
LIBdir       = $(TOPdir)/lib/$(ARCH)
HPLlib       = $(LIBdir)/libhpl.a
MPdir        = /usr
MPinc        = -I$(MPdir)/include
MPlib        = $(MPdir)/lib/libmpich.a
LAdir        = /usr
LAinc        = 
LAlib        = -lopenblas
CC           = gcc
CCFLAGS      = -O3 -march=native -fomit-frame-pointer
LINKER       = gcc
LINKFLAGS    = $(CCFLAGS)
ARCHIVER     = ar
ARFLAGS      = r
RANLIB       = echo
MAKE         = make
EOF

# Build HPL
make arch=linux
cd ..
```

### Step 3: Create STREAM Benchmark for Memory Bandwidth

STREAM is a benchmark that measures sustainable memory bandwidth:

```bash
# Clone STREAM
git clone https://github.com/jeffhammond/STREAM.git
cd STREAM

# Compile with optimizations
gcc -O3 -fopenmp -DSTREAM_ARRAY_SIZE=100000000 -DNTIMES=10 stream.c -o stream
cd ..
```

### Step 4: Create FLOPS Benchmark

Create a file named `flops_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include <float.h>
#include <omp.h>

#define ARRAY_SIZE 50000000
#define ITERATIONS 10

// Function to measure time with nanosecond precision
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Single-precision floating-point benchmark
void benchmark_float(int threads) {
    float *a, *b, *c;
    double start_time, end_time, elapsed;
    double flops;
    int i, j;
    
    printf("Running single-precision benchmark with %d threads...\n", threads);
    
    // Allocate memory
    a = (float *)malloc(ARRAY_SIZE * sizeof(float));
    b = (float *)malloc(ARRAY_SIZE * sizeof(float));
    c = (float *)malloc(ARRAY_SIZE * sizeof(float));
    
    if (!a || !b || !c) {
        printf("Memory allocation failed\n");
        exit(1);
    }
    
    // Initialize arrays
    for (i = 0; i < ARRAY_SIZE; i++) {
        a[i] = 1.0f + (float)i / ARRAY_SIZE;
        b[i] = 2.0f + (float)i / ARRAY_SIZE;
        c[i] = 0.0f;
    }
    
    // Set number of threads
    omp_set_num_threads(threads);
    
    // Warm up
    #pragma omp parallel for
    for (i = 0; i < ARRAY_SIZE; i++) {
        c[i] = a[i] * b[i] + c[i];
    }
    
    // Benchmark
    start_time = get_time();
    
    for (j = 0; j < ITERATIONS; j++) {
        #pragma omp parallel for
        for (i = 0; i < ARRAY_SIZE; i++) {
            // 8 floating-point operations per iteration
            c[i] = a[i] * b[i] + c[i];
            c[i] = a[i] * c[i] + b[i];
            c[i] = a[i] * b[i] + c[i];
            c[i] = a[i] * c[i] + b[i];
        }
    }
    
    end_time = get_time();
    elapsed = end_time - start_time;
    
    // Calculate FLOPS: 8 operations per loop iteration * array size * iterations
    flops = (8.0 * ARRAY_SIZE * ITERATIONS) / elapsed;
    
    printf("Single-precision results:\n");
    printf("Time: %.6f seconds\n", elapsed);
    printf("FLOPS: %.2f MFLOPS\n", flops / 1.0e6);
    printf("GFLOPS: %.2f\n", flops / 1.0e9);
    
    // Prevent compiler from optimizing away the computation
    float sum = 0.0f;
    for (i = 0; i < ARRAY_SIZE; i += ARRAY_SIZE/10) {
        sum += c[i];
    }
    printf("Checksum: %f\n", sum);
    
    free(a);
    free(b);
    free(c);
}

// Double-precision floating-point benchmark
void benchmark_double(int threads) {
    double *a, *b, *c;
    double start_time, end_time, elapsed;
    double flops;
    int i, j;
    
    printf("Running double-precision benchmark with %d threads...\n", threads);
    
    // Allocate memory
    a = (double *)malloc(ARRAY_SIZE * sizeof(double));
    b = (double *)malloc(ARRAY_SIZE * sizeof(double));
    c = (double *)malloc(ARRAY_SIZE * sizeof(double));
    
    if (!a || !b || !c) {
        printf("Memory allocation failed\n");
        exit(1);
    }
    
    // Initialize arrays
    for (i = 0; i < ARRAY_SIZE; i++) {
        a[i] = 1.0 + (double)i / ARRAY_SIZE;
        b[i] = 2.0 + (double)i / ARRAY_SIZE;
        c[i] = 0.0;
    }
    
    // Set number of threads
    omp_set_num_threads(threads);
    
    // Warm up
    #pragma omp parallel for
    for (i = 0; i < ARRAY_SIZE; i++) {
        c[i] = a[i] * b[i] + c[i];
    }
    
    // Benchmark
    start_time = get_time();
    
    for (j = 0; j < ITERATIONS; j++) {
        #pragma omp parallel for
        for (i = 0; i < ARRAY_SIZE; i++) {
            // 8 floating-point operations per iteration
            c[i] = a[i] * b[i] + c[i];
            c[i] = a[i] * c[i] + b[i];
            c[i] = a[i] * b[i] + c[i];
            c[i] = a[i] * c[i] + b[i];
        }
    }
    
    end_time = get_time();
    elapsed = end_time - start_time;
    
    // Calculate FLOPS: 8 operations per loop iteration * array size * iterations
    flops = (8.0 * ARRAY_SIZE * ITERATIONS) / elapsed;
    
    printf("Double-precision results:\n");
    printf("Time: %.6f seconds\n", elapsed);
    printf("FLOPS: %.2f MFLOPS\n", flops / 1.0e6);
    printf("GFLOPS: %.2f\n", flops / 1.0e9);
    
    // Prevent compiler from optimizing away the computation
    double sum = 0.0;
    for (i = 0; i < ARRAY_SIZE; i += ARRAY_SIZE/10) {
        sum += c[i];
    }
    printf("Checksum: %f\n", sum);
    
    free(a);
    free(b);
    free(c);
}

// Transcendental function benchmark
void benchmark_transcendental(int threads) {
    float *a, *b;
    double start_time, end_time, elapsed;
    double flops;
    int i, j;
    
    printf("Running transcendental function benchmark with %d threads...\n", threads);
    
    // Allocate memory
    a = (float *)malloc(ARRAY_SIZE * sizeof(float));
    b = (float *)malloc(ARRAY_SIZE * sizeof(float));
    
    if (!a || !b) {
        printf("Memory allocation failed\n");
        exit(1);
    }
    
    // Initialize arrays
    for (i = 0; i < ARRAY_SIZE; i++) {
        a[i] = (float)i / ARRAY_SIZE * 2.0f * M_PI;
        b[i] = 0.0f;
    }
    
    // Set number of threads
    omp_set_num_threads(threads);
    
    // Warm up
    #pragma omp parallel for
    for (i = 0; i < ARRAY_SIZE; i++) {
        b[i] = sinf(a[i]);
    }
    
    // Benchmark
    start_time = get_time();
    
    for (j = 0; j < ITERATIONS; j++) {
        #pragma omp parallel for
        for (i = 0; i < ARRAY_SIZE; i++) {
            // Mix of transcendental functions
            b[i] = sinf(a[i]);
            b[i] += cosf(a[i]);
            b[i] += sqrtf(fabsf(a[i]));
            b[i] += logf(1.0f + fabsf(a[i]));
        }
    }
    
    end_time = get_time();
    elapsed = end_time - start_time;
    
    // Calculate FLOPS: 4 operations per loop iteration * array size * iterations
    flops = (4.0 * ARRAY_SIZE * ITERATIONS) / elapsed;
    
    printf("Transcendental function results:\n");
    printf("Time: %.6f seconds\n", elapsed);
    printf("FLOPS: %.2f MFLOPS\n", flops / 1.0e6);
    printf("GFLOPS: %.2f\n", flops / 1.0e9);
    
    // Prevent compiler from optimizing away the computation
    float sum = 0.0f;
    for (i = 0; i < ARRAY_SIZE; i += ARRAY_SIZE/10) {
        sum += b[i];
    }
    printf("Checksum: %f\n", sum);
    
    free(a);
    free(b);
}

int main(int argc, char *argv[]) {
    int max_threads = omp_get_max_threads();
    
    printf("=== Floating-Point Performance Benchmark ===\n");
    printf("System has %d available threads\n\n", max_threads);
    
    // Run single-threaded benchmarks
    benchmark_float(1);
    printf("\n");
    benchmark_double(1);
    printf("\n");
    benchmark_transcendental(1);
    printf("\n");
    
    // Run multi-threaded benchmarks
    if (max_threads > 1) {
        benchmark_float(max_threads);
        printf("\n");
        benchmark_double(max_threads);
        printf("\n");
        benchmark_transcendental(max_threads);
    }
    
    return 0;
}
```

Compile the benchmark:

```bash
gcc -O3 -fopenmp -march=native flops_benchmark.c -o flops_benchmark -lm
```

### Step 5: Create Benchmark Script

Create a file named `floating_point_benchmark.sh` with the following content:

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
echo "CPU Features:"
if [[ "$(get_arch)" == "Intel/AMD (x86_64)" ]]; then
  lscpu | grep -E 'sse|avx|fma'
else
  lscpu | grep -E 'neon|sve|asimd'
fi
echo ""

# Run custom FLOPS benchmark
echo "=== Running Custom FLOPS Benchmark ==="
./flops_benchmark | tee flops_benchmark_results.txt
echo ""

# Run STREAM benchmark
echo "=== Running STREAM Memory Bandwidth Benchmark ==="
cd STREAM
./stream | tee ../stream_results.txt
cd ..
echo ""

# Create HPL.dat configuration file
cat > hpl/bin/linux/HPL.dat << EOF
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out      output file name (if any)
6            device out (6=stdout,7=stderr,file)
1            # of problems sizes (N)
10000        Ns
1            # of NBs
192          NBs
0            PMAP process mapping (0=Row-,1=Column-major)
1            # of process grids (P x Q)
1            Ps
1            Qs
16.0         threshold
1            # of panel fact
2            PFACTs (0=left, 1=Crout, 2=Right)
1            # of recursive stopping criterium
4            NBMINs (>= 1)
1            # of panels in recursion
2            NDIVs
1            # of recursive panel fact.
1            RFACTs (0=left, 1=Crout, 2=Right)
1            # of broadcast
1            BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
1            # of lookahead depth
1            DEPTHs (>=0)
2            SWAP (0=bin-exch,1=long,2=mix)
64           swapping threshold
0            L1 in (0=transposed,1=no-transposed) form
0            U  in (0=transposed,1=no-transposed) form
1            Equilibration (0=no,1=yes)
8            memory alignment in double (> 0)
EOF

# Run HPL benchmark
echo "=== Running HPL Benchmark ==="
cd hpl/bin/linux
./xhpl | tee ../../../hpl_results.txt
cd ../../..
echo ""

# Create a simple matrix multiplication benchmark
cat > matmul.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <omp.h>

#define SIZE 2000

double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

void matrix_multiply(float *A, float *B, float *C, int n) {
    int i, j, k;
    
    #pragma omp parallel for private(j, k)
    for (i = 0; i < n; i++) {
        for (j = 0; j < n; j++) {
            float sum = 0.0f;
            for (k = 0; k < n; k++) {
                sum += A[i * n + k] * B[k * n + j];
            }
            C[i * n + j] = sum;
        }
    }
}

int main() {
    float *A, *B, *C;
    double start_time, end_time, elapsed;
    double flops;
    int n = SIZE;
    int i, j;
    
    printf("Matrix size: %d x %d\n", n, n);
    
    // Allocate memory
    A = (float *)malloc(n * n * sizeof(float));
    B = (float *)malloc(n * n * sizeof(float));
    C = (float *)malloc(n * n * sizeof(float));
    
    if (!A || !B || !C) {
        printf("Memory allocation failed\n");
        return 1;
    }
    
    // Initialize matrices
    for (i = 0; i < n; i++) {
        for (j = 0; j < n; j++) {
            A[i * n + j] = (float)rand() / RAND_MAX;
            B[i * n + j] = (float)rand() / RAND_MAX;
            C[i * n + j] = 0.0f;
        }
    }
    
    // Warm up
    matrix_multiply(A, B, C, n);
    
    // Benchmark
    start_time = get_time();
    matrix_multiply(A, B, C, n);
    end_time = get_time();
    
    elapsed = end_time - start_time;
    
    // Calculate FLOPS: 2*n operations per element
    flops = (2.0 * n * n * n) / elapsed;
    
    printf("Matrix multiplication time: %.6f seconds\n", elapsed);
    printf("Performance: %.2f GFLOPS\n", flops / 1.0e9);
    
    // Prevent compiler from optimizing away the computation
    float sum = 0.0f;
    for (i = 0; i < n; i++) {
        sum += C[i * n + i];
    }
    printf("Checksum: %f\n", sum);
    
    free(A);
    free(B);
    free(C);
    
    return 0;
}
EOF

# Compile and run matrix multiplication benchmark
echo "=== Running Matrix Multiplication Benchmark ==="
gcc -O3 -fopenmp -march=native matmul.c -o matmul -lm
./matmul | tee matmul_results.txt
echo ""

# Summarize results
echo "=== Floating-Point Performance Summary ==="
echo "Single-precision GFLOPS:"
grep "GFLOPS" flops_benchmark_results.txt | grep "Single-precision" -A 3 | grep "GFLOPS" | awk '{print $2}'

echo "Double-precision GFLOPS:"
grep "GFLOPS" flops_benchmark_results.txt | grep "Double-precision" -A 3 | grep "GFLOPS" | awk '{print $2}'

echo "Transcendental GFLOPS:"
grep "GFLOPS" flops_benchmark_results.txt | grep "Transcendental" -A 3 | grep "GFLOPS" | awk '{print $2}'

echo "Matrix Multiplication GFLOPS:"
grep "Performance" matmul_results.txt | awk '{print $2}'

echo "HPL Performance (GFLOPS):"
grep "Gflops" hpl_results.txt | tail -1 | awk '{print $7}'

echo "All floating-point benchmarks completed."
```

Make the script executable:

```bash
chmod +x floating_point_benchmark.sh
```

### Step 6: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
./floating_point_benchmark.sh | tee floating_point_benchmark_results.txt
```

### Step 7: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Single-Precision Performance**: Compare GFLOPS for single-precision operations.
2. **Double-Precision Performance**: Compare GFLOPS for double-precision operations.
3. **Transcendental Function Performance**: Compare performance for complex mathematical functions.
4. **Matrix Multiplication Performance**: Compare GFLOPS for matrix operations.
5. **LINPACK Performance**: Compare HPL benchmark results.
6. **Scaling Efficiency**: Compare how performance scales with multiple threads.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **SIMD Capabilities**: x86 has SSE, AVX, AVX2, AVX-512, while Arm has NEON and SVE.
- **FPU Design**: Different approaches to floating-point unit implementation.
- **Instruction Latency**: Differences in the number of cycles required for floating-point operations.
- **Memory Bandwidth Impact**: How memory bandwidth affects floating-point performance.
- **Compiler Optimizations**: Different compiler optimizations for each architecture.

## Relevance to Workloads

Floating-point performance benchmarking is particularly important for:

1. **Scientific Computing**: Physics simulations, computational chemistry, weather modeling
2. **Machine Learning/AI**: Training and inference for neural networks
3. **Computer Graphics**: 3D rendering, image processing, video encoding
4. **Financial Modeling**: Risk analysis, option pricing, portfolio optimization
5. **Engineering Applications**: CAD/CAM, finite element analysis, computational fluid dynamics

Understanding floating-point performance differences between architectures helps you select the optimal platform for computationally intensive applications, potentially leading to significant performance improvements and cost savings.

## Knowledge Check

1. If an application shows better single-precision performance on Arm but better double-precision performance on x86, what might this suggest?
   - A) The application has a bug in its floating-point calculations
   - B) The Arm processor has optimized SIMD units for single-precision but less efficient double-precision units
   - C) The compiler is not optimizing correctly for one architecture
   - D) The benchmark is not measuring floating-point performance correctly

2. Which type of SIMD instruction set is available on modern Arm server processors but not on x86?
   - A) AVX-512
   - B) SSE4.2
   - C) SVE (Scalable Vector Extension)
   - D) FMA (Fused Multiply-Add)

3. For a machine learning inference workload that primarily uses single-precision floating-point operations, which metric from our benchmarks would be most relevant?
   - A) Double-precision GFLOPS
   - B) Single-precision GFLOPS
   - C) HPL benchmark results
   - D) Transcendental function performance

Answers:
1. B) The Arm processor has optimized SIMD units for single-precision but less efficient double-precision units
2. C) SVE (Scalable Vector Extension)
3. B) Single-precision GFLOPS