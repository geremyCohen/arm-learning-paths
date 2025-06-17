---
title: Arm big.LITTLE and DynamIQ
weight: 2350

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Arm big.LITTLE and DynamIQ

Arm big.LITTLE and its evolution, DynamIQ, are heterogeneous computing architectures that combine high-performance "big" cores with energy-efficient "LITTLE" cores in a single processor. This design allows systems to optimize for both performance and power efficiency by assigning tasks to the most appropriate core type.

When comparing Intel/AMD (x86) versus Arm architectures, this heterogeneous approach represents a significant architectural difference. While Intel has introduced hybrid architectures like Alder Lake with Performance and Efficiency cores, Arm has been refining this approach for over a decade.

For more detailed information about Arm big.LITTLE and DynamIQ, you can refer to:
- [Arm big.LITTLE Technology](https://www.arm.com/why-arm/technologies/big-little)
- [Arm DynamIQ Technology](https://www.arm.com/why-arm/technologies/dynamiq)
- [Heterogeneous Multi-Processing](https://developer.arm.com/documentation/den0022/latest/)

## Benchmarking Exercise: Leveraging big.LITTLE Architecture

In this exercise, we'll measure and compare performance and energy efficiency when targeting specific core types on Arm big.LITTLE systems.

### Prerequisites

Ensure you have an Arm VM or device with big.LITTLE or DynamIQ architecture:
- Arm (aarch64) with heterogeneous cores (e.g., Cortex-A76 + Cortex-A55)
- Linux kernel with CPU affinity support

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc cpufrequtils linux-tools-common linux-tools-generic
```

### Step 2: Identify Core Types

Create a file named `identify_cores.sh` with the following content:

```bash
#!/bin/bash

echo "CPU Information:"
lscpu

echo -e "\nDetailed CPU Information:"
cat /proc/cpuinfo | grep "processor\|model name\|CPU part"

echo -e "\nCPU Topology:"
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    cpu_num=$(basename $cpu | sed 's/cpu//')
    
    # Try to determine if it's a big or LITTLE core
    freq_max=$(cat $cpu/cpufreq/scaling_max_freq 2>/dev/null || echo "unknown")
    
    if [ -f "$cpu/cpufreq/scaling_max_freq" ]; then
        if [ "$freq_max" -gt 1500000 ]; then
            core_type="big (performance)"
        else
            core_type="LITTLE (efficiency)"
        fi
    else
        core_type="unknown type"
    fi
    
    echo "CPU $cpu_num: $core_type, Max Frequency: $freq_max kHz"
done
```

Make the script executable and run it:

```bash
chmod +x identify_cores.sh
./identify_cores.sh
```

### Step 3: Create Core-Specific Benchmark

Create a file named `big_little_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>
#include <sched.h>

#define ITERATIONS 100000000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Thread function for CPU-intensive workload
void* cpu_workload(void* arg) {
    int cpu_id = *(int*)arg;
    
    // Set CPU affinity
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);
    
    if (pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset) != 0) {
        perror("pthread_setaffinity_np");
        return NULL;
    }
    
    printf("Thread running on CPU %d\n", cpu_id);
    
    // Perform CPU-intensive calculation
    double result = 0.0;
    double start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        result += i * 0.01;
    }
    
    double end = get_time();
    double elapsed = end - start;
    
    printf("CPU %d: Time: %.6f seconds, Operations per second: %.2f million\n", 
           cpu_id, elapsed, ITERATIONS / elapsed / 1000000);
    
    // Prevent optimization
    if (result < 0) {
        printf("This should never happen\n");
    }
    
    return NULL;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <cpu_id1> [cpu_id2] ...\n", argv[0]);
        return 1;
    }
    
    int num_cpus = argc - 1;
    pthread_t threads[num_cpus];
    int cpu_ids[num_cpus];
    
    // Create threads for each specified CPU
    for (int i = 0; i < num_cpus; i++) {
        cpu_ids[i] = atoi(argv[i+1]);
        pthread_create(&threads[i], NULL, cpu_workload, &cpu_ids[i]);
    }
    
    // Wait for threads to complete
    for (int i = 0; i < num_cpus; i++) {
        pthread_join(threads[i], NULL);
    }
    
    return 0;
}
```

Compile the benchmark:

```bash
gcc -O2 -pthread big_little_benchmark.c -o big_little_benchmark
```

### Step 4: Create Power Measurement Script

Create a file named `measure_power.sh` with the following content:

```bash
#!/bin/bash

# This is a simplified power measurement script
# For accurate measurements, use hardware power monitors

# Function to get current CPU frequency
get_cpu_freq() {
    local cpu=$1
    cat /sys/devices/system/cpu/cpu$cpu/cpufreq/scaling_cur_freq 2>/dev/null || echo "N/A"
}

