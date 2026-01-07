---
title: "Generate and Execute the Benchmark Plan"
weight: 11

layout: "learningpathall"
---

With all required components in place, it's time to generate a Fastpath benchmark plan, execute it, and analyze the results.

## Generate the Fastpath plan

Fastpath uses a YAML-formatted [plan file](https://fastpath.docs.arm.com/en/latest/user-guide/planexec.html#introduction) to define the system under test (SUT), the kernels to deploy, and the benchmark workloads to run.

This YAML file can be manually authored, but to simplify the process for this LP, a helper script is provided that gathers the required information and produces a valid `plan.yaml` file output.


1. Run the following on the Fastpath instance to activate the Fastpath virtual environment, and run the plan generator script.  Have your SUT's private IP address handy, as you'll be prompted to enter it:

```command
source ~/venv/bin/activate
cd ~/arm_kernel_install_guide
./scripts/generate_plan.sh
```

When complete, the script creates the plan, and provides a list of frequently performed tasks relative to the plan:

```output
Enter SUT private IP: 10.123.22.11
Plan name:
  fastpath_test_010726-1955

Plan written to:
  /home/ubuntu/arm_kernel_install_guide/plans/fastpath_test_010726-1955.yaml

Run Fastpath with:
  fastpath plan exec --output results/ /home/ubuntu/arm_kernel_install_guide/plans/fastpath_test_010726-1955.yaml

After Fastpath run completes, gather results with:
  fastpath result list results/ --object swprofile

Relative results per kernel:
  fastpath result show results/ --swprofile 6.19.0-rc1-ubuntu+ --relative
  fastpath result show results/ --swprofile 6.18.1-ubuntu+ --relative

Comparison between kernels:
  fastpath result show results/ --swprofile 6.19.0-rc1-ubuntu+ --swprofile 6.18.1-ubuntu+ --relative
```



## Understand the Fastpath benchmark plan

With the plan generated, you can now run Fastpath to execute the benchmark workloads defined in the plan.

Before you do, take a quick look at the generated plan file to see what kernels and workloads are defined:

```console
cat plans/fastpath_test_010726-2015.yaml # your plan filename will be different, replace accordingly
```

```output
sut:
  name: fastpath_test_010726-2015
  connection:
    method: SSH
    params:
      user: fpuser
      host: 172.31.110.221
swprofiles:
- name: fp_6.19.0-rc1-ubuntu
  kernel: /home/ubuntu/kernels/6.19.0-rc1-ubuntu+/Image.gz
  modules: /home/ubuntu/kernels/6.19.0-rc1-ubuntu+/modules.tar.xz
- name: fp_6.18.1-ubuntu
  kernel: /home/ubuntu/kernels/6.18.1-ubuntu+/Image.gz
  modules: /home/ubuntu/kernels/6.18.1-ubuntu+/modules.tar.xz
benchmarks:
- include: speedometer/v2.1.yaml
defaults:
  benchmark:
    warmups: 1
    repeats: 2
    sessions: 2
    timeout: 1h
```

Within the YAML file, you can see the plan name (sut.name), and connection info (sut.connection) for the SUT.

Under swprofiles, the two kernel variants built earlier are defined, along with their paths on the Fastpath host (which will be pushed to the SUT during test runtime).

Under benchmarks, the Speedometer v2.1 benchmark workload is specified to run against each kernel.

The yaml also shows the two kernel variants to be tested (swprofiles), and the benchmark workload to run (benchmarks).

For more information on the plan file format and options, see the [Fastpath PlanExec User Guide](https://fastpath.docs.arm.com/en/latest/user-guide/planexec.html).

For a list of current benchmarks supported by Fastpath, see the [Fastpath Benchmark User Guide](https://fastpath.docs.arm.com/en/latest/user-guide/planschema.html#benchmark-library).



## Execute the Fastpath benchmark plan

Time to run the benchmark!  An example plan execution commandline is given under the "Run Fastpath with:" section of the plan generator's output, similar to:

```output
  fastpath plan exec --output results/ /home/ubuntu/arm_kernel_install_guide/plans/fastpath_test_010726-2015.yaml
```

Copy and paste that line, to begin the testing:

```output
Executing fastpath_test_010726-2015.yaml...
0%|                | 0/12 [00:00<?, ?it/s]
```

And away the testing begins!

{{% notice Note %}}
In the above command, the `--output` parameter specifies the directory where Fastpath stores benchmark results. If the directory *does not* exist, Fastpath creates it and continues.  However, if it *does* exist already, Fastpath will fatally exit, as it doesn't want to add more results to that existing folder (unless explicitly told to do so).

The solution is to use the `--append` parameter at the end of the `fastplath plan exec` command with the existing folder name, or specify a new output directory without the `--append` parameter.

{{% /notice %}}

When the execution completes 100%, Fastpath will have run the Speedometer benchmark against both kernels on the SUT, and stored the results in the specified output directory.

In the next chapter, you'll learn how to analyze and compare the results.

