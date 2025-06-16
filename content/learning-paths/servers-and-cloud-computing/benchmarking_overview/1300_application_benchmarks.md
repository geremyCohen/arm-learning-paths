---
title: Application-Specific Benchmarking
weight: 1300

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Application-Specific Benchmarking

While synthetic benchmarks provide valuable insights into specific system components, application-specific benchmarking measures real-world performance with actual software that users run. This approach provides the most relevant performance data for making architecture decisions, as it captures the complex interactions between different system components under realistic workloads.

When comparing Intel/AMD (x86) versus Arm architectures, application benchmarks can reveal performance differences that synthetic tests might miss, including the impact of compiler optimizations, library implementations, and application-specific code paths that might favor one architecture over another.

For more detailed information about application benchmarking, you can refer to:
- [TPC Benchmarks](http://www.tpc.org/information/benchmarks.asp)
- [SPEC CPU Benchmarks](https://www.spec.org/cpu/)
- [Web Server Benchmarking](https://www.nginx.com/blog/nginx-plus-sizing-guide-how-we-tested/)

## Benchmarking Exercise: Comparing Application Performance

In this exercise, we'll benchmark several common applications across Intel/AMD and Arm architectures to understand real-world performance differences.

### Prerequisites

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Install Required Tools

Run the following commands on both VMs:

```bash
sudo apt update
sudo apt install -y apache2 mysql-server python3 python3-pip python3-matplotlib gnuplot \
                    build-essential git curl wget sysbench ab jmeter
```

### Step 2: Web Server Benchmark

Create a file named `web_server_benchmark.sh` with the following content:

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
echo "Apache Version:"
apache2 -v | head -n 1
echo ""

# Function to run Apache benchmark
run_apache_benchmark() {
  local concurrency=$1
  local requests=$2
  local file_size=$3
  local description="$concurrency concurrent connections, $requests requests, ${file_size}KB file"
  
  echo "=== Running Apache Benchmark: $description ==="
  
  # Create test file of specified size
  dd if=/dev/urandom of=/var/www/html/test_${file_size}KB.bin bs=1K count=$file_size
  
  # Restart Apache
  sudo systemctl restart apache2
  
  # Wait for Apache to start
  sleep 2
  
  # Run benchmark
  ab -c $concurrency -n $requests http://localhost/test_${file_size}KB.bin | tee apache_bench_${concurrency}_${requests}_${file_size}KB.txt
  
  # Extract results
  local rps=$(grep "Requests per second" apache_bench_${concurrency}_${requests}_${file_size}KB.txt | awk '{print $4}')
  local latency=$(grep "Time per request" apache_bench_${concurrency}_${requests}_${file_size}KB.txt | head -n 1 | awk '{print $4}')
  
  # Save result
  echo "$concurrency,$requests,$file_size,$rps,$latency" >> apache_results.csv
  
  echo ""
}

# Function to run Apache benchmark with PHP
run_php_benchmark() {
  local concurrency=$1
  local requests=$2
  local description="$concurrency concurrent connections, $requests requests, PHP processing"
  
  echo "=== Running PHP Benchmark: $description ==="
  
  # Install PHP if not already installed
  if ! command -v php &> /dev/null; then
    sudo apt install -y php libapache2-mod-php
    sudo systemctl restart apache2
  fi
  
  # Create PHP test file
  cat > /var/www/html/test.php << 'EOF'
<?php
// Simple CPU-intensive task
$start = microtime(true);

// Perform some calculations
$iterations = 100000;
$result = 0;
for ($i = 0; $i < $iterations; $i++) {
    $result += sin($i) * cos($i);
}

// Calculate some prime numbers
function isPrime($num) {
    if ($num <= 1) return false;
    if ($num <= 3) return true;
    if ($num % 2 == 0 || $num % 3 == 0) return false;
    $i = 5;
    while ($i * $i <= $num) {
        if ($num % $i == 0 || $num % ($i + 2) == 0) return false;
        $i += 6;
    }
    return true;
}

$primes = 0;
for ($i = 0; $i < 10000; $i++) {
    if (isPrime($i)) $primes++;
}

$duration = microtime(true) - $start;
echo "Calculation completed in {$duration} seconds. Found {$primes} prime numbers. Result: {$result}";
?>
EOF
  
  # Restart Apache
  sudo systemctl restart apache2
  
  # Wait for Apache to start
  sleep 2
  
  # Run benchmark
  ab -c $concurrency -n $requests http://localhost/test.php | tee php_bench_${concurrency}_${requests}.txt
  
  # Extract results
  local rps=$(grep "Requests per second" php_bench_${concurrency}_${requests}.txt | awk '{print $4}')
  local latency=$(grep "Time per request" php_bench_${concurrency}_${requests}.txt | head -n 1 | awk '{print $4}')
  
  # Save result
  echo "$concurrency,$requests,$rps,$latency" >> php_results.csv
  
  echo ""
}

# Initialize CSV files
echo "concurrency,requests,file_size_kb,requests_per_second,latency_ms" > apache_results.csv
echo "concurrency,requests,requests_per_second,latency_ms" > php_results.csv

# Run Apache benchmarks with different configurations
run_apache_benchmark 1 1000 10
run_apache_benchmark 10 1000 10
run_apache_benchmark 50 1000 10
run_apache_benchmark 100 1000 10

run_apache_benchmark 10 1000 100
run_apache_benchmark 10 1000 1000

# Run PHP benchmarks
run_php_benchmark 1 100
run_php_benchmark 10 100
run_php_benchmark 50 100

# Generate plots if gnuplot is available
if command -v gnuplot &> /dev/null; then
  echo "Generating plots..."
  
  # Apache concurrency plot
  gnuplot -e "set term png; set output 'apache_concurrency.png'; \
              set title 'Apache Performance vs Concurrency'; \
              set xlabel 'Concurrency'; \
              set ylabel 'Requests per Second'; \
              set logscale x; \
              plot 'apache_results.csv' using 1:4 with linespoints title 'RPS'"
  
  # Apache file size plot
  gnuplot -e "set term png; set output 'apache_filesize.png'; \
              set title 'Apache Performance vs File Size'; \
              set xlabel 'File Size (KB)'; \
              set ylabel 'Requests per Second'; \
              set logscale x; \
              plot 'apache_results.csv' using 3:4 with linespoints title 'RPS'"
  
  # PHP concurrency plot
  gnuplot -e "set term png; set output 'php_concurrency.png'; \
              set title 'PHP Performance vs Concurrency'; \
              set xlabel 'Concurrency'; \
              set ylabel 'Requests per Second'; \
              set logscale x; \
              plot 'php_results.csv' using 1:3 with linespoints title 'RPS'"
fi

echo "Web server benchmarks completed."
```

Make the script executable:

```bash
chmod +x web_server_benchmark.sh
```

### Step 3: Database Benchmark

Create a file named `database_benchmark.sh` with the following content:

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
echo "MySQL Version:"
mysql --version
echo ""

# Function to run MySQL OLTP benchmark
run_mysql_oltp_benchmark() {
  local threads=$1
  local table_size=$2
  local duration=$3
  local description="$threads threads, $table_size rows, $duration seconds"
  
  echo "=== Running MySQL OLTP Benchmark: $description ==="
  
  # Prepare database
  echo "Preparing database..."
  sysbench oltp_read_write --db-driver=mysql --mysql-db=test --mysql-user=root --table-size=$table_size prepare
  
  # Run benchmark
  echo "Running benchmark..."
  sysbench oltp_read_write --db-driver=mysql --mysql-db=test --mysql-user=root --table-size=$table_size --threads=$threads --time=$duration run | tee mysql_oltp_${threads}_${table_size}.txt
  
  # Extract results
  local tps=$(grep "transactions:" mysql_oltp_${threads}_${table_size}.txt | awk '{print $3}')
  local latency=$(grep "avg:" mysql_oltp_${threads}_${table_size}.txt | awk '{print $2}')
  
  # Save result
  echo "$threads,$table_size,$duration,$tps,$latency" >> mysql_oltp_results.csv
  
  # Clean up
  sysbench oltp_read_write --db-driver=mysql --mysql-db=test --mysql-user=root --table-size=$table_size cleanup
  
  echo ""
}

# Function to run MySQL read-only benchmark
run_mysql_readonly_benchmark() {
  local threads=$1
  local table_size=$2
  local duration=$3
  local description="$threads threads, $table_size rows, $duration seconds"
  
  echo "=== Running MySQL Read-Only Benchmark: $description ==="
  
  # Prepare database
  echo "Preparing database..."
  sysbench oltp_read_only --db-driver=mysql --mysql-db=test --mysql-user=root --table-size=$table_size prepare
  
  # Run benchmark
  echo "Running benchmark..."
  sysbench oltp_read_only --db-driver=mysql --mysql-db=test --mysql-user=root --table-size=$table_size --threads=$threads --time=$duration run | tee mysql_readonly_${threads}_${table_size}.txt
  
  # Extract results
  local tps=$(grep "transactions:" mysql_readonly_${threads}_${table_size}.txt | awk '{print $3}')
  local latency=$(grep "avg:" mysql_readonly_${threads}_${table_size}.txt | awk '{print $2}')
  
  # Save result
  echo "$threads,$table_size,$duration,$tps,$latency" >> mysql_readonly_results.csv
  
  # Clean up
  sysbench oltp_read_only --db-driver=mysql --mysql-db=test --mysql-user=root --table-size=$table_size cleanup
  
  echo ""
}

# Ensure MySQL is running
sudo systemctl start mysql

# Create test database if it doesn't exist
mysql -u root -e "CREATE DATABASE IF NOT EXISTS test;"

# Initialize CSV files
echo "threads,table_size,duration,transactions_per_sec,latency_ms" > mysql_oltp_results.csv
echo "threads,table_size,duration,transactions_per_sec,latency_ms" > mysql_readonly_results.csv

# Run MySQL OLTP benchmarks with different configurations
run_mysql_oltp_benchmark 1 10000 60
run_mysql_oltp_benchmark 4 10000 60
run_mysql_oltp_benchmark 16 10000 60
run_mysql_oltp_benchmark 32 10000 60

# Run MySQL read-only benchmarks
run_mysql_readonly_benchmark 1 10000 60
run_mysql_readonly_benchmark 4 10000 60
run_mysql_readonly_benchmark 16 10000 60
run_mysql_readonly_benchmark 32 10000 60

# Generate plots if gnuplot is available
if command -v gnuplot &> /dev/null; then
  echo "Generating plots..."
  
  # MySQL OLTP threads plot
  gnuplot -e "set term png; set output 'mysql_oltp_threads.png'; \
              set title 'MySQL OLTP Performance vs Threads'; \
              set xlabel 'Threads'; \
              set ylabel 'Transactions per Second'; \
              set logscale x; \
              plot 'mysql_oltp_results.csv' using 1:4 with linespoints title 'TPS'"
  
  # MySQL read-only threads plot
  gnuplot -e "set term png; set output 'mysql_readonly_threads.png'; \
              set title 'MySQL Read-Only Performance vs Threads'; \
              set xlabel 'Threads'; \
              set ylabel 'Transactions per Second'; \
              set logscale x; \
              plot 'mysql_readonly_results.csv' using 1:4 with linespoints title 'TPS'"
  
  # Compare OLTP vs read-only
  gnuplot -e "set term png; set output 'mysql_compare.png'; \
              set title 'MySQL OLTP vs Read-Only Performance'; \
              set xlabel 'Threads'; \
              set ylabel 'Transactions per Second'; \
              set logscale x; \
              plot 'mysql_oltp_results.csv' using 1:4 with linespoints title 'OLTP', \
                   'mysql_readonly_results.csv' using 1:4 with linespoints title 'Read-Only'"
fi

echo "Database benchmarks completed."
```

Make the script executable:

```bash
chmod +x database_benchmark.sh
```

### Step 4: File Compression Benchmark

Create a file named `compression_benchmark.sh` with the following content:

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
echo ""

# Install compression tools if not already installed
sudo apt install -y gzip bzip2 xz-utils lz4 zstd

# Function to create test file
create_test_file() {
  local size_mb=$1
  
  echo "Creating ${size_mb}MB test file..."
  dd if=/dev/urandom of=test_file_${size_mb}MB bs=1M count=$size_mb
}

# Function to run compression benchmark
run_compression_benchmark() {
  local tool=$1
  local level=$2
  local threads=$3
  local file=$4
  local description="$tool level $level, $threads threads, $file"
  
  echo "=== Running Compression Benchmark: $description ==="
  
  # Measure compression time and ratio
  local start_time=$(date +%s.%N)
  
  case $tool in
    gzip)
      gzip -$level -c $file > $file.gz
      compressed_file=$file.gz
      ;;
    bzip2)
      bzip2 -$level -c $file > $file.bz2
      compressed_file=$file.bz2
      ;;
    xz)
      xz -$level -T$threads -c $file > $file.xz
      compressed_file=$file.xz
      ;;
    lz4)
      lz4 -$level -c $file > $file.lz4
      compressed_file=$file.lz4
      ;;
    zstd)
      zstd -$level -T$threads -c $file > $file.zst
      compressed_file=$file.zst
      ;;
    *)
      echo "Unknown compression tool: $tool"
      return 1
      ;;
  esac
  
  local end_time=$(date +%s.%N)
  local compression_time=$(echo "$end_time - $start_time" | bc)
  
  # Calculate compression ratio
  local original_size=$(stat -c %s $file)
  local compressed_size=$(stat -c %s $compressed_file)
  local ratio=$(echo "scale=2; $original_size / $compressed_size" | bc)
  
  # Measure decompression time
  local start_time=$(date +%s.%N)
  
  case $tool in
    gzip)
      gzip -d -c $file.gz > /dev/null
      ;;
    bzip2)
      bzip2 -d -c $file.bz2 > /dev/null
      ;;
    xz)
      xz -d -c $file.xz > /dev/null
      ;;
    lz4)
      lz4 -d -c $file.lz4 > /dev/null
      ;;
    zstd)
      zstd -d -c $file.zst > /dev/null
      ;;
  esac
  
  local end_time=$(date +%s.%N)
  local decompression_time=$(echo "$end_time - $start_time" | bc)
  
  # Calculate throughput
  local compression_throughput=$(echo "scale=2; $original_size / $compression_time / 1048576" | bc)
  local decompression_throughput=$(echo "scale=2; $original_size / $decompression_time / 1048576" | bc)
  
  echo "Compression time: $compression_time seconds"
  echo "Compression ratio: $ratio:1"
  echo "Compression throughput: $compression_throughput MB/s"
  echo "Decompression time: $decompression_time seconds"
  echo "Decompression throughput: $decompression_throughput MB/s"
  
  # Save result
  echo "$tool,$level,$threads,$file,$compression_time,$ratio,$compression_throughput,$decompression_time,$decompression_throughput" >> compression_results.csv
  
  # Clean up
  rm -f $compressed_file
  
  echo ""
}

