---
title: "Benchmark plan and analysis"

weight: 14

layout: "learningpathall"
---

With the Fastpath host and SUT configured, generate the plan, execute the benchmark, and analyze the results in one workflow.

## Generate the Fastpath plan

1. From the Fastpath host, stay in the helper repository and ensure the virtual environment is active.
2. Execute the plan generator script. It prompts for the SUT IP and uses the kernel artifacts you pulled earlier:

```console
cd ~/work/arm_kernel_install_guide
./scripts/generate_plan.sh
```

3. Provide the requested values (SUT private IP, kernel locations, desired benchmark suite). The script writes `plan.yaml` to the current directory, emits the auto-generated test name, and prints the Fastpath CLI snippets you will use later to inspect results.

Keep those CLI snippets handy—they are unique to each plan and will be referenced after the benchmark run completes.

## Execute the Fastpath benchmark

Run the benchmark defined in `plan.yaml` and capture the outputs under the `results/` directory.

```console
source ~/venv/bin/activate
fastpath plan exec --output results/ plan.yaml
```

Fastpath automatically deploys each kernel variant to the SUT, executes the benchmark workload(s) specified in the plan, and stores telemetry plus summary statistics in `results/`.

## Review benchmark results

Inspect the outputs stored in the `results/` directory using the commands echoed by `generate_plan.sh`.

1. **List all captured runs** to confirm the execution finished:

```console
fastpath results list results/
```

2. **Inspect a single kernel’s metrics** using the per-run command printed by the plan generator (for example `fastpath results show --run RUN_ID results/`).
3. **Compare combined results** from both kernels using the aggregated command provided (for example `fastpath results compare --run RUN_ID_A --run RUN_ID_B results/`).

By default, rerunning Fastpath with the same `plan.yaml` and results directory requires either changing `sut.name` or supplying a new output directory. If you intentionally keep the same directory, pass `--append` to `fastpath plan exec` so the tooling preserves existing runs instead of overwriting them.
