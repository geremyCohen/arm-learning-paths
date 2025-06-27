---
title: CPU Utilization
weight: 100
layout: learningpathall
---

## Understanding CPU Utilization

CPU utilization is one of the most fundamental metrics for evaluating system performance. It represents the percentage of time the CPU spends executing non-idle tasks. Understanding CPU utilization helps identify whether your application is CPU-bound and how efficiently it uses available processing resources across different architectures.

When comparing Intel/AMD (x86) versus Arm architectures, CPU utilization patterns can reveal important differences in how each architecture handles your workloads. While the metric itself is architecture-agnostic, the underlying efficiency and behavior can vary significantly.

For more detailed information about CPU utilization, you can refer to:
- [Linux Performance Analysis with mpstat](https://www.brendangregg.com/blog/2014-06-26/linux-load-averages.html)
- [Understanding CPU Load](https://scoutapm.com/blog/understanding-load-averages)

## What the CPU Benchmark Actually Does

The `cpu_benchmark.sh` script performs a comprehensive CPU utilization analysis using three distinct stress-ng workloads:

### 1. **Full Load Test** (`stress-ng --cpu $(nproc)`)
- **Purpose**: Saturates all available CPU cores to measure maximum processing capacity
- **What it measures**: How efficiently each architecture handles compute-intensive tasks when all cores are utilized
- **Why it matters**: Reveals the true processing power and thermal characteristics under maximum load

### 2. **Half Load Test** (`stress-ng --cpu $(($(nproc) / 2))`)
- **Purpose**: Uses half the available cores to simulate partial system load
- **What it measures**: How each architecture handles moderate workloads and core scaling
- **Why it matters**: Most real-world applications don't use all cores simultaneously - this test shows practical performance

### 3. **Single Core Test** (`stress-ng --cpu 1`)
- **Purpose**: Stresses only one CPU core to measure single-threaded performance
- **What it measures**: Per-core efficiency and single-threaded optimization
- **Why it matters**: Many applications are single-threaded or have single-threaded bottlenecks

## Understanding the Architecture Differences

### Example 1: comparing Intel Xeon E5-2686 v4 (1 core) vs Arm Neoverse-N1 (2 cores):

### Full Load Results
- **Intel**: 91.6% CPU utilization
- **Arm**: 91.8% CPU utilization
- **Analysis**: Both architectures achieve similar utilization when fully loaded, indicating comparable efficiency at maximum capacity

### Half Load Results - The Key Difference
- **Intel**: 91.9% CPU utilization (still nearly maxed out)
- **Arm**: 45.7% CPU utilization (exactly half)
- **Why this happens**: 
  - Intel system has 1 core, so "half load" still means 1 stress-ng worker on 1 core = full utilization
  - Arm system has 2 cores, so "half load" means 1 stress-ng worker on 2 cores = 50% utilization
  - This demonstrates **perfect core scaling** on the Arm system

### Single Core Results
- **Intel**: 91.5% CPU utilization
- **Arm**: 45.8% CPU utilization
- **Analysis**: Similar pattern - Intel's single core is fully utilized, while Arm distributes the single-threaded load across its 2 cores

## Benchmarking Exercise

### Prerequisites

Ensure you have:
- Completed the repository setup from the previous chapter
- Two Ubuntu systems with the bench_guide repository cloned

### Step 1: Run the Benchmark

Navigate to the benchmark directory and run the comprehensive CPU benchmark:

```bash
cd bench_guide/100_cpu_utilization
./cpu_benchmark.sh
```

The script will automatically:
1. Run stress-ng with full core load for 10 seconds
2. Run stress-ng with half core load for 10 seconds  
3. Run stress-ng with single core load for 10 seconds
4. Collect detailed mpstat data for each test
5. Generate stress-ng performance metrics (operations per second, CPU time breakdown)

### Step 2: Analyze the Results

The benchmark creates multiple output files:
- `results_*.txt` - CPU utilization summaries for each test
- `mpstat_*.txt` - Detailed per-second CPU utilization data
- `metadata_*.txt` - Test configuration and average results
- `cpu_benchmark_results.txt` - Consolidated results

### Key Metrics to Compare

1. **Stress-ng Operations**: 
   - **Operations count**: Total computational work completed
   - **Ops/s (real time)**: Operations per second in wall-clock time
   - **Ops/s (CPU time)**: Operations per second of actual CPU time
   - **User vs System time**: How much time spent in user space vs kernel

2. **CPU Utilization Patterns**:
   - **User %**: Time spent executing application code
   - **System %**: Time spent in kernel/OS operations
   - **I/O Wait %**: Time waiting for disk/network operations
   - **Total utilization**: Overall CPU busy time

### Critical Insights from Multi-Load Testing

**Why Test Multiple Load Levels?**

1. **Full Load Testing** reveals maximum throughput and thermal behavior
2. **Half Load Testing** shows how efficiently each architecture scales with partial utilization
3. **Single Core Testing** identifies per-core performance and single-threaded bottlenecks

**Architecture-Specific Behaviors:**

- **Intel x86 Characteristics**: 
  - Complex cores with high single-threaded performance
  - May show high utilization even with reduced workloads due to fewer, more powerful cores
  - Better suited for single-threaded or lightly-threaded applications

- **Arm Characteristics**:
  - Simpler, more efficient cores designed for parallel workloads
  - Shows linear scaling with core count (50% load = 50% utilization)
  - Better suited for highly-parallel, multi-threaded applications
  - More predictable power consumption patterns

**The 91% vs 46% Difference Explained:**

This dramatic difference in half-load and single-core tests isn't about performance - it's about **architecture design philosophy**:

- **Intel approach**: Fewer, more powerful cores that run at high utilization
- **Arm approach**: More, simpler cores that scale linearly with workload

Both approaches can achieve the same total work, but through different strategies.

## Relevance to Workloads

This CPU utilization benchmark is particularly important for:

1. **Compute-intensive applications**: Machine learning, scientific computing, video encoding
2. **Web servers under high load**: Node.js, Nginx, Apache handling many concurrent connections
3. **Containerized environments**: Kubernetes clusters where efficient CPU utilization directly impacts density
4. **Batch processing systems**: ETL jobs, data processing pipelines

Understanding CPU utilization differences between architectures helps you make informed decisions about which architecture might be more cost-effective or performant for your specific workload.

## Knowledge Check

1. Why does the Arm system show 45.7% utilization during half-load testing while Intel shows 91.9%?
   - A) The Arm system is malfunctioning
   - B) Intel is more efficient at CPU utilization
   - C) The Arm system has 2 cores vs Intel's 1 core, so half-load uses 50% of available capacity
   - D) The benchmark is incorrectly configured

2. What does the stress-ng "Operations" metric tell us about architecture performance?
   - A) How many CPU cycles were executed
   - B) The total computational work completed during the test
   - C) The power consumption of the system
   - D) The memory bandwidth utilization

3. Why is single-core testing important when comparing architectures?
   - A) Most applications only use one core
   - B) It reveals per-core efficiency and single-threaded performance characteristics
   - C) It's easier to measure than multi-core performance
   - D) Single-core tests are more reliable than multi-core tests

4. If both architectures complete the same amount of work but show different CPU utilization patterns, this indicates:
   - A) One architecture is defective
   - B) Different core count and design philosophies achieving equivalent results
   - C) The benchmark is measuring incorrectly
   - D) One system has background processes running

Answers:
1. C) The Arm system has 2 cores vs Intel's 1 core, so half-load uses 50% of available capacity
2. B) The total computational work completed during the test
3. B) It reveals per-core efficiency and single-threaded performance characteristics
4. B) Different core count and design philosophies achieving equivalent results