# Initialize CSV file
echo "tool,level,threads,file,compression_time,ratio,compression_throughput,decompression_time,decompression_throughput" > compression_results.csv

# Create test files
create_test_file 100
create_test_file 500

# Run compression benchmarks
run_compression_benchmark "gzip" 1 1 "test_file_100MB"
run_compression_benchmark "gzip" 9 1 "test_file_100MB"
run_compression_benchmark "bzip2" 1 1 "test_file_100MB"
run_compression_benchmark "bzip2" 9 1 "test_file_100MB"
run_compression_benchmark "xz" 1 1 "test_file_100MB"
run_compression_benchmark "xz" 6 1 "test_file_100MB"
run_compression_benchmark "lz4" 1 1 "test_file_100MB"
run_compression_benchmark "lz4" 9 1 "test_file_100MB"
run_compression_benchmark "zstd" 1 1 "test_file_100MB"
run_compression_benchmark "zstd" 19 1 "test_file_100MB"

# Run multi-threaded compression benchmarks
run_compression_benchmark "xz" 6 $(nproc) "test_file_500MB"
run_compression_benchmark "zstd" 19 $(nproc) "test_file_500MB"

# Generate plots if gnuplot is available
if command -v gnuplot &> /dev/null; then
  echo "Generating plots..."
  
  # Compression throughput plot
  gnuplot -e "set term png; set output 'compression_throughput.png'; \
              set title 'Compression Throughput'; \
              set xlabel 'Compression Tool'; \
              set ylabel 'Throughput (MB/s)'; \
              set style data histogram; \
              set style fill solid; \
              set xtics rotate by -45; \
              plot 'compression_results.csv' using 7:xtic(strcol(1).' '.strcol(2)) title 'Compression'"
  
  # Decompression throughput plot
  gnuplot -e "set term png; set output 'decompression_throughput.png'; \
              set title 'Decompression Throughput'; \
              set xlabel 'Compression Tool'; \
              set ylabel 'Throughput (MB/s)'; \
              set style data histogram; \
              set style fill solid; \
              set xtics rotate by -45; \
              plot 'compression_results.csv' using 9:xtic(strcol(1).' '.strcol(2)) title 'Decompression'"
  
  # Compression ratio plot
  gnuplot -e "set term png; set output 'compression_ratio.png'; \
              set title 'Compression Ratio'; \
              set xlabel 'Compression Tool'; \
              set ylabel 'Ratio'; \
              set style data histogram; \
              set style fill solid; \
              set xtics rotate by -45; \
              plot 'compression_results.csv' using 6:xtic(strcol(1).' '.strcol(2)) title 'Ratio'"
