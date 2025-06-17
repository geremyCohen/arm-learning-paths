---
title: Energy Efficiency Under Different Workloads
weight: 2000

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Energy Efficiency Under Different Workloads

Energy efficiency in computing refers to the amount of useful work a system can perform per unit of energy consumed. While our earlier chapter on power efficiency provided a general overview, this chapter focuses specifically on how energy efficiency varies across different types of workloads and how architectural differences between Intel/AMD (x86) and Arm can lead to significant variations in energy consumption patterns.

Different workloads stress different parts of the processor and system, resulting in varying power consumption profiles. Understanding these patterns is crucial for optimizing both performance and energy costs, especially in large-scale deployments where energy expenses can be substantial.

For more detailed information about energy efficiency in computing, you can refer to:
- [Energy-Efficient Computing](https://www.energy.gov/eere/buildings/energy-efficient-computing)
- [Power Management in Modern Processors](https://www.anandtech.com/show/14514/examining-intel-ice-lake-microarchitecture-power)
- [Arm Energy Efficiency](https://www.arm.com/why-arm/power-efficiency)

## Benchmarking Exercise: Comparing Energy Efficiency Across Workloads

In this exercise, we'll measure and compare energy efficiency across Intel/AMD and Arm architectures under different types of workloads.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential stress-ng cpupower-utils linux-tools-common linux-tools-generic python3-matplotlib
```

### Step 2: Create Workload Scripts

Create a file named `cpu_workload.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <pthread.h>

#define NUM_THREADS 4
#define DURATION 30  // seconds

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// CPU-intensive workload
void* cpu_intensive(void* arg) {
    int thread_id = *(int*)arg;
    double start_time = get_time();
    double end_time = start_time + DURATION;
    uint64_t operations = 0;
    
    printf("Thread %d started\n", thread_id);
    
    while (get_time() < end_time) {
        // Perform compute-intensive operations
        double result = 0.0;
        for (int i = 0; i < 1000000; i++) {
            result += i * 1.1;
        }
        operations++;
        
        // Prevent compiler from optimizing away the calculation
        if (result < 0) {
            printf("This should never happen\n");
        }
    }
    
    printf("Thread %d completed %lu operations\n", thread_id, operations);
    
    // Return operations count
    uint64_t* ops = malloc(sizeof(uint64_t));
    *ops = operations;
    return ops;
}

// Memory-intensive workload
void* memory_intensive(void* arg) {
    int thread_id = *(int*)arg;
    double start_time = get_time();
    double end_time = start_time + DURATION;
    uint64_t operations = 0;
    
    // Allocate a large array (100MB)
    const size_t array_size = 100 * 1024 * 1024 / sizeof(int);
    int* array = (int*)malloc(array_size * sizeof(int));
    if (!array) {
        perror("malloc");
        return NULL;
    }
    
    printf("Thread %d started\n", thread_id);
    
    while (get_time() < end_time) {
        // Perform memory-intensive operations
        for (size_t i = 0; i < array_size; i++) {
            array[i] = i;
        }
        
        int sum = 0;
        for (size_t i = 0; i < array_size; i++) {
            sum += array[i];
        }
        operations++;
        
        // Prevent compiler from optimizing away the calculation
        if (sum < 0) {
            printf("This should never happen\n");
        }
    }
    
    free(array);
    printf("Thread %d completed %lu operations\n", thread_id, operations);
    
    // Return operations count
    uint64_t* ops = malloc(sizeof(uint64_t));
    *ops = operations;
    return ops;
}

// Mixed workload
void* mixed_workload(void* arg) {
    int thread_id = *(int*)arg;
    double start_time = get_time();
    double end_time = start_time + DURATION;
    uint64_t operations = 0;
    
    // Allocate a medium-sized array (10MB)
    const size_t array_size = 10 * 1024 * 1024 / sizeof(int);
    int* array = (int*)malloc(array_size * sizeof(int));
    if (!array) {
        perror("malloc");
        return NULL;
    }
    
    printf("Thread %d started\n", thread_id);
    
    while (get_time() < end_time) {
        // Alternate between CPU and memory operations
        double result = 0.0;
        for (int i = 0; i < 100000; i++) {
            result += i * 1.1;
        }
        
        for (size_t i = 0; i < array_size / 10; i++) {
            array[i] = i;
            result += array[i];
        }
        
        operations++;
        
        // Prevent compiler from optimizing away the calculation
        if (result < 0) {
            printf("This should never happen\n");
        }
    }
    
    free(array);
    printf("Thread %d completed %lu operations\n", thread_id, operations);
    
    // Return operations count
    uint64_t* ops = malloc(sizeof(uint64_t));
    *ops = operations;
    return ops;
}

// Idle workload with periodic spikes
void* bursty_workload(void* arg) {
    int thread_id = *(int*)arg;
    double start_time = get_time();
    double end_time = start_time + DURATION;
    uint64_t operations = 0;
    
    printf("Thread %d started\n", thread_id);
    
    while (get_time() < end_time) {
        // Burst of activity (20% of the time)
        double burst_end = get_time() + 0.2;
        while (get_time() < burst_end) {
            double result = 0.0;
            for (int i = 0; i < 1000000; i++) {
                result += i * 1.1;
            }
            operations++;
            
            // Prevent compiler from optimizing away the calculation
            if (result < 0) {
                printf("This should never happen\n");
            }
        }
        
        // Idle period (80% of the time)
        usleep(800000);  // 800ms
    }
    
    printf("Thread %d completed %lu operations\n", thread_id, operations);
    
    // Return operations count
    uint64_t* ops = malloc(sizeof(uint64_t));
    *ops = operations;
    return ops;
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        printf("Usage: %s <workload_type>\n", argv[0]);
        printf("  1: CPU-intensive\n");
        printf("  2: Memory-intensive\n");
        printf("  3: Mixed\n");
        printf("  4: Bursty\n");
        return 1;
    }
    
    int workload_type = atoi(argv[1]);
    pthread_t threads[NUM_THREADS];
    int thread_ids[NUM_THREADS];
    
    printf("CPU Architecture: %s\n", 
        #ifdef __x86_64__
        "x86_64"
        #elif defined(__aarch64__)
        "aarch64"
        #else
        "unknown"
        #endif
    );
    
    printf("Starting %d threads with workload type %d for %d seconds\n", 
           NUM_THREADS, workload_type, DURATION);
    
    // Create threads
    for (int i = 0; i < NUM_THREADS; i++) {
        thread_ids[i] = i;
        
        switch (workload_type) {
            case 1:
                pthread_create(&threads[i], NULL, cpu_intensive, &thread_ids[i]);
                break;
            case 2:
                pthread_create(&threads[i], NULL, memory_intensive, &thread_ids[i]);
                break;
            case 3:
                pthread_create(&threads[i], NULL, mixed_workload, &thread_ids[i]);
                break;
            case 4:
                pthread_create(&threads[i], NULL, bursty_workload, &thread_ids[i]);
                break;
            default:
                printf("Invalid workload type\n");
                return 1;
        }
    }
    
    // Wait for threads to complete
    uint64_t total_operations = 0;
    for (int i = 0; i < NUM_THREADS; i++) {
        uint64_t* thread_ops;
        pthread_join(threads[i], (void**)&thread_ops);
        total_operations += *thread_ops;
        free(thread_ops);
    }
    
    printf("Total operations completed: %lu\n", total_operations);
    printf("Operations per second: %.2f\n", (double)total_operations / DURATION);
    
    return 0;
}
```

### Step 3: Create Energy Measurement Script

Create a file named `measure_energy.sh` with the following content:

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

# Function to measure power consumption
measure_power() {
  local workload=$1
  
  # Try different methods to measure power
  if [ -d "/sys/class/powercap/intel-rapl" ]; then
    echo "Using Intel RAPL for power measurement..."
    
    # Read initial energy values
    initial_values=()
    domains=()
    for domain in /sys/class/powercap/intel-rapl/intel-rapl:*; do
      if [ -f "$domain/energy_uj" ]; then
        initial_values+=("$(cat $domain/energy_uj)")
        domains+=("$domain")
      fi
    done
    
    # Run the workload
    ./cpu_workload $workload
    
    # Read final energy values and calculate power
    echo "Power consumption:"
    local i=0
    total_energy_joules=0
    for domain in "${domains[@]}"; do
      if [ -f "$domain/energy_uj" ]; then
        local final_value=$(cat $domain/energy_uj)
        local domain_name=$(cat $domain/name)
        local energy_joules=$(( (final_value - ${initial_values[$i]}) / 1000000 ))
        local power_watts=$(echo "scale=2; $energy_joules / 30" | bc)
        echo "$domain_name: $power_watts watts"
        total_energy_joules=$((total_energy_joules + energy_joules))
        i=$((i+1))
      fi
    done
    
    echo "Total energy: $total_energy_joules joules"
    
  elif [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then
    echo "Using CPU frequency scaling for power estimation..."
    
    # Get initial timestamp and frequency
    initial_time=$(date +%s)
    initial_freqs=()
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
      if [ -f "$cpu" ]; then
        initial_freqs+=("$(cat $cpu)")
      fi
    done
    
    # Run the workload
    ./cpu_workload $workload
    
    # Calculate estimated power based on frequency
    local final_time=$(date +%s)
    local actual_duration=$((final_time - initial_time))
    
    echo "Estimated power consumption over $actual_duration seconds:"
    local total_freq_ghz=0
    local i=0
    
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
      if [ -f "$cpu" ] && [ $i -lt ${#initial_freqs[@]} ]; then
        local final_freq=$(cat $cpu)
        local avg_freq=$(( (final_freq + ${initial_freqs[$i]}) / 2 ))
        local freq_ghz=$(echo "scale=3; $avg_freq / 1000000" | bc)
        total_freq_ghz=$(echo "scale=3; $total_freq_ghz + $freq_ghz" | bc)
        i=$((i+1))
      fi
    done
    
    # Rough estimation based on frequency
    # This is a very simplified model and not accurate
    local estimated_power=$(echo "scale=2; $total_freq_ghz * 5" | bc)
    echo "Estimated total CPU power: $estimated_power watts (rough approximation)"
    
  else
    echo "No power measurement capability detected"
    
    # Just run the workload
    ./cpu_workload $workload
  fi
}

# Display system information
echo "=== System Information ==="
echo "Architecture: $(get_arch)"
echo "CPU Model:"
lscpu | grep "Model name"
echo "CPU Cores: $(nproc)"
echo ""

# Compile the workload program
gcc -O2 -pthread cpu_workload.c -o cpu_workload

# Initialize results file
echo "workload,operations,ops_per_second,energy_joules,ops_per_joule" > energy_results.csv

# Run different workloads
for workload in 1 2 3 4; do
  case $workload in
    1) name="CPU-intensive" ;;
    2) name="Memory-intensive" ;;
    3) name="Mixed" ;;
    4) name="Bursty" ;;
  esac
  
  echo "=== Running $name workload ==="
  
  # Measure power and run workload
  measure_power $workload | tee ${name// /_}_results.txt
  
  # Extract results
  ops=$(grep "Total operations completed:" ${name// /_}_results.txt | awk '{print $4}')
  ops_per_sec=$(grep "Operations per second:" ${name// /_}_results.txt | awk '{print $4}')
  
  # Try to extract energy information
  energy_joules=$(grep "Total energy:" ${name// /_}_results.txt | awk '{print $3}')
  
  # Calculate operations per joule if energy data is available
  if [ -n "$energy_joules" ] && [ "$energy_joules" -gt 0 ]; then
    ops_per_joule=$(echo "scale=2; $ops / $energy_joules" | bc)
  else
    energy_joules="N/A"
    ops_per_joule="N/A"
  fi
  
  echo "$name,$ops,$ops_per_sec,$energy_joules,$ops_per_joule" >> energy_results.csv
  
  echo ""
  sleep 5  # Cool down between tests
done

echo "Energy efficiency benchmarks completed. Results saved to energy_results.csv"
```

Make the script executable:

```bash
chmod +x measure_energy.sh
```

### Step 4: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
sudo ./measure_energy.sh
```

### Step 5: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Energy Efficiency**: Compare operations per joule across different workloads.
2. **Workload Sensitivity**: Identify which workloads show the largest efficiency differences between architectures.
3. **Power Scaling**: Compare how power consumption scales with different types of work.
4. **Performance per Watt**: Compare the computational efficiency for each workload type.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Power Management Features**: Different approaches to power states, frequency scaling, and core gating.
- **Microarchitectural Efficiency**: How efficiently each architecture executes different instruction types.
- **Memory Subsystem**: Power efficiency of the memory hierarchy under different access patterns.
- **Idle Power**: Baseline power consumption when parts of the processor are idle.

## Relevance to Workloads

Energy efficiency benchmarking across different workloads is particularly important for:

1. **Cloud Infrastructure**: Optimizing workload placement for energy efficiency
2. **Data Centers**: Managing power and cooling costs
3. **Edge Computing**: Maximizing battery life or operating within power constraints
4. **High-Performance Computing**: Balancing performance and energy consumption
5. **Mobile and Embedded Systems**: Extending battery life under varying workloads

Understanding energy efficiency differences between architectures helps you:
- Select the optimal architecture for specific workload types
- Schedule workloads to maximize energy efficiency
- Design applications to minimize energy consumption
- Make informed decisions about hardware procurement based on expected workloads

## Advanced Analysis: Dynamic Voltage and Frequency Scaling (DVFS)

For a deeper understanding of energy efficiency, you can analyze how each architecture responds to DVFS:

```bash
# On systems with cpupower
for freq in $(cpupower frequency-info -l | tail -n 1 | awk '{print $1, $2}'); do
  sudo cpupower frequency-set -f $freq
  # Run a benchmark at this frequency
  # Measure power consumption
done
```

This can reveal how efficiently each architecture scales performance with power.

## Knowledge Check

1. If an application shows significantly better energy efficiency on Arm for CPU-intensive workloads but similar efficiency for memory-intensive workloads, what might this suggest?
   - A) Arm's CPU execution units are more power-efficient
   - B) The memory subsystem is the dominant power consumer in memory-intensive workloads
   - C) The benchmark is not measuring energy correctly
   - D) The application is not optimized for either architecture

2. Which workload characteristic typically benefits most from the power efficiency advantages of modern processors?
   - A) Constant high CPU utilization
   - B) Bursty workloads with idle periods
   - C) Memory-bound operations
   - D) I/O-intensive operations

3. If a bursty workload shows better energy efficiency than a constant workload with the same average performance, what feature is likely responsible for this difference?
   - A) Larger cache sizes
   - B) Dynamic frequency scaling during idle periods
   - C) Better branch prediction
   - D) Higher memory bandwidth

Answers:
1. A) Arm's CPU execution units are more power-efficient
2. B) Bursty workloads with idle periods
3. B) Dynamic frequency scaling during idle periods