# Function to estimate power based on frequency
# This is a very rough approximation
estimate_power() {
    local cpu=$1
    local freq=$(get_cpu_freq $cpu)
    
    if [ "$freq" == "N/A" ]; then
        echo "N/A"
        return
    fi
    
    # Very simplified model: power ~ frequency^2
    # This is just for demonstration purposes
    echo "scale=2; ($freq / 1000000)^2" | bc
}

# Monitor CPU stats during benchmark
monitor_cpu() {
    local cpu=$1
    local duration=$2
    local interval=1
    
    echo "Monitoring CPU $cpu for $duration seconds..."
    echo "Time,Frequency,EstimatedPower" > cpu${cpu}_stats.csv
    
    for ((i=0; i<duration; i++)); do
        freq=$(get_cpu_freq $cpu)
        power=$(estimate_power $cpu)
        echo "$i,$freq,$power" >> cpu${cpu}_stats.csv
        sleep $interval
    done
}

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <cpu_id> <duration>"
    exit 1
fi

cpu=$1
duration=$2

# Start monitoring
monitor_cpu $cpu $duration &
monitor_pid=$!

# Wait for monitoring to complete
wait $monitor_pid

echo "Monitoring complete. Results saved to cpu${cpu}_stats.csv"
```

Make the script executable:

```bash
chmod +x measure_power.sh
```

### Step 5: Create Benchmark Script

Create a file named `run_big_little_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Identify big and LITTLE cores
# This is a simplified approach - adjust based on your system
big_cores=""
little_cores=""

# Try to identify cores based on max frequency
for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    cpu_num=$(basename $cpu | sed 's/cpu//')
    
    if [ -f "$cpu/cpufreq/scaling_max_freq" ]; then
        freq_max=$(cat $cpu/cpufreq/scaling_max_freq)
        
        if [ "$freq_max" -gt 1500000 ]; then
            big_cores="$big_cores $cpu_num"
        else
            little_cores="$little_cores $cpu_num"
        fi
    fi
done

# If we couldn't identify cores, use defaults
if [ -z "$big_cores" ]; then
    big_cores="0"
    little_cores="1"
fi

echo "Identified big cores:$big_cores"
echo "Identified LITTLE cores:$little_cores"

# Run benchmark on big core
echo "Running benchmark on big core..."
big_core=$(echo $big_cores | awk '{print $1}')
./measure_power.sh $big_core 30 &
./big_little_benchmark $big_core | tee big_core_results.txt

# Run benchmark on LITTLE core
echo "Running benchmark on LITTLE core..."
little_core=$(echo $little_cores | awk '{print $1}')
./measure_power.sh $little_core 30 &
./big_little_benchmark $little_core | tee little_core_results.txt

# Run benchmark on both core types
echo "Running benchmark on both core types..."
./big_little_benchmark $big_core $little_core | tee mixed_core_results.txt

echo "Benchmark complete. Results saved to text files."
```

Make the script executable:

```bash
chmod +x run_big_little_benchmark.sh
```

### Step 6: Run the Benchmark

Execute the benchmark script:

```bash
./run_big_little_benchmark.sh
```

### Step 7: Analyze the Results

When analyzing the results, consider:

1. **Performance Difference**: Compare operations per second between big and LITTLE cores.
2. **Energy Efficiency**: Compare estimated power consumption relative to performance.
3. **Workload Suitability**: Determine which workloads are better suited for each core type.

## Arm-specific Workload Placement Optimizations

Arm architectures offer several optimization techniques to leverage heterogeneous cores effectively:

### 1. Task-Specific Core Affinity

Create a file named `task_affinity.c`:

```c
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>
#include <sched.h>
#include <time.h>

#define NUM_TASKS 4
#define ITERATIONS 50000000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// CPU-intensive task (suitable for big cores)
void* cpu_intensive_task(void* arg) {
    int task_id = *(int*)arg;
    int cpu_id = task_id % 2;  // Assign to CPU 0 or 1
    
    // Set CPU affinity
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);
    pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
    
    printf("CPU-intensive task %d running on CPU %d\n", task_id, cpu_id);
    
    double start = get_time();
    
    // Perform CPU-intensive work
    volatile double result = 0.0;
    for (int i = 0; i < ITERATIONS; i++) {
        result += i * 0.01;
    }
    
    double end = get_time();
    printf("Task %d on CPU %d: Time: %.6f seconds\n", task_id, cpu_id, end - start);
    
    return NULL;
}

