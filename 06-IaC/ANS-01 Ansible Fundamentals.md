---
tags: [devops, iac, ansible, config-management]
aliases: [Ansible Basics]
created: 2025-06-27
status: #complete
difficulty: #beginner
cert-relevant: #none
---

# ANS-01 Ansible Fundamentals

> [!abstract] Overview
> Provisioning a server with Terraform is only half the battle; configuring it is the other half. If you have 50 Linux servers and need to install Nginx, create a user, and patch a security vulnerability on all of them simultaneously, doing it manually via SSH is impossible. Ansible is an IT automation engine that handles configuration management, application deployment, and task automation. Its agentless architecture (using standard SSH) makes it incredibly lightweight and universally adopted in DevOps.

---

## Concept Overview

- **What it is** — An open-source configuration management tool written in Python. It uses YAML to describe the desired state of systems and executes modules over SSH to achieve that state.
- **Why DevOps engineers use it** — Idempotency and Agentless design. **Idempotency** means you can run an Ansible script 100 times, and if the server is already correctly configured, Ansible does nothing. **Agentless** means you don't need to install any special Ansible software on the target servers; if you can SSH into it, Ansible can manage it.
- **Where you encounter this in a real job** — Patching the OpenSSL vulnerability on 500 EC2 instances across 3 AWS regions in one command, or bootstrapping a fresh Ubuntu server with monitoring agents and firewall rules.
- **Responsibility Split:**
  - **Junior DevOps**: Runs Ansible Ad-Hoc commands (e.g., `ansible all -m ping`) and executes pre-written playbooks.
  - **Mid DevOps**: Writes Idempotent playbooks, manages the `inventory` file, and handles privilege escalation (`become`).
  - **Senior/SRE**: Writes custom Python modules for Ansible, sets up Dynamic Inventories pulling directly from AWS APIs, and integrates Ansible with Packer for immutable image baking.

*Seedha simple mein: Ansible ek jaadui remote control hai. Agar aapke paas 100 TV (servers) hain, toh aapko sabke paas jaa kar volume set nahi karna padega. Aap Ansible remote mein YAML mein likh do "Volume 50", aur wo SSH ke through sab TVs ka volume ek second mein 50 kar dega. Aur sabse acchi baat, TVs pe koi receiver (agent) install nahi karna.*

---

## Technical Deep Dive

### 1. Architecture: Control Node vs. Managed Nodes
Ansible operates on a push model.
- **Control Node**: The laptop or CI/CD server where Ansible is installed. (Must be Linux/Mac, Windows requires WSL).
- **Managed Nodes**: The servers you are configuring. They only need Python and SSH installed.
- **Inventory**: A file (usually INI or YAML) that lists the IP addresses of your Managed Nodes, grouped logically (e.g., `[webservers]`, `[dbservers]`).

### 2. Modules and Idempotency
Ansible doesn't just run raw bash commands; it uses Python **Modules**. A module (like `apt`, `yum`, `user`, `file`) understands the desired state. 
If you use the `shell` module to run `mkdir /app`, and you run it twice, the second run fails because the directory exists. This is NOT idempotent.
If you use the `file` module (`state: directory`), Ansible checks if the directory exists. If yes, it reports `OK` and does nothing. If no, it creates it and reports `CHANGED`. Always use Ansible modules instead of raw shell commands to guarantee idempotency.

### 3. Ad-Hoc Commands vs. Playbooks
- **Ad-Hoc Commands**: Quick, one-line commands run from the terminal to do a single task across many servers (e.g., checking uptime, restarting a service). They are not saved for reuse.
- **Playbooks**: YAML files where complex, multi-step configurations are saved, version-controlled, and executed sequentially.

---

## Step-by-Step Lab

> [!warning] Pre-requisites
> - A Control Node (Linux/Mac/WSL) with Ansible installed (`sudo apt install ansible`)
> - 2 target Linux servers (e.g., AWS EC2 instances)
> - SSH Key access from Control Node to target servers

