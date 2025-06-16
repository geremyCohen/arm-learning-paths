---
title: Virtualization Performance
weight: 1000

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Virtualization Performance

Virtualization performance measures how efficiently a system can run virtual machines (VMs) or containers. This includes metrics like VM startup time, hypervisor overhead, memory virtualization efficiency, I/O performance, and the impact of nested virtualization. As cloud computing and containerization continue to grow, virtualization performance has become increasingly important for modern workloads.

When comparing Intel/AMD (x86) versus Arm architectures, virtualization implementations can differ significantly due to architectural design choices, hardware virtualization extensions, and hypervisor optimizations. These differences can impact the performance, density, and efficiency of virtualized environments.

For more detailed information about virtualization performance, you can refer to:
- [Hardware-Assisted Virtualization](https://www.vmware.com/content/dam/digitalmarketing/vmware/en/pdf/techpaper/vmware-hardware-assisted-virtualization.pdf)
- [Arm Virtualization Extensions](https://developer.arm.com/documentation/102142/0100/Virtualization-architecture)

## Benchmarking Exercise: Comparing Virtualization Performance

In this exercise, we'll use various tools to measure and compare virtualization performance across Intel/AMD and Arm systems.

### Prerequisites

Ensure you have two Ubuntu VMs or physical machines:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications and virtualization extensions enabled.

### Step 1: Install Required Tools

Run the following commands on both systems:

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager \
                    docker.io containerd sysbench stress-ng python3 python3-matplotlib \
                    gnuplot build-essential git
```

### Step 2: Create Benchmark Script for KVM Performance

Create a file named `kvm_benchmark.sh` with the following content:

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
echo "Virtualization Extensions:"
if [[ "$(get_arch)" == "Intel/AMD (x86_64)" ]]; then
  lscpu | grep -E 'vmx|svm'
else
  lscpu | grep -E 'vhe|sve'
fi
echo ""

# Check if KVM is available
if [ ! -e /dev/kvm ]; then
  echo "KVM is not available on this system. Please enable virtualization in BIOS/UEFI."
  exit 1
fi

# Create a small VM disk image
echo "=== Creating VM disk image ==="
qemu-img create -f qcow2 benchmark_vm.qcow2 4G

# Download a minimal cloud image based on architecture
if [[ "$(get_arch)" == "Intel/AMD (x86_64)" ]]; then
  echo "Downloading x86_64 cloud image..."
  wget -O cloud-image.img https://cloud-images.ubuntu.com/minimal/releases/focal/release/ubuntu-20.04-minimal-cloudimg-amd64.img
else
  echo "Downloading arm64 cloud image..."
  wget -O cloud-image.img https://cloud-images.ubuntu.com/minimal/releases/focal/release/ubuntu-20.04-minimal-cloudimg-arm64.img
fi

# Create cloud-init configuration
cat > cloud-init.cfg << EOF
#cloud-config
password: password
chpasswd: { expire: False }
ssh_pwauth: True
EOF

# Create cloud-init ISO
echo "Creating cloud-init ISO..."
cloud-localds cloud-init.iso cloud-init.cfg

# Function to measure VM boot time
measure_vm_boot_time() {
  local vcpus=$1
  local memory=$2
  local iterations=$3
  
  echo "=== Measuring VM boot time with $vcpus vCPUs and ${memory}MB memory ==="
  
  # Run multiple iterations
  local total_time=0
  for i in $(seq 1 $iterations); do
    echo "Iteration $i/$iterations..."
    
    # Start time measurement
    local start_time=$(date +%s.%N)
    
    # Start VM and wait for it to boot
    qemu-system-$(uname -m) \
      -name benchmark-vm \
      -machine accel=kvm \
      -cpu host \
      -smp $vcpus \
      -m ${memory}M \
      -drive file=cloud-image.img,if=virtio \
      -drive file=cloud-init.iso,if=virtio \
      -nographic \
      -serial mon:stdio \
      -no-reboot \
      -display none \
      -daemonize
    
    # Wait for VM to boot (simplified approach)
    sleep 10
    
    # Get VM PID
    local vm_pid=$(pgrep -f "qemu-system.*benchmark-vm")
    
    # Kill VM
    if [ -n "$vm_pid" ]; then
      kill -9 $vm_pid
      wait $vm_pid 2>/dev/null || true
    fi
    
    # End time measurement
    local end_time=$(date +%s.%N)
    local elapsed=$(echo "$end_time - $start_time" | bc)
    total_time=$(echo "$total_time + $elapsed" | bc)
    
    echo "Boot time: $elapsed seconds"
    
    # Wait a bit before next iteration
    sleep 2
  done
  
  # Calculate average
  local avg_time=$(echo "scale=3; $total_time / $iterations" | bc)
  echo "Average boot time over $iterations iterations: $avg_time seconds"
  echo ""
  
  # Save result
  echo "$vcpus,$memory,$avg_time" >> vm_boot_times.csv
}

# Function to measure VM CPU performance
measure_vm_cpu_performance() {
  local vcpus=$1
  local memory=$2
  
  echo "=== Measuring VM CPU performance with $vcpus vCPUs and ${memory}MB memory ==="
  
  # Start VM
  qemu-system-$(uname -m) \
    -name benchmark-vm \
    -machine accel=kvm \
    -cpu host \
    -smp $vcpus \
    -m ${memory}M \
    -drive file=cloud-image.img,if=virtio \
    -drive file=cloud-init.iso,if=virtio \
    -nographic \
    -serial mon:stdio \
    -no-reboot \
    -display none \
    -daemonize
  
  # Wait for VM to boot
  sleep 15
  
  # Get VM PID
  local vm_pid=$(pgrep -f "qemu-system.*benchmark-vm")
  
  # Run CPU benchmark inside VM (this is a simplified approach)
  # In a real scenario, you would SSH into the VM and run benchmarks
  
  # For now, we'll measure host CPU utilization as a proxy
  echo "Measuring host CPU utilization while VM is running..."
  mpstat 1 10 | tee vm_cpu_${vcpus}_${memory}.txt
  
  # Kill VM
  if [ -n "$vm_pid" ]; then
    kill -9 $vm_pid
    wait $vm_pid 2>/dev/null || true
  fi
  
  echo ""
}

# Function to measure hypervisor overhead
measure_hypervisor_overhead() {
  local vcpus=$1
  local memory=$2
  
  echo "=== Measuring hypervisor overhead with $vcpus vCPUs and ${memory}MB memory ==="
  
  # Run native benchmark
  echo "Running native benchmark..."
  sysbench cpu --threads=$vcpus --time=10 run | tee native_cpu_benchmark.txt
  
  # Start VM
  qemu-system-$(uname -m) \
    -name benchmark-vm \
    -machine accel=kvm \
    -cpu host \
    -smp $vcpus \
    -m ${memory}M \
    -drive file=cloud-image.img,if=virtio \
    -drive file=cloud-init.iso,if=virtio \
    -nographic \
    -serial mon:stdio \
    -no-reboot \
    -display none \
    -daemonize
  
  # Wait for VM to boot
  sleep 15
  
  # Get VM PID
  local vm_pid=$(pgrep -f "qemu-system.*benchmark-vm")
  
  # Run CPU benchmark on host while VM is running
  echo "Running benchmark with VM running..."
  sysbench cpu --threads=$vcpus --time=10 run | tee vm_overhead_cpu_benchmark.txt
  
  # Kill VM
  if [ -n "$vm_pid" ]; then
    kill -9 $vm_pid
    wait $vm_pid 2>/dev/null || true
  fi
  
  # Calculate overhead
  local native_events=$(grep "events per second" native_cpu_benchmark.txt | awk '{print $4}')
  local vm_events=$(grep "events per second" vm_overhead_cpu_benchmark.txt | awk '{print $4}')
  local overhead=$(echo "scale=2; (($native_events - $vm_events) / $native_events) * 100" | bc)
  
  echo "Native performance: $native_events events/sec"
  echo "Performance with VM: $vm_events events/sec"
  echo "Hypervisor overhead: $overhead%"
  echo ""
  
  # Save result
  echo "$vcpus,$memory,$native_events,$vm_events,$overhead" >> hypervisor_overhead.csv
}

# Initialize CSV files
echo "vcpus,memory_mb,boot_time_seconds" > vm_boot_times.csv
echo "vcpus,memory_mb,native_events_per_sec,vm_events_per_sec,overhead_percent" > hypervisor_overhead.csv

# Run boot time benchmarks with different configurations
measure_vm_boot_time 1 512 3
measure_vm_boot_time 2 1024 3
measure_vm_boot_time 4 2048 3

# Run CPU performance benchmarks
measure_vm_cpu_performance 1 512
measure_vm_cpu_performance 2 1024
measure_vm_cpu_performance 4 2048

# Measure hypervisor overhead
measure_hypervisor_overhead 1 512
measure_hypervisor_overhead 2 1024
measure_hypervisor_overhead 4 2048

# Clean up
echo "Cleaning up..."
rm -f benchmark_vm.qcow2 cloud-init.iso

echo "KVM benchmarks completed."
```

Make the script executable:

```bash
chmod +x kvm_benchmark.sh
```

### Step 3: Create Benchmark Script for Container Performance

Create a file named `container_benchmark.sh` with the following content:

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
echo "Docker Version:"
docker --version
echo ""

# Function to measure container startup time
measure_container_startup() {
  local iterations=$1
  local image=$2
  local description=$3
  
  echo "=== Measuring container startup time for $description ==="
  
  # Run multiple iterations
  local total_time=0
  for i in $(seq 1 $iterations); do
    echo "Iteration $i/$iterations..."
    
    # Start time measurement
    local start_time=$(date +%s.%N)
    
    # Start container
    local container_id=$(docker run -d $image sleep 10)
    
    # Wait for container to be running
    while [ "$(docker inspect -f '{{.State.Running}}' $container_id 2>/dev/null)" != "true" ]; do
      sleep 0.01
    done
    
    # End time measurement
    local end_time=$(date +%s.%N)
    local elapsed=$(echo "$end_time - $start_time" | bc)
    total_time=$(echo "$total_time + $elapsed" | bc)
    
    echo "Startup time: $elapsed seconds"
    
    # Clean up
    docker rm -f $container_id >/dev/null
    
    # Wait a bit before next iteration
    sleep 1
  done
  
  # Calculate average
  local avg_time=$(echo "scale=3; $total_time / $iterations" | bc)
  echo "Average startup time over $iterations iterations: $avg_time seconds"
  echo ""
  
  # Save result
  echo "$description,$avg_time" >> container_startup_times.csv
}

# Function to measure container CPU performance
measure_container_cpu_performance() {
  local threads=$1
  local image=$2
  local description=$3
  
  echo "=== Measuring container CPU performance for $description with $threads threads ==="
  
  # Run native benchmark
  echo "Running native benchmark..."
  sysbench cpu --threads=$threads --time=10 run | tee native_cpu_benchmark_$threads.txt
  
  # Run benchmark in container
  echo "Running benchmark in container..."
  docker run --rm $image sysbench cpu --threads=$threads --time=10 run | tee container_cpu_benchmark_${description// /_}_$threads.txt
  
  # Calculate overhead
  local native_events=$(grep "events per second" native_cpu_benchmark_$threads.txt | awk '{print $4}')
  local container_events=$(grep "events per second" container_cpu_benchmark_${description// /_}_$threads.txt | awk '{print $4}')
  local overhead=$(echo "scale=2; (($native_events - $container_events) / $native_events) * 100" | bc)
  
  echo "Native performance: $native_events events/sec"
  echo "Container performance: $container_events events/sec"
  echo "Container overhead: $overhead%"
  echo ""
  
  # Save result
  echo "$description,$threads,$native_events,$container_events,$overhead" >> container_cpu_performance.csv
}

# Function to measure container memory performance
measure_container_memory_performance() {
  local threads=$1
  local image=$2
  local description=$3
  
  echo "=== Measuring container memory performance for $description with $threads threads ==="
  
  # Run native benchmark
  echo "Running native benchmark..."
  sysbench memory --threads=$threads --memory-block-size=1K --memory-total-size=10G run | tee native_memory_benchmark_$threads.txt
  
  # Run benchmark in container
  echo "Running benchmark in container..."
  docker run --rm $image sysbench memory --threads=$threads --memory-block-size=1K --memory-total-size=10G run | tee container_memory_benchmark_${description// /_}_$threads.txt
  
  # Calculate overhead
  local native_speed=$(grep "transferred" native_memory_benchmark_$threads.txt | awk '{print $(NF-1)}')
  local container_speed=$(grep "transferred" container_memory_benchmark_${description// /_}_$threads.txt | awk '{print $(NF-1)}')
  local overhead=$(echo "scale=2; (($native_speed - $container_speed) / $native_speed) * 100" | bc)
  
  echo "Native performance: $native_speed MiB/sec"
  echo "Container performance: $container_speed MiB/sec"
  echo "Container overhead: $overhead%"
  echo ""
  
  # Save result
  echo "$description,$threads,$native_speed,$container_speed,$overhead" >> container_memory_performance.csv
}

# Pull benchmark images
echo "Pulling benchmark images..."
docker pull ubuntu:20.04
docker pull alpine:latest

# Create benchmark image with sysbench
echo "Creating benchmark image..."
cat > Dockerfile << EOF
FROM ubuntu:20.04
RUN apt-get update && apt-get install -y sysbench stress-ng
EOF

docker build -t sysbench-benchmark .

# Initialize CSV files
echo "image,startup_time_seconds" > container_startup_times.csv
echo "image,threads,native_events_per_sec,container_events_per_sec,overhead_percent" > container_cpu_performance.csv
echo "image,threads,native_speed_mib_sec,container_speed_mib_sec,overhead_percent" > container_memory_performance.csv

# Run startup time benchmarks
measure_container_startup 10 "ubuntu:20.04" "Ubuntu"
measure_container_startup 10 "alpine:latest" "Alpine"

# Run CPU performance benchmarks
measure_container_cpu_performance 1 "sysbench-benchmark" "Ubuntu with Sysbench"
measure_container_cpu_performance $(nproc) "sysbench-benchmark" "Ubuntu with Sysbench"

# Run memory performance benchmarks
measure_container_memory_performance 1 "sysbench-benchmark" "Ubuntu with Sysbench"
measure_container_memory_performance $(nproc) "sysbench-benchmark" "Ubuntu with Sysbench"

# Generate plots if gnuplot is available
if command -v gnuplot &> /dev/null; then
  echo "Generating plots..."
  
  # Container startup time plot
  gnuplot -e "set term png; set output 'container_startup_times.png'; \
              set title 'Container Startup Time'; \
              set xlabel 'Container Image'; \
              set ylabel 'Time (seconds)'; \
              set style data histogram; \
              set style fill solid; \
              plot 'container_startup_times.csv' using 2:xtic(1) title 'Startup Time'"
  
  # Container CPU performance plot
  gnuplot -e "set term png; set output 'container_cpu_performance.png'; \
              set title 'Container CPU Performance'; \
              set xlabel 'Configuration'; \
              set ylabel 'Events per Second'; \
              set style data histogram; \
              set style fill solid; \
              plot 'container_cpu_performance.csv' using 3:xtic(1) title 'Native', \
                   '' using 4 title 'Container'"
  
  # Container memory performance plot
  gnuplot -e "set term png; set output 'container_memory_performance.png'; \
              set title 'Container Memory Performance'; \
              set xlabel 'Configuration'; \
              set ylabel 'MiB/sec'; \
              set style data histogram; \
              set style fill solid; \
              plot 'container_memory_performance.csv' using 3:xtic(1) title 'Native', \
                   '' using 4 title 'Container'"
fi

echo "Container benchmarks completed."
```

Make the script executable:

```bash
chmod +x container_benchmark.sh
```

### Step 4: Run the Benchmarks

Execute the benchmark scripts on both systems:

```bash
# Run KVM benchmark (requires root privileges)
sudo ./kvm_benchmark.sh | tee kvm_benchmark_results.txt

# Run container benchmark
sudo ./container_benchmark.sh | tee container_benchmark_results.txt
```

### Step 5: Analyze the Results

Compare the results from both architectures, focusing on:

1. **VM Boot Time**: Compare how quickly VMs start up on each architecture.
2. **Hypervisor Overhead**: Compare the performance impact of running the hypervisor.
3. **Container Startup Time**: Compare how quickly containers start up on each architecture.
4. **Container Performance Overhead**: Compare the performance impact of containerization.
5. **Scaling Behavior**: Compare how virtualization performance scales with increasing vCPUs.

### Interpretation

When analyzing the results, consider these architecture-specific factors:

- **Hardware Virtualization Extensions**: Different implementations of virtualization support (Intel VT-x/AMD-V vs. Arm VHE).
- **Memory Management Unit (MMU) Virtualization**: Different approaches to virtualizing memory access.
- **I/O Virtualization**: Different implementations of I/O virtualization.
- **Instruction Set Complexity**: The impact of CISC vs. RISC instruction sets on virtualization.
- **Hypervisor Optimization**: Different levels of hypervisor optimization for each architecture.

## Relevance to Workloads

Virtualization performance benchmarking is particularly important for:

1. **Cloud Infrastructure**: Public and private cloud platforms running many VMs
2. **Container Orchestration**: Kubernetes clusters managing containerized applications
3. **Microservices**: Architectures with many isolated services
4. **Serverless Computing**: Functions-as-a-Service platforms
5. **Virtual Desktop Infrastructure (VDI)**: Hosting virtual desktops for remote users
6. **Development Environments**: Local virtualization for testing and development

Understanding virtualization performance differences between architectures helps you select the optimal platform for virtualized environments, potentially leading to better density, lower costs, and improved application performance.

## Advanced Analysis: Nested Virtualization

For a deeper understanding of architectural differences in virtualization, you can also test nested virtualization performance (running a VM inside another VM) if your hardware supports it:

```bash
# Inside a VM, check if nested virtualization is supported
cat /sys/module/kvm_intel/parameters/nested  # For Intel
cat /sys/module/kvm_amd/parameters/nested    # For AMD
cat /sys/module/kvm_arm/parameters/nested    # For Arm
```

This can reveal additional architectural differences in how efficiently each platform handles complex virtualization scenarios.

## Knowledge Check

1. If VM boot times are significantly faster on one architecture but container startup times are similar, what might this suggest?
   - A) The faster architecture has more efficient hardware virtualization extensions
   - B) The container runtime is not optimized for either architecture
   - C) The VM images are different sizes
   - D) The benchmark methodology is flawed

2. Which virtualization metric is most likely to show architectural differences rather than software implementation differences?
   - A) Container image pull time
   - B) VM disk I/O performance
   - C) Memory virtualization overhead
   - D) Network virtualization throughput

3. If hypervisor overhead increases more rapidly with VM count on one architecture compared to another, what might be the cause?
   - A) The architecture with higher scaling overhead has less efficient MMU virtualization
   - B) The operating system is not optimized for virtualization
   - C) The VMs are configured incorrectly
   - D) The benchmark is CPU-bound rather than testing virtualization overhead

Answers:
1. A) The faster architecture has more efficient hardware virtualization extensions
2. C) Memory virtualization overhead
3. A) The architecture with higher scaling overhead has less efficient MMU virtualization