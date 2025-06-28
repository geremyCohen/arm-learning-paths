---
title: CPU Utilization
weight: 100
layout: learningpathall
---

## Why CPU Utilization Matters

CPU utilization is a critical metric for understanding how effectively your workloads use available CPU resources. Sustained high utilization (near 100%) indicates a CPU-bound workload, while lower utilization can point to I/O, memory, or synchronization bottlenecks. Comparing utilization across architectures helps you select the platform best suited to your workload.

## Key Architecture Differences (x86 vs Arm)

- Intel x86 with SMT/Hyper-Threading presents two logical threads per physical core. SMT can boost parallel throughput by hiding pipeline stalls, but shares core resources across threads.
- Arm server cores (Neoverse-N1, V1) operate single-threaded per core. Each software thread maps one-to-one to a physical core, delivering predictable per-core performance and linear scaling without resource contention.

## Running the Benchmark via the Visualizer

1. Launch the Visualizer UI (e.g., run `bench_guide/visualizer/server`).
2. In the UI, select **100_cpu_utilization** from the **Benchmark** dropdown.
3. Choose your target ARM and Intel instances.
4. Click **Run Benchmark** and wait for all tests (full, half, single) to complete.
5. Click **View Report** to open the interactive HTML report with CPU utilization charts and detailed metrics.

## What the CPU Benchmark Actually Does

The `cpu_benchmark.sh` script walks through three key stress-ng scenarios to highlight different CPU utilization patterns. Below are conversational descriptions of each test, with the exact stress-ng invocation shown as a code block.

### 1. Full Load Test
```bash
stress-ng --cpu $(nproc) --timeout $TEST_DURATION --metrics-brief
```
In this test, stress-ng spawns workers equal to the total number of CPU cores. This fully saturates the system and reveals maximum throughput and thermal behavior under heavy, sustained compute load.

### 2. Half Load Test
```bash
stress-ng --cpu $(($(nproc) / 2)) --timeout $TEST_DURATION --metrics-brief
```
Here we simulate a moderate load by using half of the available cores. On multi-core systems, this shows how well the CPU scales when not fully loaded. On single-core systems, the script clamps the worker count to one to avoid a zero-worker scenario, effectively mirroring a full-load test.

### 3. Single Core Test
```bash
stress-ng --cpu 1 --timeout $TEST_DURATION --metrics-brief
```
This test restricts stress-ng to a single worker, allowing you to measure per-core performance and single-threaded efficiency. It helps identify bottlenecks that only show up when one core is handling the entire workload.

## Understanding the Architecture Differences

### Example 1: comparing Intel Xeon E5-2686 v4 (1 core) vs Arm Neoverse-N1 (2 cores):

### Full Load Results
- **Intel**: 91.6% CPU utilization
- **Arm**: 91.8% CPU utilization
- **Analysis**: Both architectures achieve similar utilization when fully loaded, indicating comparable efficiency at maximum capacity

### Half Load Results - The Key Difference
- **Intel**: 91.9% CPU utilization (still nearly maxed out)
- **Arm**: 45.7% CPU utilization (~50%)
- **Why this happens**:
  - The benchmark script originally did integer division for half-load (`nproc/2`), so on a 1-core Intel box that yields 0. Stress-ng defaults to at least one worker, effectively still saturating the single core. The script has been updated to clamp half-load to a minimum of one core.
  - On the 2-core Arm system, one stress-ng worker runs across two cores, giving ~50% of capacity. Measurement and OS scheduling overhead (and how we average per-core busy%) yield ~46% rather than a perfect 50%.
  - This both shows **linear core-scaling** on Arm and highlights how tooling/OS behavior can affect the exact numbers.

### Single Core Results
- **Intel**: 91.5% CPU utilization
- **Arm**: 45.8% CPU utilization (~46%)
- **Analysis**:
  - On Intel the single stress-ng worker fully saturates the lone core.
  - On Arm the OS schedules that one worker on a single core (per-core breakdown shows one ≈91% busy and the other ≈1% idle), averaging ~46%. This illustrates per-core efficiency differences and how scheduling affects the overall average.

