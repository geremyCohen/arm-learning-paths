---
title: SVE2 Vector Performance for Neoverse
weight: 1650

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding SVE2 Vector Performance on Neoverse

Scalable Vector Extension 2 (SVE2) is Arm's next-generation SIMD technology available in Neoverse V1 and N2 processors. Unlike NEON with its fixed 128-bit vectors, SVE2 allows for vector lengths from 128 to 2048 bits, with Neoverse implementations typically supporting 256-bit vectors. This scalability enables the same code to run efficiently across different Neoverse implementations.

When comparing Intel/AMD (AVX/AVX2/AVX-512) versus Arm Neoverse with SVE2, the scalable nature of SVE2 provides unique advantages for vectorized code portability and future-proofing. This can have substantial performance implications for compute-intensive cloud workloads.

## Benchmarking Exercise: SVE2 Vector Performance on Neoverse

In this exercise, we'll measure and compare the performance of SVE2 vector operations on Arm Neoverse architecture, with fallbacks for Neoverse N1 which uses NEON.

### Prerequisites

Ensure you have an Arm VM with Neoverse processors:
- Arm (aarch64) with Neoverse V1/N2 for SVE2 support
- Arm (aarch64) with Neoverse N1 will use NEON fallback

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc
```

### Step 2: Create Feature Detection Code

Create a file named `detect_features.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/auxv.h>

// Define constants if not available in headers
#ifndef HWCAP_SVE
#define HWCAP_SVE (1 << 22)
#endif

#ifndef HWCAP2_SVE2
#define HWCAP2_SVE2 (1 << 1)
#endif

int main() {
    printf("CPU Architecture: aarch64\n");
    
    // Get CPU information
    FILE *fp = popen("lscpu | grep 'Model name'", "r");
    if (fp) {
        char buffer[256];
        while (fgets(buffer, sizeof(buffer), fp)) {
            printf("%s", buffer);
        }
        pclose(fp);
    }
    
    // Check for SVE/SVE2 support
    unsigned long hwcap = getauxval(AT_HWCAP);
    unsigned long hwcap2 = getauxval(AT_HWCAP2);
    
    int sve_supported = (hwcap & HWCAP_SVE) != 0;
    int sve2_supported = (hwcap2 & HWCAP2_SVE2) != 0;
    
    printf("SVE support: %s\n", sve_supported ? "Yes" : "No");
    printf("SVE2 support: %s\n", sve2_supported ? "Yes" : "No");
    
    // Detect if running on Neoverse
    fp = popen("lscpu | grep -i neoverse", "r");
    if (fp) {
        char buffer[256];
        int is_neoverse = 0;
        while (fgets(buffer, sizeof(buffer), fp)) {
            is_neoverse = 1;
            printf("%s", buffer);
        }
        pclose(fp);
        
        if (!is_neoverse) {
            printf("Neoverse: Not detected\n");
        }
    }
    
    // If SVE is supported, get vector length
    if (sve_supported) {
        #ifdef __ARM_FEATURE_SVE
        int vector_bits = svcntb() * 8;
        printf("SVE vector length: %d bits\n", vector_bits);
        #else
        printf("SVE vector length: Unknown (compiler support missing)\n");
        #endif
    }
    
    return 0;
}
```

Compile and run:

```bash
gcc -march=armv8.2-a detect_features.c -o detect_features
./detect_features
```

### Step 3: Create SVE2/NEON Vector Benchmark

Create a file named `neoverse_vector_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

// Include SVE header if available
#if defined(__ARM_FEATURE_SVE)
#include <arm_sve.h>
#endif

// Include NEON header for fallback
#include <arm_neon.h>

#define ARRAY_SIZE 10000000
#define ITERATIONS 10

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Standard vector addition
void vector_add_standard(float *a, float *b, float *c, size_t n) {
    for (size_t i = 0; i < n; i++) {
        c[i] = a[i] + b[i];
    }
}