// Bursty task (suitable for LITTLE cores)
void* bursty_task(void* arg) {
    int task_id = *(int*)arg;
    int cpu_id = task_id % 2 + 2;  // Assign to CPU 2 or 3
    
    // Set CPU affinity
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);
    pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
    
    printf("Bursty task %d running on CPU %d\n", task_id, cpu_id);
    
    double start = get_time();
    
    // Perform bursty work
    for (int burst = 0; burst < 10; burst++) {
        volatile double result = 0.0;
        for (int i = 0; i < ITERATIONS / 10; i++) {
            result += i * 0.01;
        }
        usleep(100000);  // Sleep between bursts
    }
    
    double end = get_time();
    printf("Task %d on CPU %d: Time: %.6f seconds\n", task_id, cpu_id, end - start);
    
    return NULL;
}

int main() {
    pthread_t threads[NUM_TASKS];
    int task_ids[NUM_TASKS];
    
    // Create CPU-intensive tasks
    for (int i = 0; i < NUM_TASKS/2; i++) {
        task_ids[i] = i;
        pthread_create(&threads[i], NULL, cpu_intensive_task, &task_ids[i]);
    }
    
    // Create bursty tasks
    for (int i = NUM_TASKS/2; i < NUM_TASKS; i++) {
        task_ids[i] = i;
        pthread_create(&threads[i], NULL, bursty_task, &task_ids[i]);
    }
    
    // Wait for all tasks to complete
    for (int i = 0; i < NUM_TASKS; i++) {
        pthread_join(threads[i], NULL);
    }
    
    return 0;
}
```

Compile with:

```bash
gcc -O2 -pthread task_affinity.c -o task_affinity
```

### 2. Key Arm big.LITTLE Optimization Techniques

1. **Workload-Aware Scheduling**:
   ```c
   // For CPU-intensive tasks, use big cores
   cpu_set_t big_core_set;
   CPU_ZERO(&big_core_set);
   CPU_SET(big_core_id, &big_core_set);
   pthread_setaffinity_np(thread, sizeof(cpu_set_t), &big_core_set);
   
   // For I/O or bursty tasks, use LITTLE cores
   cpu_set_t little_core_set;
   CPU_ZERO(&little_core_set);
   CPU_SET(little_core_id, &little_core_set);
   pthread_setaffinity_np(thread, sizeof(cpu_set_t), &little_core_set);
   ```

2. **Energy-Aware Task Partitioning**:
   ```c
   // Divide work based on core capabilities
   void process_data(data_t* data, int size) {
       int big_core_chunk = size * 0.7;  // 70% to big cores
       int little_core_chunk = size * 0.3;  // 30% to LITTLE cores
       
       // Process on big cores (parallel intensive work)
       #pragma omp parallel for num_threads(big_core_count)
       for (int i = 0; i < big_core_chunk; i++) {
           // Process data[i]
       }
       
       // Process on LITTLE cores (sequential work)
       for (int i = big_core_chunk; i < size; i++) {
           // Process data[i]
       }
   }
   ```

3. **Dynamic Core Selection**:
   ```c
   // Choose core based on workload characteristics
   int select_optimal_core(task_t* task) {
       if (task->compute_intensity > THRESHOLD) {
           return get_available_big_core();
       } else {
           return get_available_little_core();
       }
   }
   ```

4. **Frequency Scaling Awareness**:
   ```bash
   # Set big cores to performance mode for latency-sensitive tasks
   echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
   
   # Set LITTLE cores to powersave for background tasks
   echo powersave > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
   ```

5. **Asymmetric Multithreading**:
   ```c
   // Create thread pool with core-specific queues
   thread_pool_t* create_asymmetric_pool() {
       thread_pool_t* pool = malloc(sizeof(thread_pool_t));
       
       // High-priority queue for big cores
       pool->big_core_queue = create_queue();
       
       // Low-priority queue for LITTLE cores
       pool->little_core_queue = create_queue();
       
       return pool;
   }
   
   // Submit task to appropriate queue
   void submit_task(thread_pool_t* pool, task_t* task) {
       if (task->priority == HIGH) {
           enqueue(pool->big_core_queue, task);
       } else {
           enqueue(pool->little_core_queue, task);
       }
   }
   ```

These optimizations can help leverage the heterogeneous nature of Arm big.LITTLE and DynamIQ architectures, improving both performance and energy efficiency.

## Relevance to Workloads

Arm big.LITTLE and DynamIQ optimizations are particularly important for:

1. **Mobile Applications**: Balancing performance and battery life
2. **Edge Computing**: Maximizing performance within power constraints
3. **Server Workloads**: Improving energy efficiency in data centers
4. **Mixed Workloads**: Systems running both latency-sensitive and background tasks
5. **IoT Devices**: Extending battery life while maintaining responsiveness

Understanding big.LITTLE architecture helps you:
- Optimize task scheduling for heterogeneous cores
- Balance performance and power consumption
- Design energy-efficient applications
- Improve responsiveness while minimizing energy use