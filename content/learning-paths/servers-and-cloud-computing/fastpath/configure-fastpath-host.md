---
title: "Prepare Fastpath runtime and SUT"

weight: 10

layout: "learningpathall"
---

Configure the Fastpath host, provision the system under test (SUT), and verify connectivity between them.

## Configure the Fastpath host

1. Stay on the Fastpath host and ensure you are in the helper repository:

```console
cd ~/work/arm_kernel_install_guide
```

2. Run the host configuration script, targeting localhost:

```console
./scripts/configure_fastpath_host.sh --host localhost
```

3. The script creates a Python virtual environment (default `~/venv`) and installs the Fastpath CLI alongside its dependencies. Whenever you log back into the machine, activate the environment before running any Fastpath commands:

```console
source ~/venv/bin/activate
```

At this stage the Fastpath host has both the kernel artifacts and the Fastpath software stack required for orchestration.

## Provision the SUT

1. Launch a Graviton4 `c8g.12xlarge` instance with Ubuntu 24.04 LTS in the same VPC as the Fastpath host.
2. Attach at least 200 GB of gp3 storage to accommodate kernel deployments and benchmark data.
3. Tag the instance `fastpath-sut` and reuse the existing SSH key pair.
4. After it boots, SSH in once to verify connectivity and record its private IP address:

```console
curl -s http://169.254.169.254/latest/meta-data/local-ipv4
```

## Configure the SUT via Fastpath

1. Back on the Fastpath host, activate the Python environment if needed:

```console
source ~/venv/bin/activate
```

2. Run the SUT configuration script, substituting the private IP captured above:

```console
cd ~/work/arm_kernel_install_guide
./scripts/configure_fastpath_sut.sh --host SUT_PRIVATE_IP
```

3. If you lose track of the IP, query it via the AWS CLI:

```console
aws ec2 describe-instances --filters "Name=tag:Name,Values=fastpath-sut" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" --output text
```

The script installs the Fastpath agent, creates the `fpuser` account, and primes the SUT for remote kernel installs.

## Validate Fastpath connectivity

Ensure the Fastpath host can reach the SUT and gather its fingerprint.

```console
source ~/venv/bin/activate
./fastpath/fastpath/fastpath sut fingerprint --user fpuser SUT_PRIVATE_IP
```

A successful run prints hardware details for the SUT. If the command fails, verify security group rules and rerun the configuration script.
