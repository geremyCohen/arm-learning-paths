---
title: Dot Product Instructions
weight: 1651

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Dot Product Instructions

Dot product operations are fundamental to many computational workloads, especially in machine learning, signal processing, and linear algebra. Arm's Dot Product instructions (UDOT/SDOT) introduced in Armv8.4-A provide hardware acceleration for these operations, enabling four simultaneous multiply-accumulate operations per cycle.

When comparing Intel/AMD (x86) versus Arm architectures, Arm's dedicated dot product instructions offer significant performance advantages for specific workloads. While x86 has SIMD instructions that can be used for dot products, Arm's purpose-built instructions are often more efficient for these operations.

## Benchmarking Exercise: Measuring Dot Product Performance

In this exercise, we'll measure the performance impact of using dot product instructions on Arm Neoverse processors.

### Prerequisites

Ensure you have an Arm VM with:
- Arm (aarch64) with Neoverse V1/N2 processors (for dot product support)
- GCC or Clang compiler installed

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc
```

### Step 2: Create Dot Product Benchmark

Create a file named `dot_product_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#ifdef __ARM_FEATURE_DOTPROD
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

// Standard dot product implementation
int32_t dot_product_standard(int8_t *a, int8_t *b, size_t size) {
    int32_t sum = 0;
    for (size_t i = 0; i < size; i++) {
        sum += a[i] * b[i];
    }
    return sum;
}

// NEON-optimized dot product without dot product instructions
int32_t dot_product_neon(int8_t *a, int8_t *b, size_t size) {
#ifdef __ARM_NEON
    int32x4_t sum_vec = vdupq_n_s32(0);
    
    // Process 16 elements at a time
    for (size_t i = 0; i <= size - 16; i += 16) {
        // Load 16 elements (as 8-bit values)
        int8x16_t a_vec = vld1q_s8(&a[i]);
        int8x16_t b_vec = vld1q_s8(&b[i]);
        
        // Convert to 16-bit
        int16x8_t a_low = vmovl_s8(vget_low_s8(a_vec));
        int16x8_t a_high = vmovl_s8(vget_high_s8(a_vec));
        int16x8_t b_low = vmovl_s8(vget_low_s8(b_vec));
        int16x8_t b_high = vmovl_s8(vget_high_s8(b_vec));
        
        // Multiply and accumulate
        sum_vec = vmlal_s16(sum_vec, vget_low_s16(a_low), vget_low_s16(b_low));
        sum_vec = vmlal_s16(sum_vec, vget_high_s16(a_low), vget_high_s16(b_low));
        sum_vec = vmlal_s16(sum_vec, vget_low_s16(a_high), vget_low_s16(b_high));
        sum_vec = vmlal_s16(sum_vec, vget_high_s16(a_high), vget_high_s16(b_high));
    }
    
    // Horizontal sum
    int32_t sum = vaddvq_s32(sum_vec);
    
    // Process remaining elements
    for (size_t i = (size / 16) * 16; i < size; i++) {
        sum += a[i] * b[i];
    }
    
    return sum;
#else
    return dot_product_standard(a, b, size);
#endif
}

// Dot product using dedicated dot product instructions
int32_t dot_product_dotprod(int8_t *a, int8_t *b, size_t size) {
#if defined(__ARM_FEATURE_DOTPROD)
    int32x4_t sum_vec = vdupq_n_s32(0);
    
    // Process 16 elements at a time
    for (size_t i = 0; i <= size - 16; i += 16) {
        // Load 16 elements (as 8-bit values)
        int8x16_t a_vec = vld1q_s8(&a[i]);
        int8x16_t b_vec = vld1q_s8(&b[i]);
        
        // Use dot product instruction
        sum_vec = vdotq_s32(sum_vec, a_vec, b_vec);
    }
    
    // Horizontal sum
    int32_t sum = vaddvq_s32(sum_vec);
    
    // Process remaining elements
    for (size_t i = (size / 16) * 16; i < size; i++) {
        sum += a[i] * b[i];
    }
    
    return sum;
#else
    return dot_product_neon(a, b, size);
#endif
}

