---
title: "What You Will Build"

weight: 2

layout: "learningpathall"
---

Kernels provide the bridge between applications and the underlying hardware. Building a custom kernel lets you:

1. Enable new platform capabilities ahead of their default release (for example, an Armv9 instruction set or device driver).
2. Apply experimental scheduler or memory-management patches to evaluate performance in context.
3. Toggle debugging or tracing features to investigate hard-to-reproduce issues without waiting for upstream packages.

In this Fastpath-focused tutorial you will assemble two kernel variants with `tuxmake`, deploy them with Fastpath’s automation, and compare their performance on a dedicated test system running a reproducible benchmark workload.

To keep the ramp-up simple we rely on helper scripts from the [`arm_kernel_install_guide`](https://github.com/geremyCohen/arm_kernel_install_guide) repository.  
These scripts wrap the detailed procedure covered in the official [Fastpath documentation](https://fastpath.docs.arm.com/en/latest/index.html).  
Whenever you want more context, or need to extend the workflow, refer back to the official guide.

The remainder of this learning path walks through the build portion of the workflow. Deployment and benchmarking with Fastpath are handled in the subsequent steps.
