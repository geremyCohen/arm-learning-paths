---
title: Arm Cryptography Extensions
weight: 2250

### FIXED, DO NOT MODIFY
layout: learningpathall
---

## Understanding Arm Cryptography Extensions

Arm Cryptography Extensions provide hardware acceleration for common cryptographic algorithms, significantly improving performance and energy efficiency compared to software implementations. These extensions are available in Armv8-A architectures and include dedicated instructions for AES encryption/decryption, SHA hashing, and other cryptographic operations.

When comparing Intel/AMD (x86) versus Arm architectures, both offer hardware acceleration for cryptography, but with different instruction sets and performance characteristics. Understanding these differences is crucial for security-sensitive applications where cryptographic performance is important.

For more detailed information about Arm Cryptography Extensions, you can refer to:
- [Arm Architecture Reference Manual](https://developer.arm.com/documentation/ddi0487/latest)
- [Arm Cryptography Extensions](https://community.arm.com/arm-community-blogs/b/architectures-and-processors-blog/posts/armv8-a-architecture-evolution)
- [Cryptographic Hardware Acceleration](https://www.arm.com/why-arm/technologies/security)

## Benchmarking Exercise: Comparing Cryptographic Performance

In this exercise, we'll measure and compare the performance of cryptographic operations with and without hardware acceleration on Arm architecture.

### Prerequisites

Ensure you have an Arm VM with cryptography extensions support:
- Arm (aarch64) with Armv8-A architecture supporting crypto extensions

### Step 1: Install Required Tools

Run the following commands:

```bash
sudo apt update
sudo apt install -y build-essential gcc openssl libssl-dev
```

### Step 2: Create AES Benchmark

Create a file named `aes_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <openssl/evp.h>
#include <openssl/aes.h>
#include <openssl/err.h>

#define BUFFER_SIZE (16 * 1024 * 1024)  // 16MB
#define ITERATIONS 10

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

// Function to handle OpenSSL errors
void handle_errors() {
    ERR_print_errors_fp(stderr);
    abort();
}

// AES-CBC encryption using OpenSSL
int aes_encrypt(unsigned char *plaintext, int plaintext_len, unsigned char *key,
                unsigned char *iv, unsigned char *ciphertext) {
    EVP_CIPHER_CTX *ctx;
    int len;
    int ciphertext_len;

    // Create and initialize the context
    if(!(ctx = EVP_CIPHER_CTX_new()))
        handle_errors();

    // Initialize the encryption operation
    if(1 != EVP_EncryptInit_ex(ctx, EVP_aes_256_cbc(), NULL, key, iv))
        handle_errors();

    // Provide the message to be encrypted, and obtain the encrypted output
    if(1 != EVP_EncryptUpdate(ctx, ciphertext, &len, plaintext, plaintext_len))
        handle_errors();
    ciphertext_len = len;

    // Finalize the encryption
    if(1 != EVP_EncryptFinal_ex(ctx, ciphertext + len, &len))
        handle_errors();
    ciphertext_len += len;

    // Clean up
    EVP_CIPHER_CTX_free(ctx);

    return ciphertext_len;
}

int main() {
    // Check for Arm crypto extensions
    #ifdef __aarch64__
    unsigned long features;
    asm("mrs %0, ID_AA64ISAR0_EL1" : "=r" (features));
    int has_aes = (features >> 4) & 0xf;
    printf("Arm AES hardware support: %s\n", has_aes ? "Yes" : "No");
    #else
    printf("Not running on Arm architecture\n");
    #endif

    // Allocate buffers
    unsigned char *plaintext = malloc(BUFFER_SIZE);
    unsigned char *ciphertext = malloc(BUFFER_SIZE + AES_BLOCK_SIZE);
    
    if (!plaintext || !ciphertext) {
        perror("Memory allocation failed");
        return 1;
    }
    
    // Generate random plaintext
    for (int i = 0; i < BUFFER_SIZE; i++) {
        plaintext[i] = rand() & 0xFF;
    }
    
    // Key and IV for AES-256-CBC
    unsigned char key[32];
    unsigned char iv[16];
    
    // Generate random key and IV
    for (int i = 0; i < 32; i++) {
        key[i] = rand() & 0xFF;
    }
    for (int i = 0; i < 16; i++) {
        iv[i] = rand() & 0xFF;
    }
    
    // Benchmark AES encryption
    double start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        int ciphertext_len = aes_encrypt(plaintext, BUFFER_SIZE, key, iv, ciphertext);
        if (i == 0) {
            printf("Encrypted %d bytes\n", ciphertext_len);
        }
    }
    
    double end = get_time();
    double elapsed = end - start;
    
    printf("AES-256-CBC encryption time: %.6f seconds\n", elapsed);
    printf("Throughput: %.2f MB/s\n", (BUFFER_SIZE * ITERATIONS) / (elapsed * 1024 * 1024));
    
    // Clean up
    free(plaintext);
    free(ciphertext);
    
    return 0;
}
```

Compile with OpenSSL support:

```bash
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -march=armv8.2-a+crypto aes_benchmark.c -o aes_benchmark -lcrypto
```

### Step 3: Create SHA Benchmark

Create a file named `sha_benchmark.c` with the following content:

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <openssl/sha.h>

#define BUFFER_SIZE (16 * 1024 * 1024)  // 16MB
#define ITERATIONS 10

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

int main() {
    // Check for Arm crypto extensions
    #ifdef __aarch64__
    unsigned long features;
    asm("mrs %0, ID_AA64ISAR0_EL1" : "=r" (features));
    int has_sha1 = (features >> 8) & 0xf;
    int has_sha256 = (features >> 12) & 0xf;
    printf("Arm SHA1 hardware support: %s\n", has_sha1 ? "Yes" : "No");
    printf("Arm SHA256 hardware support: %s\n", has_sha256 ? "Yes" : "No");
    #else
    printf("Not running on Arm architecture\n");
    #endif

    // Allocate buffer
    unsigned char *data = malloc(BUFFER_SIZE);
    if (!data) {
        perror("Memory allocation failed");
        return 1;
    }
    
    // Generate random data
    for (int i = 0; i < BUFFER_SIZE; i++) {
        data[i] = rand() & 0xFF;
    }
    
    // Benchmark SHA-256
    unsigned char sha256_hash[SHA256_DIGEST_LENGTH];
    double start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        SHA256(data, BUFFER_SIZE, sha256_hash);
    }
    
    double end = get_time();
    double elapsed = end - start;
    
    printf("SHA-256 hash time: %.6f seconds\n", elapsed);
    printf("Throughput: %.2f MB/s\n", (BUFFER_SIZE * ITERATIONS) / (elapsed * 1024 * 1024));
    
    // Print first few bytes of hash for verification
    printf("SHA-256 hash (first 8 bytes): ");
    for (int i = 0; i < 8; i++) {
        printf("%02x", sha256_hash[i]);
    }
    printf("...\n");
    
    // Clean up
    free(data);
    
    return 0;
}
```

Compile with OpenSSL support:

```bash
# See: ../2400_compiler_optimizations.md#cpu-specific-flags
gcc -O3 -march=armv8.2-a+crypto sha_benchmark.c -o sha_benchmark -lcrypto
```

### Step 4: Create Benchmark Script

Create a file named `run_crypto_benchmark.sh` with the following content:

```bash
#!/bin/bash

# Get architecture
arch=$(uname -m)
echo "Architecture: $arch"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"

# Check for Arm crypto extensions
if [ "$arch" = "aarch64" ]; then
    echo "Checking for Arm crypto extensions..."
    # This is a simplified check - actual detection is done in the C programs
    if grep -q "aes\|sha1\|sha2" /proc/cpuinfo; then
        echo "Crypto extensions detected in CPU features"
    else
        echo "No crypto extensions detected in CPU features"
    fi
fi

# Run AES benchmark
echo "Running AES benchmark..."
./aes_benchmark | tee aes_results.txt

# Run SHA benchmark
echo "Running SHA benchmark..."
./sha_benchmark | tee sha_results.txt

echo "Benchmark complete. Results saved to aes_results.txt and sha_results.txt"
```

Make the script executable:

```bash
chmod +x run_crypto_benchmark.sh
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

```c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef __aarch64__
#include <arm_neon.h>
#endif

#define BUFFER_SIZE (16 * 1024)  // 16KB for demonstration
#define ITERATIONS 1000

// Function to measure time
double get_time() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec / 1.0e9;
}

#ifdef __aarch64__
// AES encryption round using direct Arm instructions
void aes_encrypt_round_arm(uint8x16_t *data, uint8x16_t round_key) {
    // AES single round encryption
    *data = vaeseq_u8(*data, round_key);
    // AES mix columns
    *data = vaesmcq_u8(*data);
}

// AES encryption using direct Arm instructions
void aes_encrypt_arm(uint8_t *plaintext, uint8_t *key, uint8_t *ciphertext, size_t size) {
    // This is a simplified implementation for demonstration
    // A real implementation would need proper key expansion and full rounds
    
    uint8x16_t round_key = vld1q_u8(key);
    
    for (size_t i = 0; i < size; i += 16) {
        uint8x16_t data = vld1q_u8(plaintext + i);
        
        // Perform 10 rounds of AES (simplified)
        for (int round = 0; round < 10; round++) {
            aes_encrypt_round_arm(&data, round_key);
        }
        
        // Store result
        vst1q_u8(ciphertext + i, data);
    }
}
#endif

// Software AES encryption (very simplified)
void aes_encrypt_software(uint8_t *plaintext, uint8_t *key, uint8_t *ciphertext, size_t size) {
    // This is just a placeholder - not a real AES implementation
    for (size_t i = 0; i < size; i++) {
        ciphertext[i] = plaintext[i] ^ key[i % 16];
    }
}

int main() {
    // Check for Arm crypto extensions
    #ifdef __aarch64__
    unsigned long features;
    asm("mrs %0, ID_AA64ISAR0_EL1" : "=r" (features));
    int has_aes = (features >> 4) & 0xf;
    printf("Arm AES hardware support: %s\n", has_aes ? "Yes" : "No");
    #else
    printf("Not running on Arm architecture\n");
    int has_aes = 0;
    #endif

    // Allocate buffers
    uint8_t *plaintext = malloc(BUFFER_SIZE);
    uint8_t *ciphertext = malloc(BUFFER_SIZE);
    uint8_t *key = malloc(16);  // AES-128 key
    
    if (!plaintext || !ciphertext || !key) {
        perror("Memory allocation failed");
        return 1;
    }
    
    // Generate random data and key
    for (int i = 0; i < BUFFER_SIZE; i++) {
        plaintext[i] = rand() & 0xFF;
    }
    for (int i = 0; i < 16; i++) {
        key[i] = rand() & 0xFF;
    }
    
    // Benchmark software implementation
    double start = get_time();
    
    for (int i = 0; i < ITERATIONS; i++) {
        aes_encrypt_software(plaintext, key, ciphertext, BUFFER_SIZE);
    }
    
    double end = get_time();
    double software_time = end - start;
    
    printf("Software AES time: %.6f seconds\n", software_time);
    printf("Software throughput: %.2f MB/s\n", 
           (BUFFER_SIZE * ITERATIONS) / (software_time * 1024 * 1024));
    
    // Benchmark hardware implementation if available
    #ifdef __aarch64__
    if (has_aes) {
        start = get_time();
        
        for (int i = 0; i < ITERATIONS; i++) {
            aes_encrypt_arm(plaintext, key, ciphertext, BUFFER_SIZE);
        }
        
        end = get_time();
        double hardware_time = end - start;
        
        printf("Hardware AES time: %.6f seconds\n", hardware_time);
        printf("Hardware throughput: %.2f MB/s\n", 
               (BUFFER_SIZE * ITERATIONS) / (hardware_time * 1024 * 1024));
        
        // Calculate speedup
        printf("Hardware speedup: %.2fx\n", software_time / hardware_time);
    }
    #endif
    
    // Clean up
    free(plaintext);
    free(ciphertext);
    free(key);
    
    return 0;
}
```

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
   ```c
   #include <arm_neon.h>
   
   // AES encryption using Arm instructions
   uint8x16_t data = vld1q_u8(input);
   uint8x16_t key = vld1q_u8(round_key);
   
   // AES single round encryption
   data = vaeseq_u8(data, key);
   // AES mix columns
   data = vaesmcq_u8(data);
   ```

3. **SHA Instructions**:
   ```c
   #include <arm_neon.h>
   
   // SHA-1 hash round using Arm instructions
   uint32x4_t abcd = vld1q_u32(hash_state);
   uint32_t e = hash_state[4];
   uint32x4_t round_input = vld1q_u32(message);
   
   // SHA-1 schedule update
   uint32x4_t schedule = vsha1su0q_u32(prev1, prev2, prev3);
   schedule = vsha1su1q_u32(schedule, prev0);
   
   // SHA-1 hash update
   uint32x4_t hash = vsha1hq_u32(abcd);
   abcd = vsha1cq_u32(abcd, e, round_input);
   ```

4. **Parallel Cryptographic Operations**:
   ```c
   // Process multiple blocks in parallel
   for (int i = 0; i < size; i += 64) {
       uint8x16_t block1 = vld1q_u8(&data[i]);
       uint8x16_t block2 = vld1q_u8(&data[i+16]);
       uint8x16_t block3 = vld1q_u8(&data[i+32]);
       uint8x16_t block4 = vld1q_u8(&data[i+48]);
       
       // Process all four blocks
       // ...
   }
   ```

5. **Optimized Key Expansion**:
   ```c
   // AES key expansion using Arm instructions
   uint8x16_t key = vld1q_u8(initial_key);
   uint8x16_t round_key = key;
   
   // Generate round keys
   for (int round = 1; round <= 10; round++) {
       // Key expansion logic using AESE/AESMC instructions
       // ...
   }
   ```

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