// NEON vector addition (for Neoverse N1)
void vector_add_neon(float *a, float *b, float *c, size_t n) {
    size_t i = 0;
    
    // Process 4 elements at a time using NEON
    for (; i <= n - 4; i += 4) {
        float32x4_t va = vld1q_f32(&a[i]);
        float32x4_t vb = vld1q_f32(&b[i]);
        float32x4_t vc = vaddq_f32(va, vb);
        vst1q_f32(&c[i], vc);
    }
    
    // Process remaining elements
    for (; i < n; i++) {
        c[i] = a[i] + b[i];
    }
}

// SVE vector addition (for Neoverse V1/N2)
#if defined(__ARM_FEATURE_SVE)
void vector_add_sve(float *a, float *b, float *c, size_t n) {
    size_t i = 0;
    
    // Process elements using SVE
    for (; i < n; i += svcntw()) {
        svbool_t pg = svwhilelt_b32(i, n);
        svfloat32_t va = svld1(pg, &a[i]);
        svfloat32_t vb = svld1(pg, &b[i]);
        svfloat32_t vc = svadd_f32_z(pg, va, vb);
        svst1(pg, &c[i], vc);
    }
}
#endif

int main() {
    // Check for SVE support
    #if defined(__ARM_FEATURE_SVE)
    int sve_supported = 1;
    int vector_bits = svcntb() * 8;
    printf("SVE vector length: %d bits\n", vector_bits);
    #else
    int sve_supported = 0;
    printf("SVE not supported by compiler\n");
    #endif
    
    // Allocate arrays
    float *a = aligned_alloc(64, ARRAY_SIZE * sizeof(float));
    float *b = aligned_alloc(64, ARRAY_SIZE * sizeof(float));
    float *c1 = aligned_alloc(64, ARRAY_SIZE * sizeof(float));
    float *c2 = aligned_alloc(64, ARRAY_SIZE * sizeof(float));
    
    if (!a || !b || !c1 || !c2) {
        perror("Memory allocation failed");
        return 1;
    }
    
    // Initialize arrays
    for (int i = 0; i < ARRAY_SIZE; i++) {
        a[i] = (float)i / 1000.0f;
        b[i] = (float)i / 2000.0f;
    }
    
    // Benchmark standard vector addition
    double start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        vector_add_standard(a, b, c1, ARRAY_SIZE);
    }
    double end = get_time();
    double standard_time = end - start;
    
    printf("Standard vector add time: %.6f seconds\n", standard_time);
    
    // Benchmark NEON vector addition
    start = get_time();
    for (int i = 0; i < ITERATIONS; i++) {
        vector_add_neon(a, b, c2, ARRAY_SIZE);
    }
    end = get_time();
    double neon_time = end - start;
    
    printf("NEON vector add time: %.6f seconds\n", neon_time);
    printf("NEON speedup: %.2fx\n", standard_time / neon_time);
    
    // Benchmark SVE vector addition if supported
    #if defined(__ARM_FEATURE_SVE)
    if (sve_supported) {
        start = get_time();
        for (int i = 0; i < ITERATIONS; i++) {
            vector_add_sve(a, b, c2, ARRAY_SIZE);
        }
        end = get_time();
        double sve_time = end - start;
        
        printf("SVE vector add time: %.6f seconds\n", sve_time);
        printf("SVE speedup vs standard: %.2fx\n", standard_time / sve_time);
        printf("SVE speedup vs NEON: %.2fx\n", neon_time / sve_time);
    }
    #endif
    
    free(a);
    free(b);
    free(c1);
    free(c2);
    
    return 0;
}
```

### Step 4: Create Compilation Script for Different Neoverse Targets

Create a file named `compile_neoverse.sh` with the following content:

```bash
#!/bin/bash

echo "Compiling for Neoverse targets..."

# Detect CPU features
SVE_SUPPORT=$(./detect_features | grep "SVE support" | grep -c "Yes")
SVE2_SUPPORT=$(./detect_features | grep "SVE2 support" | grep -c "Yes")
NEOVERSE_MODEL=$(lscpu | grep -i neoverse | head -1)

