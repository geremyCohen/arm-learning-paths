---
title: "Manage your AWS resources"

weight: 17

layout: "learningpathall"
---

Benchmarks can run for hours, so keep a simple hygiene checklist to control cost and preserve artifacts:

1. Stop the *fastpath* and SUT instances when you are not actively testing. Restart them only when you are ready to rerun `fastpath plan exec`.
2. Terminate instances once you no longer need them, but archive the `results/` directory (for example, to Amazon S3) before doing so.
3. Track the EBS volumes that back each instance. Deleting an instance does not automatically delete detached volumes, so remove unused storage to avoid lingering charges.

Following these practices keeps your *fastpath* lab ready for future experiments without surprise expenses.
