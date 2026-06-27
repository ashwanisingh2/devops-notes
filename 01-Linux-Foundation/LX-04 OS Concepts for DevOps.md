---
tags: [devops, linux, os-concepts]
aliases: [Linux OS Concepts]
created: 2025-06-27
status: #complete
difficulty: #intermediate
cert-relevant: #none
---

# LX-04 OS Concepts for DevOps

> [!abstract]
> A DevOps engineer must understand how the operating system (Linux) allocates resources like CPU, Memory, and Disk to applications. Without this OS-level knowledge, troubleshooting performance bottlenecks, container crashes, or disk space issues becomes impossible guesswork.

## Concept Overview

**What:** Core OS concepts dictate how a Linux kernel interacts with hardware. It involves managing processes (execution), memory (RAM/Swap), filesystems (storage), and virtualization.
**Why:** Applications don't run in a vacuum. When a Kubernetes pod crashes with `OOMKilled`, or a database slows down due to high `iowait`, you need to know exactly how the Linux kernel is making decisions.
**Where:** Used constantly during incident response, performance tuning, and capacity planning.
**Responsibility Split:** Systems Engineers/DevOps tweak OS kernel parameters (sysctl) and manage resources, while developers focus on application logic. 

*OS ek traffic police ki tarah hai jo CPU, memory aur disk ka traffic control karta hai. Agar traffic police ka rule samajh aa gaya, toh aap server pe koi bhi bottleneck dhoondh sakte hain.*

## Technical Deep Dive

### 1. Process Management & CPU Scheduling
A **Process** is an executing instance of a program, carrying its own memory space. A **Thread** is a lightweight unit of execution within a process that shares the same memory. When a server has limited CPU cores, the OS kernel uses a **CPU Scheduler** (like the Completely Fair Scheduler - CFS in Linux) to rapidly context-switch between processes, giving the illusion of simultaneous execution.
To control a process, Linux uses **Signals**. The most common are `SIGTERM` (Signal 15), which politely asks a process to shut down and clean up, and `SIGKILL` (Signal 9), which brutally terminates the process at the kernel level without giving it a chance to clean up.

### 2. Memory Management & OOM Killer
Linux allocates RAM to processes. When physical RAM is exhausted, Linux uses **Swap**—a designated area on the hard drive acting as slow, emergency RAM. However, heavy swapping destroys performance. 
If both RAM and Swap are critically low, the Linux kernel invokes the **Out-Of-Memory (OOM) Killer**. The OOM Killer calculates a "badness" score for each process and sacrifices (kills) the one consuming the most memory to save the system from freezing. This is why Docker containers or Java apps suddenly crash under load.
*Jab server ki memory full ho jati hai, OOM Killer aake sabse bade memory khane wale process ka "murder" kar deta hai, taaki baki system zinda reh sake.*

### 3. Filesystems & Inode Exhaustion
A Linux filesystem (like `ext4` or `xfs`) manages how data is stored on disk. Beyond just disk space (GBs), filesystems use **Inodes**. An inode is a data structure that stores metadata about a file (permissions, owner, block location). 
Every file or directory consumes one inode. **Inode Exhaustion** happens when you create millions of tiny files. Even if you have 500GB of free disk space, if you run out of inodes, Linux will throw a "No space left on device" error.
Virtualization also relies on OS features. **Type 1 Hypervisors** (ESXi, KVM) run directly on hardware, while **Type 2 Hypervisors** (VirtualBox) run on top of an existing OS. Docker containers are not VMs; they are just isolated Linux processes using cgroups and namespaces.

## Step-by-Step Lab

**Objective:** Understand inodes, observe process signals, and simulate an OOM Kill scenario safely.

**Step 1: Check Inode usage**
Instead of checking disk space (`df -h`), check inode usage.
```bash
df -i
```
*Expected Output:* Shows the total inodes, used inodes, and percentage for each mounted filesystem.

**Step 2: Simulate Inode Exhaustion (Small Scale)**
Let's see how fast creating files uses inodes.
```bash
mkdir /tmp/inode_test && cd /tmp/inode_test
touch file_{1..1000}.txt
df -i /tmp/inode_test
```
*Expected Output:* You will see the inode count drop. (Run `rm -rf /tmp/inode_test` to clean up).

**Step 3: Understand Process Signals (SIGTERM vs SIGKILL)**
Start a background sleep process.
```bash
sleep 1000 &
```
Find its PID and gracefully terminate it (SIGTERM).
```bash
PID=$(pgrep -n sleep)
kill -15 $PID
```
*Expected Output:* `[1]+  Terminated  sleep 1000`

Start another sleep process, and force kill it (SIGKILL).
```bash
sleep 1000 &
PID=$(pgrep -n sleep)
kill -9 $PID
```
*Expected Output:* `[1]+  Killed  sleep 1000`

