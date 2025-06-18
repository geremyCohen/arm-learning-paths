---
title: Large System Extensions (LSE) Atomics
weight: 1700

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding LSE Atomics

Large System Extensions (LSE) were introduced in Armv8.1-A to improve the performance of atomic operations in multi-core systems. Traditional atomic operations on Arm used load-exclusive/store-exclusive (LD/ST-EX) instruction pairs, which could lead to high contention and poor performance in large systems. LSE provides new atomic instructions that perform these operations more efficiently.

When comparing Intel/AMD (x86) versus Arm architectures, LSE brings Arm's atomic operation performance closer to x86's, which has long had efficient atomic instructions. This is particularly important for multi-threaded applications and synchronization primitives.

## Benchmarking Exercise: Comparing Atomic Operation Performance

In this exercise, we'll measure and compare the performance of atomic operations using traditional LD/ST-EX pairs versus LSE instructions on Arm Neoverse processors.

### Prerequisites

Ensure you have an Arm VM with:
- Arm (aarch64) with Armv8.1-A or newer (for LSE support)
- GCC or Clang compiler installed

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc g++
```

### Step 2: Create LSE Benchmark

Create a file named `lse_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>
#include <stdint.h>
#include <stdatomic.h>

#define NUM_THREADS 4
#define ITERATIONS 10000000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Thread argument structure
typedef struct {
    int thread_id;
    int num_iterations;
    _Atomic int *counter;
    int use_lse;
} thread_arg_t;

// Thread function for atomic increment
void* atomic_increment_thread(void* arg) {
    thread_arg_t* thread_arg = (thread_arg_t*)arg;
    _Atomic int *counter = thread_arg->counter;
    int iterations = thread_arg->num_iterations;
    
    if (thread_arg->use_lse) {
        // Use C11 atomics (will use LSE on supported hardware)
        for (int i = 0; i < iterations; i++) {
            atomic_fetch_add(counter, 1);
        }
    } else {
        // Use inline assembly with load-exclusive/store-exclusive
        for (int i = 0; i < iterations; i++) {
            int old_val, new_val;
            do {
                // Load exclusive
                __asm__ volatile("ldxr %w0, [%2]"
                                : "=&r" (old_val)
                                : "m" (*counter), "r" (counter)
                                : "memory");
                
                new_val = old_val + 1;
                
                // Store exclusive
                int store_result;
                __asm__ volatile("stxr %w0, %w1, [%3]"
                                : "=&r" (store_result), "=m" (*counter)
                                : "r" (new_val), "r" (counter)
                                : "memory");
                
                // If store failed, retry
            } while (store_result != 0);
        }
    }
    
    return NULL;
}

int main() {
    printf("CPU Architecture: %s\n", 
        #ifdef __aarch64__
        "aarch64"
        #else
        "other"
        #endif
    );
    
    // Check for LSE support
    #ifdef __ARM_FEATURE_ATOMICS
    printf("LSE Atomics: Supported by compiler\n");
    #else
    printf("LSE Atomics: Not supported by compiler\n");
    #endif
    
    // Allocate counters
    _Atomic int *counter_ldstex = (_Atomic int*)malloc(sizeof(_Atomic int));
    _Atomic int *counter_lse = (_Atomic int*)malloc(sizeof(_Atomic int));
    
    if (!counter_ldstex || !counter_lse) {
        perror("malloc");
        return 1;
    }
    
    *counter_ldstex = 0;
    *counter_lse = 0;
    
    // Create thread arguments
    thread_arg_t thread_args_ldstex[NUM_THREADS];
    thread_arg_t thread_args_lse[NUM_THREADS];
    pthread_t threads_ldstex[NUM_THREADS];
    pthread_t threads_lse[NUM_THREADS];
    
    // Benchmark LD/ST-EX
    printf("\nBenchmarking LD/ST-EX atomic operations...\n");
    double start = get_time();
    
    for (int i = 0; i < NUM_THREADS; i++) {
        thread_args_ldstex[i].thread_id = i;
        thread_args_ldstex[i].num_iterations = ITERATIONS / NUM_THREADS;
        thread_args_ldstex[i].counter = counter_ldstex;
        thread_args_ldstex[i].use_lse = 0;
        
        pthread_create(&threads_ldstex[i], NULL, atomic_increment_thread, &thread_args_ldstex[i]);
    }
    
    for (int i = 0; i < NUM_THREADS; i++) {
        pthread_join(threads_ldstex[i], NULL);
    }
    
    double end = get_time();
    double ldstex_time = end - start;
    
    printf("LD/ST-EX time: %.6f seconds\n", ldstex_time);
    printf("LD/ST-EX operations per second: %.2f million\n", 
           ITERATIONS / ldstex_time / 1000000);
    printf("Final counter value: %d\n", *counter_ldstex);
    
    // Benchmark LSE
    printf("\nBenchmarking LSE atomic operations...\n");
    start = get_time();
    
    for (int i = 0; i < NUM_THREADS; i++) {
        thread_args_lse[i].thread_id = i;
        thread_args_lse[i].num_iterations = ITERATIONS / NUM_THREADS;
        thread_args_lse[i].counter = counter_lse;
        thread_args_lse[i].use_lse = 1;
        
        pthread_create(&threads_lse[i], NULL, atomic_increment_thread, &thread_args_lse[i]);
    }
    
    for (int i = 0; i < NUM_THREADS; i++) {
        pthread_join(threads_lse[i], NULL);
    }
    
    end = get_time();
    double lse_time = end - start;
    
    printf("LSE time: %.6f seconds\n", lse_time);
    printf("LSE operations per second: %.2f million\n", 
           ITERATIONS / lse_time / 1000000);
    printf("Final counter value: %d\n", *counter_lse);
    
    // Calculate speedup
    printf("\nLSE speedup: %.2fx\n", ldstex_time / lse_time);
    
    free(counter_ldstex);
    free(counter_lse);
    
    return 0;
}
```

Compile with LSE support:

```bash
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -march=armv8.1-a+lse -pthread lse_benchmark.c -o lse_benchmark
```

### Step 3: Create Lock-Free Queue Benchmark

Create a file named `lockfree_queue_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>
#include <stdint.h>
#include <stdatomic.h>

