---
title: Setting Up the Benchmark Repository
weight: 050
layout: learningpathall
---

## Setting Up Your Benchmarking Environment

Before diving into the individual benchmarking exercises, you'll need to set up the benchmark code repository on both your Intel/AMD (x86_64) and Arm (aarch64) systems. This repository contains all the source code, scripts, and tools needed for the benchmarking exercises in this learning path.

## Prerequisites

Ensure you have:
- Two Ubuntu systems: one Intel/AMD (x86_64) and one Arm (aarch64)
- Git installed on both systems
- Basic development tools (we'll install these as needed)

## Step 1: Clone the Benchmark Repository

On both systems, clone the benchmark repository:

```bash
git clone https://github.com/geremyCohen/bench_guide.git
cd bench_guide
```

## Step 2: Verify Repository Structure

Confirm the repository structure:

```bash
ls -la
```

You should see directories for each benchmarking topic:
- `cpu_utilization/` - CPU utilization benchmarks
- `memory_bandwidth/` - Memory bandwidth benchmarks
- `cache_performance/` - Cache performance benchmarks
- `atomic_operations/` - Atomic operations benchmarks
- `branch_prediction/` - Branch prediction benchmarks
- `simd_vector/` - SIMD and vector performance benchmarks
- And many more...

## Step 3: Install Basic Dependencies

Install the basic tools needed across all benchmarks:

```bash
sudo apt update
sudo apt install -y build-essential git curl
```

## Repository Organization

Each benchmark directory follows a consistent structure:

- `setup.sh` - Installs benchmark-specific dependencies
- `benchmark.sh` - Compiles and runs the benchmark
- `*.c` or `*.cpp` files - Benchmark source code
- `README.md` - Benchmark-specific documentation

## Usage Pattern

For each benchmarking exercise in this learning path:

1. Navigate to the appropriate directory (e.g., `cd cpu_utilization`)
2. Run the setup script: `./setup.sh`
3. Run the benchmark: `./benchmark.sh`
4. Analyze the results as described in each chapter

## Next Steps

You're now ready to proceed with the individual benchmarking exercises. Each subsequent chapter will direct you to the appropriate directory and provide specific instructions for running that benchmark.

The benchmark repository is designed to work identically on both Intel/AMD and Arm systems, allowing you to make direct performance comparisons between architectures using the same code and methodology.