fi

# Clean up
rm -f test_file_100MB test_file_500MB

echo "Compression benchmarks completed."
```

Make the script executable:

```bash
chmod +x compression_benchmark.sh
```

### Step 5: Run the Benchmarks

Execute the benchmark scripts on both VMs:

```bash
# Run web server benchmark
sudo ./web_server_benchmark.sh | tee web_server_benchmark_results.txt

# Run database benchmark
sudo ./database_benchmark.sh | tee database_benchmark_results.txt

# Run compression benchmark
./compression_benchmark.sh | tee compression_benchmark_results.txt
```

### Step 6: Analyze the Results

Compare the results from both architectures, focusing on:

1. **Web Server Performance**: Compare requests per second and latency across different concurrency levels and file sizes.
2. **Database Performance**: Compare transactions per second and latency for OLTP and read-only workloads.
3. **Compression Performance**: Compare compression/decompression throughput and ratios for different algorithms.
4. **Scaling Behavior**: Compare how performance scales with increasing threads or concurrency.
5. **Workload Sensitivity**: Identify which workloads show the largest performance differences between architectures.

### Interpretation

When analyzing the results, consider these application-specific factors:

- **Web Server**: Different architectures may handle connection management, request parsing, and static file serving differently.
- **Database**: Query execution, join algorithms, and buffer management can vary in efficiency across architectures.
- **Compression**: Different algorithms may leverage architecture-specific instructions and memory access patterns.
- **PHP Processing**: Interpreter performance and JIT compilation efficiency can vary between architectures.

## Relevance to Workloads

Application benchmarking is directly relevant to real-world deployments:

1. **Web Servers**: E-commerce sites, content management systems, API servers
2. **Databases**: Transaction processing, data warehousing, analytics
3. **Compression**: Backup systems, content delivery networks, log processing
4. **PHP Applications**: Content management systems, web applications, e-commerce platforms

Understanding application performance differences between architectures helps you make informed decisions about which platform is best suited for your specific workloads, potentially leading to significant cost savings and performance improvements.

## Best Practices for Application Benchmarking

For more accurate and meaningful results:

1. **Use Representative Data**: Ensure test data resembles production data in size and structure.
2. **Warm-up Period**: Allow applications to reach steady state before measuring performance.
3. **Multiple Iterations**: Run tests multiple times to account for variability.
4. **Realistic Configurations**: Use production-like configurations rather than defaults.
5. **End-to-End Testing**: Measure complete application stacks rather than isolated components.

## Knowledge Check

1. If a web server shows similar static file serving performance on both architectures but significantly different PHP processing performance, what might this suggest?
   - A) The network stack is more efficient on one architecture
   - B) The PHP interpreter or JIT compiler performs differently on each architecture
   - C) The web server software is not properly optimized
   - D) The benchmark methodology is flawed

2. When benchmarking database performance, which metric is most important for an OLTP workload?
   - A) Sequential read throughput
   - B) Transactions per second
   - C) Query compilation time
   - D) Database size on disk

3. If compression benchmarks show that one architecture performs better with zstd but worse with gzip compared to another architecture, what might this indicate?
   - A) One architecture has better support for newer algorithms
   - B) The benchmark is not measuring correctly
   - C) Different algorithms leverage different architectural features
   - D) The compression ratio is different between architectures

Answers:
1. B) The PHP interpreter or JIT compiler performs differently on each architecture
2. B) Transactions per second
3. C) Different algorithms leverage different architectural features