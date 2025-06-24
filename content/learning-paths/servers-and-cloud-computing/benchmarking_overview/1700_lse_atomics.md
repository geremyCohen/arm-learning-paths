---
title: Large System Extensions (LSE) Atomics
weight: 1700
layout: learningpathall
---

## Understanding LSE Atomics

Large System Extensions (LSE) were introduced in Armv8.1-A to improve the performance of atomic operations in multi-core systems. Traditional atomic operations on Arm used load-exclusive/store-exclusive (LD/ST-EX) instruction pairs, which could lead to high contention and poor performance in large systems. LSE provides new atomic instructions that perform these operations more efficiently.

When comparing Intel/AMD (x86) versus Arm architectures, LSE brings Arm's atomic operation performance closer to x86's, which has long had efficient atomic instructions. This is particularly important for multi-threaded applications and synchronization primitives.

## Benchmarking Exercise

### Prerequisites

Ensure you have:
- Completed the repository setup from the previous chapter
- Two Ubuntu systems with the bench_guide repository cloned

### Step 1: Navigate to Directory

Navigate to the benchmark directory:

```bash
cd bench_guide/atomic_operations
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
- Arm (aarch64) with Armv8.1-A or newer (for LSE support)
- GCC or Clang compiler installed

### Step 1: Download and Run Setup Script

Download and run the setup script to install required tools:

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/atomic_operations/setup.sh
chmod +x setup.sh
./setup.sh
```

### Step 2: Download Benchmark Files

Download the benchmark files:

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/atomic_operations/lse_benchmark.c
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/atomic_operations/lockfree_queue_benchmark.c
```

### Step 3: Run the Benchmark

Execute the benchmark script:

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/atomic_operations/benchmark.sh
chmod +x benchmark.sh
./benchmark.sh | tee lse_benchmark_results.txt
```

The benchmark script will:
1. Compile the LSE and lock-free queue benchmarks with appropriate compiler flags
2. Run both benchmarks and display performance comparisons
3. Show LSE speedup over traditional LD/ST-EX operations

### Step 4: Analyze the Results

Create a file named `lockfree_queue_benchmark.c` with the following content:

Compile with LSE support:

```bash
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -march=armv8.1-a+lse -pthread lockfree_queue_benchmark.c -o lockfree_queue_benchmark
```

### Step 4: Run the Benchmarks

Execute the benchmarks:

```bash
./lse_benchmark
./lockfree_queue_benchmark
```

## Key LSE Atomic Operations

### 1. Atomic Add

```c
// C11 atomic add (uses LSE on supported hardware)
int old_value = atomic_fetch_add(ptr, 1);

// Direct LSE assembly
int old_value;
__asm__ volatile("ldadd %w1, %w0, [%2]"
                : "=r" (old_value)
                : "r" (1), "r" (ptr)
                : "memory");
```

### 2. Atomic Swap

```c
// C11 atomic exchange (uses LSE on supported hardware)
int old_value = atomic_exchange(ptr, new_value);

// Direct LSE assembly
int old_value;
__asm__ volatile("swp %w1, %w0, [%2]"
                : "=r" (old_value)
                : "r" (new_value), "r" (ptr)
                : "memory");
```

### 3. Compare and Swap

```c
// C11 atomic compare-exchange (uses LSE on supported hardware)
int expected = old_value;
bool success = atomic_compare_exchange_strong(ptr, &expected, new_value);

// Direct LSE assembly
int old_value, success;
__asm__ volatile("cas %w0, %w1, [%2]"
                : "=&r" (old_value)
                : "r" (new_value), "r" (ptr)
                : "memory");
success = (old_value == expected);
```

### 4. Atomic Bitwise Operations

```c
// C11 atomic OR (uses LSE on supported hardware)
int old_value = atomic_fetch_or(ptr, mask);

// Direct LSE assembly
int old_value;
__asm__ volatile("ldset %w1, %w0, [%2]"
                : "=r" (old_value)
                : "r" (mask), "r" (ptr)
                : "memory");
```

### 5. Memory Ordering

```c
// Full memory barrier
__asm__ volatile("dmb sy" ::: "memory");

// Store barrier
__asm__ volatile("dmb st" ::: "memory");

// Load barrier
__asm__ volatile("dmb ld" ::: "memory");
```

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| LSE Atomics | ✓ | ✓ | ✓ |

