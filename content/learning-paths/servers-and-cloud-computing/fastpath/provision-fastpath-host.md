---
title: "Fastpath host preparation"

weight: 6

layout: "learningpathall"
---

Build out the Fastpath orchestration node, align its dependencies with the build machine, pull over kernel artifacts, and shut down the original builder when finished.

## Launch the Fastpath host

1. Use the [Compute Service Provider learning path](/learning-paths/servers-and-cloud-computing/csp/) to review the EC2 creation process.
2. Launch a Graviton4 `c8g.2xlarge` instance with Ubuntu 24.04 LTS. Attach at least 100 GB of gp3 storage.
3. Place the instance in the same VPC/subnet as the build machine so that private IP connectivity works out of the box.
4. Tag it with a recognizable name such as `fastpath-host` and reuse the same SSH key pair for consistency.

When the instance is running, note both its public endpoint (for SSH) and its private IP (for peer-to-peer transfers later in the workflow).

## Install dependencies and clone tuxmake

Repeat the dependency installation process so the Fastpath host has the same toolchain and helper scripts as the build machine.

1. SSH into the `c8g.2xlarge` instance.
2. Follow the **Install and clone** section of the Kernel Install Guide once more: `http://localhost:1313/install-guides/kernel-build/#install-and-clone`.
3. Clone the `arm_kernel_install_guide` repository into `~/work/arm_kernel_install_guide` (or another path that matches the build machine for muscle memory).
4. Verify the setup with:

```console
tuxmake --version
ls ~/work/arm_kernel_install_guide/scripts
```

Keeping both machines aligned ensures every script behaves identically in later steps.

## Copy kernel artifacts from the build machine

Use the provided script to pull the freshly built kernel images from the build machine onto the Fastpath host.

1. On the **build** machine, capture its private IP address so the Fastpath host knows where to pull from:

```console
curl -s http://169.254.169.254/latest/meta-data/local-ipv4
```

2. On the **Fastpath** host, change into the helper repository and run the pull script, substituting the private IP you just recorded:

```console
cd ~/work/arm_kernel_install_guide
./scripts/pull_kernel_artifacts.sh --host BUILD_PRIVATE_IP
```

The script transfers the kernel binaries and metadata into the Fastpath host’s working directories, ready for deployment.

## Power down the build machine

After the artifacts finish copying you no longer need the high-core-count build instance.

1. SSH into the build machine one last time and issue:

```console
sudo init 0
```

2. When you are completely done with kernel rebuilds, terminate the instance in the AWS console to avoid extra charges. Until then it will remain in a `stopped` state and accrue minimal storage costs only.

From this point forward the workflow uses the Fastpath host and the upcoming SUT instance.