### Step 1: Create the Inventory File
```ini
# Create a file named 'hosts'
[webservers]
192.168.1.10
192.168.1.11

[dbservers]
192.168.1.12

# Grouping groups together
[production:children]
webservers
dbservers
```

### Step 2: Configure ansible.cfg
```ini
# Create ansible.cfg in the same directory to override default behaviors
[defaults]
inventory = ./hosts
host_key_checking = False
remote_user = ubuntu
private_key_file = ~/.ssh/my-key.pem
```

### Step 3: Run Ad-Hoc Ping Module
```bash
# Test connectivity to all servers in the inventory
ansible all -m ping

# Expected output:
# 192.168.1.10 | SUCCESS => {
#     "ansible_facts": {
#         "discovered_interpreter_python": "/usr/bin/python3"
#     },
#     "changed": false,
#     "ping": "pong"
# }
```

### Step 4: Run Ad-Hoc System Tasks
```bash
# Check uptime on all webservers
ansible webservers -m command -a "uptime"

# Create a user on all servers. Requires sudo/root privileges (-b / --become)
ansible all -m user -a "name=johndoe state=present" -b

# Expected output:
# 192.168.1.10 | CHANGED => { "name": "johndoe", "state": "present", ... }
```

### Step 5: Test Idempotency
```bash
# Run the EXACT SAME user creation command again
ansible all -m user -a "name=johndoe state=present" -b

# Expected output:
# 192.168.1.10 | SUCCESS => { "name": "johndoe", "state": "present" ... }
# Notice it says SUCCESS (Green), not CHANGED (Yellow). Ansible knew the user existed and did nothing!
```

> [!tip] Pro Tip
> Never disable `host_key_checking = False` in a true production environment, as it opens you up to Man-in-the-Middle (MITM) attacks via SSH. Instead, strictly manage your `known_hosts` file, or use a tool like HashiCorp Vault to inject SSH certificates dynamically.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `ansible all -m ping` | Tests SSH and Python connectivity | `ansible all -m ping -i hosts` |
| `ansible -m command` | Runs a raw command (bypasses shell) | `ansible web -m command -a "uptime"` |
| `ansible -m shell` | Runs a shell command (supports pipes `\|`) | `ansible db -m shell -a "cat /etc/passwd \| grep root"` |
| `ansible -m setup` | Gathers "Facts" (OS, IP, CPU details) | `ansible all -m setup` |
| `ansible-doc <module>`| Reads the manual/parameters for a module | `ansible-doc yum` |
| `ansible-inventory` | Validates and dumps the inventory config | `ansible-inventory --list` |
| `ansible -b` | Elevates privileges (runs as root/sudo) | `ansible all -m apt -a "name=nginx" -b` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|------------------|
| `UNREACHABLE! => "msg": "Failed to connect to the host via ssh"` | SSH Key or Port issue | Verify you can manually SSH (`ssh -i key.pem user@IP`). Check if `remote_user` in `ansible.cfg` matches the cloud provider's default user (e.g., `ubuntu` or `ec2-user`). |
| `MODULE FAILURE: /usr/bin/python: not found` | Target is missing Python | Ansible requires Python on the target. Run an ad-hoc command to install it first: `ansible all -m raw -a "apt install -y python3" -b`. |
| `Missing sudo password` | Passwordless sudo not configured | If the target user requires a password for `sudo`, you must pass the `-K` (or `--ask-become-pass`) flag to the ansible command. |
| Ad-Hoc command modifying files fails with `Permission denied` | Forgot privilege escalation | You are trying to edit `/etc/` or install packages as a normal user. Add the `-b` (become) flag to the end of your command. |
| Dynamic inventory script returns nothing | Cloud credentials missing | If using `aws_ec2` plugin, ensure your terminal has valid AWS keys exported, otherwise Ansible cannot query the AWS API. |

---

