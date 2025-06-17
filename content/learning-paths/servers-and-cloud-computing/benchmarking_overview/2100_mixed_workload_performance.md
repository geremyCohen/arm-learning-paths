---
title: Mixed Workload Performance
weight: 2100

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Mixed Workload Performance

In real-world environments, systems rarely run a single type of workload. Instead, they typically execute a mix of applications with different resource requirements, creating contention for shared resources like CPU cores, caches, memory bandwidth, and I/O. Understanding how different architectures handle these mixed workloads is crucial for predicting real-world performance.

When comparing Intel/AMD (x86) versus Arm architectures, mixed workload performance can vary significantly due to differences in resource allocation, cache hierarchies, memory controllers, and scheduling mechanisms. These architectural differences can lead to varying levels of interference between concurrent applications.

For more detailed information about mixed workload performance, you can refer to:
- [Performance Isolation in Multi-tenant Environments](https://www.usenix.org/conference/osdi18/presentation/boucher)
- [Resource Contention in Multicore Systems](https://dl.acm.org/doi/10.1145/2451116.2451125)
- [Workload Characterization](https://www.intel.com/content/www/us/en/developer/articles/technical/workload-characterization-guidelines.html)

## Benchmarking Exercise: Comparing Mixed Workload Performance

In this exercise, we'll measure and compare how Intel/AMD and Arm architectures handle multiple concurrent workloads with different resource requirements.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential gcc g++ python3-matplotlib stress-ng sysbench fio
```

### Step 2: Create Mixed Workload Script

Create a file named `mixed_workload.sh` with the following content:

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

# Function to run a command in the background and store its PID
run_background() {
  local cmd="$1"
  local log="$2"
  
  eval "$cmd" > "$log" 2>&1 &
  echo $!
}

# Function to measure baseline performance
measure_baseline() {
  local workload="$1"
  local duration="$2"
  
  echo "Measuring baseline performance for $workload..."
  
  case "$workload" in
    cpu)
      sysbench cpu --threads=1 --time=$duration run | tee baseline_cpu.txt
      baseline_score=$(grep "events per second" baseline_cpu.txt | awk '{print $4}')
      ;;
    memory)
      sysbench memory --threads=1 --memory-block-size=1K --memory-total-size=100G --time=$duration run | tee baseline_memory.txt
      baseline_score=$(grep "transferred" baseline_memory.txt | awk '{print $(NF-1)}')
      ;;
    io)
      fio --name=baseline --filename=test_file --size=1G --rw=randrw --bs=4k --iodepth=64 --numjobs=1 --runtime=$duration --time_based --direct=1 | tee baseline_io.txt
      baseline_score=$(grep "IOPS" baseline_io.txt | head -1 | awk '{print $2}' | sed 's/,//')
      ;;
  esac
  
  echo "Baseline $workload score: $baseline_score"
  echo "$baseline_score"
}

# Function to run mixed workload test
run_mixed_test() {
  local primary="$1"
  local secondary="$2"
  local duration="$3"
  
  echo "Running mixed workload test: $primary with $secondary background load..."
  
  # Start background load
  case "$secondary" in
    cpu)
      bg_pid=$(run_background "stress-ng --cpu $(( $(nproc) - 1 )) --timeout ${duration}s" "bg_cpu.log")
      ;;
    memory)
      bg_pid=$(run_background "stress-ng --vm $(( $(nproc) / 2 )) --vm-bytes 1G --timeout ${duration}s" "bg_memory.log")
      ;;
    io)
      bg_pid=$(run_background "fio --name=bg_io --filename=bg_file --size=2G --rw=randrw --bs=4k --iodepth=64 --numjobs=1 --runtime=$duration --time_based --direct=1" "bg_io.log")
      ;;
  esac
  
  # Wait for background load to start
  sleep 2
  
  # Run primary workload
  case "$primary" in
    cpu)
      sysbench cpu --threads=1 --time=$duration run | tee mixed_cpu.txt
      mixed_score=$(grep "events per second" mixed_cpu.txt | awk '{print $4}')
      ;;
    memory)
      sysbench memory --threads=1 --memory-block-size=1K --memory-total-size=100G --time=$duration run | tee mixed_memory.txt
      mixed_score=$(grep "transferred" mixed_memory.txt | awk '{print $(NF-1)}')
      ;;
    io)
      fio --name=mixed_io --filename=test_file --size=1G --rw=randrw --bs=4k --iodepth=64 --numjobs=1 --runtime=$duration --time_based --direct=1 | tee mixed_io.txt
      mixed_score=$(grep "IOPS" mixed_io.txt | head -1 | awk '{print $2}' | sed 's/,//')
      ;;
  esac
  
  # Kill background process
  kill $bg_pid 2>/dev/null
  
  echo "Mixed $primary score with $secondary background: $mixed_score"
  echo "$mixed_score"
}

# Display system information
echo "=== System Information ==="
echo "Architecture: $(get_arch)"
echo "CPU Model:"
lscpu | grep "Model name"
echo "CPU Cores: $(nproc)"
echo "Memory:"
free -h | grep "Mem:"
echo ""

# Create results file
echo "test,baseline,with_cpu_load,with_memory_load,with_io_load,cpu_impact,memory_impact,io_impact" > mixed_workload_results.csv

# Set test duration
duration=30

# Run tests for CPU workload
echo "=== Testing CPU Workload ==="
cpu_baseline=$(measure_baseline cpu $duration)
cpu_with_cpu=$(run_mixed_test cpu cpu $duration)
cpu_with_memory=$(run_mixed_test cpu memory $duration)
cpu_with_io=$(run_mixed_test cpu io $duration)

# Calculate impact percentages
cpu_cpu_impact=$(echo "scale=2; ($cpu_baseline - $cpu_with_cpu) * 100 / $cpu_baseline" | bc)
cpu_memory_impact=$(echo "scale=2; ($cpu_baseline - $cpu_with_memory) * 100 / $cpu_baseline" | bc)
cpu_io_impact=$(echo "scale=2; ($cpu_baseline - $cpu_with_io) * 100 / $cpu_baseline" | bc)

echo "CPU workload impact:"
echo "  With CPU load: ${cpu_cpu_impact}% degradation"
echo "  With Memory load: ${cpu_memory_impact}% degradation"
echo "  With I/O load: ${cpu_io_impact}% degradation"
echo ""

# Run tests for Memory workload
echo "=== Testing Memory Workload ==="
memory_baseline=$(measure_baseline memory $duration)
memory_with_cpu=$(run_mixed_test memory cpu $duration)
memory_with_memory=$(run_mixed_test memory memory $duration)
memory_with_io=$(run_mixed_test memory io $duration)

# Calculate impact percentages
memory_cpu_impact=$(echo "scale=2; ($memory_baseline - $memory_with_cpu) * 100 / $memory_baseline" | bc)
memory_memory_impact=$(echo "scale=2; ($memory_baseline - $memory_with_memory) * 100 / $memory_baseline" | bc)
memory_io_impact=$(echo "scale=2; ($memory_baseline - $memory_with_io) * 100 / $memory_baseline" | bc)

echo "Memory workload impact:"
echo "  With CPU load: ${memory_cpu_impact}% degradation"
echo "  With Memory load: ${memory_memory_impact}% degradation"
echo "  With I/O load: ${memory_io_impact}% degradation"
echo ""

# Run tests for I/O workload
echo "=== Testing I/O Workload ==="
io_baseline=$(measure_baseline io $duration)
io_with_cpu=$(run_mixed_test io cpu $duration)
io_with_memory=$(run_mixed_test io memory $duration)
io_with_io=$(run_mixed_test io io $duration)

# Calculate impact percentages
io_cpu_impact=$(echo "scale=2; ($io_baseline - $io_with_cpu) * 100 / $io_baseline" | bc)
io_memory_impact=$(echo "scale=2; ($io_baseline - $io_with_memory) * 100 / $io_baseline" | bc)
io_io_impact=$(echo "scale=2; ($io_baseline - $io_with_io) * 100 / $io_baseline" | bc)

echo "I/O workload impact:"
echo "  With CPU load: ${io_cpu_impact}% degradation"
echo "  With Memory load: ${io_memory_impact}% degradation"
echo "  With I/O load: ${io_io_impact}% degradation"
echo ""

# Save results to CSV
echo "cpu,$cpu_baseline,$cpu_with_cpu,$cpu_with_memory,$cpu_with_io,$cpu_cpu_impact,$cpu_memory_impact,$cpu_io_impact" >> mixed_workload_results.csv
echo "memory,$memory_baseline,$memory_with_cpu,$memory_with_memory,$memory_with_io,$memory_cpu_impact,$memory_memory_impact,$memory_io_impact" >> mixed_workload_results.csv
echo "io,$io_baseline,$io_with_cpu,$io_with_memory,$io_with_io,$io_cpu_impact,$io_memory_impact,$io_io_impact" >> mixed_workload_results.csv

# Clean up
rm -f test_file bg_file

echo "Mixed workload benchmarks completed. Results saved to mixed_workload_results.csv"
```

Make the script executable:

```bash
chmod +x mixed_workload.sh
```

### Step 3: Create Resource Contention Script

Create a file named `resource_contention.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>
#include <string.h>

#define MAX_THREADS 16
#define ARRAY_SIZE (64 * 1024 * 1024)  // 64MB
#define CACHE_LINE_SIZE 64
#define DURATION 30  // seconds

// Thread parameters
typedef struct {
    int thread_id;
    int thread_count;
    int workload_type;
    double *results;
    char *shared_array;
    size_t array_size;
    int duration;
} thread_params_t;

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// CPU-intensive workload with no sharing
void* cpu_no_sharing(void* arg) {
    thread_params_t* params = (thread_params_t*)arg;
    int thread_id = params->thread_id;
    double start_time = get_time();
    double end_time = start_time + params->duration;
    uint64_t operations = 0;
    
    // Each thread works on its own data
    double local_result = 0.0;
    
    while (get_time() < end_time) {
        for (int i = 0; i < 1000000; i++) {
            local_result += i * 1.1;
        }
        operations++;
    }
    
    params->results[thread_id] = operations;
    return NULL;
}

// CPU-intensive workload with shared data
void* cpu_shared_data(void* arg) {
    thread_params_t* params = (thread_params_t*)arg;
    int thread_id = params->thread_id;
    int thread_count = params->thread_count;
    double start_time = get_time();
    double end_time = start_time + params->duration;
    uint64_t operations = 0;
    
    // All threads work on the same cache line
    size_t shared_index = 0;
    
    while (get_time() < end_time) {
        for (int i = 0; i < 10000; i++) {
            // All threads update the same cache line
            params->shared_array[shared_index]++;
        }
        operations++;
    }
    
    params->results[thread_id] = operations;
    return NULL;
}

// Memory-intensive workload with no sharing
void* memory_no_sharing(void* arg) {
    thread_params_t* params = (thread_params_t*)arg;
    int thread_id = params->thread_id;
    int thread_count = params->thread_count;
    double start_time = get_time();
    double end_time = start_time + params->duration;
    uint64_t operations = 0;
    
    // Each thread works on its own portion of the array
    size_t chunk_size = params->array_size / thread_count;
    size_t start_idx = thread_id * chunk_size;
    size_t end_idx = (thread_id + 1) * chunk_size;
    
    while (get_time() < end_time) {
        for (size_t i = start_idx; i < end_idx; i++) {
            params->shared_array[i] = (char)(i & 0xFF);
        }
        operations++;
    }
    
    params->results[thread_id] = operations;
    return NULL;
}

// Memory-intensive workload with shared data
void* memory_shared_data(void* arg) {
    thread_params_t* params = (thread_params_t*)arg;
    int thread_id = params->thread_id;
    int thread_count = params->thread_count;
    double start_time = get_time();
    double end_time = start_time + params->duration;
    uint64_t operations = 0;
    
    // All threads work on the same portion of the array
    size_t shared_size = params->array_size / 16;  // Small portion for contention
    size_t start_idx = 0;
    size_t end_idx = shared_size;
    
    while (get_time() < end_time) {
        for (size_t i = start_idx; i < end_idx; i++) {
            params->shared_array[i] = (char)(i & 0xFF);
        }
        operations++;
    }
    
    params->results[thread_id] = operations;
    return NULL;
}

// False sharing workload
void* false_sharing(void* arg) {
    thread_params_t* params = (thread_params_t*)arg;
    int thread_id = params->thread_id;
    int thread_count = params->thread_count;
    double start_time = get_time();
    double end_time = start_time + params->duration;
    uint64_t operations = 0;
    
    // Each thread updates its own element, but elements are on the same cache line
    size_t index = thread_id * sizeof(char);  // Adjacent bytes in the same cache line
    
    while (get_time() < end_time) {
        for (int i = 0; i < 1000000; i++) {
            params->shared_array[index]++;
        }
        operations++;
    }
    
    params->results[thread_id] = operations;
    return NULL;
}

// No false sharing workload
void* no_false_sharing(void* arg) {
    thread_params_t* params = (thread_params_t*)arg;
    int thread_id = params->thread_id;
    int thread_count = params->thread_count;
    double start_time = get_time();
    double end_time = start_time + params->duration;
    uint64_t operations = 0;
    
    // Each thread updates its own element, with elements on different cache lines
    size_t index = thread_id * CACHE_LINE_SIZE;  // Each thread gets its own cache line
    
    while (get_time() < end_time) {
        for (int i = 0; i < 1000000; i++) {
            params->shared_array[index]++;
        }
        operations++;
    }
    
    params->results[thread_id] = operations;
    return NULL;
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        printf("Usage: %s <workload_type> <thread_count>\n", argv[0]);
        printf("  Workload types:\n");
        printf("    1: CPU-intensive, no sharing\n");
        printf("    2: CPU-intensive, shared data\n");
        printf("    3: Memory-intensive, no sharing\n");
        printf("    4: Memory-intensive, shared data\n");
        printf("    5: False sharing\n");
        printf("    6: No false sharing\n");
        return 1;
    }
    
    int workload_type = atoi(argv[1]);
    int thread_count = atoi(argv[2]);
    
    if (thread_count > MAX_THREADS) {
        printf("Thread count limited to %d\n", MAX_THREADS);
        thread_count = MAX_THREADS;
    }
    
    printf("CPU Architecture: %s\n", 
        #ifdef __x86_64__
        "x86_64"
        #elif defined(__aarch64__)
        "aarch64"
        #else
        "unknown"
        #endif
    );
    
    printf("Running workload type %d with %d threads for %d seconds\n", 
           workload_type, thread_count, DURATION);
    
    // Allocate shared array
    char *shared_array = (char*)malloc(ARRAY_SIZE);
    if (!shared_array) {
        perror("malloc");
        return 1;
    }
    
    // Initialize array
    memset(shared_array, 0, ARRAY_SIZE);
    
    // Allocate results array
    double results[MAX_THREADS] = {0};
    
    // Create thread parameters
    thread_params_t params[MAX_THREADS];
    pthread_t threads[MAX_THREADS];
    
    // Initialize thread parameters
    for (int i = 0; i < thread_count; i++) {
        params[i].thread_id = i;
        params[i].thread_count = thread_count;
        params[i].workload_type = workload_type;
        params[i].results = results;
        params[i].shared_array = shared_array;
        params[i].array_size = ARRAY_SIZE;
        params[i].duration = DURATION;
    }
    
    // Create threads
    for (int i = 0; i < thread_count; i++) {
        switch (workload_type) {
            case 1:
                pthread_create(&threads[i], NULL, cpu_no_sharing, &params[i]);
                break;
            case 2:
                pthread_create(&threads[i], NULL, cpu_shared_data, &params[i]);
                break;
            case 3:
                pthread_create(&threads[i], NULL, memory_no_sharing, &params[i]);
                break;
            case 4:
                pthread_create(&threads[i], NULL, memory_shared_data, &params[i]);
                break;
            case 5:
                pthread_create(&threads[i], NULL, false_sharing, &params[i]);
                break;
            case 6:
                pthread_create(&threads[i], NULL, no_false_sharing, &params[i]);
                break;
            default:
                printf("Invalid workload type\n");
                free(shared_array);
                return 1;
        }
    }
    
    // Wait for threads to complete
    for (int i = 0; i < thread_count; i++) {
        pthread_join(threads[i], NULL);
    }
    
    // Calculate total and average operations
    double total_operations = 0;
    for (int i = 0; i < thread_count; i++) {
        total_operations += results[i];
    }
    double avg_operations = total_operations / thread_count;
    
    // Calculate standard deviation
    double variance = 0;
    for (int i = 0; i < thread_count; i++) {
        variance += (results[i] - avg_operations) * (results[i] - avg_operations);
    }
    double stddev = sqrt(variance / thread_count);
    
    // Calculate min and max
    double min_ops = results[0];
    double max_ops = results[0];
    for (int i = 1; i < thread_count; i++) {
        if (results[i] < min_ops) min_ops = results[i];
        if (results[i] > max_ops) max_ops = results[i];
    }
    
    // Print results
    printf("\nResults:\n");
    printf("Total operations: %.0f\n", total_operations);
    printf("Average operations per thread: %.2f\n", avg_operations);
    printf("Standard deviation: %.2f (%.2f%%)\n", stddev, (stddev / avg_operations) * 100);
    printf("Min operations: %.0f\n", min_ops);
    printf("Max operations: %.0f\n", max_ops);
    printf("Max/Min ratio: %.2f\n", max_ops / min_ops);
    
    // Print per-thread results
    printf("\nPer-thread operations:\n");
    for (int i = 0; i < thread_count; i++) {
        printf("Thread %d: %.0f\n", i, results[i]);
    }
    
    free(shared_array);
    return 0;
}
```

Compile the resource contention benchmark:

```bash
gcc -O2 -pthread resource_contention.c -o resource_contention -lm
```

### Step 4: Create Resource Contention Script

Create a file named `run_contention_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Get architecture and CPU info
arch=$(uname -m)
echo "Architecture: $arch"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "CPU Cores: $(nproc)"

# Initialize results file
echo "workload,threads,total_ops,avg_ops,stddev,stddev_percent,min_ops,max_ops,max_min_ratio" > contention_results.csv

# Run resource contention benchmarks
for workload in 1 2 3 4 5 6; do
  case $workload in
    1) name="CPU-no-sharing" ;;
    2) name="CPU-shared-data" ;;
    3) name="Memory-no-sharing" ;;
    4) name="Memory-shared-data" ;;
    5) name="False-sharing" ;;
    6) name="No-false-sharing" ;;
  esac
  
  echo "=== Running $name benchmark ==="
  
  # Run with different thread counts
  for threads in 1 2 4 $(nproc); do
    if [ $threads -le $(nproc) ]; then
      echo "Testing with $threads threads..."
      ./resource_contention $workload $threads | tee ${name}_${threads}.txt
      
      # Extract results
      total=$(grep "Total operations:" ${name}_${threads}.txt | awk '{print $3}')
      avg=$(grep "Average operations per thread:" ${name}_${threads}.txt | awk '{print $5}')
      stddev=$(grep "Standard deviation:" ${name}_${threads}.txt | awk '{print $3}')
      stddev_pct=$(grep "Standard deviation:" ${name}_${threads}.txt | awk -F'[()]' '{print $2}' | sed 's/%//')
      min=$(grep "Min operations:" ${name}_${threads}.txt | awk '{print $3}')
      max=$(grep "Max operations:" ${name}_${threads}.txt | awk '{print $3}')
      ratio=$(grep "Max/Min ratio:" ${name}_${threads}.txt | awk '{print $3}')
      
      echo "$name,$threads,$total,$avg,$stddev,$stddev_pct,$min,$max,$ratio" >> contention_results.csv
    fi
  done
  
  echo ""
done

echo "Running mixed workload benchmark..."
./mixed_workload.sh

echo "All benchmarks completed."
```

Make the script executable:

```bash
chmod +x run_contention_benchmark.sh
```

### Step 5: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
sudo ./run_contention_benchmark.sh
```

### Step 6: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Workload Interference**: Compare how much one workload type affects another.
2. **Resource Contention**: Compare the impact of shared vs. non-shared resources.
3. **Scalability Under Contention**: Compare how performance scales with increasing thread count under contention.
4. **False Sharing Impact**: Compare the performance impact of false sharing.
5. **Fairness**: Compare the standard deviation of thread performance to assess fairness.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Cache Coherence Protocol**: Different approaches to maintaining cache coherence can affect contention.
- **Memory Controller Design**: Different memory controller implementations can handle concurrent access differently.
- **Scheduler Implementation**: Different CPU schedulers may prioritize workloads differently.
- **Resource Partitioning**: Some architectures may have better isolation between cores or threads.

## Arm-specific Optimizations

Arm architectures offer several optimization techniques to improve mixed workload performance:

### 1. Arm-optimized Workload Isolation

Create a file named `arm_workload_isolation.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include <sched.h>

#define CPU_ITERATIONS 100000000
#define MEMORY_SIZE 100000000
#define IO_OPERATIONS 1000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// CPU-intensive workload
void* cpu_workload(void* arg) {
    int cpu_id = *(int*)arg;
    volatile double result = 0.0;
    
    // Set CPU affinity if specified
    if (cpu_id >= 0) {
        cpu_set_t cpuset;
        CPU_ZERO(&cpuset);
        CPU_SET(cpu_id, &cpuset);
        pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
        printf("CPU workload running on CPU %d\n", cpu_id);
    }
    
    double start = get_time();
    
    // Perform CPU-intensive operations
    for (int i = 0; i < CPU_ITERATIONS; i++) {
        result += i * 1.1;
    }
    
    double end = get_time();
    printf("CPU workload time: %.6f seconds\n", end - start);
    
    return NULL;
}

// Memory-intensive workload
void* memory_workload(void* arg) {
    int cpu_id = *(int*)arg;
    
    // Set CPU affinity if specified
    if (cpu_id >= 0) {
        cpu_set_t cpuset;
        CPU_ZERO(&cpuset);
        CPU_SET(cpu_id, &cpuset);
        pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
        printf("Memory workload running on CPU %d\n", cpu_id);
    }
    
    // Allocate large array
    int* array = (int*)malloc(MEMORY_SIZE * sizeof(int));
    if (!array) {
        perror("malloc");
        return NULL;
    }
    
    double start = get_time();
    
    // Perform memory-intensive operations
    for (int i = 0; i < MEMORY_SIZE; i++) {
        array[i] = i;
    }
    
    // Read back to ensure memory operations complete
    volatile int sum = 0;
    for (int i = 0; i < MEMORY_SIZE; i++) {
        sum += array[i];
    }
    
    double end = get_time();
    printf("Memory workload time: %.6f seconds\n", end - start);
    
    free(array);
    return NULL;
}

// I/O-intensive workload
void* io_workload(void* arg) {
    int cpu_id = *(int*)arg;
    
    // Set CPU affinity if specified
    if (cpu_id >= 0) {
        cpu_set_t cpuset;
        CPU_ZERO(&cpuset);
        CPU_SET(cpu_id, &cpuset);
        pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
        printf("I/O workload running on CPU %d\n", cpu_id);
    }
    
    double start = get_time();
    
    // Perform I/O operations
    FILE* file = fopen("io_test.txt", "w");
    if (!file) {
        perror("fopen");
        return NULL;
    }
    
    for (int i = 0; i < IO_OPERATIONS; i++) {
        fprintf(file, "Line %d: This is a test of I/O performance under mixed workloads.\n", i);
        fflush(file);  // Force write to disk
    }
    
    fclose(file);
    
    double end = get_time();
    printf("I/O workload time: %.6f seconds\n", end - start);
    
    return NULL;
}

int main(int argc, char* argv[]) {
    int isolation_mode = 0;
    
    if (argc > 1) {
        isolation_mode = atoi(argv[1]);
    }
    
    printf("Running with isolation mode: %d\n", isolation_mode);
    printf("Number of CPUs: %ld\n", sysconf(_SC_NPROCESSORS_ONLN));
    
    pthread_t cpu_thread, memory_thread, io_thread;
    int cpu_core = -1, memory_core = -1, io_core = -1;
    
    // Set core affinity based on isolation mode
    if (isolation_mode == 1) {
        // Simple isolation: different cores for different workload types
        cpu_core = 0;
        memory_core = 1;
        io_core = 2;
    }
    
    // Start workloads
    pthread_create(&cpu_thread, NULL, cpu_workload, &cpu_core);
    pthread_create(&memory_thread, NULL, memory_workload, &memory_core);
    pthread_create(&io_thread, NULL, io_workload, &io_core);
    
    // Wait for completion
    pthread_join(cpu_thread, NULL);
    pthread_join(memory_thread, NULL);
    pthread_join(io_thread, NULL);
    
    return 0;
}
```

Compile with:

```bash
gcc -O3 -pthread arm_workload_isolation.c -o arm_workload_isolation
```

Run with different isolation modes:

```bash
# No isolation
./arm_workload_isolation 0

# With isolation
./arm_workload_isolation 1
```

### 2. Arm-optimized Memory Allocation

Create a file named `arm_memory_allocation.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>
#include <unistd.h>

#define NUM_THREADS 4
#define ALLOCATIONS_PER_THREAD 1000
#define ALLOCATION_SIZE 1024

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Thread-local storage for memory allocations
__thread void* thread_local_buffers[ALLOCATIONS_PER_THREAD];

// Standard allocation workload
void* standard_allocation(void* arg) {
    int thread_id = *(int*)arg;
    void* buffers[ALLOCATIONS_PER_THREAD];
    
    double start = get_time();
    
    // Allocate memory
    for (int i = 0; i < ALLOCATIONS_PER_THREAD; i++) {
        buffers[i] = malloc(ALLOCATION_SIZE);
        if (buffers[i]) {
            memset(buffers[i], thread_id, ALLOCATION_SIZE);
        }
    }
    
    // Use memory
    for (int i = 0; i < ALLOCATIONS_PER_THREAD; i++) {
        if (buffers[i]) {
            volatile char sum = 0;
            char* buf = (char*)buffers[i];
            for (int j = 0; j < ALLOCATION_SIZE; j += 64) {
                sum += buf[j];
            }
        }
    }
    
    // Free memory
    for (int i = 0; i < ALLOCATIONS_PER_THREAD; i++) {
        free(buffers[i]);
    }
    
    double end = get_time();
    printf("Thread %d: Standard allocation time: %.6f seconds\n", 
           thread_id, end - start);
    
    return NULL;
}

// Thread-local allocation workload
void* thread_local_allocation(void* arg) {
    int thread_id = *(int*)arg;
    
    double start = get_time();
    
    // Allocate memory in thread-local storage
    for (int i = 0; i < ALLOCATIONS_PER_THREAD; i++) {
        thread_local_buffers[i] = malloc(ALLOCATION_SIZE);
        if (thread_local_buffers[i]) {
            memset(thread_local_buffers[i], thread_id, ALLOCATION_SIZE);
        }
    }
    
    // Use memory
    for (int i = 0; i < ALLOCATIONS_PER_THREAD; i++) {
        if (thread_local_buffers[i]) {
            volatile char sum = 0;
            char* buf = (char*)thread_local_buffers[i];
            for (int j = 0; j < ALLOCATION_SIZE; j += 64) {
                sum += buf[j];
            }
        }
    }
    
    // Free memory
    for (int i = 0; i < ALLOCATIONS_PER_THREAD; i++) {
        free(thread_local_buffers[i]);
    }
    
    double end = get_time();
    printf("Thread %d: Thread-local allocation time: %.6f seconds\n", 
           thread_id, end - start);
    
    return NULL;
}

int main() {
    pthread_t threads[NUM_THREADS];
    int thread_ids[NUM_THREADS];
    
    printf("Testing standard memory allocation...\n");
    for (int i = 0; i < NUM_THREADS; i++) {
        thread_ids[i] = i;
        pthread_create(&threads[i], NULL, standard_allocation, &thread_ids[i]);
    }
    
    for (int i = 0; i < NUM_THREADS; i++) {
        pthread_join(threads[i], NULL);
    }
    
    printf("\nTesting thread-local memory allocation...\n");
    for (int i = 0; i < NUM_THREADS; i++) {
        thread_ids[i] = i;
        pthread_create(&threads[i], NULL, thread_local_allocation, &thread_ids[i]);
    }
    
    for (int i = 0; i < NUM_THREADS; i++) {
        pthread_join(threads[i], NULL);
    }
    
    return 0;
}
```

Compile with:

```bash
gcc -O3 -pthread arm_memory_allocation.c -o arm_memory_allocation
```

### 3. Key Arm Mixed Workload Optimization Techniques

1. **Workload Isolation on Arm big.LITTLE/DynamIQ Systems**:
   - Place compute-intensive workloads on big cores
   - Place I/O or memory-bound workloads on LITTLE cores
   - Use `sched_setaffinity()` to control placement

2. **Memory Allocator Optimization**:
   - Consider using jemalloc instead of glibc malloc:
   ```bash
   # Install jemalloc
   sudo apt install libjemalloc-dev
   
   # Compile with jemalloc
   gcc -O3 program.c -o program -ljemalloc
   
   # Run with jemalloc
   LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so ./program
   ```

3. **NUMA Awareness for Multi-socket Arm Systems**:
   ```c
   #include <numa.h>
   
   // Allocate memory on the local NUMA node
   void* local_memory = numa_alloc_local(size);
   
   // Allocate memory on a specific NUMA node
   void* node_memory = numa_alloc_onnode(size, node);
   ```

4. **Cache Partitioning with Cache Coloring**:
   ```c
   // Allocate memory aligned to cache line size
   void* buffer = aligned_alloc(64, size);
   
   // Access with stride to use different cache sets
   for (int i = 0; i < size; i += 4096) {
       buffer[i] = value;
   }
   ```

5. **I/O Optimization for Mixed Workloads**:
   ```c
   // Set I/O priority for different threads
   #include <sys/resource.h>
   
   // For background I/O threads
   ioprio_set(IOPRIO_WHO_PROCESS, pid, 
              IOPRIO_PRIO_VALUE(IOPRIO_CLASS_IDLE, 0));
   
   // For critical I/O threads
   ioprio_set(IOPRIO_WHO_PROCESS, pid, 
              IOPRIO_PRIO_VALUE(IOPRIO_CLASS_RT, 0));
   ```

These optimizations can significantly improve mixed workload performance on Arm architectures by reducing resource contention and improving isolation between different types of workloads.

## Relevance to Workloads

Mixed workload performance benchmarking is particularly important for:

1. **Virtualized Environments**: Multiple VMs sharing physical resources
2. **Container Platforms**: Multiple containers running on the same host
3. **Database Servers**: OLTP and OLAP workloads running concurrently
4. **Web Servers**: Handling diverse request types simultaneously
5. **Multi-tenant Systems**: Multiple users or applications sharing resources

Understanding mixed workload performance differences between architectures helps you:
- Design more efficient multi-tenant environments
- Predict performance in real-world scenarios with mixed workloads
- Implement appropriate resource isolation mechanisms
- Make informed decisions about workload placement and scheduling

## Knowledge Check

1. If a CPU-intensive workload shows minimal degradation when running alongside a memory-intensive workload on one architecture but significant degradation on another, what might this suggest?
   - A) The first architecture has better isolation between CPU and memory subsystems
   - B) The second architecture has a larger cache
   - C) The operating system is not properly optimized
   - D) The benchmark is not measuring correctly

2. Which resource contention pattern typically shows the largest performance difference between x86 and Arm architectures?
   - A) CPU contention with no sharing
   - B) Memory contention with shared data
   - C) False sharing between threads
   - D) I/O contention

3. If an architecture shows high standard deviation in per-thread performance under contention, what might this indicate?
   - A) The architecture has more CPU cores
   - B) The architecture has unfair resource allocation under contention
   - C) The benchmark is not running long enough
   - D) The operating system is not properly configured

Answers:
1. A) The first architecture has better isolation between CPU and memory subsystems
2. C) False sharing between threads
3. B) The architecture has unfair resource allocation under contention