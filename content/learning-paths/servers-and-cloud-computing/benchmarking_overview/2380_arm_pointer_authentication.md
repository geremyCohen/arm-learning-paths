---
title: Arm Pointer Authentication
weight: 2380
layout: learningpathall
---

## Understanding Arm Pointer Authentication

Arm Pointer Authentication (PAC) is a security feature introduced in Armv8.3-A that helps protect against memory corruption attacks by cryptographically signing and verifying pointers. PAC adds authentication codes to unused bits of pointers, which are verified before the pointer is used, preventing attackers from manipulating function pointers, return addresses, and data pointers.

When comparing Intel/AMD (x86) versus Arm architectures, PAC represents a significant security advantage for Arm, as x86 does not have an equivalent hardware-based pointer protection mechanism. Intel's Control-flow Enforcement Technology (CET) addresses some similar threats but uses a different approach.

For more detailed information about Arm Pointer Authentication, you can refer to:
- [Arm Pointer Authentication](https://developer.arm.com/documentation/102376/latest/)
- [Armv8.3-A Security Features](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/armv8-a-architecture-2016-additions)
- [Pointer Authentication on ARMv8.3](https://www.qualcomm.com/media/documents/files/whitepaper-pointer-authentication-on-armv8-3.pdf)

## Benchmarking Exercise

### Prerequisites

Ensure you have:
- Completed the repository setup from the previous chapter
- ARM (aarch64) system with the bench_guide repository cloned

### Step 1: Navigate to Directory

Navigate to the benchmark directory:

```bash
cd bench_guide/arm_pointer_authentication
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

Ensure you have two Ubuntu VMs:
- One running on Intel/AMD (x86_64)
- One running on Arm (aarch64)

Both should have similar specifications for fair comparison.

### Step 1: Download and Run Setup Script

Download and run the setup script to install required tools:

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/arm_pointer_authentication/setup.sh
chmod +x setup.sh
./setup.sh
```

### Step 2: Run the Benchmark

Execute the benchmark script on both VMs:

```bash
curl -O https://raw.githubusercontent.com/geremyCohen/bench_guide/main/arm_pointer_authentication/benchmark.sh
chmod +x benchmark.sh
./benchmark.sh | tee arm_pointer_authentication_results.txt
```

### Step 3: Analyze the Results Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc
```

### Step 2: Check PAC Support

Create a file named `check_pac.c` with the following content:

Compile and run:

```bash
gcc -o check_pac check_pac.c
./check_pac
```

### Step 6: Run the Benchmark

Execute the benchmark script:

```bash
./run_pac_benchmark.sh
```

### Step 7: Analyze the Results

When analyzing the results, consider:

1. **PAC Overhead**: Measure the performance impact of enabling PAC.
2. **Security Benefits**: Consider the security improvements relative to the performance cost.
3. **Use Case Suitability**: Determine which applications can benefit most from PAC with minimal performance impact.

## Arm-specific PAC Optimizations

Arm architectures offer several optimization techniques to minimize the performance impact of Pointer Authentication:

### 1. Selective PAC Application

Create a file named `selective_pac.c`:

Compile with:

```bash
gcc -O3 -march=armv8.3-a+pauth selective_pac.c -o selective_pac
```

### 2. Key Arm PAC Optimization Techniques

1. **Selective PAC Application**: Apply PAC only to security-critical pointers:
   ```c
   // For security-critical function pointers
   func_ptr_t secure_func = __builtin_pauth_sign_unauthenticated(func, 0, 0);
   
   // For non-critical function pointers
   func_ptr_t regular_func = func;  // No PAC
   ```

2. **Compiler Flags for PAC**:
   ```bash
   # Enable PAC for return addresses only
   gcc -mbranch-protection=pac-ret
   
   # Enable PAC for return addresses and function pointers
   gcc -mbranch-protection=pac-ret+leaf
   
   # Enable full PAC protection
   gcc -mbranch-protection=standard
   ```

3. **Key Selection for Different Pointer Types**:
   ```c
   // Use different keys for different pointer types
   data_ptr_t data_ptr = __builtin_pauth_sign_unauthenticated(ptr, 1, 0);  // Data key
   func_ptr_t func_ptr = __builtin_pauth_sign_unauthenticated(ptr, 0, 0);  // Instruction key
   ```

4. **Caching Authenticated Pointers**:
   ```c
   // Authenticate once, use multiple times
   func_ptr_t auth_ptr = __builtin_pauth_auth(signed_ptr, 0, 0);
   
   // Use the authenticated pointer multiple times
   for (int i = 0; i < count; i++) {
       auth_ptr();
   }
   ```

5. **Combining PAC with Other Security Features**:
   ```c
   // Use PAC with BTI (Branch Target Identification)
   gcc -march=armv8.5-a+pauth+bti -mbranch-protection=pac-ret+bti
   ```

These PAC optimizations can help balance security and performance on Arm architectures, allowing you to apply strong protection to security-critical components while minimizing overhead for performance-sensitive code.

## Neoverse Compatibility

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| PAC     | ✗           | ✓           | ✓           |

Pointer Authentication availability:
- Neoverse N1: Not supported
- Neoverse V1: Fully supported
- Neoverse N2: Fully supported

The code in this chapter uses runtime detection to automatically use PAC when available and fall back to standard pointer protection on Neoverse N1.

## Further Reading

- [Arm Pointer Authentication](https://developer.arm.com/documentation/102376/latest/)
- [Arm Architecture Reference Manual - PAC](https://developer.arm.com/documentation/ddi0487/latest/)
- [Pointer Authentication on ARMv8.3](https://www.qualcomm.com/media/documents/files/whitepaper-pointer-authentication-on-armv8-3.pdf)
- [Linux Kernel PAC Support Documentation](https://www.kernel.org/doc/html/latest/arm64/pointer-authentication.html)
- [LLVM Pointer Authentication Documentation](https://llvm.org/docs/PointerAuthentication.html)

## Relevance to Workloads

Pointer Authentication is particularly important for:

1. **Security-Critical Applications**: Financial services, authentication systems
2. **Systems Processing Untrusted Input**: Web servers, parsers, interpreters
3. **Privileged Software**: Operating system kernels, hypervisors
4. **Applications with Complex Control Flow**: JIT compilers, interpreters
5. **Legacy C/C++ Codebases**: Applications vulnerable to memory corruption

Understanding PAC's capabilities and performance characteristics helps you:
- Improve application security with manageable performance impact
- Protect against control-flow hijacking attacks
- Balance security and performance requirements
- Make informed decisions about security feature adoption