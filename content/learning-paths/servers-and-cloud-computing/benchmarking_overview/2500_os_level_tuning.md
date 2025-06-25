---
title: OS-Level Tuning for Neoverse
weight: 2500
layout: learningpathall
---

## Understanding OS-Level Tuning for Neoverse

Operating system tuning plays a crucial role in maximizing the performance of Arm Neoverse processors in cloud environments. By configuring kernel parameters, CPU governors, and interrupt handling, you can significantly improve throughput, reduce latency, and enhance power efficiency without modifying application code.

For more detailed information about OS-level tuning for Neoverse, you can refer to:
- [Arm Neoverse Platform Optimization Guide](https://developer.arm.com/documentation/102042/latest/)
- [Linux Kernel Documentation](https://www.kernel.org/doc/html/latest/)
- [Tuning Linux for Arm Servers](https://community.arm.com/arm-community-blogs/b/infrastructure-solutions-blog)

## Benchmarking Exercise

### Prerequisites

Ensure you have:
- Completed the repository setup from the previous chapter
- ARM (aarch64) system with the bench_guide repository cloned

### Step 1: Navigate to Directory

Navigate to the benchmark directory:

```bash
cd bench_guide/2500_os_level_tuning
```

### Step 2: Install Dependencies

Run the setup script:

```bash
./setup.sh
```

### Step 3: Run the Benchmark

Execute the benchmark:

```bash
./benchmark.sh
```

### Step 4: Analyze the Results

Ensure you have an Arm VM with:
- Arm (aarch64) with Neoverse processors
- Root access to modify system parameters
- Linux kernel 5.4 or newer

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y linux-tools-common linux-tools-generic cpufrequtils sysstat numactl
```

### Step 5: Run the Benchmarks

Execute the benchmark scripts (requires root privileges):

```bash
sudo ./test_cpu_governors.sh
sudo ./test_irq_affinity.sh
sudo ./test_numa_policy.sh
```

## Key Neoverse OS-Level Tuning Techniques

### 1. CPU Frequency Governor Selection

### 2. Interrupt Affinity Optimization

### 3. NUMA Memory Policy

### 4. Transparent Hugepages

### 5. I/O Scheduler Tuning

## OS Tuning Trade-offs

| Tuning Parameter | Performance Impact | Power Impact | Latency Impact | Stability Impact |
|------------------|-------------------|--------------|----------------|-----------------|
| CPU Governor: performance | High (+) | High (-) | Low (+) | None |
| CPU Governor: powersave | High (-) | High (+) | High (-) | None |
| CPU Governor: schedutil | Medium (+) | Medium (+) | Medium (+) | None |
| IRQ Affinity: distribute | Medium (+) | Low (-) | Medium (+) | None |
| IRQ Affinity: consolidate | Low (-) | Medium (+) | High (-) | None |
| NUMA: local | High (+) | Low (+) | Medium (+) | None |
| NUMA: interleave | Medium (+) | Low (-) | Low (+) | None |
| THP: always | High (+) | Low (-) | Variable | Low (-) |
| THP: madvise | Medium (+) | None | None | None |

## When to Use Each Tuning Parameter

1. **Latency-Sensitive Workloads**:
   - CPU Governor: performance
   - IRQ Affinity: distribute or isolate
   - NUMA Policy: local or bind
   - THP: madvise or never

2. **Throughput-Oriented Workloads**:
   - CPU Governor: schedutil
   - IRQ Affinity: distribute
   - NUMA Policy: interleave
   - THP: always

3. **Power-Constrained Environments**:
   - CPU Governor: powersave or schedutil
   - IRQ Affinity: consolidate
   - NUMA Policy: local
   - THP: madvise

4. **Mixed Workloads**:
   - CPU Governor: schedutil
   - IRQ Affinity: distribute
   - NUMA Policy: local
   - THP: madvise

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| CPU Governors | ✓ | ✓ | ✓ |
| IRQ Affinity | ✓ | ✓ | ✓ |
| NUMA Policies | ✓ | ✓ | ✓ |
| Transparent Hugepages | ✓ | ✓ | ✓ |
| I/O Schedulers | ✓ | ✓ | ✓ |

All OS-level tuning techniques in this chapter work on all Neoverse processors.

## Further Reading

- [Linux CPUFreq Governors](https://www.kernel.org/doc/html/latest/admin-guide/pm/cpufreq.html)
- [Linux IRQ Affinity](https://www.kernel.org/doc/Documentation/IRQ-affinity.txt)
- [Linux NUMA Memory Policy](https://www.kernel.org/doc/html/latest/admin-guide/mm/numa_memory_policy.html)
- [Transparent Hugepages](https://www.kernel.org/doc/html/latest/admin-guide/mm/transhuge.html)
- [Linux I/O Schedulers](https://www.kernel.org/doc/Documentation/block/switching-sched.txt)

## Relevance to Cloud Computing Workloads

OS-level tuning is particularly important for cloud computing on Neoverse:

1. **Performance Consistency**: Proper tuning reduces performance variability
2. **Resource Utilization**: Optimized settings improve hardware utilization
3. **Multi-tenant Efficiency**: NUMA and IRQ tuning improve isolation between workloads
4. **Power Efficiency**: Governor selection impacts energy consumption and costs
5. **Latency Reduction**: IRQ and scheduler tuning can significantly reduce tail latencies

Understanding OS-level tuning helps you:
- Maximize performance per dollar in cloud environments
- Improve application responsiveness and predictability
- Reduce infrastructure costs through better resource utilization
- Balance performance and power efficiency requirements