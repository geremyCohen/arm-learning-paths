---
title: System Latency and Jitter
weight: 600

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding System Latency and Jitter

System latency refers to the time delay between an input and the corresponding output in a computing system. Jitter is the variation in latency over time. These metrics are critical for real-time systems, financial applications, gaming, and any application where consistent response times are essential.

When comparing Intel/AMD (x86) versus Arm architectures, latency and jitter characteristics can differ due to variations in interrupt handling, power management features, cache hierarchies, and overall system design. These architectural differences can significantly impact applications that require predictable, low-latency responses.

For more detailed information about system latency and jitter, you can refer to:
- [Understanding and Measuring Latency](https://bravenewgeek.com/everything-you-know-about-latency-is-wrong/)
- [Latency and Jitter in Real-time Systems](https://www.embedded.com/understanding-and-using-jitter-in-embedded-systems/)

## Benchmarking Exercise: Comparing System Latency and Jitter

In this exercise, we'll use specialized tools to measure and compare system latency and jitter across Intel/AMD and Arm systems.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential git python3 python3-matplotlib gnuplot stress-ng cyclictest
```

### Step 2: Install and Build Latency Measurement Tools

```bash
# Clone the rt-tests repository for cyclictest
git clone https://git.kernel.org/pub/scm/utils/rt-tests/rt-tests.git
cd rt-tests
make
cd ..

# Install hwlat detector if not already available
sudo modprobe hwlat_detector
```

### Step 3: Create Benchmark Script

Create a file named `latency_benchmark.sh` with the following content:

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

# Display system information
echo "=== System Information ==="
echo "Architecture: $(get_arch)"
echo "CPU Model:"
lscpu | grep "Model name"
echo "Kernel Information:"
uname -a
echo ""

# Function to run cyclictest
run_cyclictest() {
  local duration=$1
  local load=$2
  local description=$3
  
  echo "=== Running cyclictest with $description ==="
  
  if [ "$load" = "true" ]; then
    # Start background load
    stress-ng --cpu $(nproc) --io 2 --vm 1 --vm-bytes 256M --timeout ${duration}s &
    stress_pid=$!
    echo "Background load started with PID $stress_pid"
  fi
  
  # Run cyclictest
  sudo ./rt-tests/cyclictest -a -t -n -p 80 -i 1000 -l $((duration * 1000)) -h 1000 -q > cyclictest_${description// /_}.txt
  
  if [ "$load" = "true" ]; then
    # Ensure stress-ng is terminated
    kill $stress_pid 2>/dev/null || true
  fi
  
  # Extract and display results
  echo "Results:"
  grep "Min Latencies" cyclictest_${description// /_}.txt
  grep "Avg Latencies" cyclictest_${description// /_}.txt
  grep "Max Latencies" cyclictest_${description// /_}.txt
  echo ""
  
  # Create histogram
  ./rt-tests/cyclictest_hist.sh cyclictest_${description// /_}.txt > histogram_${description// /_}.txt
  
  # Generate plot if gnuplot is available
  if command -v gnuplot &> /dev/null; then
    gnuplot -e "set term png; set output 'latency_histogram_${description// /_}.png'; \
                set title 'Latency Histogram - $description'; \
                set xlabel 'Latency (us)'; \
                set ylabel 'Frequency'; \
                set logscale y; \
                plot 'histogram_${description// /_}.txt' using 1:2 with lines title 'Latency'"
    echo "Histogram plot saved as latency_histogram_${description// /_}.png"
  fi
}

# Function to measure scheduling latency
measure_scheduling_latency() {
  echo "=== Measuring Scheduling Latency ==="
  
  # Create a simple C program to measure scheduling latency
  cat > sched_latency.c << 'EOF'
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <sched.h>
#include <pthread.h>
#include <string.h>
#include <errno.h>

#define BILLION 1000000000L
#define MILLION 1000000L

void set_priority(int priority) {
    struct sched_param param;
    param.sched_priority = priority;
    if (sched_setscheduler(0, SCHED_FIFO, &param) == -1) {
        fprintf(stderr, "Failed to set scheduler: %s\n", strerror(errno));
    }
}

int main(int argc, char *argv[]) {
    int iterations = 100000;
    struct timespec start, end;
    long long *latencies;
    long long min = BILLION, max = 0, total = 0;
    int i;
    
    latencies = (long long *)malloc(iterations * sizeof(long long));
    if (!latencies) {
        perror("malloc");
        return 1;
    }
    
    // Set high priority
    set_priority(99);
    
    // Measure scheduling latency
    for (i = 0; i < iterations; i++) {
        clock_gettime(CLOCK_MONOTONIC, &start);
        sched_yield();  // Yield the CPU
        clock_gettime(CLOCK_MONOTONIC, &end);
        
        // Calculate latency in nanoseconds
        latencies[i] = (end.tv_sec - start.tv_sec) * BILLION + (end.tv_nsec - start.tv_nsec);
        
        if (latencies[i] < min) min = latencies[i];
        if (latencies[i] > max) max = latencies[i];
        total += latencies[i];
        
        // Small sleep to avoid CPU hogging
        if (i % 1000 == 0) {
            usleep(1);
        }
    }
    
    // Calculate statistics
    double avg = (double)total / iterations;
    
    // Calculate standard deviation (jitter)
    double variance = 0;
    for (i = 0; i < iterations; i++) {
        variance += ((double)latencies[i] - avg) * ((double)latencies[i] - avg);
    }
    double stddev = sqrt(variance / iterations);
    
    printf("Scheduling Latency Statistics (nanoseconds):\n");
    printf("Min: %lld ns\n", min);
    printf("Avg: %.2f ns\n", avg);
    printf("Max: %lld ns\n", max);
    printf("Jitter (StdDev): %.2f ns\n", stddev);
    
    // Output histogram data for plotting
    FILE *fp = fopen("sched_latency_hist.txt", "w");
    if (fp) {
        // Create 100 buckets from min to max
        long long bucket_size = (max - min) / 100;
        if (bucket_size < 1) bucket_size = 1;
        
        int *buckets = (int *)calloc(101, sizeof(int));
        
        for (i = 0; i < iterations; i++) {
            int bucket = (latencies[i] - min) / bucket_size;
            if (bucket > 100) bucket = 100;
            buckets[bucket]++;
        }
        
        for (i = 0; i <= 100; i++) {
            fprintf(fp, "%lld %d\n", min + i * bucket_size, buckets[i]);
        }
        
        fclose(fp);
        free(buckets);
    }
    
    free(latencies);
    return 0;
}
EOF

  # Compile the program
  gcc -O2 sched_latency.c -o sched_latency -lm
  
  # Run the program
  sudo ./sched_latency | tee sched_latency_results.txt
  
  # Generate plot if gnuplot is available
  if command -v gnuplot &> /dev/null && [ -f sched_latency_hist.txt ]; then
    gnuplot -e "set term png; set output 'sched_latency_histogram.png'; \
                set title 'Scheduling Latency Histogram'; \
                set xlabel 'Latency (ns)'; \
                set ylabel 'Frequency'; \
                set logscale y; \
                plot 'sched_latency_hist.txt' using 1:2 with lines title 'Latency'"
    echo "Scheduling latency histogram saved as sched_latency_histogram.png"
  fi
}

# Function to measure interrupt latency
measure_interrupt_latency() {
  echo "=== Measuring Interrupt Latency ==="
  
  # Check if hwlat detector module is available
  if lsmod | grep -q hwlat_detector; then
    echo "Using hwlat detector to measure hardware latency..."
    
    # Configure hwlat detector
    sudo sh -c "echo 10000000 > /sys/kernel/debug/hwlat_detector/window"  # 10ms window
    sudo sh -c "echo 100 > /sys/kernel/debug/hwlat_detector/width"  # 100us width
    
    # Start hwlat detector
    sudo sh -c "echo 1 > /sys/kernel/debug/hwlat_detector/enable"
    
    echo "Measuring for 30 seconds..."
    sleep 30
    
    # Stop hwlat detector
    sudo sh -c "echo 0 > /sys/kernel/debug/hwlat_detector/enable"
    
    # Display results
    echo "Hardware latency results:"
    cat /sys/kernel/debug/hwlat_detector/count
    cat /sys/kernel/debug/hwlat_detector/max
    cat /sys/kernel/debug/hwlat_detector/sample
  else
    echo "hwlat_detector module not available, skipping hardware latency test"
  fi
}

# Run tests
echo "Starting latency and jitter benchmarks..."

# Run cyclictest with different scenarios
run_cyclictest 30 false "idle system"
run_cyclictest 30 true "system under load"

# Measure scheduling latency
measure_scheduling_latency

# Measure interrupt latency
measure_interrupt_latency

echo "All latency and jitter tests completed."
```

Make the script executable:

```bash
chmod +x latency_benchmark.sh
```

### Step 4: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
sudo ./latency_benchmark.sh | tee latency_benchmark_results.txt
```

### Step 5: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Baseline Latency**: Compare minimum latency values in idle conditions.
2. **Average Latency**: Compare average response times.
3. **Maximum Latency (Worst Case)**: Compare worst-case latency spikes.
4. **Jitter**: Compare the standard deviation or variation in latency.
5. **Behavior Under Load**: Compare how latency and jitter change under system load.
6. **Scheduling Latency**: Compare context switching and scheduling efficiency.
7. **Interrupt Latency**: Compare hardware interrupt response times.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Interrupt Architecture**: Different approaches to interrupt handling and prioritization.
- **Power Management**: C-states, P-states, and their impact on wake-up latency.
- **Cache Coherence**: Different cache coherence protocols and their latency implications.
- **Memory Hierarchy**: Impact of memory access patterns on predictable performance.
- **CPU Frequency Scaling**: Different approaches to dynamic frequency scaling.

## Relevance to Workloads

System latency and jitter benchmarking is particularly important for:

1. **Real-time Systems**: Industrial control, robotics, autonomous vehicles
2. **Financial Trading**: High-frequency trading platforms where microseconds matter
3. **Audio/Video Processing**: Media streaming, video conferencing, live broadcasting
4. **Gaming Servers**: Multiplayer game hosting requiring consistent response times
5. **Telecommunications**: VoIP, 5G packet processing, network function virtualization
6. **Database Systems**: Transaction processing with strict latency requirements

Understanding latency and jitter differences between architectures helps you select the optimal platform for latency-sensitive applications and properly tune system configurations for consistent performance.

## Knowledge Check

1. If a system shows low average latency but occasional high spikes (high jitter), what might be the most likely cause?
   - A) Insufficient CPU power
   - B) Background system processes or power management features
   - C) Network congestion
   - D) Application design flaws

2. Which of the following workloads would be most sensitive to differences in system jitter between architectures?
   - A) Batch processing of large datasets
   - B) Real-time audio processing
   - C) Web server handling HTTP requests
   - D) File compression

3. If an Arm system shows lower interrupt latency but higher scheduling latency compared to an x86 system, what might this suggest about architectural differences?
   - A) The Arm system has more efficient interrupt controllers but less optimized context switching
   - B) The benchmark is biased toward one architecture
   - C) The operating system is not properly optimized for Arm
   - D) The x86 system has hardware acceleration for scheduling

Answers:
1. B) Background system processes or power management features
2. B) Real-time audio processing
3. A) The Arm system has more efficient interrupt controllers but less optimized context switching