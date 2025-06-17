---
title: Arm Pointer Authentication
weight: 2380

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Arm Pointer Authentication

Arm Pointer Authentication (PAC) is a security feature introduced in Armv8.3-A that helps protect against memory corruption attacks by cryptographically signing and verifying pointers. PAC adds authentication codes to unused bits of pointers, which are verified before the pointer is used, preventing attackers from manipulating function pointers, return addresses, and data pointers.

When comparing Intel/AMD (x86) versus Arm architectures, PAC represents a significant security advantage for Arm, as x86 does not have an equivalent hardware-based pointer protection mechanism. Intel's Control-flow Enforcement Technology (CET) addresses some similar threats but uses a different approach.

For more detailed information about Arm Pointer Authentication, you can refer to:
- [Arm Pointer Authentication](https://developer.arm.com/documentation/102376/latest/)
- [Armv8.3-A Security Features](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/armv8-a-architecture-2016-additions)
- [Pointer Authentication on ARMv8.3](https://www.qualcomm.com/media/documents/files/whitepaper-pointer-authentication-on-armv8-3.pdf)

## Benchmarking Exercise: Measuring PAC Performance Impact

In this exercise, we'll measure the performance impact of enabling Pointer Authentication on Arm architecture.

### Prerequisites

Ensure you have an Arm VM with PAC support:
- Arm (aarch64) with Armv8.3-A or newer architecture supporting PAC
- Linux kernel with PAC support enabled

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc
```

### Step 2: Check PAC Support

Create a file named `check_pac.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/auxv.h>

// Define constants if not available in headers
#ifndef HWCAP2_PACGA
#define HWCAP2_PACGA (1 << 30)
#endif

int main() {
    // Check if PAC is supported by the hardware
    unsigned long hwcap2 = getauxval(AT_HWCAP2);
    int pac_supported = (hwcap2 & HWCAP2_PACGA) != 0;
    
    printf("PAC hardware support: %s\n", pac_supported ? "Yes" : "No");
    
    if (pac_supported) {
        printf("PAC is available on this system\n");
        
        // Check if kernel has PAC enabled
        // This is a simplified check - actual detection may vary by system
        FILE *fp = fopen("/proc/cpuinfo", "r");
        if (fp) {
            char line[1024];
            int pac_enabled = 0;
            
            while (fgets(line, sizeof(line), fp)) {
                if (strstr(line, "pac") || strstr(line, "paca") || strstr(line, "pacg")) {
                    pac_enabled = 1;
                    break;
                }
            }
            
            fclose(fp);
            
            printf("PAC kernel support: %s\n", pac_enabled ? "Enabled" : "Not detected");
        }
    }
    
    return 0;
}
```

Compile and run:

```bash
gcc -o check_pac check_pac.c
./check_pac
```

### Step 3: Create PAC Benchmark

Create a file named `pac_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ITERATIONS 1000000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Function pointer type
typedef void (*func_ptr_t)(void);

// Simple function to be called through pointer
void target_function() {
    // Do nothing, just a target for function pointers
    asm volatile("" ::: "memory");
}

#ifdef __aarch64__
// Sign a function pointer using PAC (if available)
func_ptr_t sign_function_pointer(func_ptr_t ptr) {
    #if __ARM_FEATURE_PAC_DEFAULT
    return __builtin_pauth_sign_unauthenticated(ptr, 0, 0);
    #else
    return ptr;
    #endif
}

// Authenticate and call a signed function pointer
void call_authenticated_function(func_ptr_t signed_ptr) {
    #if __ARM_FEATURE_PAC_DEFAULT
    func_ptr_t auth_ptr = __builtin_pauth_auth(signed_ptr, 0, 0);
    auth_ptr();
    #else
    signed_ptr();
    #endif
}
#else
// Dummy implementations for non-Arm architectures
func_ptr_t sign_function_pointer(func_ptr_t ptr) {
    return ptr;
}

void call_authenticated_function(func_ptr_t signed_ptr) {
    signed_ptr();
}
#endif

int main() {
    printf("CPU Architecture: %s\n", 
        #ifdef __aarch64__
        "aarch64"
        #else
        "other"
        #endif
    );
    
    printf("PAC support in compiler: %s\n", 
        #if __ARM_FEATURE_PAC_DEFAULT
        "Yes"
        #else
        "No"
        #endif
    );
    
    // Benchmark standard function calls
    func_ptr_t func = target_function;
    double start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        func();
    }
    
    double end = get_time();
    double standard_time = end - start;
    
    printf("Standard function call time: %.6f seconds\n", standard_time);
    printf("Standard calls per second: %.2f million\n", ITERATIONS / standard_time / 1000000);
    
    // Benchmark PAC function calls
    func_ptr_t signed_func = sign_function_pointer(target_function);
    start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        call_authenticated_function(signed_func);
    }
    
    end = get_time();
    double pac_time = end - start;
    
    printf("PAC function call time: %.6f seconds\n", pac_time);
    printf("PAC calls per second: %.2f million\n", ITERATIONS / pac_time / 1000000);
    printf("PAC overhead: %.2f%%\n", ((pac_time / standard_time) - 1.0) * 100);
    
    return 0;
}
```

Compile with PAC support:

```bash
gcc -O3 -march=armv8.3-a+pauth pac_benchmark.c -o pac_benchmark
```

### Step 4: Create Return Address Signing Benchmark

Create a file named `pac_return_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ITERATIONS 1000000
#define CALL_DEPTH 10

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Recursive function without PAC
__attribute__((noinline))
int recursive_call_standard(int depth) {
    if (depth <= 0) return 0;
    return depth + recursive_call_standard(depth - 1);
}

