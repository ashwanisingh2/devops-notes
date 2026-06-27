---
tags: [devops, linux, foundations]
aliases: [Linux Basics]
created: 2025-06-27
status: '#complete'
difficulty: '#beginner'
cert-relevant: '#none'
---

# Linux for DevOps Engineers

> [!abstract] Overview
> Linux is the bedrock of modern DevOps infrastructure. From cloud VMs and Docker containers to Kubernetes nodes and CI/CD runners, nearly every production system runs on the Linux kernel. As a DevOps engineer, the terminal is your primary workspace — you will use it to provision servers, debug live issues at 2 AM, automate repetitive tasks, manage users and permissions, and keep services running with zero downtime. Mastering Linux is not optional; it is the entry ticket to every serious DevOps role.

---

## Concept Overview

**What it is** — Linux is a free, open-source, Unix-like operating system kernel. It provides the bridge between hardware and the applications running on top. You interact with it primarily through the Shell (Bash, Zsh, etc.) via the Command Line Interface (CLI).

*Linux ek open-source operating system hai jo hardware aur software ke beech ka bridge ka kaam karta hai. Aap isse terminal ke through chalate ho.*

**Why DevOps engineers need it** — Almost every cloud provider (AWS, GCP, Azure) defaults to Linux instances. Docker containers run on Linux. Kubernetes nodes are Linux. Your CI/CD pipelines execute on Linux runners. If you can't navigate a Linux terminal confidently, you simply cannot do DevOps.

*Agar aap terminal pe comfortable nahi ho, toh DevOps mein aage jaana mushkil hai — kyunki production mein GUI nahi hota, sirf terminal hota hai.*

**Where it's used** — Production servers, staging environments, container runtimes, monitoring agents, log aggregation, and infrastructure-as-code execution — all of it is Linux.

**Responsibility Split:**

| Role | Linux Responsibility |
|---|---|
| Developer | Run apps locally, read logs, basic CLI usage |
| DevOps Engineer | Server setup, user management, firewall, services, automation, monitoring |
| SRE | Deep kernel tuning, performance profiling, incident response |

### 🏠 Desi Analogy — Linux Filesystem = Ghar Ka Layout

Think of the Linux filesystem like **ghar ka layout** (the layout of a house):

- `/` (root) = **Poora ghar** — the entire house starts from here
- `/home` = **Bedrooms** — each family member (user) gets their own room
- `/etc` = **Kitchen cabinet** — all the configuration/recipes are stored here
- `/var/log` = **Diary / register** — everything that happens gets logged here
- `/tmp` = **Guest room** — temporary stuff, cleaned up regularly
- `/usr/bin` = **Toolbox** — all the tools (commands/programs) you use daily
- Files = **Saamaan** (belongings) inside each room

*Jaise ghar mein har kamre ka apna kaam hota hai, waise hi Linux mein har directory ka apna purpose hota hai. `/etc` mein config files hain, `/var/log` mein logs hain, `/home` mein users ka data hai.*

---

## Technical Deep Dive

### 1. Filesystem & Navigation

The Linux filesystem is a single tree rooted at `/`. There are no drive letters like Windows. Everything — devices, processes, configs — is represented as a file.

**Essential Navigation Commands:**

```bash
# Print current working directory
pwd
# Output: /home/devops

# List files with details (permissions, owner, size, date)
ls -lah
# Output:
# drwxr-xr-x  5 devops devops 4.0K Jun 27 10:00 .
# -rw-r--r--  1 devops devops  220 Jun 27 09:50 .bashrc

# Change directory
cd /var/log

# Go back to home directory
cd ~

# Create nested directories in one shot
mkdir -p /opt/devops/scripts/monitoring

# Find files by name recursively
find /etc -name "*.conf" -type f

# Search inside files for a pattern
grep -rn "PermitRootLogin" /etc/ssh/
# Output: /etc/ssh/sshd_config:38:PermitRootLogin no
```

*`pwd` se pata chalta hai aap kahan ho, `ls -lah` se sab kuch dikhta hai — hidden files bhi, aur `find` se koi bhi file dhoondh sakte ho poore system mein.*

### 2. Permissions & User Management

Every file in Linux has three permission sets: **Owner**, **Group**, and **Others**. Each set has three permissions: **Read (r=4)**, **Write (w=2)**, **Execute (x=1)**.

