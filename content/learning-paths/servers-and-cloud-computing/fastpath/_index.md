---
title: Fastpath Kernel Build and Install Guide

minutes_to_complete: 45

who_is_this_for: Software developers and performance engineers who want to explore benchmarking across different kernel versions with Fastpath on Arm.

learning_objectives:
    - Understand how Fastpath streamlines kernel experimentation workflows
    - Provision an Arm-based build machine and compile Fastpath-enabled kernels on it
    - Provision an Arm-based test system, also known as the System Under Test (SUT)
    - Create a test plan consisting of kernel versions and benchmark suites 
    - Launch an Arm-based Fastpath host to orchestrate the kernel benchmarking process on the SUT

prerequisites:
    - An AWS account with permissions to create EC2 instances
    - Familiarity with basic Linux administration and SSH

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

This learning path focuses on the workflow a kernel developer follows to compare the performance of a benchmark across two kernel configurations by way of Fastpath.

In about an hour you will:

1. Build a build, SUT, and Fastpath host on Arm-based AWS EC2 instances.
2. Compile kernel versions of your choice to test against via the build host.
3. Install Fastpath and its dependencies on the SUT and Fastpath hosts.
4. Perform kernel benchmarking using Fastpath, and analyze the results.

> **Tip:** The complete Fastpath reference documentation is available at [fastpath.docs.arm.com](https://fastpath.docs.arm.com/en/latest/index.html).  
