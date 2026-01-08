---
title: "What You Will Build"

weight: 2

layout: "learningpathall"
---

Kernels sit between your applications and the underlying hardware. Rebuilding a custom kernel lets you consume new features early, apply experimental scheduler or memory patches, or toggle specialized instrumentation without waiting for distro updates. If you care about squeezing the most performance from an Arm server, custom kernels are how you measure the effect of those changes.

For this tutorial we focus on a concrete experiment: run the Speedometer browser benchmark on **two** kernel versions and see which one delivers the higher score. That mirrors the day-to-day workflow for kernel engineers—build, deploy, compare—and Fastpath provides the automation that keeps it reproducible.

To keep things organized we use three Arm-based nodes:

1. **Build host** – compiles the Fastpath-ready kernels you want to test.
2. **Fastpath host** – manages plan generation, deployment, benchmarking, and result collection.
3. **System Under Test (SUT)** – runs each kernel and executes the Speedometer workload.

Arm’s [`arm_kernel_install_guide`](https://github.com/geremyCohen/arm_kernel_install_guide) repository supplies wrapper scripts for every stage, so you don’t have to wire the workflow together yourself. You’ll use those scripts to compile kernels on the build host, prepare the Fastpath host and SUT, generate a plan, run it, and read the results. Refer to the official [Fastpath documentation](https://fastpath.docs.arm.com/en/latest/index.html) any time you need deeper context or want to expand the process beyond this guided example.

The remaining chapters walk you through provisioning the three nodes, compiling the kernels, configuring Fastpath, and executing the benchmark comparison end to end.
