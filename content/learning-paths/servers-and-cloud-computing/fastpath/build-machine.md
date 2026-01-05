---
title: "Build machine setup"

weight: 3

layout: "learningpathall"
---

Fastpath expects a powerful Arm server to compile kernels quickly and stage artifacts for deployment.  
Launch an AWS Graviton4 `c8g.24xlarge` instance and treat it as the *build* machine throughout the rest of the guide.

1. Open the [Compute Service Provider learning path](/learning-paths/servers-and-cloud-computing/csp/) in your browser (`http://localhost:1313/learning-paths/servers-and-cloud-computing/csp/`) and follow the AWS EC2 section to create a new instance.
2. Choose the latest Ubuntu 24.04 LTS Arm AMI, select the `c8g.24xlarge` shape, and attach at least 200 GB of gp3 storage to accommodate kernel sources and build artifacts.
3. Reuse an existing SSH key pair or create a new one dedicated to this workflow. Restrict the security group to your workstation’s IP for SSH (port 22) access.
4. (Optional) Tag the instance with `Name=fastpath-build` to make it easy to identify later.

When the instance reports a `running` state, note the public IP or DNS name. You will SSH into this build machine for the remaining steps.

## Install dependencies and clone tuxmake

With the build machine online, prepare it by following the *Install and clone* section of the Kernel Install Guide.

1. SSH into the `c8g.24xlarge` host using the key pair you created earlier.
2. Open `http://localhost:1313/install-guides/kernel-build/#install-and-clone` on your workstation.  
   The guide provides the `apt` packages, Python dependencies, and repository clone commands that are already validated for Fastpath.
3. Run each command from that section verbatim on the build machine. When cloning, place the `arm_kernel_install_guide` repository under your home directory (for example, `~/work/arm_kernel_install_guide`) so the helper scripts remain in a predictable location.
4. Confirm that the `tuxmake` CLI is available by running `tuxmake --version`. This ensures every subsequent script can invoke the same kernel build pipeline that the Fastpath documentation describes in [Build a kernel](https://fastpath.docs.arm.com/en/latest/user-guide/buildkernel.html).

If any dependency step fails, refer back to the Kernel Install Guide for troubleshooting tips—this learning path assumes that the base toolchain is working before moving on.
