---
title: "Build a Fastpath-enabled kernel"

weight: 5

layout: "learningpathall"
---

You now have everything required to produce kernels that comply with the Fastpath harness.  
Reuse the Fastpath-specific tags that ship with the Kernel Install Guide to trigger a pair of comparable builds.

1. Stay on the build machine and change into the `arm_kernel_install_guide` workspace you cloned earlier.
2. Open `http://localhost:1313/install-guides/kernel-build/#2-custom-tags-with-fastpath-enabled` and follow the instructions in that section.  
   The helper script wraps the `tuxmake` invocation with the Fastpath build options documented in [Fastpath User Guide → Build a kernel](https://fastpath.docs.arm.com/en/latest/user-guide/buildkernel.html).
3. When prompted, confirm the output directory (for example, `~/work/kernel-builds/fastpath`). The script builds two kernel images by default—one baseline and one Fastpath-instrumented—so you can compare performance later.
4. Monitor the console output for the `BUILD COMPLETE` message. If the build fails, consult both the Kernel Install Guide and the Fastpath troubleshooting notes before re-running the script.

Once the `tuxmake` jobs finish you will have Fastpath-ready kernel artifacts on the build machine.  
In the next stages of this learning path you will deploy those kernels with Fastpath and run the benchmark harness to measure their performance deltas.