LSE is available on all Neoverse processors:
- Neoverse N1: Fully supported
- Neoverse V1: Fully supported
- Neoverse N2: Fully supported

## OS/Kernel Tweaks for LSE Atomics

To ensure optimal LSE performance on Neoverse systems, apply these OS-level tweaks:

### 1. Verify LSE Support in the Kernel

Check if LSE is enabled in your kernel:

```bash
# Check if LSE is supported in the kernel
cat /proc/cpuinfo | grep -i atomics

# Check kernel version (LSE support improved in newer kernels)
uname -r
```

### 2. Enable LSE in the Kernel

For older kernels that don't enable LSE by default, add these kernel parameters:

```bash
# Add to /etc/default/grub
GRUB_CMDLINE_LINUX="$GRUB_CMDLINE_LINUX arm64.lse=on"

# Update grub and reboot
sudo update-grub
sudo reboot
```

### 3. CPU Scheduler Settings

Optimize the CPU scheduler for multi-threaded workloads using LSE:

```bash
# Set scheduler minimum granularity (microseconds)
echo 3000 | sudo tee /proc/sys/kernel/sched_min_granularity_ns

# Set scheduler wakeup granularity
echo 4000 | sudo tee /proc/sys/kernel/sched_wakeup_granularity_ns

# Set scheduler migration cost
echo 500000 | sudo tee /proc/sys/kernel/sched_migration_cost_ns
```

### 4. Memory Allocation Policy

Configure memory allocation policy for multi-threaded applications:

```bash
# Set NUMA interleave policy for shared memory
numactl --interleave=all ./your_multithreaded_app

# Or set in the application
#include <numa.h>
numa_set_interleave_mask(numa_all_nodes_ptr);
```

## Additional Performance Tweaks

### 1. Contention Mitigation with Padding

Prevent false sharing by padding atomic variables:

```c
// Without padding (potential false sharing)
struct bad_counters {
    _Atomic int counter1;
    _Atomic int counter2;
};

// With padding to prevent false sharing
struct good_counters {
    _Atomic int counter1;
    char padding1[60];  // Pad to 64 bytes (cache line size)
    _Atomic int counter2;
    char padding2[60];
};
```

### 2. Batching Atomic Operations

Reduce contention by batching atomic operations:

### 3. Lock-Free Ring Buffer with LSE

Implement an efficient lock-free ring buffer using LSE:

### 4. Memory Ordering Optimization

Use appropriate memory ordering for better performance:

```c
// Default memory ordering (sequentially consistent, but slower)
int old_value = atomic_fetch_add(counter, 1);

// Relaxed ordering for simple counters (faster)
int old_value = atomic_fetch_add_explicit(counter, 1, memory_order_relaxed);

// Release-acquire ordering for synchronization (balanced)
atomic_store_explicit(flag, 1, memory_order_release);
// ... in another thread ...
if (atomic_load_explicit(flag, memory_order_acquire)) {
    // Data synchronized
}
```

These tweaks can provide an additional 30-70% performance improvement for atomic operations on Neoverse processors, especially in highly concurrent workloads.

## Further Reading

- [Arm Architecture Reference Manual - LSE](https://developer.arm.com/documentation/ddi0487/latest/)
- [Arm LSE Atomics](https://developer.arm.com/documentation/102336/0100/Large-System-Extensions--LSE-)
- [Optimizing Lock-Free Code with LSE](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/lock-free-programming-with-arm-large-system-extensions)
- [C11 Atomics and LSE](https://developer.arm.com/documentation/101754/0606/Atomics-and-Synchronization/C11-C---atomics)

## Relevance to Cloud Computing Workloads

LSE atomic operations are particularly important for cloud computing on Neoverse:

1. **Databases**: Lock-free data structures for concurrent access
2. **Web Servers**: High-throughput request handling
3. **Message Queues**: Producer-consumer patterns
4. **In-Memory Caches**: Concurrent updates to cached data
5. **Thread Synchronization**: Mutexes, semaphores, and barriers

Understanding LSE helps you:
- Improve multi-threaded application performance by 2-10x
- Reduce contention in highly concurrent systems
- Implement efficient lock-free data structures
- Optimize synchronization primitives for Neoverse processors