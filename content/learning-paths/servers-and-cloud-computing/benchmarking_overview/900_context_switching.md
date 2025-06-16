---
title: Context Switching Performance
weight: 900

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Context Switching Performance

Context switching is the process by which a CPU switches from executing one process or thread to another. This operation is fundamental to multitasking operating systems but introduces overhead as the CPU must save the state of the current process and load the state of the next process. Context switching performance directly impacts system responsiveness, especially in environments with many concurrent processes or threads.

When comparing Intel/AMD (x86) versus Arm architectures, context switching characteristics can differ due to variations in pipeline design, register file size, TLB (Translation Lookaside Buffer) implementation, and architectural state complexity. These differences can significantly impact applications with high concurrency or frequent task switching.

For more detailed information about context switching, you can refer to:
- [Understanding Context Switching Overhead](https://eli.thegreenplace.net/2018/measuring-context-switching-and-memory-overheads-for-linux-threads/)
- [Linux Kernel Context Switching](https://www.kernel.org/doc/html/latest/scheduler/sched-design-CFS.html)

## Benchmarking Exercise: Comparing Context Switching Performance

In this exercise, we'll use specialized tools to measure and compare context switching performance across Intel/AMD and Arm systems.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y build-essential git python3 python3-matplotlib gnuplot linux-tools-common linux-tools-generic
```

### Step 2: Build LMBench for Context Switch Measurement

LMBench includes tools for measuring context switching time:

```bash
git clone https://github.com/intel/lmbench.git
cd lmbench
make
cd ..
```

### Step 3: Create Custom Context Switch Benchmark

Create a file named `ctx_switch.c` with the following content:

```c
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <sched.h>
#include <pthread.h>
#include <semaphore.h>
#include <string.h>
#include <errno.h>

#define BILLION 1000000000L
#define ITERATIONS 1000000

// Shared data between threads
struct shared_data {
    sem_t sem1;
    sem_t sem2;
    int iterations;
    long long *latencies;
};

// Thread function for ping-pong test
void *thread_func(void *arg) {
    struct shared_data *data = (struct shared_data *)arg;
    struct timespec start, end;
    int i;
    
    for (i = 0; i < data->iterations; i++) {
        // Signal thread 1
        sem_post(&data->sem1);
        
        // Wait for thread 2
        clock_gettime(CLOCK_MONOTONIC, &start);
        sem_wait(&data->sem2);
        clock_gettime(CLOCK_MONOTONIC, &end);
        
        // Calculate latency in nanoseconds
        data->latencies[i] = (end.tv_sec - start.tv_sec) * BILLION + (end.tv_nsec - start.tv_nsec);
    }
    
    return NULL;
}

// Set thread affinity to a specific CPU
int set_cpu_affinity(pthread_t thread, int cpu_id) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);
    
    int result = pthread_setaffinity_np(thread, sizeof(cpu_set_t), &cpuset);
    if (result != 0) {
        fprintf(stderr, "Failed to set thread affinity: %s\n", strerror(result));
        return -1;
    }
    
    return 0;
}

// Set process priority to real-time
void set_priority() {
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    if (sched_setscheduler(0, SCHED_FIFO, &param) == -1) {
        fprintf(stderr, "Failed to set scheduler: %s\n", strerror(errno));
    }
}

