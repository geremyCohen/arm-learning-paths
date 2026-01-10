---
title: "Fastpath LP Testing Playbook"
---

Use this reference before every Fastpath learning-path (LP) validation run so test transcripts stay consistent and reusable.

## General Workflow
- Always work from the `LP_walk_through` branch (or whatever branch the user specifies) and keep `.codex` artifacts out of commits unless explicitly requested.
- Run `AWS_PROFILE=arm aws sts get-caller-identity` (or export `AWS_DEFAULT_PROFILE=arm`) first; stop immediately if credentials fail.
- Capture every shell command referenced in the LP along with trimmed but real output snippets. Use fenced blocks labeled `command`/`output` in the markdown.

## Run Sequencing
1. **First pass (authoring mode)**  
   - Follow the LP step-by-step.  
   - Update the LP with ` ```command` and ` ```output` blocks that reflect real executions.  
   - Fix any inaccuracies encountered.
2. **Second pass (verification mode)**  
   - Re-run all steps without editing the LP.  
   - Only report whether every step still works plus any follow-up suggestions.  
   - Note any drift between documented commands/output and the second run.

## AWS & Instance Rules
- Region: `us-east-1` unless the user explicitly overrides it, and default all AWS CLI usage to `AWS_DEFAULT_PROFILE=arm`.
- Name every EC2 instance with the prefix `gcohen-` (e.g., `gcohen-fastpath-build-docs`).
- Default instance types:
  - Build machines: `c8g.24xlarge`.
  - Non-build helpers (Fastpath host, SUT, etc.): `c8g.2xlarge`.
- Prefer existing key pair `gcohen1`; keep the private key on the local workstation.
- Security groups:
  - Create per-test security groups when needed (e.g., `gcohen-fastpath-build-sg`) and restrict SSH ingress to the current Codex public IP.
  - Reuse groups if they already exist with the same rules.
  - There is no need to document security group creation / ec2-related aws cli steps.  You may need to discover how to create a SG, id the VPC/subnet to use, the ec2 commands, etc., but these do not need to be included in the LP, as we assume the user knows what to do when we say "bring up an instance"

## Lifecycle Management
- **Build machines**: shut them down with `sudo init 0` or `aws ec2 stop-instances` when finished, but do **not** terminate them. This preserves the kernel artifacts for follow-up work.
- **Fastpath host & SUT instances**: stop them when the scenario is complete to limit cost; terminate only when the user explicitly approves.
- Remove any temporary security groups only after all dependent instances are terminated or the user says they are no longer needed.

## Fastpath/Tuxmake Specifics
- Always clone `https://github.com/geremyCohen/arm_kernel_install_guide.git` into the home directory of the build host, then `chmod +x scripts/*.sh`.
- Run the Fastpath build via:
  ```
  ./scripts/kernel_build_and_install.sh --tags v6.18.1,v6.19-rc1 --fastpath true
  ```
  Adjust tag lists only if the LP explicitly asks for different versions.
- Save the build logs locally (copy/paste into the LP or an appendix) so failures can be diagnosed without re-running a 15-minute build.
- When referencing artifacts later (pull scripts, Fastpath deployment), record the actual artifact directory paths produced by the build (`~/kernels/<tag>`).

## Documentation Notes
- Keep the Hugo front matter untouched unless the user requests metadata changes.
- Use the `{% notice %}` shortcodes consistently if adding warnings/tips.
- Mention the exact instance IDs, IPs, and AWS resources in the validation report so the user can reuse or clean them up.
- If a command differs between regions or instance sizes, call it out explicitly rather than editing the canonical LP instructions.

## Common Pitfalls to Watch
- Missing `AWS_DEFAULT_PROFILE=arm` or region flags → credentials errors.
- Forgetting to open SSH from the Codex IP after creating a new security group.
- Terminating build instances too early, forcing rebuilds.
- Not waiting for `aws ec2 wait instance-running` before SSH, leading to connection failures.

Keeping to these rules ensures repeatable Fastpath LP tests and minimizes AWS spend. Run through this checklist before each testing cycle.