echo "Detected: $NEOVERSE_MODEL"
echo "SVE support: $SVE_SUPPORT"
echo "SVE2 support: $SVE2_SUPPORT"

# Compile for appropriate Neoverse target
if [[ $NEOVERSE_MODEL == *"N1"* ]]; then
    echo "Compiling for Neoverse N1..."
    gcc -O3 -march=armv8.2-a+crypto+fp16+rcpc+dotprod neoverse_vector_benchmark.c -o neoverse_vector_benchmark
elif [[ $NEOVERSE_MODEL == *"N2"* ]]; then
    echo "Compiling for Neoverse N2..."
    gcc -O3 -march=armv8.5-a+sve2 neoverse_vector_benchmark.c -o neoverse_vector_benchmark
elif [[ $NEOVERSE_MODEL == *"V1"* ]]; then
    echo "Compiling for Neoverse V1..."
    gcc -O3 -march=armv8.4-a+sve neoverse_vector_benchmark.c -o neoverse_vector_benchmark
elif [[ $SVE2_SUPPORT -eq 1 ]]; then
    echo "Compiling with SVE2 support..."
    gcc -O3 -march=armv8.5-a+sve2 neoverse_vector_benchmark.c -o neoverse_vector_benchmark
elif [[ $SVE_SUPPORT -eq 1 ]]; then
    echo "Compiling with SVE support..."
    gcc -O3 -march=armv8.2-a+sve neoverse_vector_benchmark.c -o neoverse_vector_benchmark
else
    echo "Compiling with NEON only (generic Neoverse)..."
    gcc -O3 -march=armv8.2-a+crypto+fp16+rcpc+dotprod neoverse_vector_benchmark.c -o neoverse_vector_benchmark
fi

