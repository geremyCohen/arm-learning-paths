---
title: Atomic Operations and Lock-Free Programming
weight: 1700

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Atomic Operations and Lock-Free Programming

Atomic operations are indivisible operations that complete in a single step from the perspective of other threads. They are fundamental building blocks for synchronization in concurrent programming, enabling lock-free and wait-free algorithms that can significantly improve performance in multi-threaded applications.

When comparing Intel/AMD (x86) versus Arm architectures, atomic operation implementations can differ significantly due to variations in memory consistency models, hardware support for atomic instructions, and the efficiency of memory barriers. These differences can have substantial performance implications for highly concurrent applications.

For more detailed information about atomic operations and lock-free programming, you can refer to:
- [C++ Atomic Operations Library](https://en.cppreference.com/w/cpp/atomic)
- [Memory Consistency Models](https://www.cs.utexas.edu/~bornholt/post/memory-models.html)
- [Lock-Free Programming Techniques](https://www.cs.cmu.edu/~410-f10/doc/Lock-Free.pdf)

## Benchmarking Exercise: Comparing Atomic Operation Performance

In this exercise, we'll measure and compare the performance of various atomic operations across Intel/AMD and Arm architectures.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential g++ python3-matplotlib
```

### Step 2: Create Atomic Operations Benchmark

Create a file named `atomic_benchmark.cpp` with the following content:

```cpp
#include <iostream>
#include <vector>
#include <atomic>
#include <thread>
#include <chrono>
#include <cstring>

// Function to measure time
double get_time() {
    auto now = std::chrono::high_resolution_clock::now();
    auto duration = now.time_since_epoch();
    return std::chrono::duration_cast<std::chrono::nanoseconds>(duration).count() * 1e-9;
}

// Benchmark for atomic load
void benchmark_atomic_load(int num_threads, int operations_per_thread) {
    std::atomic<int> atomic_var(0);
    std::vector<std::thread> threads;
    std::atomic<int> ready_count(0);
    std::atomic<bool> start_flag(false);
    
    for (int t = 0; t < num_threads; ++t) {
        threads.emplace_back([&, t]() {
            // Signal ready and wait for start
            ready_count.fetch_add(1);
            while (!start_flag.load(std::memory_order_relaxed)) {
                // Spin wait
            }
            
            // Perform atomic loads
            int result = 0;
            for (int i = 0; i < operations_per_thread; ++i) {
                result += atomic_var.load(std::memory_order_relaxed);
            }
            
            // Prevent optimization
            if (result == -1) {
                std::cout << "This should never happen" << std::endl;
            }
        });
    }
    
    // Wait for all threads to be ready
    while (ready_count.load() < num_threads) {
        // Spin wait
    }
    
    // Start the benchmark
    double start_time = get_time();
    start_flag.store(true, std::memory_order_relaxed);
    
    // Wait for all threads to finish
    for (auto& thread : threads) {
        thread.join();
    }
    double end_time = get_time();
    
    double elapsed = end_time - start_time;
    double operations_per_second = (double)num_threads * operations_per_thread / elapsed;
    double ns_per_operation = elapsed * 1e9 / (num_threads * operations_per_thread);
    
    std::cout << "Atomic Load:" << std::endl;
    std::cout << "  Threads: " << num_threads << std::endl;
    std::cout << "  Operations per thread: " << operations_per_thread << std::endl;
    std::cout << "  Time: " << elapsed << " seconds" << std::endl;
    std::cout << "  Operations per second: " << operations_per_second / 1e6 << " million" << std::endl;
    std::cout << "  Time per operation: " << ns_per_operation << " ns" << std::endl;
    std::cout << std::endl;
}

// Benchmark for atomic store
void benchmark_atomic_store(int num_threads, int operations_per_thread) {
    std::atomic<int> atomic_var(0);
    std::vector<std::thread> threads;
    std::atomic<int> ready_count(0);
    std::atomic<bool> start_flag(false);
    
    for (int t = 0; t < num_threads; ++t) {
        threads.emplace_back([&, t]() {
            // Signal ready and wait for start
            ready_count.fetch_add(1);
            while (!start_flag.load(std::memory_order_relaxed)) {
                // Spin wait
            }
            
            // Perform atomic stores
            for (int i = 0; i < operations_per_thread; ++i) {
                atomic_var.store(i, std::memory_order_relaxed);
            }
        });
    }
    
    // Wait for all threads to be ready
    while (ready_count.load() < num_threads) {
        // Spin wait
    }
    
    // Start the benchmark
    double start_time = get_time();
    start_flag.store(true, std::memory_order_relaxed);
    
    // Wait for all threads to finish
    for (auto& thread : threads) {
        thread.join();
    }
    double end_time = get_time();
    
    double elapsed = end_time - start_time;
    double operations_per_second = (double)num_threads * operations_per_thread / elapsed;
    double ns_per_operation = elapsed * 1e9 / (num_threads * operations_per_thread);
    
    std::cout << "Atomic Store:" << std::endl;
    std::cout << "  Threads: " << num_threads << std::endl;
    std::cout << "  Operations per thread: " << operations_per_thread << std::endl;
    std::cout << "  Time: " << elapsed << " seconds" << std::endl;
    std::cout << "  Operations per second: " << operations_per_second / 1e6 << " million" << std::endl;
    std::cout << "  Time per operation: " << ns_per_operation << " ns" << std::endl;
    std::cout << std::endl;
}

// Benchmark for atomic fetch_add
void benchmark_atomic_fetch_add(int num_threads, int operations_per_thread) {
    std::atomic<int> atomic_var(0);
    std::vector<std::thread> threads;
    std::atomic<int> ready_count(0);
    std::atomic<bool> start_flag(false);
    
    for (int t = 0; t < num_threads; ++t) {
        threads.emplace_back([&, t]() {
            // Signal ready and wait for start
            ready_count.fetch_add(1);
            while (!start_flag.load(std::memory_order_relaxed)) {
                // Spin wait
            }
            
            // Perform atomic fetch_add
            for (int i = 0; i < operations_per_thread; ++i) {
                atomic_var.fetch_add(1, std::memory_order_relaxed);
            }
        });
    }
    
    // Wait for all threads to be ready
    while (ready_count.load() < num_threads) {
        // Spin wait
    }
    
    // Start the benchmark
    double start_time = get_time();
    start_flag.store(true, std::memory_order_relaxed);
    
    // Wait for all threads to finish
    for (auto& thread : threads) {
        thread.join();
    }
    double end_time = get_time();
    
    double elapsed = end_time - start_time;
    double operations_per_second = (double)num_threads * operations_per_thread / elapsed;
    double ns_per_operation = elapsed * 1e9 / (num_threads * operations_per_thread);
    
    std::cout << "Atomic Fetch Add:" << std::endl;
    std::cout << "  Threads: " << num_threads << std::endl;
    std::cout << "  Operations per thread: " << operations_per_thread << std::endl;
    std::cout << "  Time: " << elapsed << " seconds" << std::endl;
    std::cout << "  Operations per second: " << operations_per_second / 1e6 << " million" << std::endl;
    std::cout << "  Time per operation: " << ns_per_operation << " ns" << std::endl;
    std::cout << "  Final value: " << atomic_var.load() << std::endl;
    std::cout << std::endl;
}

// Benchmark for compare_exchange_weak
void benchmark_atomic_cas(int num_threads, int operations_per_thread) {
    std::atomic<int> atomic_var(0);
    std::vector<std::thread> threads;
    std::atomic<int> ready_count(0);
    std::atomic<bool> start_flag(false);
    
    for (int t = 0; t < num_threads; ++t) {
        threads.emplace_back([&, t]() {
            // Signal ready and wait for start
            ready_count.fetch_add(1);
            while (!start_flag.load(std::memory_order_relaxed)) {
                // Spin wait
            }
            
            // Perform atomic compare_exchange_weak
            for (int i = 0; i < operations_per_thread; ++i) {
                int expected = atomic_var.load(std::memory_order_relaxed);
                while (!atomic_var.compare_exchange_weak(expected, expected + 1, 
                                                        std::memory_order_relaxed)) {
                    // Retry on failure
                }
            }
        });
    }
    
    // Wait for all threads to be ready
    while (ready_count.load() < num_threads) {
        // Spin wait
    }
    
    // Start the benchmark
    double start_time = get_time();
    start_flag.store(true, std::memory_order_relaxed);
    
    // Wait for all threads to finish
    for (auto& thread : threads) {
        thread.join();
    }
    double end_time = get_time();
    
    double elapsed = end_time - start_time;
    double operations_per_second = (double)num_threads * operations_per_thread / elapsed;
    double ns_per_operation = elapsed * 1e9 / (num_threads * operations_per_thread);
    
    std::cout << "Atomic Compare-and-Swap:" << std::endl;
    std::cout << "  Threads: " << num_threads << std::endl;
    std::cout << "  Operations per thread: " << operations_per_thread << std::endl;
    std::cout << "  Time: " << elapsed << " seconds" << std::endl;
    std::cout << "  Operations per second: " << operations_per_second / 1e6 << " million" << std::endl;
    std::cout << "  Time per operation: " << ns_per_operation << " ns" << std::endl;
    std::cout << "  Final value: " << atomic_var.load() << std::endl;
    std::cout << std::endl;
}

int main(int argc, char* argv[]) {
    int test_type = 0;
    int num_threads = 4;
    int operations_per_thread = 10000000;
    
    if (argc > 1) test_type = std::atoi(argv[1]);
    if (argc > 2) num_threads = std::atoi(argv[2]);
    if (argc > 3) operations_per_thread = std::atoi(argv[3]);
    
    std::cout << "CPU Architecture: " << 
        #ifdef __x86_64__
        "x86_64"
        #elif defined(__aarch64__)
        "aarch64"
        #else
        "unknown"
        #endif
        << std::endl;
    
    std::cout << "Number of hardware threads: " << std::thread::hardware_concurrency() << std::endl;
    std::cout << std::endl;
    
    switch (test_type) {
        case 0:
            benchmark_atomic_load(num_threads, operations_per_thread);
            break;
        case 1:
            benchmark_atomic_store(num_threads, operations_per_thread);
            break;
        case 2:
            benchmark_atomic_fetch_add(num_threads, operations_per_thread);
            break;
        case 3:
            benchmark_atomic_cas(num_threads, operations_per_thread);
            break;
        default:
            std::cout << "Running all tests" << std::endl;
            benchmark_atomic_load(num_threads, operations_per_thread);
            benchmark_atomic_store(num_threads, operations_per_thread);
            benchmark_atomic_fetch_add(num_threads, operations_per_thread);
            benchmark_atomic_cas(num_threads, operations_per_thread);
    }
    
    return 0;
}
```

### Step 3: Create Lock-Free Queue Benchmark

Create a file named `lockfree_queue.cpp` with the following content:

```cpp
#include <iostream>
#include <vector>
#include <atomic>
#include <thread>
#include <chrono>
#include <cstring>

// Function to measure time
double get_time() {
    auto now = std::chrono::high_resolution_clock::now();
    auto duration = now.time_since_epoch();
    return std::chrono::duration_cast<std::chrono::nanoseconds>(duration).count() * 1e-9;
}

// Simple lock-free queue implementation
template<typename T>
class LockFreeQueue {
private:
    struct Node {
        T data;
        std::atomic<Node*> next;
        
        Node(const T& value) : data(value), next(nullptr) {}
    };
    
    std::atomic<Node*> head;
    std::atomic<Node*> tail;
    
public:
    LockFreeQueue() {
        Node* dummy = new Node(T());
        head.store(dummy);
        tail.store(dummy);
    }
    
    ~LockFreeQueue() {
        while (Node* node = head.load()) {
            head.store(node->next);
            delete node;
        }
    }
    
    void enqueue(const T& value) {
        Node* new_node = new Node(value);
        Node* old_tail;
        
        while (true) {
            old_tail = tail.load();
            Node* next = old_tail->next.load();
            
            if (old_tail == tail.load()) {
                if (next == nullptr) {
                    if (old_tail->next.compare_exchange_weak(next, new_node)) {
                        break;
                    }
                } else {
                    tail.compare_exchange_weak(old_tail, next);
                }
            }
        }
        
        tail.compare_exchange_weak(old_tail, new_node);
    }
    
    bool dequeue(T& result) {
        Node* old_head;
        
        while (true) {
            old_head = head.load();
            Node* old_tail = tail.load();
            Node* next = old_head->next.load();
            
            if (old_head == head.load()) {
                if (old_head == old_tail) {
                    if (next == nullptr) {
                        return false;  // Queue is empty
                    }
                    tail.compare_exchange_weak(old_tail, next);
                } else {
                    result = next->data;
                    if (head.compare_exchange_weak(old_head, next)) {
                        break;
                    }
                }
            }
        }
        
        delete old_head;
        return true;
    }
};

// Benchmark for lock-free queue
void benchmark_lockfree_queue(int num_producers, int num_consumers, int operations_per_producer) {
    LockFreeQueue<int> queue;
    std::vector<std::thread> threads;
    std::atomic<int> ready_count(0);
    std::atomic<bool> start_flag(false);
    std::atomic<int> consumed_count(0);
    
    // Create producer threads
    for (int t = 0; t < num_producers; ++t) {
        threads.emplace_back([&, t]() {
            // Signal ready and wait for start
            ready_count.fetch_add(1);
            while (!start_flag.load(std::memory_order_relaxed)) {
                // Spin wait
            }
            
            // Produce items
            for (int i = 0; i < operations_per_producer; ++i) {
                queue.enqueue(i);
            }
        });
    }
    
    // Create consumer threads
    for (int t = 0; t < num_consumers; ++t) {
        threads.emplace_back([&, t]() {
            // Signal ready and wait for start
            ready_count.fetch_add(1);
            while (!start_flag.load(std::memory_order_relaxed)) {
                // Spin wait
            }
            
            // Consume items
            int result;
            while (consumed_count.load() < num_producers * operations_per_producer) {
                if (queue.dequeue(result)) {
                    consumed_count.fetch_add(1);
                }
            }
        });
    }
    
    // Wait for all threads to be ready
    while (ready_count.load() < num_producers + num_consumers) {
        // Spin wait
    }
    
    // Start the benchmark
    double start_time = get_time();
    start_flag.store(true, std::memory_order_relaxed);
    
    // Wait for all threads to finish
    for (auto& thread : threads) {
        thread.join();
    }
    double end_time = get_time();
    
    double elapsed = end_time - start_time;
    double operations_per_second = (double)num_producers * operations_per_producer / elapsed;
    double ns_per_operation = elapsed * 1e9 / (num_producers * operations_per_producer);
    
    std::cout << "Lock-Free Queue:" << std::endl;
    std::cout << "  Producers: " << num_producers << std::endl;
    std::cout << "  Consumers: " << num_consumers << std::endl;
    std::cout << "  Operations per producer: " << operations_per_producer << std::endl;
    std::cout << "  Time: " << elapsed << " seconds" << std::endl;
    std::cout << "  Operations per second: " << operations_per_second / 1e6 << " million" << std::endl;
    std::cout << "  Time per operation: " << ns_per_operation << " ns" << std::endl;
    std::cout << "  Items consumed: " << consumed_count.load() << std::endl;
    std::cout << std::endl;
}

int main(int argc, char* argv[]) {
    int num_producers = 2;
    int num_consumers = 2;
    int operations_per_producer = 1000000;
    
    if (argc > 1) num_producers = std::atoi(argv[1]);
    if (argc > 2) num_consumers = std::atoi(argv[2]);
    if (argc > 3) operations_per_producer = std::atoi(argv[3]);
    
    std::cout << "CPU Architecture: " << 
        #ifdef __x86_64__
        "x86_64"
        #elif defined(__aarch64__)
        "aarch64"
        #else
        "unknown"
        #endif
        << std::endl;
    
    std::cout << "Number of hardware threads: " << std::thread::hardware_concurrency() << std::endl;
    std::cout << std::endl;
    
    benchmark_lockfree_queue(num_producers, num_consumers, operations_per_producer);
    
    return 0;
}
```

### Step 4: Create Benchmark Script

Create a file named `run_atomic_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Get architecture and CPU info
arch=$(uname -m)
echo "Architecture: $arch"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "Hardware threads: $(nproc)"

# Compile benchmarks
echo "Compiling benchmarks..."
g++ -std=c++17 -O3 -pthread atomic_benchmark.cpp -o atomic_benchmark
g++ -std=c++17 -O3 -pthread lockfree_queue.cpp -o lockfree_queue

# Initialize results file
echo "operation,threads,time,ops_per_second,ns_per_op" > atomic_results.csv

# Run atomic operation benchmarks
echo "Running atomic operation benchmarks..."

# Test with different thread counts
for threads in 1 2 4 $(nproc); do
    # Atomic load
    echo "Testing atomic load with $threads threads..."
    ./atomic_benchmark 0 $threads 10000000 | tee atomic_load_${threads}.txt
    
    time=$(grep "Time:" atomic_load_${threads}.txt | awk '{print $2}')
    ops=$(grep "Operations per second:" atomic_load_${threads}.txt | awk '{print $4}')
    ns=$(grep "Time per operation:" atomic_load_${threads}.txt | awk '{print $4}')
    
    echo "load,$threads,$time,$ops,$ns" >> atomic_results.csv
    
    # Atomic store
    echo "Testing atomic store with $threads threads..."
    ./atomic_benchmark 1 $threads 10000000 | tee atomic_store_${threads}.txt
    
    time=$(grep "Time:" atomic_store_${threads}.txt | awk '{print $2}')
    ops=$(grep "Operations per second:" atomic_store_${threads}.txt | awk '{print $4}')
    ns=$(grep "Time per operation:" atomic_store_${threads}.txt | awk '{print $4}')
    
    echo "store,$threads,$time,$ops,$ns" >> atomic_results.csv
    
    # Atomic fetch_add
    echo "Testing atomic fetch_add with $threads threads..."
    ./atomic_benchmark 2 $threads 10000000 | tee atomic_fetch_add_${threads}.txt
    
    time=$(grep "Time:" atomic_fetch_add_${threads}.txt | awk '{print $2}')
    ops=$(grep "Operations per second:" atomic_fetch_add_${threads}.txt | awk '{print $4}')
    ns=$(grep "Time per operation:" atomic_fetch_add_${threads}.txt | awk '{print $4}')
    
    echo "fetch_add,$threads,$time,$ops,$ns" >> atomic_results.csv
    
    # Atomic CAS
    echo "Testing atomic CAS with $threads threads..."
    ./atomic_benchmark 3 $threads 1000000 | tee atomic_cas_${threads}.txt
    
    time=$(grep "Time:" atomic_cas_${threads}.txt | awk '{print $2}')
    ops=$(grep "Operations per second:" atomic_cas_${threads}.txt | awk '{print $4}')
    ns=$(grep "Time per operation:" atomic_cas_${threads}.txt | awk '{print $4}')
    
    echo "cas,$threads,$time,$ops,$ns" >> atomic_results.csv
done

# Run lock-free queue benchmark
echo "Running lock-free queue benchmark..."

# Initialize queue results file
echo "producers,consumers,time,ops_per_second,ns_per_op" > queue_results.csv

# Test with different thread configurations
for threads in 1 2 4; do
    echo "Testing lock-free queue with $threads producers and $threads consumers..."
    ./lockfree_queue $threads $threads 1000000 | tee queue_${threads}_${threads}.txt
    
    time=$(grep "Time:" queue_${threads}_${threads}.txt | awk '{print $2}')
    ops=$(grep "Operations per second:" queue_${threads}_${threads}.txt | awk '{print $4}')
    ns=$(grep "Time per operation:" queue_${threads}_${threads}.txt | awk '{print $4}')
    
    echo "$threads,$threads,$time,$ops,$ns" >> queue_results.csv
done

echo "Benchmark complete. Results saved to atomic_results.csv and queue_results.csv"
```

Make the script executable:

```bash
chmod +x run_atomic_benchmark.sh
```

### Step 5: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
./run_atomic_benchmark.sh
```

### Step 6: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Atomic Operation Latency**: Compare the time per operation for different atomic operations.
2. **Scalability**: Compare how performance scales with increasing thread count.
3. **Operation Efficiency**: Compare the relative efficiency of different atomic operations.
4. **Lock-Free Data Structure Performance**: Compare the throughput of the lock-free queue.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Memory Consistency Model**: x86 has a stronger memory model (TSO - Total Store Order) compared to Arm's weaker memory model.
- **Atomic Instruction Implementation**: Different architectures implement atomic instructions differently.
- **Cache Coherence Protocol**: Different approaches to maintaining cache coherence can affect atomic operation performance.
- **Memory Barrier Cost**: The cost of memory barriers/fences can vary significantly between architectures.

## Relevance to Workloads

Atomic operation and lock-free programming benchmarking is particularly important for:

1. **High-Performance Concurrent Systems**: Thread pools, work queues, task schedulers
2. **Low-Latency Trading Systems**: Order matching engines, market data processors
3. **Real-Time Systems**: Control systems, signal processing
4. **Parallel Data Processing**: Concurrent hash maps, lock-free data structures
5. **Operating System Kernels**: Schedulers, memory managers, device drivers

Understanding atomic operation differences between architectures helps you optimize concurrent code for better performance by:
- Selecting appropriate atomic operations and memory ordering
- Designing data structures with architecture-specific characteristics in mind
- Minimizing contention and false sharing
- Using appropriate synchronization primitives for each architecture

## Knowledge Check

1. If atomic compare-and-swap (CAS) operations are significantly slower on one architecture compared to another, what might be the most effective optimization strategy?
   - A) Use more threads to compensate for the slower operations
   - B) Redesign algorithms to use simpler atomic operations like fetch_add where possible
   - C) Increase the CPU clock speed
   - D) Use standard mutex locks instead of atomic operations

2. Which memory ordering is typically most efficient on both x86 and Arm architectures?
   - A) memory_order_seq_cst (sequential consistency)
   - B) memory_order_acq_rel (acquire-release)
   - C) memory_order_relaxed (relaxed)
   - D) memory_order_consume (consume)

3. When implementing a lock-free data structure that will run on both x86 and Arm, what should you be most careful about?
   - A) Using the same number of threads on both architectures
   - B) Memory ordering requirements, which are more important on Arm's weaker memory model
   - C) Using the same compiler for both architectures
   - D) Ensuring both systems have the same amount of RAM

Answers:
1. B) Redesign algorithms to use simpler atomic operations like fetch_add where possible
2. C) memory_order_relaxed (relaxed)
3. B) Memory ordering requirements, which are more important on Arm's weaker memory model