int main(int argc, char *argv[]) {
    pthread_t thread;
    struct shared_data data;
    long long min = BILLION, max = 0, total = 0;
    double avg, variance = 0, stddev;
    int i, iterations = ITERATIONS;
    int same_cpu = 0;
    int cpu1 = 0, cpu2 = 1;
    
    // Parse command line arguments
    if (argc > 1) {
        iterations = atoi(argv[1]);
    }
    
    if (argc > 2) {
        same_cpu = atoi(argv[2]);
    }
    
    if (argc > 4) {
        cpu1 = atoi(argv[3]);
        cpu2 = atoi(argv[4]);
    }
    
    // Allocate memory for latency measurements
    data.latencies = (long long *)malloc(iterations * sizeof(long long));
    if (!data.latencies) {
        perror("malloc");
        return 1;
    }
    
    // Initialize semaphores
    if (sem_init(&data.sem1, 0, 0) == -1 || sem_init(&data.sem2, 0, 0) == -1) {
        perror("sem_init");
        free(data.latencies);
        return 1;
    }
    
    data.iterations = iterations;
    
    // Set real-time priority
    set_priority();
    
    // Create thread
    if (pthread_create(&thread, NULL, thread_func, &data) != 0) {
        perror("pthread_create");
        sem_destroy(&data.sem1);
        sem_destroy(&data.sem2);
        free(data.latencies);
        return 1;
    }
    
    // Set CPU affinity
    if (!same_cpu) {
        printf("Running threads on different CPUs (CPU %d and CPU %d)\n", cpu1, cpu2);
        set_cpu_affinity(pthread_self(), cpu1);
        set_cpu_affinity(thread, cpu2);
    } else {
        printf("Running both threads on the same CPU (CPU %d)\n", cpu1);
        set_cpu_affinity(pthread_self(), cpu1);
        set_cpu_affinity(thread, cpu1);
    }
    
    // Ping-pong test
    for (i = 0; i < iterations; i++) {
        // Wait for thread 1
        sem_wait(&data.sem1);
        
        // Signal thread 2
        sem_post(&data.sem2);
    }
    
    // Wait for thread to finish
    pthread_join(thread, NULL);
    
    // Calculate statistics
    for (i = 0; i < iterations; i++) {
        if (data.latencies[i] < min) min = data.latencies[i];
        if (data.latencies[i] > max) max = data.latencies[i];
        total += data.latencies[i];
    }
    
    avg = (double)total / iterations;
    
    for (i = 0; i < iterations; i++) {
        variance += ((double)data.latencies[i] - avg) * ((double)data.latencies[i] - avg);
    }
    
    stddev = sqrt(variance / iterations);
    
    // Print results
    printf("Context Switch Latency Statistics (nanoseconds):\n");
    printf("Iterations: %d\n", iterations);
    printf("Min: %lld ns\n", min);
    printf("Avg: %.2f ns\n", avg);
    printf("Max: %lld ns\n", max);
    printf("StdDev: %.2f ns\n", stddev);
    
    // Output histogram data for plotting
    FILE *fp = fopen("ctx_switch_hist.txt", "w");
    if (fp) {
        // Create 100 buckets from min to max
        long long bucket_size = (max - min) / 100;
        if (bucket_size < 1) bucket_size = 1;
        
        int *buckets = (int *)calloc(101, sizeof(int));
        
        for (i = 0; i < iterations; i++) {
            int bucket = (data.latencies[i] - min) / bucket_size;
            if (bucket > 100) bucket = 100;
            buckets[bucket]++;
        }
        
        for (i = 0; i <= 100; i++) {
            fprintf(fp, "%lld %d\n", min + i * bucket_size, buckets[i]);
        }
        
        fclose(fp);
        free(buckets);
    }
    
    // Clean up
    sem_destroy(&data.sem1);
    sem_destroy(&data.sem2);
    free(data.latencies);
    
    return 0;
}
```

Compile the benchmark:

```bash
gcc -O2 ctx_switch.c -o ctx_switch -lpthread -lm
```

### Step 4: Create Pipe-Based Context Switch Benchmark

Create a file named `pipe_ctx_switch.c` with the following content:

```c
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <sched.h>
#include <sys/wait.h>
#include <string.h>
#include <errno.h>

#define BILLION 1000000000L
#define ITERATIONS 100000
#define BUFFER_SIZE 1

// Set process affinity to a specific CPU
int set_cpu_affinity(int pid, int cpu_id) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);
    
    if (sched_setaffinity(pid, sizeof(cpu_set_t), &cpuset) == -1) {
        perror("sched_setaffinity");
        return -1;
    }
    
    return 0;
}