int main() {
    printf("CPU Architecture: %s\n", 
        #ifdef __aarch64__
        "aarch64"
        #else
        "other"
        #endif
    );
    
    printf("Dot Product Instructions: %s\n", 
        #ifdef __ARM_FEATURE_DOTPROD
        "Supported"
        #else
        "Not supported"
        #endif
    );
    
    // Allocate arrays
    int8_t *a = (int8_t *)malloc(ARRAY_SIZE * sizeof(int8_t));
    int8_t *b = (int8_t *)malloc(ARRAY_SIZE * sizeof(int8_t));
    
    if (!a || !b) {
        perror("malloc");
        return 1;
    }
    
    // Initialize arrays with random values
    srand(42);  // Fixed seed for reproducibility
    for (size_t i = 0; i < ARRAY_SIZE; i++) {
        a[i] = (int8_t)(rand() % 256 - 128);
        b[i] = (int8_t)(rand() % 256 - 128);
    }
    
    // Benchmark standard implementation
    double start = get_time();
    int32_t result_standard = 0;
    for (int i = 0; i < ITERATIONS; i++) {
        result_standard = dot_product_standard(a, b, ARRAY_SIZE);
    }
    double end = get_time();
    double standard_time = end - start;
    
    printf("Standard dot product time: %.6f seconds\n", standard_time);
    printf("Standard result: %d\n", result_standard);
    
    // Benchmark NEON implementation
    start = get_time();
    int32_t result_neon = 0;
    for (int i = 0; i < ITERATIONS; i++) {
        result_neon = dot_product_neon(a, b, ARRAY_SIZE);
    }
    end = get_time();
    double neon_time = end - start;
    
    printf("NEON dot product time: %.6f seconds\n", neon_time);
    printf("NEON result: %d\n", result_neon);
    printf("NEON speedup: %.2fx\n", standard_time / neon_time);
    
    // Benchmark dot product instruction implementation
    start = get_time();
    int32_t result_dotprod = 0;
    for (int i = 0; i < ITERATIONS; i++) {
        result_dotprod = dot_product_dotprod(a, b, ARRAY_SIZE);
    }
    end = get_time();
    double dotprod_time = end - start;
    
    printf("Dot product instruction time: %.6f seconds\n", dotprod_time);
    printf("Dot product instruction result: %d\n", result_dotprod);
    printf("Dot product instruction speedup vs standard: %.2fx\n", standard_time / dotprod_time);
    printf("Dot product instruction speedup vs NEON: %.2fx\n", neon_time / dotprod_time);
    
    // Verify results match
    if (result_standard != result_neon || result_standard != result_dotprod) {
        printf("Error: Results don't match!\n");
    }
    
    free(a);
    free(b);
    
    return 0;
}
```

Compile with dot product support:

```bash
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -march=armv8.4-a+dotprod dot_product_benchmark.c -o dot_product_benchmark
```

### Step 3: Run the Benchmark

Execute the benchmark:

```bash
./dot_product_benchmark
```

## Practical Dot Product Implementation

### 1. Matrix Multiplication with Dot Product

Create a file named `matrix_multiply_dotprod.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#ifdef __ARM_FEATURE_DOTPROD
#include <arm_neon.h>
#endif

#define SIZE 1024
#define BLOCK_SIZE 32

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Standard matrix multiplication with int8_t
void matrix_multiply_standard(int8_t *a, int8_t *b, int32_t *c, int size) {
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            int32_t sum = 0;
            for (int k = 0; k < size; k++) {
                sum += a[i * size + k] * b[k * size + j];
            }
            c[i * size + j] = sum;
        }
    }
}

// Matrix multiplication using dot product instructions
void matrix_multiply_dotprod(int8_t *a, int8_t *b, int32_t *c, int size) {
#if defined(__ARM_FEATURE_DOTPROD)
    // Block-based matrix multiplication with dot product
    for (int i = 0; i < size; i += BLOCK_SIZE) {
        for (int j = 0; j < size; j += BLOCK_SIZE) {
            for (int k = 0; k < size; k += BLOCK_SIZE) {
                // Process blocks
                for (int ii = i; ii < i + BLOCK_SIZE && ii < size; ii++) {
                    for (int jj = j; jj < j + BLOCK_SIZE && jj < size; jj++) {
                        int32x4_t sum_vec = vdupq_n_s32(0);
                        
                        // Process 16 elements at a time using dot product
                        for (int kk = k; kk < k + BLOCK_SIZE && kk < size; kk += 16) {
                            if (kk + 16 <= size) {
                                int8x16_t a_vec = vld1q_s8(&a[ii * size + kk]);
                                int8x16_t b_vec = vld1q_s8(&b[kk * size + jj]);
                                sum_vec = vdotq_s32(sum_vec, a_vec, b_vec);
                            }
                        }
                        
                        // Horizontal sum
                        int32_t sum = vaddvq_s32(sum_vec);
                        
                        // Process remaining elements
                        for (int kk = k + ((k + BLOCK_SIZE) / 16) * 16; 
                             kk < k + BLOCK_SIZE && kk < size; kk++) {
                            sum += a[ii * size + kk] * b[kk * size + jj];
                        }
                        
                        c[ii * size + jj] += sum;
                    }
                }
            }
        }
    }
#else
    matrix_multiply_standard(a, b, c, size);
#endif
}