echo "Compilation complete."
```

Make the script executable:

```bash
chmod +x compile_neoverse.sh
```

### Step 5: Run the Benchmark

Execute the compilation and benchmark:

```bash
./compile_neoverse.sh
./neoverse_vector_benchmark
```

## Key Neoverse-specific Vector Optimization Techniques

1. **Neoverse N1 Optimizations (NEON-based)**:
   ```c
   // Optimize for 128-bit NEON vectors
   void optimize_for_n1(float *data, int size) {
       // Use NEON with careful loop unrolling (4x)
       for (int i = 0; i < size; i += 16) {
           float32x4_t v1 = vld1q_f32(&data[i]);
           float32x4_t v2 = vld1q_f32(&data[i+4]);
           float32x4_t v3 = vld1q_f32(&data[i+8]);
           float32x4_t v4 = vld1q_f32(&data[i+12]);
           
           // Process vectors...
           
           vst1q_f32(&data[i], v1);
           vst1q_f32(&data[i+4], v2);
           vst1q_f32(&data[i+8], v3);
           vst1q_f32(&data[i+12], v4);
       }
   }
   ```

2. **Neoverse V1/N2 Optimizations (SVE/SVE2)**:
   ```c
   // Optimize for scalable SVE vectors (typically 256-bit on Neoverse)
   void optimize_for_v1_n2(float *data, int size) {
       for (int i = 0; i < size; i += svcntw()) {
           svbool_t pg = svwhilelt_b32(i, size);
           svfloat32_t v = svld1(pg, &data[i]);
           
           // Process vector...
           
           svst1(pg, &data[i], v);
       }
   }
   ```

3. **Neoverse-specific Compiler Flags**:
   ```bash
   # Neoverse N1
   gcc -O3 -march=armv8.2-a+crypto+fp16+rcpc+dotprod
   
   # Neoverse V1
   gcc -O3 -march=armv8.4-a+sve
   
   # Neoverse N2
   gcc -O3 -march=armv8.5-a+sve2
   ```

4. **Runtime Feature Detection**:
   ```c
   #include <sys/auxv.h>
   
   void select_optimal_implementation() {
       unsigned long hwcap = getauxval(AT_HWCAP);
       unsigned long hwcap2 = getauxval(AT_HWCAP2);
       
       if (hwcap2 & HWCAP2_SVE2) {
           // Use SVE2 implementation (Neoverse N2)
       } else if (hwcap & HWCAP_SVE) {
           // Use SVE implementation (Neoverse V1)
       } else {
           // Use NEON implementation (Neoverse N1)
       }
   }
   ```

5. **Vector-Length Agnostic Programming**:
   ```c
   // Works efficiently regardless of SVE vector length
   void vector_length_agnostic(float *a, float *b, float *c, int size) {
       for (int i = 0; i < size; i += svcntw()) {
           svbool_t pg = svwhilelt_b32(i, size);
           svfloat32_t va = svld1(pg, &a[i]);
           svfloat32_t vb = svld1(pg, &b[i]);
           svfloat32_t vc = svadd_f32_z(pg, va, vb);
           svst1(pg, &c[i], vc);
       }
   }
   ```

These optimizations ensure your code runs efficiently across the entire Neoverse family, from N1 (NEON) to V1/N2 (SVE/SVE2), making it ideal for cloud computing environments.

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| NEON    | ✓           | ✓           | ✓           |
| SVE     | ✗           | ✓ (128-256 bit) | ✓ (128-256 bit) |
| SVE2    | ✗           | ✗           | ✓           |

The code in this chapter uses runtime detection to automatically select the best implementation:
- On Neoverse N1: Uses NEON implementation
- On Neoverse V1: Uses SVE implementation
- On Neoverse N2: Uses SVE2 implementation

## Further Reading

- [Arm Neoverse SVE and SVE2 documentation](https://developer.arm.com/documentation/102476/latest/)
- [Arm SVE Programming Examples](https://developer.arm.com/documentation/102340/latest/)
- [Arm C Language Extensions for SVE](https://developer.arm.com/documentation/100987/latest/)
- [Arm Neoverse V1 Technical Reference Manual](https://developer.arm.com/documentation/101427/latest/)
- [Arm Neoverse N2 Technical Reference Manual](https://developer.arm.com/documentation/101675/latest/)

## Compiler Optimizations for SVE/SVE2

To maximize the performance of SVE and SVE2 code on Neoverse processors, use these compiler optimizations:

```bash
# For Neoverse V1 (SVE)
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -mcpu=neoverse-v1 -ffast-math -ftree-vectorize sve_code.c -o sve_optimized

# For Neoverse N2 (SVE2)
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -mcpu=neoverse-n2 -ffast-math -ftree-vectorize sve2_code.c -o sve2_optimized

# For portable code with runtime detection
# See: ../2400_compiler_optimizations.md#link-time-optimization
gcc -O3 -march=armv8.2-a -ffast-math -ftree-vectorize -flto vector_code.c -o vector_optimized
```

### Optimization Trade-offs

| Optimization | Performance Impact | Compatibility | When to Use |
|--------------|-------------------|--------------|------------|
| `-mcpu=neoverse-xx` | High (+) | Specific to CPU | Production builds for known hardware |
| `-march=armv8.2-a` | Medium (+) | Works on all Neoverse | Portable binaries |
| `-ffast-math` | Medium (+) | May affect precision | When IEEE compliance isn't critical |
| `-ftree-vectorize` | High (+) | Safe | Always with -O2 or higher |
| `-flto` | High (+) | Increases build time | Final production builds |

For development and debugging, use `-O0 -g` to disable optimizations and preserve debug information.

## Relevance to Cloud Computing Workloads

Vector performance optimization is particularly important for cloud computing on Neoverse:

1. **High-Performance Computing**: Scientific simulations, weather modeling
2. **Machine Learning Inference**: Neural network operations
3. **Data Analytics**: Processing large datasets
4. **Database Acceleration**: Column-store operations, filtering
5. **Media Transcoding**: Video encoding/decoding at scale

Understanding Neoverse vector capabilities helps you:
- Write code that scales across different Neoverse implementations
- Maximize compute density in cloud environments
- Reduce power consumption for vector operations
- Optimize performance per watt for data center workloads