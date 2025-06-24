---
title: SVE2 Vector Performance for Neoverse
weight: 1650
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
// Code moved to external repository
// See benchmark files in bench_guide repository
```

Compile and run:

```bash
gcc -march=armv8.2-a detect_features.c -o detect_features
./detect_features
```

### Step 3: Create SVE2/NEON Vector Benchmark

Create a file named `neoverse_vector_benchmark.c` with the following content:

```c
// Code moved to external repository
// See benchmark files in bench_guide repository
```

### Step 4: Create Compilation Script for Different Neoverse Targets

Create a file named `compile_neoverse.sh` with the following content:

```bash
// Code moved to external repository
// See benchmark files in bench_guide repository
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
// Code moved to external repository
// See benchmark files in bench_guide repository
```

2. **Neoverse V1/N2 Optimizations (SVE/SVE2)**:
   

3. **Neoverse-specific Compiler Flags**:
   

4. **Runtime Feature Detection**:
   

5. **Vector-Length Agnostic Programming**:
   

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

## OS/Kernel Tweaks for SVE/SVE2

To maximize SVE/SVE2 performance on Neoverse, apply these OS-level tweaks:

### 1. Enable SVE in the Kernel

Check if SVE is enabled in your kernel:

```bash
# Check if SVE is supported in the kernel
cat /proc/cpuinfo | grep -i sve

# Check SVE vector length
cat /proc/sys/abi/sve_default_vector_length
```

If SVE is supported but not enabled, you can enable it by adding kernel parameters:

```bash
# Add to /etc/default/grub
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX sve=on sve_default_vector_length=256"

# Update grub and reboot
sudo update-grub
sudo reboot
```

### 2. Set Process SVE Vector Length

You can set the SVE vector length for a specific process:

```bash
# Set SVE vector length to 256 bits for a process
sudo prctl --sve-set-vl 256 --pid <PID>

# Run a command with specific SVE vector length
sudo prctl --sve-set-vl 256 -- ./your_sve_program
```

### 3. CPU Frequency Governor

Set the CPU governor to performance mode for maximum SVE throughput:

```bash
# Set all CPUs to performance mode
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" | sudo tee $cpu
done
```

## Additional Performance Tweaks

### 1. Loop Unrolling for SVE

Unroll loops to better utilize SVE/SVE2 instructions:

```c
// Code moved to external repository
// See benchmark files in bench_guide repository
```

### 2. Memory Alignment for SVE

Align data to improve SVE load/store performance:

```c
// Allocate aligned memory
float *a = (float *)aligned_alloc(64, size * sizeof(float));

// Or use posix_memalign
float *a;
posix_memalign((void**)&a, 64, size * sizeof(float));
```

### 3. Prefetching with SVE

Add prefetch hints to improve memory access patterns:

These tweaks can provide an additional 10-30% performance improvement for SVE/SVE2 workloads on Neoverse processors.

## Further Reading

- [Arm Neoverse SVE and SVE2 documentation](https://developer.arm.com/documentation/102476/latest/)
- [Arm SVE Programming Examples](https://developer.arm.com/documentation/102340/latest/)
- [Arm C Language Extensions for SVE](https://developer.arm.com/documentation/100987/latest/)
- [Arm Neoverse V1 Technical Reference Manual](https://developer.arm.com/documentation/101427/latest/)
- [Arm Neoverse N2 Technical Reference Manual](https://developer.arm.com/documentation/101675/latest/)

## Compiler Optimizations for SVE/SVE2

To maximize the performance of SVE and SVE2 code on Neoverse processors, use these compiler optimizations:

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