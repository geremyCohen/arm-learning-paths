---
title: Fastpath Kernel Build and Install Guide

minutes_to_complete: 45

who_is_this_for: Software developers and performance engineers who want to explore Fastpath-assisted Linux kernel builds on Arm servers.

learning_objectives:
    - Understand how Fastpath streamlines kernel experimentation workflows
    - Provision a dedicated Arm build host for kernel compilation
    - Install the required toolchain and clone the provided tuxmake utilities
    - Trigger a Fastpath-enabled kernel build that is ready for benchmarking

prerequisites:
    - An AWS account with permissions to create Graviton instances
    - Familiarity with basic Linux administration and SSH access
    - Local clones of the `arm-learning-paths` and `arm_kernel_install_guide` repositories

author: Geremy Cohen

### Tags
skilllevels: Intermediate
subjects: Operating Systems
armips:
    - Neoverse
operatingsystems:
    - Linux
tools_software_languages:
    - Fastpath
    - tuxmake
    - Linux kernel

further_reading:
    - resource:
        title: Fastpath documentation
        link: https://fastpath.docs.arm.com/en/latest/index.html
        type: documentation
    - resource:
        title: Kernel install guide
        link: /install-guides/kernel-build/
        type: guide
    - resource:
        title: AWS Compute Service Provider learning path
        link: /learning-paths/servers-and-cloud-computing/csp/
        type: guide

### FIXED, DO NOT MODIFY
# ================================================================================
weight: 1
layout: "learningpathall"
learning_path_main_page: "yes"
---

Fastpath accelerates the cycle of building, deploying, and benchmarking Linux kernels on Arm-based infrastructure.  
This learning path focuses on the core workflow a kernel developer follows to compare two kernel configurations using the utility scripts that accompany the official Fastpath tooling.

In less than an hour you will:

1. Launch a high-core-count Arm build machine on AWS.
2. Install the curated toolchain and clone the tuxmake helpers from the Kernel Install Guide.
3. Build a Fastpath-enabled kernel that is ready to deploy and benchmark in the follow-on steps.

> **Tip:** The complete Fastpath reference documentation remains available at [fastpath.docs.arm.com](https://fastpath.docs.arm.com/en/latest/index.html).  
> The condensed procedure here relies on helper scripts from the `arm_kernel_install_guide` repository to reduce the amount of manual configuration required.
