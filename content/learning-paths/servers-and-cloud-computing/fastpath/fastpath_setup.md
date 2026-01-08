---
title: "Setup Fastpath Instance"

weight: 6

layout: "learningpathall"
---
With newlycompiled kernels ready and waiting on the build instance, it's time to set up the Fastpath host. 

The Fastpath host will manage testing against the system under test (SUT) and coordinate benchmarking runs.

## Provision the Fastpath host


Launch the *fastpath host* machine with the following settings:

1. **Name** — *fastpath-host*
2. **Operating system** — *Ubuntu*
3. **AMI** — *Ubuntu 24.04 LTS (Arm)*
4. **Architecture** — *64-bit Arm*
5. **Instance type** — `c8g.4xlarge`
6. **Key pair** — *Select or create a key for SSH*
7. **Security group** — *allow SSH inbound from your IP and peer nodes*
8. **Storage** — *200 GB gp3*

For a visual representation of these steps, refer back to the diagram in [Build Setup](../build_setup/).

When the instance reports a `running` state, note the public and private IP addresses as FASTPATH_PUBLIC_IP and FASTPATH_PRIVATE_IP.  You'll need these values later.

## Install Fastpath Dependencies

Repeat the dependency installation process so the Fastpath host has the same toolchain and helper scripts as the build machine.

1. SSH into the `c8g.4xlarge` Fastpath host using the configured key pair.

2. Open the [Install and Clone section](https://localhost:1313/install-guides/kernel-build/#install-and-clone) of the install guide from your workstation.

3. Run each command from that section on the Fastpath machine.  It should be similar to the following (always refer to the above link for the latest command line):

    ```output
    $ sudo apt update && sudo apt install -y git python3 python3-pip python3-venv build-essential bc rsync dwarves flex bison libssl-dev libelf-dev btop yq

    WARNING: apt does not have a stable CLI interface. Use with caution in scripts.
    Hit:1 http://us-east-1.ec2.ports.ubuntu.com/ubuntu-ports noble InRelease
    Get:2 http://us-east-1.ec2.ports.ubuntu.com/ubuntu-ports noble-updates InRelease [126 kB]
    ...
    0 upgraded, 104 newly installed, 0 to remove and 43 not upgraded.
    Setting up build-essential (12.10ubuntu1) ...
    Setting up libssl-dev:arm64 (3.0.13-0ubuntu3.6) ...
    Setting up python3-pip (24.0+dfsg-1ubuntu1.3) ...

    $ cd
    $ git clone https://github.com/geremyCohen/arm_kernel_install_guide.git ~/arm_kernel_install_guide
    $ cd ~/arm_kernel_install_guide && chmod +x scripts/*.sh

    Cloning into 'arm_kernel_install_guide'...
    ```

## Copy kernels between build and Fastpath instances

When we begin testing, the Fastpath instance will push the compiled kernels to the SUT for testing.  But as of now, the kernels are still on the build instance. This next step copies the kernels from the build instance to the new Fastpath instance.

1. Locate the value you recorded earlier for BUILD_PRIVATE_IP.

2. On the Fastpath instance, ```cd``` into the `arm_kernel_install_guide` folder you just cloned. 

3. Run the `pull_kernel_artifacts.sh` script, substituting BUILD_PRIVATE_IP with the private IP of the build instance:

    ```command
    cd ~/arm_kernel_install_guide
    ./scripts/pull_kernel_artifacts.sh --host 172.31.110.110 
    ```

    ```output
    [2026-01-08 18:35:14] Pulling kernel artifacts:
    [2026-01-08 18:35:14]   Host        : 172.31.110.110
    [2026-01-08 18:35:14]   SSH user    : ubuntu
    [2026-01-08 18:35:14]   Remote dir  : /home/ubuntu/work/kernel-builds/fastpath
    [2026-01-08 18:35:14]   Local dir   : /home/ubuntu/kernels
    [2026-01-08 18:35:14]   Versions    : auto-detected
    [2026-01-08 18:35:15] Copying 6.18.1-ubuntu+/Image.gz
    [2026-01-08 18:35:16] Copying 6.18.1-ubuntu+/modules.tar.xz
    [2026-01-08 18:35:18] Copying optional 6.18.1-ubuntu+/config.stock
    [2026-01-08 18:35:18] Copying 6.19.0-rc1-ubuntu+/Image.gz
    [2026-01-08 18:35:19] Copying 6.19.0-rc1-ubuntu+/modules.tar.xz
    [2026-01-08 18:35:21] Copying optional 6.19.0-rc1-ubuntu+/config.stock
    [2026-01-08 18:35:21] Artifact pull complete.
    ```


When the script completes, the Fastpath host is ready with the kernels it needs for testing.

## Power down the build machine

After copying the artifacts from the build machine, stop (or terminate it) to avoid incurring additional costs.  If you wish to keep it around for future kernel builds, stopping it is sufficient.


{{% notice Note %}}
If you do decide to keep the machine around as a kernel copy host, you can modify it to a smaller instance type such as `c8g.4xlarge` to save on costs when its running.  The larger 24xlarge instance is only needed during kernel compilation.
{{% /notice %}}

## Configure the Fastpath host

With kernels copied over, the final step is to install and configure the Fastpath software onto the Fastpath host.  From the same folder, run the host configuration script targeting localhost:

1. Stay on the Fastpath host and ensure you are in the cloned repository.  If needed, you can easily navigate there again:

    ```command
    cd ~/arm_kernel_install_guide
    ```

2. Run the Fastpath host setup script, targeting localhost (the current machine):

    ```command
    ./scripts/configure_fastpath_host.sh --host localhost
    ```

    ```output
    [2026-01-08 18:35:27] Configuring fastpath host localhost (non-interactive mode)
    [2026-01-08 18:35:27] Installing prerequisites
    ...
    [2026-01-08 18:36:10] Fastpath host setup complete.
    ```

Take note that the script creates a Python virtual environment (default `~/venv`) and installs the Fastpath CLI alongside its dependencies:

    ```command
    source ~/venv/bin/activate
    which python
    ```

    ```output
    /home/ubuntu/venv/bin/python
    ```

{{% notice Note %}}
Whenever you log back into the machine, make sure to activate the virtual environment (the above commandline) before running any Fastpath commands.
{{% /notice %}}

With the Fastpath host configured, you're now ready to provision the system under test (SUT) and verify connectivity between them.