// Recursive function with PAC (return address signing)
__attribute__((noinline))
#if __ARM_FEATURE_PAC_DEFAULT
__attribute__((pauth_return_address))
#endif
int recursive_call_pac(int depth) {
    if (depth <= 0) return 0;
    return depth + recursive_call_pac(depth - 1);
}

int main() {
    printf("CPU Architecture: %s\n", 
        #ifdef __aarch64__
        "aarch64"
        #else
        "other"
        #endif
    );
    
    printf("PAC support in compiler: %s\n", 
        #if __ARM_FEATURE_PAC_DEFAULT
        "Yes"
        #else
        "No"
        #endif
    );
    
    // Benchmark standard recursive calls
    volatile int result1 = 0;
    double start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        result1 = recursive_call_standard(CALL_DEPTH);
    }
    
    double end = get_time();
    double standard_time = end - start;
    
    printf("Standard recursive call time: %.6f seconds\n", standard_time);
    printf("Standard recursive calls per second: %.2f million\n", 
           ITERATIONS / standard_time / 1000000);
    
    // Benchmark PAC recursive calls
    volatile int result2 = 0;
    start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        result2 = recursive_call_pac(CALL_DEPTH);
    }
    
    end = get_time();
    double pac_time = end - start;
    
    printf("PAC recursive call time: %.6f seconds\n", pac_time);
    printf("PAC recursive calls per second: %.2f million\n", 
           ITERATIONS / pac_time / 1000000);
    printf("PAC recursive call overhead: %.2f%%\n", 
           ((pac_time / standard_time) - 1.0) * 100);
    
    // Verify results are the same
    printf("Results: %d %d\n", result1, result2);
    
    return 0;
}
```

Compile with PAC return address signing:

```bash
gcc -O3 -march=armv8.3-a+pauth -mbranch-protection=pac-ret pac_return_benchmark.c -o pac_return_benchmark
```

### Step 5: Create Benchmark Script

Create a file named `run_pac_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Get architecture
arch=$(uname -m)
echo "Architecture: $arch"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"

# Check PAC support
echo "Checking PAC support..."
./check_pac

# Run PAC benchmark
echo "Running PAC function pointer benchmark..."
./pac_benchmark | tee pac_benchmark_results.txt

# Run PAC return address benchmark
echo "Running PAC return address benchmark..."
./pac_return_benchmark | tee pac_return_benchmark_results.txt

echo "Benchmark complete. Results saved to text files."
```

Make the script executable:

```bash
chmod +x run_pac_benchmark.sh
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

```c
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>

#define ITERATIONS 1000000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Function pointer type
typedef void (*func_ptr_t)(void);

// Simple function to be called through pointer
void target_function() {
    // Do nothing, just a target for function pointers
    asm volatile("" ::: "memory");
}

#ifdef __aarch64__
// Sign a function pointer using PAC (if available)
func_ptr_t sign_function_pointer(func_ptr_t ptr) {
    #if __ARM_FEATURE_PAC_DEFAULT
    return __builtin_pauth_sign_unauthenticated(ptr, 0, 0);
    #else
    return ptr;
    #endif
}

// Authenticate and call a signed function pointer
void call_authenticated_function(func_ptr_t signed_ptr) {
    #if __ARM_FEATURE_PAC_DEFAULT
    func_ptr_t auth_ptr = __builtin_pauth_auth(signed_ptr, 0, 0);
    auth_ptr();
    #else
    signed_ptr();
    #endif
}
#else
// Dummy implementations for non-Arm architectures
func_ptr_t sign_function_pointer(func_ptr_t ptr) {
    return ptr;
}

void call_authenticated_function(func_ptr_t signed_ptr) {
    signed_ptr();
}
#endif

// Security-critical function that should be protected
__attribute__((noinline))
void security_critical_function() {
    // Simulate security-critical operation
    asm volatile("" ::: "memory");
}

// Non-critical function that doesn't need protection
__attribute__((noinline))
void non_critical_function() {
    // Simulate non-critical operation
    asm volatile("" ::: "memory");
}

int main() {
    // Benchmark selective PAC application
    func_ptr_t critical_func = sign_function_pointer(security_critical_function);
    func_ptr_t non_critical_func = non_critical_function;  // No PAC
    
    // Benchmark critical function calls with PAC
    double start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        call_authenticated_function(critical_func);
    }
    
    double end = get_time();
    double critical_time = end - start;
    
    printf("Critical function call time (with PAC): %.6f seconds\n", critical_time);
    
    // Benchmark non-critical function calls without PAC
    start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        non_critical_func();
    }
    
    end = get_time();
    double non_critical_time = end - start;
    
    printf("Non-critical function call time (without PAC): %.6f seconds\n", non_critical_time);
    printf("PAC overhead for critical functions: %.2f%%\n", 
           ((critical_time / non_critical_time) - 1.0) * 100);
    
    return 0;
}
```

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