// Set process priority to real-time
void set_priority() {
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    if (sched_setscheduler(0, SCHED_FIFO, &param) == -1) {
        fprintf(stderr, "Failed to set scheduler: %s\n", strerror(errno));
    }
}

int main(int argc, char *argv[]) {
    int pipe1[2], pipe2[2];
    pid_t pid;
    char buf[BUFFER_SIZE];
    struct timespec start, end;
    long long *latencies;
    long long min = BILLION, max = 0, total = 0;
    double avg, variance = 0, stddev;
    int i, iterations = ITERATIONS;
    int same_cpu = 0;
    int cpu1 = 0, cpu2 = 1;
    
    // Parse command line arguments
    if (argc > 1) {
        iterations = atoi(argv[1]);
    }
    
    if (argc > 2) {
        same_cpu = atoi(argv[2]);
    }
    
    if (argc > 4) {
        cpu1 = atoi(argv[3]);
        cpu2 = atoi(argv[4]);
    }
    
    // Allocate memory for latency measurements
    latencies = (long long *)malloc(iterations * sizeof(long long));
    if (!latencies) {
        perror("malloc");
        return 1;
    }
    
    // Create pipes
    if (pipe(pipe1) == -1 || pipe(pipe2) == -1) {
        perror("pipe");
        free(latencies);
        return 1;
    }
    
    // Set real-time priority
    set_priority();
    
    // Fork process
    pid = fork();
    
    if (pid == -1) {
        perror("fork");
        free(latencies);
        return 1;
    }
    
    if (pid == 0) {
        // Child process
        close(pipe1[1]); // Close write end of pipe1
        close(pipe2[0]); // Close read end of pipe2
        
        // Set CPU affinity
        if (!same_cpu) {
            set_cpu_affinity(0, cpu2);
        } else {
            set_cpu_affinity(0, cpu1);
        }
        
        for (i = 0; i < iterations; i++) {
            // Read from pipe1
            if (read(pipe1[0], buf, BUFFER_SIZE) != BUFFER_SIZE) {
                perror("read");
                exit(1);
            }
            
            // Write to pipe2
            if (write(pipe2[1], buf, BUFFER_SIZE) != BUFFER_SIZE) {
                perror("write");
                exit(1);
            }
        }
        
        close(pipe1[0]);
        close(pipe2[1]);
        exit(0);
    } else {
        // Parent process
        close(pipe1[0]); // Close read end of pipe1
        close(pipe2[1]); // Close write end of pipe2
        
        // Set CPU affinity
        if (!same_cpu) {
            printf("Running processes on different CPUs (CPU %d and CPU %d)\n", cpu1, cpu2);
            set_cpu_affinity(0, cpu1);
        } else {
            printf("Running both processes on the same CPU (CPU %d)\n", cpu1);
            set_cpu_affinity(0, cpu1);
        }
        
        // Warm up
        buf[0] = 'A';
        write(pipe1[1], buf, BUFFER_SIZE);
        read(pipe2[0], buf, BUFFER_SIZE);
        
        for (i = 0; i < iterations; i++) {
            // Write to pipe1
            clock_gettime(CLOCK_MONOTONIC, &start);
            if (write(pipe1[1], buf, BUFFER_SIZE) != BUFFER_SIZE) {
                perror("write");
                break;
            }
            
            // Read from pipe2
            if (read(pipe2[0], buf, BUFFER_SIZE) != BUFFER_SIZE) {
                perror("read");
                break;
            }
            clock_gettime(CLOCK_MONOTONIC, &end);
            
            // Calculate latency in nanoseconds
            latencies[i] = (end.tv_sec - start.tv_sec) * BILLION + (end.tv_nsec - start.tv_nsec);
        }
        
        // Wait for child process
        wait(NULL);
        
        // Calculate statistics
        for (i = 0; i < iterations; i++) {
            if (latencies[i] < min) min = latencies[i];
            if (latencies[i] > max) max = latencies[i];
            total += latencies[i];
        }
        
        avg = (double)total / iterations;
        
        for (i = 0; i < iterations; i++) {
            variance += ((double)latencies[i] - avg) * ((double)latencies[i] - avg);
        }
        
        stddev = sqrt(variance / iterations);
        
        // Print results
        printf("Process Context Switch Latency Statistics (nanoseconds):\n");
        printf("Iterations: %d\n", iterations);
        printf("Min: %lld ns\n", min);
        printf("Avg: %.2f ns\n", avg);
        printf("Max: %lld ns\n", max);
        printf("StdDev: %.2f ns\n", stddev);
        
        // Output histogram data for plotting
        FILE *fp = fopen("pipe_ctx_switch_hist.txt", "w");
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
        
        close(pipe1[1]);
        close(pipe2[0]);
        free(latencies);
    }
    
    return 0;
}
```

Compile the benchmark:

```bash
gcc -O2 pipe_ctx_switch.c -o pipe_ctx_switch -lm
```

### Step 5: Create Benchmark Script

Create a file named `context_switch_benchmark.sh` with the following content:

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
echo "CPU Cores: $(nproc)"
echo "Kernel Information:"
uname -a
echo ""

# Function to run thread context switch benchmark
run_thread_ctx_switch() {
  local iterations=$1
  local same_cpu=$2
  local cpu1=$3
  local cpu2=$4
  local description=$5
  
  echo "=== Running Thread Context Switch Benchmark: $description ==="
  ./ctx_switch $iterations $same_cpu $cpu1 $cpu2 | tee thread_ctx_switch_${description// /_}.txt
  
  # Generate plot if gnuplot is available
  if command -v gnuplot &> /dev/null && [ -f ctx_switch_hist.txt ]; then
    gnuplot -e "set term png; set output 'thread_ctx_switch_${description// /_}.png'; \
                set title 'Thread Context Switch Latency - $description'; \
                set xlabel 'Latency (ns)'; \
                set ylabel 'Frequency'; \
                set logscale y; \
                plot 'ctx_switch_hist.txt' using 1:2 with lines title 'Latency'"
    echo "Histogram plot saved as thread_ctx_switch_${description// /_}.png"
  fi
  
  echo ""
}

# Function to run process context switch benchmark
run_process_ctx_switch() {
  local iterations=$1
  local same_cpu=$2
  local cpu1=$3
  local cpu2=$4
  local description=$5
  
  echo "=== Running Process Context Switch Benchmark: $description ==="
  ./pipe_ctx_switch $iterations $same_cpu $cpu1 $cpu2 | tee process_ctx_switch_${description// /_}.txt
  
  # Generate plot if gnuplot is available
  if command -v gnuplot &> /dev/null && [ -f pipe_ctx_switch_hist.txt ]; then
    gnuplot -e "set term png; set output 'process_ctx_switch_${description// /_}.png'; \
                set title 'Process Context Switch Latency - $description'; \
                set xlabel 'Latency (ns)'; \
                set ylabel 'Frequency'; \
                set logscale y; \
                plot 'pipe_ctx_switch_hist.txt' using 1:2 with lines title 'Latency'"
    echo "Histogram plot saved as process_ctx_switch_${description// /_}.png"
  fi
  
  echo ""
}

# Run LMBench lat_ctx benchmark
echo "=== Running LMBench Context Switch Benchmark ==="
cd lmbench/bin/$(uname -m)-linux-gnu
./lat_ctx -s 64 2 | tee ../../../lmbench_ctx_switch_2proc.txt
./lat_ctx -s 64 4 | tee ../../../lmbench_ctx_switch_4proc.txt
./lat_ctx -s 64 8 | tee ../../../lmbench_ctx_switch_8proc.txt
./lat_ctx -s 64 16 | tee ../../../lmbench_ctx_switch_16proc.txt
cd ../../..
echo ""

# Run custom thread context switch benchmarks
run_thread_ctx_switch 100000 1 0 0 "same CPU"
run_thread_ctx_switch 100000 0 0 1 "different CPUs"

# Run custom process context switch benchmarks
run_process_ctx_switch 10000 1 0 0 "same CPU"
run_process_ctx_switch 10000 0 0 1 "different CPUs"

# Run perf sched benchmark if available
if command -v perf &> /dev/null; then
  echo "=== Running perf sched benchmark ==="
  perf sched record sleep 1
  perf sched latency | tee perf_sched_latency.txt
  echo ""
fi

# Summarize results
echo "=== Context Switch Performance Summary ==="
echo "Thread Context Switch Latency (same CPU):"
grep "Avg:" thread_ctx_switch_same_CPU.txt | awk '{print $2 " " $3}'

echo "Thread Context Switch Latency (different CPUs):"
grep "Avg:" thread_ctx_switch_different_CPUs.txt | awk '{print $2 " " $3}'

echo "Process Context Switch Latency (same CPU):"
grep "Avg:" process_ctx_switch_same_CPU.txt | awk '{print $2 " " $3}'

echo "Process Context Switch Latency (different CPUs):"
grep "Avg:" process_ctx_switch_different_CPUs.txt | awk '{print $2 " " $3}'

echo "All context switch benchmarks completed."
```