```bash
# View permissions
ls -l deploy.sh
# Output: -rwxr-xr-- 1 devops devops 1024 Jun 27 10:00 deploy.sh
# Breakdown: Owner=rwx(7), Group=r-x(5), Others=r--(4) → 754

# Set permissions numerically
chmod 755 deploy.sh    # Owner: full, Group: read+execute, Others: read+execute

# Change file ownership
chown devops:devops /opt/app/config.yml

# Set default permissions for new files
umask 022    # New files get 644, new directories get 755

# Create a new user with home directory
useradd -m -s /bin/bash devops_user

# Set password
passwd devops_user

# Add user to sudo group
usermod -aG sudo devops_user

# Check user info
id devops_user
# Output: uid=1001(devops_user) gid=1001(devops_user) groups=1001(devops_user),27(sudo)
```

*Permissions samjho aise — Owner ghar ka malik hai, Group family members hain, Others bahar ke log hain. `chmod 755` ka matlab: malik ko sab allowed, family aur bahar waalon ko sirf padhna aur chalana allowed.*

### 3. Package Management & Services

Package managers install, update, and remove software. The manager depends on the distro:

| Distro Family | Package Manager | Example |
|---|---|---|
| Debian/Ubuntu | `apt` | `apt install nginx` |
| RHEL/CentOS/Fedora | `yum` / `dnf` | `dnf install httpd` |

```bash
# Update package index and upgrade all packages (Debian/Ubuntu)
sudo apt update && sudo apt upgrade -y

# Install a package
sudo apt install -y nginx curl wget git htop net-tools

# Check service status
sudo systemctl status nginx
# Output:
# ● nginx.service - A high performance web server
#    Active: active (running) since Fri 2025-06-27 10:05:00 UTC

# Enable service to start on boot
sudo systemctl enable nginx

# Restart a service after config change
sudo systemctl restart nginx

# View service logs
journalctl -u nginx --no-pager -n 50
```

**Networking Commands:**

```bash
# Check IP addresses
ip addr show

# Check open ports and listening services
ss -tulnp
# Output:
# LISTEN  0  511  0.0.0.0:80  0.0.0.0:*  users:(("nginx",pid=1234,fd=6))

# Test connectivity
curl -I https://google.com
wget -q --spider https://example.com && echo "Site is UP" || echo "Site is DOWN"

# DNS lookup
dig example.com +short
# Output: 93.184.216.34
```

**Disk Management:**

```bash
# Check disk space usage
df -h
# Output:
# Filesystem  Size  Used  Avail  Use%  Mounted on
# /dev/sda1    50G   12G    36G   25%  /

# Check directory size
du -sh /var/log
# Output: 2.3G    /var/log

# List block devices
lsblk
```

*`systemctl` se services ko start, stop, restart karte hain. `ss -tulnp` se pata chalta hai kaunsa port pe kaunsi service sun rahi hai. `df -h` se disk space check hota hai — production mein disk full hona sabse common problem hai.*

---

## Step-by-Step Lab: Fresh Server Setup for DevOps

> [!tip] Lab Environment
> Use a fresh Ubuntu 22.04/24.04 VM — AWS EC2, DigitalOcean droplet, Vagrant box, or WSL2.

### Step 1: System Update & Upgrade

```bash
sudo apt update && sudo apt upgrade -y
```

**Expected Output:**
```
Hit:1 http://archive.ubuntu.com/ubuntu jammy InRelease
Get:2 http://archive.ubuntu.com/ubuntu jammy-updates InRelease [119 kB]
...
Reading package lists... Done
Building dependency tree... Done
All packages are up to date.
```

### Step 2: Create a DevOps User with Sudo Access

```bash
# Create user with home directory and bash shell
sudo useradd -m -s /bin/bash devops

# Set a strong password
sudo passwd devops

# Add to sudo group
sudo usermod -aG sudo devops

# Verify
id devops
```

**Expected Output:**
```
uid=1001(devops) gid=1001(devops) groups=1001(devops),27(sudo)
```

### Step 3: Configure SSH for Secure Access

```bash
# Backup original config
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Disable root login and password auth (use keys instead)
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Restart SSH service
sudo systemctl restart sshd

# Verify SSH is running
sudo systemctl status sshd
```

**Expected Output:**
```
● ssh.service - OpenBSD Secure Shell server
     Active: active (running) since Fri 2025-06-27 10:10:00 UTC
```

### Step 4: Install Essential DevOps Tools

```bash
sudo apt install -y \
  git \
  curl \
  wget \
  htop \
  tree \
  net-tools \
  unzip \
  jq \
  vim \
  tmux

# Verify installations
git --version && curl --version | head -1 && jq --version
```

**Expected Output:**
```
git version 2.34.1
curl 7.81.0 (x86_64-pc-linux-gnu)
jq-1.6
```