**Step 4: Analyze an OOM Kill event**
Whenever a process vanishes mysteriously, always check the kernel logs for OOM killer activity.
```bash
grep -i -r 'out of memory' /var/log/syslog /var/log/messages /var/log/kern.log 2>/dev/null || dmesg | grep -i oom
```
*Expected Output:* If an OOM event occurred recently, you will see kernel logs stating `Out of memory: Killed process <PID> (java) total-vm...`. (If nothing outputs, your system hasn't experienced an OOM recently).

**Step 5: Process Tree of Docker**
If Docker is installed, see how containers are just child processes of containerd.
```bash
pstree -p -s $(pgrep dockerd || pgrep containerd)
```
*Expected Output:* Shows the tree hierarchy proving containers are native OS processes.

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
| :--- | :--- | :--- |
| `df -h` | Shows available disk space | `df -h /var` |
| `df -i` | Shows available disk inodes | `df -i /` |
| `free -m` | Shows RAM and Swap usage in MB | `free -h` |
| `top` or `htop` | Real-time process and CPU/Memory monitoring | `htop` |
| `kill -15 <PID>` | Sends SIGTERM (Graceful shutdown) | `kill -15 4521` |
| `kill -9 <PID>` | Sends SIGKILL (Force quit) | `kill -9 4521` |
| `dmesg -T \| grep -i oom` | Checks kernel buffer for OOM killer events | `dmesg -T \| grep -i kill` |
| `pstree` | Displays running processes as a tree | `pstree -p` |

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
| :--- | :--- | :--- |
| `No space left on device` but `df -h` shows 50% free | Inode exhaustion. Millions of tiny files (like session files or logs) consumed all inodes. | 1. Run `df -i` to confirm 100% inode usage. 2. Find directories with many files: `find / -xdev -type f \| cut -d "/" -f 2 \| sort \| uniq -c \| sort -n`. 3. Delete unneeded files. |
| Application suddenly crashed without error logs | The Linux OOM (Out of Memory) Killer terminated the process. | 1. Run `dmesg -T \| grep -i oom`. 2. If true, increase server RAM, configure application memory limits (e.g., JVM heap), or add Swap space. |
| Server load average is extremely high, but CPU usage is low | High `iowait`. Processes are stuck waiting for slow disk I/O. | 1. Run `top` and look at the `wa` (iowait) percentage. 2. Use `iotop` to find the process thrashing the disk. 3. Upgrade to SSD or optimize DB queries. |
| Process ignores `kill <PID>` | `kill` defaults to `SIGTERM`. If a process is hung in an uninterruptible sleep state (Disk IO), it can't process the signal. | 1. Try `kill -9 <PID>` (SIGKILL). 2. If it still persists (Zombie/D state), you might need to reboot the server or fix the storage mount. |
| High Swap usage causing system lag | Applications are using more memory than physical RAM, causing constant read/writes to the disk swap file. | 1. Check `free -m`. 2. Tune `vm.swappiness` in `/etc/sysctl.conf` to prefer RAM. 3. Add more physical RAM. |

## Real-World Job Scenario

**Scenario:** An Apache web server hosting a PHP application starts throwing "No space left on device" errors when users try to upload profile pictures. The junior engineer checks `df -h` and sees 100GB free space and gets thoroughly confused.
- **Junior Action:** Restarts the server hoping the error goes away. It doesn't. Upgrades the EBS volume on AWS and pays more money. The error persists.
- **Senior Action:** Immediately recognizes the symptom. Runs `df -i` and sees `/var` is at 100% inode usage. Navigates to `/var/lib/php/sessions` and runs a find command, discovering 4 million stale 1KB session files because the PHP garbage collection cronjob failed. Deletes the old session files, instantly resolving the outage without spending a dime on cloud resources.

## Interview Questions

**Q1: What is the difference between a process and a thread?**
**A:** A process is an independent execution unit with its own memory space. If a process crashes, it doesn't affect others. A thread is a smaller execution unit within a process. Multiple threads share the same memory space of their parent process, making communication between them faster but meaning a crash in one thread can bring down the entire process.

**Q2: You have a server with 50GB free disk space, but you get a "Disk Full" error. What is happening?**
**A:** The filesystem has run out of Inodes. An inode is required to store the metadata of every single file or directory. If an application creates millions of extremely small files, it exhausts the finite pool of inodes before filling up the actual disk capacity (blocks).

**Q3: Explain the difference between SIGTERM and SIGKILL.**
**A:** SIGTERM (Signal 15) is a request sent to a process asking it to terminate. The process can catch this signal, close database connections, save state, and shut down gracefully. SIGKILL (Signal 9) goes straight to the kernel, which instantly kills the process. The process has no chance to clean up, which can lead to data corruption.

**Q4: What is the OOM Killer and how does it decide who dies?**
**A:** The Out-Of-Memory (OOM) Killer is a kernel mechanism that activates when the system runs out of physical RAM and Swap. To prevent a kernel panic, it kills a process to free up memory. It calculates a score based on how much memory the process uses and its `oom_score_adj` value. Usually, the fattest memory consumer is killed.

**Q5: What is the difference between Type 1 and Type 2 Hypervisors, and where does Docker fit in?**
**A:** Type 1 (Bare-metal) runs directly on the hardware (e.g., VMware ESXi, KVM). Type 2 runs on top of a Host OS (e.g., VirtualBox). Docker is neither. Docker does not use hypervisors or hardware virtualization. It uses Linux kernel features (cgroups, namespaces) to isolate standard Linux processes, making it vastly more lightweight than a Virtual Machine.

## Related Notes
- [[LX-05 Networking for DevOps]]
- [[Master Index]]
