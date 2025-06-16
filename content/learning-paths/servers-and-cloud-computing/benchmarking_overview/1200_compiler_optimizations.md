---
title: Compiler Optimizations and Architecture Performance
weight: 1200

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Compiler Optimizations

Compiler optimizations play a crucial role in extracting maximum performance from any CPU architecture. The same source code can yield significantly different performance results depending on how it's compiled. When comparing Intel/AMD (x86) versus Arm architectures, understanding compiler behavior becomes even more important, as each architecture may benefit from different optimization techniques.

Compilers translate human-readable source code into machine instructions, making numerous decisions along the way about instruction selection, scheduling, inlining, vectorization, and many other transformations. These decisions can have profound effects on performance, and they often interact with specific architectural features.

For more detailed information about compiler optimizations, you can refer to:
- [GCC Optimization Options](https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html)
- [LLVM/Clang Optimization Guide](https://llvm.org/docs/Passes.html)
- [Architecture-Specific Optimizations](https://developer.arm.com/documentation/101725/0200/Optimization)

## Benchmarking Exercise: Comparing Compiler Optimization Impact

In this exercise, we'll explore how different compiler optimizations affect performance on Intel/AMD and Arm architectures, and how to identify the best optimization strategies for each platform.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential gcc g++ clang llvm time python3 python3-matplotlib gnuplot
```

### Step 2: Create Test Programs

Create a file named `matrix_multiply.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

#define SIZE 1024

double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

void matrix_multiply_naive(float *A, float *B, float *C, int n) {
    int i, j, k;
    
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

void matrix_multiply_optimized(float *A, float *B, float *C, int n) {
    int i, j, k;
    
    // Cache blocking optimization
    int block_size = 32;
    
    for (int ii = 0; ii < n; ii += block_size) {
        for (int jj = 0; jj < n; jj += block_size) {
            for (int kk = 0; kk < n; kk += block_size) {
                // Process block
                for (i = ii; i < ii + block_size && i < n; i++) {
                    for (j = jj; j < jj + block_size && j < n; j++) {
                        float sum = C[i * n + j];
                        for (k = kk; k < kk + block_size && k < n; k++) {
                            sum += A[i * n + k] * B[k * n + j];
                        }
                        C[i * n + j] = sum;
                    }
                }
            }
        }
    }
}

int main(int argc, char *argv[]) {
    float *A, *B, *C;
    double start_time, end_time, elapsed;
    int n = SIZE;
    int use_optimized = 0;
    
    // Parse command line arguments
    if (argc > 1) {
        if (strcmp(argv[1], "optimized") == 0) {
            use_optimized = 1;
        }
    }
    
    printf("Matrix size: %d x %d\n", n, n);
    printf("Using %s implementation\n", use_optimized ? "optimized" : "naive");
    
    // Allocate memory
    A = (float *)malloc(n * n * sizeof(float));
    B = (float *)malloc(n * n * sizeof(float));
    C = (float *)malloc(n * n * sizeof(float));
    
    if (!A || !B || !C) {
        printf("Memory allocation failed\n");
        return 1;
    }
    
    // Initialize matrices
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            A[i * n + j] = (float)rand() / RAND_MAX;
            B[i * n + j] = (float)rand() / RAND_MAX;
            C[i * n + j] = 0.0f;
        }
    }
    
    // Warm up
    if (use_optimized) {
        matrix_multiply_optimized(A, B, C, n);
    } else {
        matrix_multiply_naive(A, B, C, n);
    }
    
    // Reset C
    memset(C, 0, n * n * sizeof(float));
    
    // Benchmark
    start_time = get_time();
    
    if (use_optimized) {
        matrix_multiply_optimized(A, B, C, n);
    } else {
        matrix_multiply_naive(A, B, C, n);
    }
    
    end_time = get_time();
    
    elapsed = end_time - start_time;
    
    // Calculate FLOPS: 2*n^3 operations
    double flops = (2.0 * n * n * n) / elapsed;
    
    printf("Execution time: %.6f seconds\n", elapsed);
    printf("Performance: %.2f GFLOPS\n", flops / 1.0e9);
    
    // Prevent compiler from optimizing away the computation
    float sum = 0.0f;
    for (int i = 0; i < n; i++) {
        sum += C[i * n + i];
    }
    printf("Checksum: %f\n", sum);
    
    free(A);
    free(B);
    free(C);
    
    return 0;
}
```

Create another file named `vectorization_test.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

#define ARRAY_SIZE 50000000

double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

void vector_add(float *a, float *b, float *c, int n) {
    for (int i = 0; i < n; i++) {
        c[i] = a[i] + b[i];
    }
}

void vector_multiply(float *a, float *b, float *c, int n) {
    for (int i = 0; i < n; i++) {
        c[i] = a[i] * b[i];
    }
}

void vector_fma(float *a, float *b, float *c, float *d, int n) {
    for (int i = 0; i < n; i++) {
        d[i] = a[i] * b[i] + c[i];
    }
}

int main(int argc, char *argv[]) {
    float *a, *b, *c, *d;
    double start_time, end_time, elapsed;
    int n = ARRAY_SIZE;
    char *operation = "add";
    
    // Parse command line arguments
    if (argc > 1) {
        operation = argv[1];
    }
    
    printf("Array size: %d\n", n);
    printf("Operation: %s\n", operation);
    
    // Allocate memory
    a = (float *)malloc(n * sizeof(float));
    b = (float *)malloc(n * sizeof(float));
    c = (float *)malloc(n * sizeof(float));
    d = (float *)malloc(n * sizeof(float));
    
    if (!a || !b || !c || !d) {
        printf("Memory allocation failed\n");
        return 1;
    }
    
    // Initialize arrays
    for (int i = 0; i < n; i++) {
        a[i] = (float)rand() / RAND_MAX;
        b[i] = (float)rand() / RAND_MAX;
        c[i] = (float)rand() / RAND_MAX;
        d[i] = 0.0f;
    }
    
    // Warm up
    if (strcmp(operation, "add") == 0) {
        vector_add(a, b, c, n);
    } else if (strcmp(operation, "multiply") == 0) {
        vector_multiply(a, b, c, n);
    } else if (strcmp(operation, "fma") == 0) {
        vector_fma(a, b, c, d, n);
    }
    
    // Benchmark
    start_time = get_time();
    
    if (strcmp(operation, "add") == 0) {
        vector_add(a, b, c, n);
    } else if (strcmp(operation, "multiply") == 0) {
        vector_multiply(a, b, c, n);
    } else if (strcmp(operation, "fma") == 0) {
        vector_fma(a, b, c, d, n);
    }
    
    end_time = get_time();
    
    elapsed = end_time - start_time;
    
    // Calculate operations per second
    double ops = n / elapsed;
    
    printf("Execution time: %.6f seconds\n", elapsed);
    printf("Performance: %.2f million operations per second\n", ops / 1.0e6);
    
    // Prevent compiler from optimizing away the computation
    float sum = 0.0f;
    if (strcmp(operation, "fma") == 0) {
        for (int i = 0; i < n; i += 1000) {
            sum += d[i];
        }
    } else {
        for (int i = 0; i < n; i += 1000) {
            sum += c[i];
        }
    }
    printf("Checksum: %f\n", sum);
    
    free(a);
    free(b);
    free(c);
    free(d);
    
    return 0;
}
```

### Step 3: Create Benchmark Script

Create a file named `compiler_optimization_benchmark.sh` with the following content:

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
echo "Compiler Versions:"
gcc --version | head -n 1
clang --version | head -n 1
echo ""

# Function to compile and run matrix multiplication benchmark
run_matrix_benchmark() {
  local compiler=$1
  local opt_level=$2
  local arch_flags=$3
  local algorithm=$4
  local description="$compiler $opt_level $arch_flags $algorithm"
  
  echo "=== Running Matrix Multiplication Benchmark: $description ==="
  
  # Compile
  $compiler $opt_level $arch_flags matrix_multiply.c -o matrix_multiply_${compiler}_${opt_level// /_}_${algorithm} -lm
  
  # Run
  ./matrix_multiply_${compiler}_${opt_level// /_}_${algorithm} $algorithm | tee matrix_${compiler}_${opt_level// /_}_${algorithm}.txt
  
  # Extract performance
  local gflops=$(grep "Performance:" matrix_${compiler}_${opt_level// /_}_${algorithm}.txt | awk '{print $2}')
  
  # Save result
  echo "$compiler,$opt_level,$arch_flags,$algorithm,$gflops" >> matrix_results.csv
  
  echo ""
}

# Function to compile and run vectorization benchmark
run_vector_benchmark() {
  local compiler=$1
  local opt_level=$2
  local arch_flags=$3
  local operation=$4
  local description="$compiler $opt_level $arch_flags $operation"
  
  echo "=== Running Vectorization Benchmark: $description ==="
  
  # Compile
  $compiler $opt_level $arch_flags vectorization_test.c -o vector_${compiler}_${opt_level// /_}_${operation} -lm
  
  # Run
  ./vector_${compiler}_${opt_level// /_}_${operation} $operation | tee vector_${compiler}_${opt_level// /_}_${operation}.txt
  
  # Extract performance
  local mops=$(grep "Performance:" vector_${compiler}_${opt_level// /_}_${operation}.txt | awk '{print $2}')
  
  # Save result
  echo "$compiler,$opt_level,$arch_flags,$operation,$mops" >> vector_results.csv
  
  echo ""
}

# Function to analyze assembly code
analyze_assembly() {
  local compiler=$1
  local opt_level=$2
  local arch_flags=$3
  local source_file=$4
  local description="$compiler $opt_level $arch_flags $source_file"
  
  echo "=== Analyzing Assembly Code: $description ==="
  
  # Generate assembly
  $compiler $opt_level $arch_flags -S -o ${source_file%.c}_${compiler}_${opt_level// /_}.s $source_file
  
  # Count instructions
  echo "Instruction count:"
  grep -v "^\s*\." ${source_file%.c}_${compiler}_${opt_level// /_}.s | grep -v "^#" | grep -v "^\s*$" | wc -l
  
  # Check for SIMD instructions
  echo "SIMD instruction check:"
  if [[ "$(get_arch)" == "Intel/AMD (x86_64)" ]]; then
    grep -E 'addps|mulps|movaps|xmm|ymm|zmm' ${source_file%.c}_${compiler}_${opt_level// /_}.s | wc -l
  else
    grep -E 'ld1|st1|fmla|fadd|fmul' ${source_file%.c}_${compiler}_${opt_level// /_}.s | wc -l
  fi
  
  echo ""
}

# Initialize CSV files
echo "compiler,opt_level,arch_flags,algorithm,gflops" > matrix_results.csv
echo "compiler,opt_level,arch_flags,operation,mops" > vector_results.csv

# Define optimization levels
opt_levels=("-O0" "-O1" "-O2" "-O3" "-Ofast")

# Define architecture-specific flags
if [[ "$(get_arch)" == "Intel/AMD (x86_64)" ]]; then
  arch_flags=("" "-march=native" "-march=native -mavx2" "-march=native -mavx2 -mfma")
else
  arch_flags=("" "-march=native" "-march=native -mcpu=native" "-march=native -mcpu=native -mtune=native")
fi

# Run matrix multiplication benchmarks with GCC
for opt in "${opt_levels[@]}"; do
  for arch in "${arch_flags[@]}"; do
    run_matrix_benchmark "gcc" "$opt" "$arch" "naive"
    run_matrix_benchmark "gcc" "$opt" "$arch" "optimized"
  done
done

# Run matrix multiplication benchmarks with Clang
for opt in "${opt_levels[@]}"; do
  for arch in "${arch_flags[@]}"; do
    run_matrix_benchmark "clang" "$opt" "$arch" "naive"
    run_matrix_benchmark "clang" "$opt" "$arch" "optimized"
  done
done

# Run vectorization benchmarks with GCC
for opt in "${opt_levels[@]}"; do
  for arch in "${arch_flags[@]}"; do
    run_vector_benchmark "gcc" "$opt" "$arch" "add"
    run_vector_benchmark "gcc" "$opt" "$arch" "multiply"
    run_vector_benchmark "gcc" "$opt" "$arch" "fma"
  done
done

# Run vectorization benchmarks with Clang
for opt in "${opt_levels[@]}"; do
  for arch in "${arch_flags[@]}"; do
    run_vector_benchmark "clang" "$opt" "$arch" "add"
    run_vector_benchmark "clang" "$opt" "$arch" "multiply"
    run_vector_benchmark "clang" "$opt" "$arch" "fma"
  done
done

# Analyze assembly code for key configurations
analyze_assembly "gcc" "-O0" "" "matrix_multiply.c"
analyze_assembly "gcc" "-O3" "-march=native" "matrix_multiply.c"
analyze_assembly "clang" "-O3" "-march=native" "matrix_multiply.c"
analyze_assembly "gcc" "-O3" "-march=native" "vectorization_test.c"

# Generate plots if gnuplot is available
if command -v gnuplot &> /dev/null; then
  echo "Generating plots..."
  
  # Matrix multiplication performance plot
  gnuplot -e "set term png; set output 'matrix_performance.png'; \
              set title 'Matrix Multiplication Performance'; \
              set xlabel 'Compiler and Optimization Level'; \
              set ylabel 'GFLOPS'; \
              set style data histogram; \
              set style fill solid; \
              set xtics rotate by -45; \
              plot 'matrix_results.csv' using 5:xtic(strcol(1).' '.strcol(2)) title 'Performance'"
  
  # Vectorization performance plot
  gnuplot -e "set term png; set output 'vector_performance.png'; \
              set title 'Vector Operation Performance'; \
              set xlabel 'Compiler and Optimization Level'; \
              set ylabel 'Million Operations per Second'; \
              set style data histogram; \
              set style fill solid; \
              set xtics rotate by -45; \
              plot 'vector_results.csv' using 5:xtic(strcol(1).' '.strcol(2).' '.strcol(4)) title 'Performance'"
fi

echo "Compiler optimization benchmarks completed."
```

Make the script executable:

```bash
chmod +x compiler_optimization_benchmark.sh
```

### Step 4: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
./compiler_optimization_benchmark.sh | tee compiler_optimization_results.txt
```

### Step 5: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Optimization Level Impact**: How performance scales with different optimization levels (-O0 to -Ofast).
2. **Architecture-Specific Flags**: The impact of architecture-specific compiler flags.
3. **Compiler Differences**: Performance variations between GCC and Clang.
4. **Vectorization Efficiency**: How well each architecture handles vectorized operations.
5. **Algorithm Implementation**: The impact of algorithm optimizations across architectures.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **SIMD Capabilities**: x86 has SSE, AVX, AVX2, AVX-512, while Arm has NEON and SVE.
- **Instruction Scheduling**: Different architectures benefit from different instruction ordering.
- **Register Allocation**: The number and usage of registers can impact compiler optimization.
- **Memory Access Patterns**: How each architecture handles different memory access patterns.
- **Compiler Maturity**: The level of optimization support for each architecture in the compiler.

## Relevance to Workloads

Compiler optimization benchmarking is particularly important for:

1. **High-Performance Computing**: Scientific simulations, numerical analysis, computational physics
2. **Media Processing**: Image and video encoding/decoding, audio processing
3. **Machine Learning**: Training and inference workloads
4. **Financial Applications**: Risk analysis, algorithmic trading
5. **Database Systems**: Query execution engines, data processing pipelines

Understanding compiler optimization differences between architectures helps you select the optimal compilation strategies for your applications, potentially leading to significant performance improvements with minimal code changes.

## Advanced Optimization Techniques

For production environments, consider these advanced techniques:

1. **Profile-Guided Optimization (PGO)**: Compile with `-fprofile-generate`, run the application with typical workloads, then recompile with `-fprofile-use` to optimize based on actual execution patterns.

2. **Link-Time Optimization (LTO)**: Use `-flto` to enable optimizations across compilation units.

3. **Function Multi-Versioning**: Create multiple versions of performance-critical functions optimized for different instruction sets.

4. **Interprocedural Optimization (IPO)**: Enable `-fipa-*` optimizations for whole-program analysis.

5. **Architecture-Specific Tuning**: Use `-mtune=` to optimize for specific CPU models within an architecture family.

## Knowledge Check

1. If a program shows significant performance improvement with `-O3` on x86 but minimal improvement on Arm, what might be the cause?
   - A) The compiler has better optimization support for x86
   - B) The program uses instructions that are more efficiently optimized on x86
   - C) The Arm processor is already running at peak efficiency
   - D) The benchmark is not measuring correctly

2. Which compiler flag is most important to enable when trying to get the best performance from architecture-specific SIMD instructions?
   - A) `-O3`
   - B) `-march=native`
   - C) `-funroll-loops`
   - D) `-ffast-math`

3. If vectorization analysis shows that a loop is not being vectorized despite using `-O3`, what might be the most likely reason?
   - A) The compiler doesn't support vectorization
   - B) The loop has dependencies that prevent safe vectorization
   - C) The CPU doesn't have vector instructions
   - D) The loop is too short to benefit from vectorization

Answers:
1. B) The program uses instructions that are more efficiently optimized on x86
2. B) `-march=native`
3. B) The loop has dependencies that prevent safe vectorization