### Example 2: comparing ARM Neoverse-V1 (16 cores) vs Intel Xeon Platinum 8488C (32 cores):

### Full Load Results
- **ARM c7g.4xlarge**: 91.2% CPU utilization
- **Intel c7i.8xlarge**: 90.9% CPU utilization
- **Analysis**: Both platforms exhibit similar high utilization when fully loaded, showing effective core saturation under maximum stress.

### Half Load Results - The Key Difference
- **ARM**: 45.6% CPU utilization
- **Intel**: 45.5% CPU utilization
- **Why this happens**:
  - On ARM, 8 stress-ng workers on 16 cores yield ~50% capacity; measurement/averaging overhead results in ~45.6%.
  - On Intel, 16 stress-ng workers on 32 cores yield ~50% capacity; measurement overhead results in ~45.5%.
  - Demonstrates linear core-scaling on both architectures and highlights how tool/OS measurement subtleties affect exact numbers.

### Single Core Results
- **ARM**: 5.8% CPU utilization
- **Intel**: 2.9% CPU utilization
- **Analysis**:
  - A single stress-ng worker on 16-core ARM maps to one core, averaging 5.8% (ideal 6.25%) due to overhead.
  - A single stress-ng worker on 32-core Intel maps to one core, averaging 2.9% (ideal 3.125%).
  - Highlights the dilution effect of increasing core counts on single-threaded utilization and the underlying per-core performance difference.

### Example 2: comparing ARM Neoverse-V1 (16 cores) vs Intel Xeon Platinum 8488C (32 cores):

### Full Load Results
- **ARM c7g.4xlarge**: 91.2% CPU utilization
- **Intel c7i.8xlarge**: 90.9% CPU utilization
- **Analysis**: Both platforms exhibit similar high utilization under full parallel load, showing that each architecture can effectively saturate all cores when maximally stressed.

### Half Load Results - The Key Difference
- **ARM**: 45.6% CPU utilization
- **Intel**: 45.5% CPU utilization
- **Why this happens**:
  - On ARM, using 8 workers on 16 cores yields ~50% capacity; measurement/averaging overhead results in ~45.6%.
  - On Intel, using 16 workers on 32 cores yields ~50% capacity; measurement overhead yields ~45.5%.
  - Demonstrates linear core-scaling on both architectures and underscores how tooling/OS measurement subtleties affect exact values.

### Single Core Results
- **ARM**: 5.8% CPU utilization
- **Intel**: 2.9% CPU utilization
- **Analysis**:
  - One stress-ng worker on 16-core ARM maps to one core, averaging 5.8% rather than the ideal 6.25% due to overhead.
  - One stress-ng worker on 32-core Intel maps to one core, averaging 2.9% rather than the ideal 3.125%.
  - This dilution effect shows how larger core counts reduce single-threaded utilization percentages and highlights per-core performance differences.

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

- - **Intel x86 Characteristics**:
-   - Complex cores with high single-threaded performance
-   - May show high utilization even with reduced workloads due to fewer, more powerful cores
-   - Better suited for single-threaded or lightly-threaded applications
-   - Supports Simultaneous Multithreading (SMT/Hyper-Threading) on many Xeon CPUs, exposing multiple logical threads per physical core. SMT can boost throughput for parallel workloads but can also split per-core utilization across threads.

- - **Arm Characteristics**:
-   - Simpler, more efficient cores designed for parallel workloads
-   - Shows linear scaling with core count (50% load = 50% utilization)
-   - Better suited for highly-parallel, multi-threaded applications
-   - More predictable power consumption patterns
-   - Typically does not support SMT (Neoverse-N1 is single-threaded per core), so each software thread maps one-to-one to a physical core, yielding consistent per-core performance and predictable utilization.

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