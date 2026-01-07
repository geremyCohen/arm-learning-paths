## Fastpath Host Serial Console TODO

**Context (2026-01-07)**  
- Fastpath host: `gcohen-fastpath` (`i-08eba6020ba91eb75`, us-east-1a)  
- `fpuser` created locally with `/bin/bash` and password `Fpuser!Fastpath2026`.  
- Goal: prove we can access the EC2 serial console using the AWS CLI + SSH, log in as `fpuser`, then reboot safely.

**What’s blocking**  
1. `aws ec2-instance-connect send-serial-console-ssh-public-key ...` succeeds.  
2. `ssh -i ~/.ssh/gcohen1.pem i-08eba6020ba91eb75.port0@serial-console.ec2-instance-connect.us-east-1.aws` authenticates, but the connection is immediately closed by the remote host before we see a login prompt.  
3. `serial-getty@ttyS0` is active on the host and account-level serial-console access is enabled, so the failure appears to be on the AWS service path.

**Resolution (2026-01-07)**  
- Successfully pushed the SSH key via `aws ec2-instance-connect send-serial-console-ssh-public-key` and automated the connection using `pexpect`, logged in as `fpuser`, ran `whoami`, and exited.  
- Immediately rebooted `gcohen-fastpath` (`sudo reboot` over SSH) and confirmed the host returned by looping on `ssh ubuntu@98.94.83.199 'echo fastpath-up'`.

This TODO is now complete.
