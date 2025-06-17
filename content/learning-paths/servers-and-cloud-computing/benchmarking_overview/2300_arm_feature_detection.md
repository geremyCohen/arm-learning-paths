---
title: Neoverse Feature Detection
weight: 2300

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Arm Neoverse Feature Detection

Arm Neoverse processors offer various security and performance features that differ across generations (N1, V1, N2). To write portable code that runs efficiently across all Neoverse processors, runtime feature detection is essential. This allows your code to use advanced features when available while providing fallbacks for older processors.

This approach is particularly important for cloud computing environments where you may not know which specific Neoverse processor your code will run on.

For more detailed information about Arm feature detection, you can refer to:
- [Arm Architecture Reference Manual](https://developer.arm.com/documentation/ddi0487/latest)
- [Arm Neoverse Platform Architecture](https://developer.arm.com/documentation/102136/latest/)
- [Arm Feature Detection in Linux](https://www.kernel.org/doc/html/latest/arm64/cpu-feature-registers.html)

## Feature Detection Implementation

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc
```

### Step 2: Create Comprehensive Feature Detection Code

Create a file named `neoverse_feature_detect.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/auxv.h>
#include <string.h>

// Define constants if not available in headers
#ifndef HWCAP_ATOMICS
#define HWCAP_ATOMICS (1 << 8)
#endif

#ifndef HWCAP_ASIMD
#define HWCAP_ASIMD (1 << 1)
#endif

#ifndef HWCAP_AES
#define HWCAP_AES (1 << 3)
#endif

#ifndef HWCAP_PMULL
#define HWCAP_PMULL (1 << 4)
#endif

#ifndef HWCAP_SHA1
#define HWCAP_SHA1 (1 << 5)
#endif

#ifndef HWCAP_SHA2
#define HWCAP_SHA2 (1 << 6)
#endif

#ifndef HWCAP_CRC32
#define HWCAP_CRC32 (1 << 7)
#endif

#ifndef HWCAP_SVE
#define HWCAP_SVE (1 << 22)
#endif

#ifndef HWCAP2_SVE2
#define HWCAP2_SVE2 (1 << 1)
#endif

#ifndef HWCAP2_MTE
#define HWCAP2_MTE (1 << 18)
#endif

#ifndef HWCAP2_PACGA
#define HWCAP2_PACGA (1 << 30)
#endif

// Function to detect Neoverse model
const char* detect_neoverse_model() {
    FILE *fp = popen("lscpu | grep -i neoverse", "r");
    if (!fp) return "Unknown";
    
    static char buffer[256];
    if (fgets(buffer, sizeof(buffer), fp)) {
        pclose(fp);
        
        if (strstr(buffer, "N1")) return "Neoverse N1";
        if (strstr(buffer, "N2")) return "Neoverse N2";
        if (strstr(buffer, "V1")) return "Neoverse V1";
        
        // Return the raw string if we can't identify the specific model
        return buffer;
    }
    
    pclose(fp);
    return "Not Neoverse";
}

int main() {
    printf("CPU Architecture: aarch64\n");
    
    // Get CPU information
    FILE *fp = popen("lscpu | grep 'Model name'", "r");
    if (fp) {
        char buffer[256];
        while (fgets(buffer, sizeof(buffer), fp)) {
            printf("%s", buffer);
        }
        pclose(fp);
    }
    
    // Detect Neoverse model
    const char* neoverse_model = detect_neoverse_model();
    printf("Neoverse model: %s\n", neoverse_model);
    
    // Get hardware capabilities
    unsigned long hwcap = getauxval(AT_HWCAP);
    unsigned long hwcap2 = getauxval(AT_HWCAP2);
    
    printf("\nHardware Capabilities:\n");
    
    // Basic features
    printf("ASIMD (NEON): %s\n", (hwcap & HWCAP_ASIMD) ? "Yes" : "No");
    printf("Atomic instructions: %s\n", (hwcap & HWCAP_ATOMICS) ? "Yes" : "No");
    printf("CRC32 instructions: %s\n", (hwcap & HWCAP_CRC32) ? "Yes" : "No");
    
    // Crypto extensions
    printf("\nCrypto Extensions:\n");
    printf("AES instructions: %s\n", (hwcap & HWCAP_AES) ? "Yes" : "No");
    printf("PMULL instructions: %s\n", (hwcap & HWCAP_PMULL) ? "Yes" : "No");
    printf("SHA1 instructions: %s\n", (hwcap & HWCAP_SHA1) ? "Yes" : "No");
    printf("SHA2 instructions: %s\n", (hwcap & HWCAP_SHA2) ? "Yes" : "No");
    
    // Advanced features
    printf("\nAdvanced Features:\n");
    printf("SVE support: %s\n", (hwcap & HWCAP_SVE) ? "Yes" : "No");
    printf("SVE2 support: %s\n", (hwcap2 & HWCAP2_SVE2) ? "Yes" : "No");
    printf("MTE (Memory Tagging) support: %s\n", (hwcap2 & HWCAP2_MTE) ? "Yes" : "No");
    printf("PAC (Pointer Authentication) support: %s\n", (hwcap2 & HWCAP2_PACGA) ? "Yes" : "No");
    
    // If SVE is supported, get vector length
    if (hwcap & HWCAP_SVE) {
        #ifdef __ARM_FEATURE_SVE
        int vector_bits = svcntb() * 8;
        printf("SVE vector length: %d bits\n", vector_bits);
        #else
        printf("SVE vector length: Unknown (compiler support missing)\n");
        #endif
    }
    
    // Print expected features based on Neoverse model
    printf("\nExpected Features by Model:\n");
    if (strstr(neoverse_model, "N1")) {
        printf("Neoverse N1: NEON, Crypto, Atomics (No SVE, No MTE, No PAC)\n");
    } else if (strstr(neoverse_model, "V1")) {
        printf("Neoverse V1: NEON, Crypto, Atomics, SVE, PAC (No SVE2, Has MTE)\n");
    } else if (strstr(neoverse_model, "N2")) {
        printf("Neoverse N2: NEON, Crypto, Atomics, SVE2, PAC, MTE\n");
    }
    
    return 0;
}
```

Compile and run:

```bash
gcc -march=armv8.2-a neoverse_feature_detect.c -o neoverse_feature_detect
./neoverse_feature_detect
```

### Step 3: Create Feature-Based Dispatch Code

Create a file named `feature_dispatch.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <sys/auxv.h>
#include <string.h>

// Define constants if not available in headers
#ifndef HWCAP_SVE
#define HWCAP_SVE (1 << 22)
#endif

#ifndef HWCAP2_SVE2
#define HWCAP2_SVE2 (1 << 1)
#endif

#ifndef HWCAP2_MTE
#define HWCAP2_MTE (1 << 18)
#endif

#ifndef HWCAP2_PACGA
#define HWCAP2_PACGA (1 << 30)
#endif

// Function prototypes for different implementations
void process_data_neon(float *data, int size);
void process_data_sve(float *data, int size);
void process_data_sve2(float *data, int size);

void secure_memory_standard(void *ptr, size_t size);
void secure_memory_mte(void *ptr, size_t size);

void* secure_function_ptr_standard(void *ptr);
void* secure_function_ptr_pac(void *ptr);

// NEON implementation (available on all Neoverse)
void process_data_neon(float *data, int size) {
    printf("Using NEON implementation\n");
    // NEON implementation would go here
}

// SVE implementation (available on V1, N2)
#ifdef __ARM_FEATURE_SVE
void process_data_sve(float *data, int size) {
    printf("Using SVE implementation\n");
    // SVE implementation would go here
}
#else
void process_data_sve(float *data, int size) {
    printf("SVE not supported by compiler, falling back to NEON\n");
    process_data_neon(data, size);
}
#endif

// SVE2 implementation (available on N2)
#if defined(__ARM_FEATURE_SVE) && defined(__ARM_FEATURE_SVE2)
void process_data_sve2(float *data, int size) {
    printf("Using SVE2 implementation\n");
    // SVE2 implementation would go here
}
#else
void process_data_sve2(float *data, int size) {
    printf("SVE2 not supported by compiler, falling back to SVE or NEON\n");
    process_data_sve(data, size);
}
#endif

// Standard memory protection
void secure_memory_standard(void *ptr, size_t size) {
    printf("Using standard memory protection\n");
    // Standard protection would go here
}

// MTE memory protection (available on V1, N2)
void secure_memory_mte(void *ptr, size_t size) {
    #if defined(__ARM_FEATURE_MEMORY_TAGGING)
    printf("Using MTE memory protection\n");
    // MTE implementation would go here
    #else
    printf("MTE not supported by compiler, falling back to standard protection\n");
    secure_memory_standard(ptr, size);
    #endif
}

// Standard pointer protection
void* secure_function_ptr_standard(void *ptr) {
    printf("Using standard pointer protection\n");
    return ptr;
}

// PAC pointer protection (available on V1, N2)
void* secure_function_ptr_pac(void *ptr) {
    #if __ARM_FEATURE_PAC_DEFAULT
    printf("Using PAC pointer protection\n");
    // PAC implementation would go here
    return ptr;  // In real code, would use __builtin_pauth_sign_unauthenticated
    #else
    printf("PAC not supported by compiler, falling back to standard protection\n");
    return secure_function_ptr_standard(ptr);
    #endif
}

// Function to select optimal implementation based on available features
typedef struct {
    int has_sve;
    int has_sve2;
    int has_mte;
    int has_pac;
} feature_flags_t;

feature_flags_t detect_features() {
    feature_flags_t features = {0};
    
    unsigned long hwcap = getauxval(AT_HWCAP);
    unsigned long hwcap2 = getauxval(AT_HWCAP2);
    
    features.has_sve = (hwcap & HWCAP_SVE) != 0;
    features.has_sve2 = (hwcap2 & HWCAP2_SVE2) != 0;
    features.has_mte = (hwcap2 & HWCAP2_MTE) != 0;
    features.has_pac = (hwcap2 & HWCAP2_PACGA) != 0;
    
    return features;
}

int main() {
    // Detect available features
    feature_flags_t features = detect_features();
    
    printf("Detected features:\n");
    printf("SVE: %s\n", features.has_sve ? "Yes" : "No");
    printf("SVE2: %s\n", features.has_sve2 ? "Yes" : "No");
    printf("MTE: %s\n", features.has_mte ? "Yes" : "No");
    printf("PAC: %s\n", features.has_pac ? "Yes" : "No");
    
    // Allocate test data
    float *data = malloc(1024 * sizeof(float));
    if (!data) {
        perror("malloc");
        return 1;
    }
    
    printf("\nSelecting optimal vector implementation:\n");
    // Select optimal vector implementation
    if (features.has_sve2) {
        process_data_sve2(data, 1024);
    } else if (features.has_sve) {
        process_data_sve(data, 1024);
    } else {
        process_data_neon(data, 1024);
    }
    
    printf("\nSelecting optimal memory protection:\n");
    // Select optimal memory protection
    if (features.has_mte) {
        secure_memory_mte(data, 1024 * sizeof(float));
    } else {
        secure_memory_standard(data, 1024 * sizeof(float));
    }
    
    printf("\nSelecting optimal pointer protection:\n");
    // Select optimal pointer protection
    void *func_ptr = (void*)&main;
    if (features.has_pac) {
        func_ptr = secure_function_ptr_pac(func_ptr);
    } else {
        func_ptr = secure_function_ptr_standard(func_ptr);
    }
    
    free(data);
    return 0;
}
```

Compile and run:

```bash
gcc -march=armv8.2-a feature_dispatch.c -o feature_dispatch
./feature_dispatch
```

## Neoverse Feature Matrix

The following table summarizes the key features available in different Neoverse processors:

| Feature | Neoverse N1 | Neoverse V1 | Neoverse N2 |
|---------|-------------|-------------|-------------|
| NEON    | ✓           | ✓           | ✓           |
| Crypto Extensions | ✓ | ✓           | ✓           |
| SVE     | ✗           | ✓ (128-256 bit) | ✓ (128-256 bit) |
| SVE2    | ✗           | ✗           | ✓           |
| MTE     | ✗           | ✓           | ✓           |
| PAC     | ✗           | ✓           | ✓           |
| LSE     | ✓           | ✓           | ✓           |
| MPAM    | ✓           | ✓           | ✓           |
| RME     | ✗           | ✗           | ✓           |

## Optimal Compiler Flags for Neoverse

To compile code that runs efficiently on specific Neoverse processors, use these compiler flags:

```bash
# For Neoverse N1 (baseline)
gcc -O3 -march=armv8.2-a+crypto+fp16+rcpc+dotprod

# For Neoverse V1
gcc -O3 -march=armv8.4-a+sve+crypto+fp16+rcpc+dotprod+bf16

# For Neoverse N2
gcc -O3 -march=armv8.5-a+sve2+crypto+fp16+rcpc+dotprod+bf16+i8mm
```

For portable code that runs across all Neoverse processors, use runtime feature detection:

```bash
# Baseline compatibility with optimizations
gcc -O3 -march=armv8.2-a+crypto+fp16+rcpc+dotprod
```

## Feature Detection Best Practices

1. **Runtime Feature Detection**:
   ```c
   // Check for hardware features at runtime
   unsigned long hwcap = getauxval(AT_HWCAP);
   unsigned long hwcap2 = getauxval(AT_HWCAP2);
   
   if (hwcap2 & HWCAP2_SVE2) {
       // Use SVE2 implementation
   } else if (hwcap & HWCAP_SVE) {
       // Use SVE implementation
   } else {
       // Use NEON implementation
   }
   ```

2. **Function Multi-versioning**:
   ```c
   // Define multiple function versions
   __attribute__((target("sve2")))
   void process_data(float *data, int size) {
       // SVE2 implementation
   }
   
   __attribute__((target("sve")))
   void process_data(float *data, int size) {
       // SVE implementation
   }
   
   __attribute__((target("default")))
   void process_data(float *data, int size) {
       // NEON implementation
   }
   ```

3. **Conditional Compilation with Runtime Checks**:
   ```c
   #ifdef __ARM_FEATURE_SVE
   // SVE-specific code
   #else
   // Fallback code
   #endif
   
   // Combined with runtime check
   if (hwcap & HWCAP_SVE) {
       // Use SVE code
   }
   ```

4. **Feature-Based Dispatch Tables**:
   ```c
   typedef void (*process_func_t)(float*, int);
   
   // Initialize dispatch table based on detected features
   process_func_t select_implementation() {
       unsigned long hwcap = getauxval(AT_HWCAP);
       unsigned long hwcap2 = getauxval(AT_HWCAP2);
       
       if (hwcap2 & HWCAP2_SVE2) return process_data_sve2;
       if (hwcap & HWCAP_SVE) return process_data_sve;
       return process_data_neon;
   }
   ```

5. **Graceful Degradation**:
   ```c
   // Try to use the best available implementation with fallbacks
   void secure_memory(void *ptr, size_t size) {
       unsigned long hwcap2 = getauxval(AT_HWCAP2);
       
       if (hwcap2 & HWCAP2_MTE) {
           secure_memory_mte(ptr, size);
       } else {
           secure_memory_standard(ptr, size);
       }
   }
   ```

These feature detection techniques ensure your code runs efficiently across all Neoverse processors in cloud computing environments, taking advantage of advanced features when available while maintaining compatibility with older processors.

## Relevance to Cloud Computing Workloads

Feature detection is particularly important for cloud computing on Neoverse:

1. **Portable Performance**: Ensuring code runs efficiently across different Neoverse generations
2. **Security Features**: Leveraging MTE and PAC when available
3. **Vector Processing**: Using the best available SIMD instructions (NEON, SVE, SVE2)
4. **Cloud Portability**: Writing code that works across different cloud providers' Arm offerings
5. **Future-Proofing**: Preparing for newer Neoverse generations with additional features

Understanding Neoverse feature detection helps you:
- Write code that automatically adapts to available hardware features
- Maximize performance across different cloud environments
- Leverage security features when available
- Maintain compatibility with older Neoverse processors