#define QUEUE_SIZE 1000000
#define NUM_PRODUCERS 2
#define NUM_CONSUMERS 2
#define ITEMS_PER_PRODUCER 1000000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Lock-free queue structure
typedef struct {
    int *buffer;
    _Atomic int head;
    _Atomic int tail;
    int size;
} lockfree_queue_t;

// Initialize queue
void queue_init(lockfree_queue_t *queue, int size) {
    queue->buffer = (int*)malloc(size * sizeof(int));
    queue->head = 0;
    queue->tail = 0;
    queue->size = size;
}

// Enqueue item (producer)
int queue_enqueue(lockfree_queue_t *queue, int item) {
    int tail = atomic_load(&queue->tail);
    int next_tail = (tail + 1) % queue->size;
    
    if (next_tail == atomic_load(&queue->head)) {
        // Queue is full
        return 0;
    }
    
    queue->buffer[tail] = item;
    atomic_store(&queue->tail, next_tail);
    return 1;
}

// Dequeue item (consumer)
int queue_dequeue(lockfree_queue_t *queue, int *item) {
    int head = atomic_load(&queue->head);
    
    if (head == atomic_load(&queue->tail)) {
        // Queue is empty
        return 0;
    }
    
    *item = queue->buffer[head];
    atomic_store(&queue->head, (head + 1) % queue->size);
    return 1;
}

// Thread argument structure
typedef struct {
    int thread_id;
    lockfree_queue_t *queue;
    int num_items;
    _Atomic int *total;
} thread_arg_t;

// Producer thread function
void* producer_thread(void* arg) {
    thread_arg_t* thread_arg = (thread_arg_t*)arg;
    lockfree_queue_t *queue = thread_arg->queue;
    int num_items = thread_arg->num_items;
    
    for (int i = 0; i < num_items; i++) {
        int item = thread_arg->thread_id * num_items + i + 1;
        while (!queue_enqueue(queue, item)) {
            // Queue is full, retry
            pthread_yield();
        }
    }
    
    return NULL;
}

// Consumer thread function
void* consumer_thread(void* arg) {
    thread_arg_t* thread_arg = (thread_arg_t*)arg;
    lockfree_queue_t *queue = thread_arg->queue;
    int num_items = thread_arg->num_items;
    _Atomic int *total = thread_arg->total;
    
    for (int i = 0; i < num_items; i++) {
        int item;
        while (!queue_dequeue(queue, &item)) {
            // Queue is empty, retry
            pthread_yield();
        }
        atomic_fetch_add(total, item);
    }
    
    return NULL;
}