Make the script executable:

```bash
chmod +x context_switch_benchmark.sh
```

### Step 6: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
sudo ./context_switch_benchmark.sh | tee context_switch_benchmark_results.txt
```

### Step 7: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Thread Context Switch Latency**: Compare the time it takes to switch between threads.
2. **Process Context Switch Latency**: Compare the time it takes to switch between processes.
3. **Same-CPU vs. Different-CPU Switching**: Compare the impact of CPU locality on context switching.
4. **Scaling Behavior**: Compare how context switching latency changes with increasing process count.
5. **Latency Distribution**: Compare the variance and outliers in context switching times.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Register Set Size**: Different architectures have different numbers of registers that need to be saved/restored.
- **TLB Design**: Translation Lookaside Buffer implementation affects address translation during context switches.
- **Pipeline Depth**: Deeper pipelines may require more state to be saved/restored.
- **Cache Hierarchy**: Different cache designs can affect the cost of cold caches after a context switch.
- **Architectural State**: The amount of CPU state that needs to be preserved during a context switch.

## Relevance to Workloads

Context switching performance benchmarking is particularly important for:

1. **Web Servers**: Handling many concurrent connections
2. **Database Systems**: Processing multiple concurrent transactions
3. **Containerized Applications**: Running many isolated processes
4. **Real-time Systems**: Meeting strict timing requirements
5. **Microservices Architectures**: Managing many small, communicating services
6. **Event-driven Applications**: Responding to asynchronous events

Understanding context switching differences between architectures helps you select the optimal platform for highly concurrent applications and properly tune system configurations for maximum performance.

## Knowledge Check

1. If an application shows significantly higher context switching overhead on one architecture, which of the following would be the most effective mitigation strategy?
   - A) Increase the application's memory allocation
   - B) Reduce the number of threads or processes and use asynchronous I/O instead
   - C) Increase the CPU clock speed
   - D) Add more CPU cores to the system

2. Which of the following workload characteristics would be most sensitive to differences in context switching performance between architectures?
   - A) CPU-bound batch processing with few threads
   - B) Memory-intensive data processing with large working sets
   - C) I/O-bound processing with many short-lived threads
   - D) Single-threaded computation with no interruptions

3. If context switching between threads on the same CPU is much faster than between threads on different CPUs, what does this suggest about the architecture?
   - A) The CPU has inefficient core-to-core communication
   - B) The memory controller is a bottleneck
   - C) The cache coherence protocol has high overhead
   - D) The operating system scheduler is not optimized

Answers:
1. B) Reduce the number of threads or processes and use asynchronous I/O instead
2. C) I/O-bound processing with many short-lived threads
3. C) The cache coherence protocol has high overhead