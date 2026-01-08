---
title: "Setup System Under Test Instance"

weight: 10

layout: "learningpathall"
---
Now that kernels are built and the Fastpath host is ready, it's time to set up the system under test (SUT).


## Provision the SUT

The System Under Test (SUT) is the target machine where Fastpath installs your kernels, runs benchmarks on each kernel (one at a time) and when complete, compares and displays the results via Fastpath.

Just like choosing the kernels to test, the instance type of the SUT depends on your use case. For this Fastpath LP, we recommend a Graviton4 `c8g.12xl` instance with Ubuntu 24.04 LTS. This instance type provides a good balance of CPU and memory for a test benchmark.

Launch the *SUT* host machine with the following settings:

1. **Name** — *fastpath-sut*
2. **Operating system** — *Ubuntu*
3. **AMI** — *Ubuntu 24.04 LTS (Arm)*
4. **Architecture** — *64-bit Arm*
5. **Instance type** — `c8g.12xlarge`
6. **Key pair** — `gcohen1` (or your own key)
7. **Security group** — *allow SSH inbound from your IP and Fastpath host*
8. **Storage** — *200 GB gp3*

For a visual representation of these steps, refer back to the diagram in [Build Setup](../build_setup/).

When the instance reports a `running` state, note the public and private IP addresses as SUT_PUBLIC_IP and SUT_PRIVATE_IP.  You'll need these values later.


## Configure the SUT via the Fastpath instance


You'll next run a script that remotely installs the Fastpath software, and the required `fpuser` system account.  It also sets up SSH access for the new `fpuser` account by copying over ubuntu@SUT's `~/.ssh/authorized_keys` file.

{{% notice Note %}}
When communicating from the Fastpath host to the SUT, use the SUT's private IP address.  This will allow for much faster communication and file transfer.
{{% /notice %}}

In this example, `44.201.174.17` is used as the Fastpath host public IP, and `100.119.0.139` is used as the SUT's private IP. Replace with your own values:

```command
ssh -A -i ~/.ssh/gcohen1.pem ubuntu@3.86.227.83 # SSH to FASTPATH_PUBLIC_IP with agent forwarding
source ~/venv/bin/activate # Activate the Fastpath virtual environment
cd ~/arm_kernel_install_guide # Enter the helper scripts repository
./scripts/configure_fastpath_sut.sh --host 172.31.100.19 # Configure the new SUT instance via its private IP
```

```output
[2026-01-08 18:36:23] Configuring 172.31.100.19 as fastpath SUT (non-interactive mode)
[2026-01-08 18:36:23] Ensuring docker.io, btop, and yq are installed
Warning: Permanently added '172.31.100.19' (ED25519) to the list of known hosts.
Hit:1 http://us-east-1.ec2.ports.ubuntu.com/ubuntu-ports noble InRelease
...
[2026-01-08 18:36:47] Creating/updating fpuser
[2026-01-08 18:36:53] Testing SSH connectivity for fpuser
fpuser
[2026-01-08 18:36:54] Fastpath SUT configuration complete.
[2026-01-08 18:36:54] Note: ubuntu may need to re-login for docker group membership to take effect.
```



## Validate Fastpath connectivity
Once complete, ensure the Fastpath host can properly ping the SUT with the following command:

```command
cd ~/fastpath
source ~/venv/bin/activate
./fastpath/fastpath sut fingerprint --user fpuser 172.31.100.19
```

```output
HW:
  host_name: ip-172-31-100-19
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