int main() {
    printf("CPU Architecture: %s\n", 
        #ifdef __aarch64__
        "aarch64"
        #else
        "other"
        #endif
    );
    
    // Check for LSE support
    #ifdef __ARM_FEATURE_ATOMICS
    printf("LSE Atomics: Supported by compiler\n");
    #else
    printf("LSE Atomics: Not supported by compiler\n");
    #endif
    
    // Initialize queue
    lockfree_queue_t queue;
    queue_init(&queue, QUEUE_SIZE);
    
    // Initialize total
    _Atomic int total = 0;
    
    // Create thread arguments
    thread_arg_t producer_args[NUM_PRODUCERS];
    thread_arg_t consumer_args[NUM_CONSUMERS];
    pthread_t producer_threads[NUM_PRODUCERS];
    pthread_t consumer_threads[NUM_CONSUMERS];
    
    // Calculate items per consumer
    int items_per_consumer = (ITEMS_PER_PRODUCER * NUM_PRODUCERS) / NUM_CONSUMERS;
    
    printf("\nBenchmarking lock-free queue with %d producers and %d consumers...\n", 
           NUM_PRODUCERS, NUM_CONSUMERS);
    printf("Each producer will enqueue %d items\n", ITEMS_PER_PRODUCER);
    printf("Each consumer will dequeue %d items\n", items_per_consumer);
    
    double start = get_time();
    
    // Start consumer threads
    for (int i = 0; i < NUM_CONSUMERS; i++) {
        consumer_args[i].thread_id = i;
        consumer_args[i].queue = &queue;
        consumer_args[i].num_items = items_per_consumer;
        consumer_args[i].total = &total;
        
        pthread_create(&consumer_threads[i], NULL, consumer_thread, &consumer_args[i]);
    }
    
    // Start producer threads
    for (int i = 0; i < NUM_PRODUCERS; i++) {
        producer_args[i].thread_id = i;
        producer_args[i].queue = &queue;
        producer_args[i].num_items = ITEMS_PER_PRODUCER;
        producer_args[i].total = &total;
        
        pthread_create(&producer_threads[i], NULL, producer_thread, &producer_args[i]);
    }
    
    // Wait for producer threads to complete
    for (int i = 0; i < NUM_PRODUCERS; i++) {
        pthread_join(producer_threads[i], NULL);
    }
    
    // Wait for consumer threads to complete
    for (int i = 0; i < NUM_CONSUMERS; i++) {
        pthread_join(consumer_threads[i], NULL);
    }
    
    double end = get_time();
    double elapsed = end - start;
    
    printf("Total time: %.6f seconds\n", elapsed);
    printf("Operations per second: %.2f million\n", 
           (ITEMS_PER_PRODUCER * NUM_PRODUCERS * 2) / elapsed / 1000000);
    printf("Final total: %d\n", total);
    
    // Calculate expected total
    int expected_total = 0;
    for (int i = 0; i < NUM_PRODUCERS; i++) {
        for (int j = 0; j < ITEMS_PER_PRODUCER; j++) {
            expected_total += i * ITEMS_PER_PRODUCER + j + 1;
        }
    }
    printf("Expected total: %d\n", expected_total);
    
    free(queue.buffer);
    
    return 0;
}
```

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

```c
// High contention approach
void increment_counter(_Atomic int *counter) {
    for (int i = 0; i < 100; i++) {
        atomic_fetch_add(counter, 1);
    }
}

// Batched approach with lower contention
void batched_increment(_Atomic int *counter) {
    // Do local work first
    int local_sum = 0;
    for (int i = 0; i < 100; i++) {
        local_sum++;
    }
    
    // Single atomic update
    atomic_fetch_add(counter, local_sum);
}
```

### 3. Lock-Free Ring Buffer with LSE

Implement an efficient lock-free ring buffer using LSE:

```c
#include <stdatomic.h>

typedef struct {
    void *buffer[BUFFER_SIZE];
    _Atomic unsigned head;
    _Atomic unsigned tail;
} ring_buffer_t;

// Initialize ring buffer
void ring_buffer_init(ring_buffer_t *rb) {
    atomic_store(&rb->head, 0);
    atomic_store(&rb->tail, 0);
}

// Enqueue item (non-blocking)
int ring_buffer_enqueue(ring_buffer_t *rb, void *item) {
    unsigned tail = atomic_load(&rb->tail);
    unsigned next_tail = (tail + 1) % BUFFER_SIZE;
    
    // Check if buffer is full
    if (next_tail == atomic_load(&rb->head)) {
        return 0;  // Buffer full
    }
    
    // Store item
    rb->buffer[tail] = item;
    
    // Update tail with release semantics
    atomic_store_explicit(&rb->tail, next_tail, memory_order_release);
    return 1;
}

// Dequeue item (non-blocking)
int ring_buffer_dequeue(ring_buffer_t *rb, void **item) {
    unsigned head = atomic_load(&rb->head);
    
    // Check if buffer is empty
    if (head == atomic_load(&rb->tail)) {
        return 0;  // Buffer empty
    }
    
    // Get item
    *item = rb->buffer[head];
    
    // Update head with release semantics
    atomic_store_explicit(&rb->head, (head + 1) % BUFFER_SIZE, memory_order_release);
    return 1;
}
```

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