## Real-World Job Scenario

> [!info] Scenario
> **Situation:** "A critical zero-day vulnerability is announced in `log4j`. Security mandates that every Java process on all 200 Linux servers must be stopped immediately."

**What Junior DevOps Does:**
Opens 5 terminal windows, connects to 5 servers via SSH, runs `systemctl stop java-app`, and prepares to spend the next 4 hours doing this manually, praying they don't miss a server.

**Escalation Trigger:**
The CISO wants confirmation in 10 minutes that the vulnerability is mitigated across the entire fleet. Manual SSH will not meet the SLA.

**Senior Engineer Resolution:**
1. Verifies the Ansible inventory is up to date (`ansible all --list-hosts`).
2. Runs a single Ad-Hoc command using the `service` module with privilege escalation:
   `ansible all -m service -a "name=java-app state=stopped" -b -f 50`
3. The `-f 50` flag tells Ansible to fork 50 parallel SSH connections at once.
4. Within 15 seconds, Ansible reports back the status of all 200 servers. 195 report `CHANGED` (service stopped). 5 report `FAILED`.
5. The Senior immediately isolates those 5 failed servers for manual investigation, while confidently reporting to the CISO that 98% of the fleet is secured.

**Lesson Learned:**
Ansible Ad-Hoc commands are the ultimate firefighting tool for widespread fleet operations.

---

## Interview Questions

**Q1 (Conceptual):** What does "Agentless" mean in the context of Ansible, and why is it an advantage over Chef or Puppet?
**A:** Agentless means Ansible does not require any proprietary daemon or software running continuously on the target servers. It relies entirely on standard SSH and Python. This is a massive advantage because it eliminates the overhead of managing, patching, and troubleshooting agent software, and reduces CPU/Memory consumption on the target nodes.

**Q2 (Practical):** You need to restart the `nginx` service on 10 servers, but you only want to do it on servers where the OS is Ubuntu. How do you do this using an Ad-Hoc command?
**A:** Assuming my inventory has a group for ubuntu servers, I would run: `ansible ubuntu_group -m service -a "name=nginx state=restarted" -b`. If they aren't grouped, I can filter using gathered facts, but standard grouping in the inventory file is the correct Ansible pattern.

**Q3 (Scenario-based):** You wrote a script to append a line to a configuration file using the `shell` module (`echo "config=true" >> /etc/app.conf`). Your senior rejects the PR and says it breaks idempotency. Why, and how do you fix it?
**A:** The `shell` module is not idempotent; if run 10 times, it will append "config=true" 10 times, corrupting the file. To fix it, I must use Ansible's built-in `lineinfile` module: `-m lineinfile -a "path=/etc/app.conf line='config=true'"`. This module checks if the line exists first; if it does, it safely skips the action.

**Q4 (Deep dive):** Explain what "Ansible Facts" are and how they are gathered.
**A:** Ansible Facts are system properties (like OS family, IP addresses, MAC addresses, CPU cores, and free memory) gathered from the target nodes. When an Ansible run starts, it secretly executes the `setup` module first. This module queries the target's system information and stores it in variables (like `ansible_os_family`) that you can use later to write conditional logic (e.g., "Only run this yum command IF OS is CentOS").

**Q5 (Trick/Gotcha):** Can you use Ansible to manage Windows servers? If yes, does it use SSH?
**A:** Yes, Ansible can manage Windows servers, but it does NOT natively use SSH. Instead, it uses Windows Remote Management (WinRM) or PowerShell Remoting over HTTPS. You must configure the Windows host to accept WinRM connections and use specific Windows modules (like `win_service` or `win_feature`) instead of the Linux modules.

---

## Related Notes

[[00-MOC/Master-Index|Master Index]]
[[06-IaC/ANS-02 Ansible Playbooks|Ansible Playbooks]]
[[01-Linux-Foundation/LX-01 Linux for DevOps|Linux SSH Basics]]
