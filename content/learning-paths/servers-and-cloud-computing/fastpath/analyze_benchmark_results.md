---
title: "Analyze the Benchmark Results"
weight: 14

layout: "learningpathall"
---

## Review benchmark results



To inspect the outputs stored in the `results/` directory you can use the sample commands output when `generate_plan.sh` completed.  Some examples are below:

### List swprofiles involved from tests saved in the *results* folder:

To see the swprofiles (kernels) tested and stored in the results directory, run:

```commandline
fastpath result list results/ --object swprofile
```

If you followed the tutorial exactly, you should see output similar to:

```output
+------------------+----------------------+
| ID               | fp_6.18.1-ubuntu     |
+------------------+----------------------+
| Kernel Name      | 6.18.1-ubuntu+       |
+------------------+----------------------+
| Kernel Git SHA   | <none>               |
+------------------+----------------------+
| Userspace        | Ubuntu 24.04.3 LTS   |
+------------------+----------------------+
| cmdline          | <none>               |
+------------------+----------------------+
| sysctl           | <none>               |
+------------------+----------------------+
| bootscript       | <none>               |
+------------------+----------------------+

+------------------+----------------------+
| ID               | fp_6.19.0-rc1-ubuntu |
+------------------+----------------------+
| Kernel Name      | 6.19.0-rc1-ubuntu+   |
+------------------+----------------------+
| Kernel Git SHA   | <none>               |
+------------------+----------------------+
| Userspace        | Ubuntu 24.04.3 LTS   |
+------------------+----------------------+
| cmdline          | <none>               |
+------------------+----------------------+
| sysctl           | <none>               |
+------------------+----------------------+
| bootscript       | <none>               |
+------------------+----------------------+
```

### View relative results per kernel

To see the relative results for each kernel, run the following commands:

```commandline
  fastpath result show results/ --swprofile 6.19.0-rc1-ubuntu+ --relative
```
Relative in this case means that the statistics displayed are relative to the mean. In addition to the min/mean/max, you are also given the confidence interval bounds, the coefficient of variation and the number of samples, similar to:

```output
+------------------+--------------------+--------+----------+--------+----------+--------+--------+-------+
| Benchmark        | Result Class       |    min | ci95min  |   mean | ci95max  |    max |     cv | count |
+------------------+--------------------+--------+----------+--------+----------+--------+--------+-------+
| speedometer/v2.1 | score (runs/min)   | -0.57% |  -1.09%  | 219.25 |   1.09%  |  0.80% |  0.68% |     4 |
+------------------+--------------------+--------+----------+--------+----------+--------+--------+-------+
```

You can run it again for the other kernel:

```commandline
fastpath result show results/ --swprofile fp_6.18.1-ubuntu --relative```
```
with output similar to:

```output
+------------------+--------------------+--------+----------+--------+----------+--------+--------+-------+
| Benchmark        | Result Class       |    min | ci95min  |   mean | ci95max  |    max |     cv | count |
+------------------+--------------------+--------+----------+--------+----------+--------+--------+-------+
| speedometer/v2.1 | score (runs/min)   | -1.03% |  -1.50%  | 219.25 |   1.50%  |  0.80% |  0.94% |     4 |
+------------------+--------------------+--------+----------+--------+----------+--------+--------+-------+
```

### Compare results between kernels

To compare the relative results between both kernels, run:



```commandline
fastpath result show results/ --swprofile fp_6.19.0-rc1-ubuntu --swprofile fp_6.18.1-ubuntu --relative
```
with output similar to:

```output
+------------------+--------------------+-----------------------+---------------------+
| Benchmark        | Result Class       | fp_6.19.0-rc1-ubuntu  | fp_6.18.1-ubuntu    |
+------------------+--------------------+-----------------------+---------------------+
| speedometer/v2.1 | score (runs/min)   |                219.25 |               0.03% |
+------------------+--------------------+-----------------------+---------------------+
```
We see 6.18.1 is performing slightly better than 6.19-rc1 in this benchmark.

More examples of analyzing results can be found in the [Fastpath Results User Guide](https://fastpath.docs.arm.com/en/latest/user-guide/resultshow.html).