### Step 5: Configure UFW Firewall

```bash
# Enable firewall
sudo ufw enable

# Allow SSH (IMPORTANT: do this BEFORE enabling, or you'll lock yourself out!)
sudo ufw allow 22/tcp

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Check firewall status
sudo ufw status verbose
```

**Expected Output:**
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
```

### Step 6: Verify All Services & Create Project Directory

```bash
# Check all critical services
sudo systemctl is-active sshd
sudo systemctl is-active ufw

# Create standard DevOps project structure
sudo mkdir -p /opt/devops/{scripts,configs,logs,backups}
sudo chown -R devops:devops /opt/devops

# Verify directory structure
tree /opt/devops
```

**Expected Output:**
```
/opt/devops
├── backups
├── configs
├── logs
└── scripts

4 directories, 0 files
```

> [!success] Lab Complete
> Your server is now updated, secured with SSH keys, has a dedicated devops user with sudo access, essential tools installed, firewall configured, and a clean project directory structure ready for automation.

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---|---|---|
| `ls -lah` | List all files with details including hidden | `ls -lah /etc/nginx/` |
| `chmod 755` | Set owner=rwx, group=r-x, others=r-x | `chmod 755 deploy.sh` |
| `chown user:group` | Change file/directory ownership | `chown devops:devops /opt/app` |
| `systemctl status` | Check if a service is running | `systemctl status nginx` |
| `journalctl -u` | View logs for a specific service | `journalctl -u nginx --no-pager -n 100` |
| `ss -tulnp` | Show listening ports and associated processes | `ss -tulnp \| grep 80` |
| `df -h` | Show disk space usage in human-readable format | `df -h /` |
| `du -sh` | Show total size of a directory | `du -sh /var/log` |
| `find / -name` | Search for files by name across filesystem | `find /etc -name "*.conf"` |
| `grep -rn` | Search for text patterns inside files recursively | `grep -rn "error" /var/log/syslog` |
| `tail -f` | Follow a log file in real-time | `tail -f /var/log/nginx/access.log` |
| `ip addr show` | Display network interfaces and IP addresses | `ip addr show eth0` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---|---|---|
| `Permission denied` when running a script | Script lacks execute permission | 1. Check: `ls -l script.sh` 2. Fix: `chmod +x script.sh` 3. Or run with: `bash script.sh` |
| `E: Unable to locate package nginx` | Package index is outdated or repo not added | 1. Run: `sudo apt update` 2. Retry: `sudo apt install nginx` 3. If still failing: `sudo add-apt-repository universe && sudo apt update` |
| `ssh: connect to host x.x.x.x port 22: Connection refused` | SSH service not running or firewall blocking port 22 | 1. On server: `sudo systemctl status sshd` 2. If inactive: `sudo systemctl start sshd` 3. Check firewall: `sudo ufw allow 22/tcp` |
| `No space left on device` | Disk is 100% full | 1. Check: `df -h` to find full partition 2. Find large files: `du -sh /var/* \| sort -rh \| head -10` 3. Clean logs: `sudo truncate -s 0 /var/log/syslog` 4. Clean apt cache: `sudo apt clean` |
| `Failed to start nginx.service: Unit nginx.service not found` | Nginx is not installed | 1. Install: `sudo apt install -y nginx` 2. Enable: `sudo systemctl enable --now nginx` 3. Verify: `systemctl status nginx` |
| `sudo: devops is not in the sudoers file` | User not added to sudo group | 1. Switch to root: `su -` 2. Add user: `usermod -aG sudo devops` 3. Verify: `id devops` (should show group 27 sudo) |
| `bash: jq: command not found` | Tool not installed on the system | 1. Install: `sudo apt install -y jq` 2. Verify: `jq --version` |

---

## Real-World Job Scenario

### 🏢 Scenario: Production Server Disk Full at 2 AM — Alert Fires

**Situation:** Monitoring (Grafana/PagerDuty) triggers a critical alert — the `/var` partition on a production web server is at 98% usage. The application is starting to throw `500 Internal Server Error` because it cannot write to log files.

**Junior Engineer Response:**
```bash
# Panics, SSH into server
ssh devops@prod-web-01

# Checks disk space
df -h
# Sees /var at 98%

# Blindly deletes log files
sudo rm -rf /var/log/*
# ❌ Problem: This also removes active log file handles
# Services may stop logging until restarted
```

**Senior Engineer Response:**
```bash
# SSH in calmly
ssh devops@prod-web-01

# 1. Assess the damage
df -h
du -sh /var/* | sort -rh | head -10
# Output: /var/log is 42G — that's the problem

# 2. Find the biggest offenders
sudo find /var/log -type f -name "*.log" -size +100M -exec ls -lh {} \;
# Output: /var/log/nginx/access.log is 38G

# 3. Truncate (don't delete) — this preserves the file handle
sudo truncate -s 0 /var/log/nginx/access.log

# 4. Set up log rotation to prevent recurrence
sudo vim /etc/logrotate.d/nginx
# Add: rotate 7, daily, compress, maxsize 500M

# 5. Force rotate now
sudo logrotate -f /etc/logrotate.d/nginx

# 6. Verify disk space is recovered
df -h
# /var now at 15% ✅

# 7. Document in incident channel and set up alert threshold at 80%
```

*Senior engineer sirf fire nahi bujhaata — woh aag dobara na lage uska bhi intezaam karta hai (log rotation). Junior engineer sirf `rm -rf` maarta hai aur sochta hai kaam ho gaya.*

---

## Interview Questions

### Q1: What is the difference between a hard link and a soft (symbolic) link?

**Answer:** A **hard link** is a direct pointer to the inode (actual data) on disk. Both the original file and the hard link share the same inode number. Deleting the original file does NOT affect the hard link — the data remains accessible. Hard links cannot cross filesystem boundaries and cannot link to directories.

A **soft link (symlink)** is a pointer to the file path (name), not the inode. It's like a shortcut. If the original file is deleted, the symlink becomes a **dangling link** and stops working.

```bash
# Create hard link
ln original.txt hardlink.txt

# Create soft link
ln -s original.txt symlink.txt

# Check inodes — hard link shares inode, symlink does not
ls -li original.txt hardlink.txt symlink.txt
```

*Hard link = duplicate chabi (key) jo same taale (lock/inode) ko kholti hai. Soft link = ek chit (note) jisme likha hai "chabi drawer mein hai" — agar drawer se chabi gayab ho gayi, toh chit bekaar hai.*

### Q2: What does `chmod 755` mean?

**Answer:** `chmod 755` sets permissions as: **Owner = rwx (4+2+1=7)**, **Group = r-x (4+0+1=5)**, **Others = r-x (4+0+1=5)**. The owner can read, write, and execute. Group members and others can only read and execute, not modify. This is the standard permission for executable scripts and directories.

### Q3: What is the difference between `systemctl` and `service`?

**Answer:** `service` is the older SysVinit command that works with init scripts in `/etc/init.d/`. `systemctl` is the modern systemd command that manages unit files in `/etc/systemd/system/` and `/lib/systemd/system/`. `systemctl` provides more features: enable/disable on boot, dependency management, socket activation, timer units, and detailed status with `journalctl` integration. On modern distros (Ubuntu 16.04+, CentOS 7+), always use `systemctl`.

```bash
# Old way
sudo service nginx restart

# Modern way (preferred)
sudo systemctl restart nginx
```

### Q4: Explain the fields in `/etc/passwd`.

**Answer:** Each line in `/etc/passwd` has 7 colon-separated fields:

```
devops:x:1001:1001:DevOps User:/home/devops:/bin/bash
  │     │  │    │       │           │          │
  │     │  │    │       │           │          └── Login shell
  │     │  │    │       │           └── Home directory
  │     │  │    │       └── GECOS (comment/full name)
  │     │  │    └── Primary GID
  │     │  └── UID
  │     └── Password placeholder (actual hash in /etc/shadow)
  └── Username
```

*Ye file har user ki identity card jaisi hai — naam, ID number, ghar ka address, aur kaunsa shell use karta hai, sab likha hota hai.*

### Q5: What is the sticky bit and where is it used?

**Answer:** The **sticky bit** is a special permission (octal `1000`, symbol `t`) set on directories. When set, only the file owner, directory owner, or root can delete or rename files inside that directory — even if others have write permission. The most common example is `/tmp`:

```bash
ls -ld /tmp
# Output: drwxrwxrwt 15 root root 4096 Jun 27 10:00 /tmp
#                  ^ the 't' at the end = sticky bit

# Set sticky bit
chmod +t /shared_directory
# Or numerically
chmod 1777 /shared_directory
```

*Sticky bit `/tmp` pe lagta hai — matlab koi bhi file bana sakta hai, lekin sirf apni file delete kar sakta hai, doosre ki nahi. Jaise office ka fridge — apna tiffin rakh sakte ho, lekin doosre ka nahi uthaa sakte.*

---

## Related Notes

- [[00 DevOps Master Index]]
- [[LX-02 Shell Scripting for DevOps]]
- [[LX-03 Process and System Management]]