int main() {
    printf("CPU Architecture: %s\n", 
        #ifdef __aarch64__
        "aarch64"
        #else
        "other"
        #endif
    );
    
    printf("Dot Product Instructions: %s\n", 
        #ifdef __ARM_FEATURE_DOTPROD
        "Supported"
        #else
        "Not supported"
        #endif
    );
    
    // Allocate matrices
    int8_t *a = (int8_t *)malloc(SIZE * SIZE * sizeof(int8_t));
    int8_t *b = (int8_t *)malloc(SIZE * SIZE * sizeof(int8_t));
    int32_t *c1 = (int32_t *)calloc(SIZE * SIZE, sizeof(int32_t));
    int32_t *c2 = (int32_t *)calloc(SIZE * SIZE, sizeof(int32_t));
    
    if (!a || !b || !c1 || !c2) {
        perror("malloc");
        return 1;
    }
    
    // Initialize matrices with random values
    srand(42);  // Fixed seed for reproducibility
    for (int i = 0; i < SIZE * SIZE; i++) {
        a[i] = (int8_t)(rand() % 256 - 128);
        b[i] = (int8_t)(rand() % 256 - 128);
    }
    
    // Benchmark standard implementation
    double start = get_time();
    matrix_multiply_standard(a, b, c1, SIZE);
    double end = get_time();
    double standard_time = end - start;
    
    printf("Standard matrix multiply time: %.6f seconds\n", standard_time);
    
    // Benchmark dot product implementation
    start = get_time();
    matrix_multiply_dotprod(a, b, c2, SIZE);
    end = get_time();
    double dotprod_time = end - start;
    
    printf("Dot product matrix multiply time: %.6f seconds\n", dotprod_time);
    printf("Speedup: %.2fx\n", standard_time / dotprod_time);
    
    // Verify results match
    int errors = 0;
    for (int i = 0; i < SIZE * SIZE; i++) {
        if (c1[i] != c2[i]) {
            errors++;
            if (errors < 10) {
                printf("Error at index %d: %d vs %d\n", i, c1[i], c2[i]);
            }
        }
    }
    printf("Errors: %d\n", errors);
    
    free(a);
    free(b);
    free(c1);
    free(c2);
    
    return 0;
}
```

Compile with:

```bash
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -march=armv8.4-a+dotprod matrix_multiply_dotprod.c -o matrix_multiply_dotprod
```

### 2. Key Dot Product Optimization Techniques

1. **Direct Dot Product Usage**:
   ```c
   #include <arm_neon.h>
   
   // Load 16 int8_t elements
   int8x16_t a_vec = vld1q_s8(a_ptr);
   int8x16_t b_vec = vld1q_s8(b_ptr);
   
   // Compute dot product and accumulate
   int32x4_t sum = vdotq_s32(sum, a_vec, b_vec);
   ```

2. **Unsigned Dot Product**:
   ```c
   // For unsigned 8-bit integers
   uint8x16_t a_vec = vld1q_u8(a_ptr);
   uint8x16_t b_vec = vld1q_u8(b_ptr);
   uint32x4_t sum = vdotq_u32(sum, a_vec, b_vec);
   ```

3. **Horizontal Sum**:
   ```c
   // Sum all elements in the vector
   int32_t result = vaddvq_s32(sum_vec);
   ```

4. **Blocked Processing for Matrix Operations**:
   ```c
   // Process in blocks for better cache utilization
   for (int i = 0; i < size; i += BLOCK_SIZE) {
       for (int j = 0; j < size; j += BLOCK_SIZE) {
           // Process block
       }
   }
   ```

5. **Mixed Precision for ML Workloads**:
   ```c
   // Use int8 for weights and activations, int32 for accumulation
   int8_t *weights;    // 8-bit weights
   int8_t *activations; // 8-bit activations
   int32_t *results;   // 32-bit results
   
   // Compute with dot product
   int32x4_t accum = vdotq_s32(accum, 
                               vld1q_s8(weights), 
                               vld1q_s8(activations));
   ```

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| Dot Product | ✓ (with ARMv8.4-A) | ✓ | ✓ |

Dot Product instruction availability:
- Neoverse N1: Available with ARMv8.4-A extensions
- Neoverse V1: Fully supported
- Neoverse N2: Fully supported

## Further Reading

- [Arm Architecture Reference Manual - Dot Product Instructions](https://developer.arm.com/documentation/ddi0596/2021-12/SIMD-FP-Instructions/SDOT--Dot-Product-signed-integer-)
- [Arm Neoverse V1 Technical Reference Manual](https://developer.arm.com/documentation/101427/latest/)
- [Arm Dot Product Instructions for Machine Learning](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/exploring-the-arm-dot-product-instructions)
- [Optimizing ML Workloads with Dot Product](https://developer.arm.com/documentation/102159/latest/)

## Relevance to Cloud Computing Workloads

Dot Product instructions are particularly important for cloud computing on Neoverse:

1. **Machine Learning Inference**: Neural network operations
2. **Signal Processing**: Filters, transforms, correlations
3. **Computer Vision**: Feature extraction, object detection
4. **Natural Language Processing**: Word embeddings, attention mechanisms
5. **Scientific Computing**: Linear algebra operations

Understanding Dot Product instructions helps you:
- Accelerate ML inference by 2-4x
- Improve performance of linear algebra operations
- Optimize signal processing algorithms
- Reduce power consumption for compute-intensive workloads