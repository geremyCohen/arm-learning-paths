---
title: Arm Cryptography Extensions
weight: 2250
layout: learningpathall
---

## Understanding Arm Cryptography Extensions

Arm Cryptography Extensions provide hardware acceleration for common cryptographic algorithms, significantly improving performance and energy efficiency compared to software implementations. These extensions are available in Armv8-A architectures and include dedicated instructions for AES encryption/decryption, SHA hashing, and other cryptographic operations.

When comparing Intel/AMD (x86) versus Arm architectures, both offer hardware acceleration for cryptography, but with different instruction sets and performance characteristics. Understanding these differences is crucial for security-sensitive applications where cryptographic performance is important.

For more detailed information about Arm Cryptography Extensions, you can refer to:
- [Arm Architecture Reference Manual](https://developer.arm.com/documentation/ddi0487/latest)
- [Arm Cryptography Extensions](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/armv8-a-architecture-evolution)
- [Cryptographic Hardware Acceleration](https://www.arm.com/why-arm/technologies/security)

## Benchmarking Exercise

### Prerequisites

Ensure you have:
- Completed the repository setup from the previous chapter
- ARM (aarch64) system with the bench_guide repository cloned

### Step 1: Navigate to Directory

Navigate to the benchmark directory:

```bash
cd bench_guide/arm_crypto_extensions
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

Ensure you have an Arm VM with cryptography extensions support:
- Arm (aarch64) with Armv8-A architecture supporting crypto extensions

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc openssl libssl-dev
```

### Step 5: Run the Benchmark

Execute the benchmark script:

```bash
./run_crypto_benchmark.sh
```

### Step 6: Analyze the Results

When analyzing the results, consider:

1. **Hardware Acceleration Impact**: Compare the performance with and without hardware acceleration.
2. **Algorithm Efficiency**: Different algorithms may benefit differently from hardware acceleration.
3. **Data Size Impact**: How performance scales with different data sizes.

## Arm-specific Cryptography Optimizations

Arm architectures offer several optimization techniques to further improve cryptographic performance:

### 1. Direct Use of Arm Crypto Instructions

Create a file named `arm_aes_direct.c`:

Compile with:

```bash
gcc -O3 -march=armv8-a+crypto arm_aes_direct.c -o arm_aes_direct
```

### 2. Key Arm Cryptography Optimization Techniques

1. **Compiler Flags for Crypto Extensions**:
   ```bash
   # Enable Arm crypto extensions
   gcc -march=armv8-a+crypto -O3 program.c -o program
   ```

2. **Direct Use of Crypto Instructions**:
   

3. **SHA Instructions**:
   

4. **Parallel Cryptographic Operations**:
   

5. **Optimized Key Expansion**:
   

These optimizations can provide significant performance improvements for cryptographic operations on Arm architectures, often achieving 5-20x speedups compared to software implementations.

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| AES     | ✓           | ✓           | ✓           |
| SHA1/SHA2 | ✓         | ✓           | ✓           |
| PMULL   | ✓           | ✓           | ✓           |
| SHA3/SM3 | ✗          | ✓           | ✓           |
| SM4     | ✗           | ✓           | ✓           |

Cryptography Extensions availability:
- Neoverse N1: Basic crypto extensions (AES, SHA1/SHA2, PMULL)
- Neoverse V1: Enhanced crypto extensions (adds SHA3, SM3, SM4)
- Neoverse N2: Enhanced crypto extensions (adds SHA3, SM3, SM4)

All code examples in this chapter work on all Neoverse processors.

## Further Reading

- [Arm Cryptography Extensions](https://developer.arm.com/documentation/ddi0500/latest/)
- [Arm Architecture Reference Manual - Cryptography Extensions](https://developer.arm.com/documentation/ddi0487/latest/)
- [Arm Neoverse Cryptography Optimization Guide](https://developer.arm.com/documentation/102042/latest/)
- [OpenSSL Acceleration on Arm](https://www.openssl.org/blog/blog/2021/03/25/OpenSSL-3-0-0-alpha16/)
- [Accelerating Cryptography with ARMv8](https://www.arm.com/blogs/blueprint/armv8-cryptography-extensions)

## Relevance to Workloads

Cryptography performance benchmarking is particularly important for:

1. **Secure Communications**: VPNs, TLS/SSL connections
2. **Disk Encryption**: Full-disk encryption systems
3. **Secure Storage**: Encrypted databases, file systems
4. **Authentication Systems**: Password hashing, token generation
5. **Blockchain Applications**: Mining, transaction verification

Understanding cryptographic performance differences between architectures helps you:
- Select the optimal architecture for security-sensitive workloads
- Choose appropriate cryptographic algorithms based on hardware support
- Balance security requirements with performance needs
- Optimize cryptographic operations for specific hardware