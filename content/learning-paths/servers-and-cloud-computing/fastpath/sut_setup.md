---
title: "Setup System Under Test Instance"

weight: 10

layout: "learningpathall"
---
Now that kernels are built and the Fastpath host is ready, it's time to set up the system under test (SUT).


## Provision the SUT

The System Under Test (SUT) is the target machine where Fastpath installs your kernels, runs benchmarks on each kernel (one at a time) and when complete, compares and displays the results via Fastpath.

Just like choosing the kernels to test, the instance type of the SUT depends on your use case. For this Fastpath LP, we recommend a Graviton4 `c8g.12xl` instance with Ubuntu 24.04 LTS. This instance type provides a good balance of CPU and memory for a test benchmark.

To launch our SUT instance, a `c8g.12xlarge` instance with the following parameters is suggested:

* ARM Architecture
* The latest Ubuntu Arm AMI
* The `c8g.12xlarge` instance type
* At least 200 GB of storage (to accommodate kernel sources and build artifacts).
* A security group that allows SSH access inbound from your workstation's IP, and other nodes you will later create in the cluster. The default TCP port 22 from anywhere is sufficient for non-production testing.
* A key pair for SSH access to the instance.

When the instance reports a `running` state, note the public and private IP addresses as SUT_PUBLIC_IP and SUT_PRIVATE_IP.  You'll need these values later.


## Configure the SUT via the Fastpath instance


You'll next run a script that remotely installs the Fastpath software, and the required `fpuser` system account.  It also sets up SSH access for the new `fpuser` account by copying over ubuntu@SUT's `~/.ssh/authorized_keys` file.

{{% notice Note %}}
When communicating from the Fastpath host to the SUT, use the SUT's private IP address.  This will allow for much faster communication and file transfer.
{{% /notice %}}

In this example, `44.201.174.17` is used as the Fastpath host public IP, and `100.119.0.139` is used as the SUT's private IP. Replace with your own values:

```command
ssh -A -i ~/.ssh/gcohen1.pem ubuntu@44.201.174.17 # SSH to FASTPATH_PUBLIC_IP with agent forwarding
source ~/venv/bin/activate # Activate the Fastpath virtual environment
cd ~/arm_kernel_install_guide # Enter the helper scripts repository
./scripts/configure_fastpath_sut.sh --host 100.119.0.139 # Configure the new SUT instance via its private IP
```

```output
[2026-01-07 00:25:45] Configuring 100.119.0.139 as fastpath SUT (non-interactive mode)
[2026-01-07 00:25:45] Ensuring docker.io, btop, and yq are installed
Warning: Permanently added '100.119.0.139' (ED25519) to the list of known hosts.
Hit:1 http://us-east-1.ec2.ports.ubuntu.com/ubuntu-ports noble InRelease
...
0 upgraded, 13 newly installed, 0 to remove and 29 not upgraded.
...
[2026-01-07 00:26:19] Testing SSH connectivity for fpuser
fpuser
[2026-01-07 00:26:20] Fastpath SUT configuration complete.
[2026-01-07 00:26:20] Note: ubuntu may need to re-login for docker group membership to take effect.
```



## Validate Fastpath connectivity
Once complete, ensure the Fastpath host can properly ping the SUT with the following command:

```command
cd ~/fastpath
source ~/venv/bin/activate
./fastpath/fastpath sut fingerprint --user fpuser 100.119.0.139
```

```output
HW:
  host_name: ip-100-119-0-139
  architecture: aarch64
  cpu_count: 48
  ...
  product_name: c8g.12xlarge
SW:
  kernel_name: 6.14.0-1018-aws
  userspace_name: Ubuntu 24.04.3 LTS
```

A successful run prints hardware details for the SUT. If the command fails, verify security group rules and rerun the configuration script.  If you are able to ssh into the SUT as `fpuser`, but the fingerprint command still fails, ensure that `docker.io` is installed on the SUT.

With the SUT now configured, you're ready to move on to the next step: setting up and running a Fastpath benchmark!  Remember to stop (but not terminate) the build instance so that kernel artifacts remain available, and stop any Fastpath/SUT instances when you are finished testing to avoid unnecessary spend.
