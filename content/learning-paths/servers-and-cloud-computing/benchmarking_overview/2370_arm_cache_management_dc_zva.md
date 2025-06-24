---
title: Data Cache Zero by VA (DC ZVA)
weight: 2371
layout: learningpathall
---

## Understanding Data Cache Zero by VA (DC ZVA)

The Data Cache Zero by Virtual Address (DC ZVA) instruction is a powerful optimization available in Arm architectures that allows zeroing an entire cache line (typically 64 bytes) with a single instruction. This can significantly improve performance for memory clearing operations, which are common in many applications.

When comparing Intel/AMD (x86) versus Arm architectures, DC ZVA provides a unique advantage for Arm in terms of memory zeroing efficiency. While x86 has optimized instructions like `REP STOSB`, DC ZVA operates directly at the cache line level, providing better performance and reduced memory traffic.

## Benchmarking Exercise

### Prerequisites

Ensure you have:
- Completed the repository setup from the previous chapter
- ARM (aarch64) system with the bench_guide repository cloned

### Step 1: Navigate to Directory

Navigate to the benchmark directory:

```bash
cd bench_guide/arm_cache_management
```

### Step 2: Install Dependencies

Run the setup script:

```bash
./setup.sh
```

### Step 3: Run the Benchmark

Execute the benchmark:

```bash
./benchmark.sh
```

### Step 4: Analyze the Results

Ensure you have an Arm VM with:
- Arm (aarch64) with Neoverse processors
- GCC or Clang compiler installed

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc
```

### Step 3: Run the Benchmark

Execute the benchmark:

```bash
./dc_zva_benchmark
```

## Practical DC ZVA Implementation

### 1. Optimized Memory Zeroing Function

Create a file named `optimized_memzero.c`:

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

### 2. Multi-threaded DC ZVA for Very Large Buffers

Parallelize DC ZVA operations for gigabyte-scale buffers:

### 3. Custom Memory Allocator with DC ZVA

Implement a custom allocator that efficiently uses DC ZVA for zeroing:

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