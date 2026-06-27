---
tags: [devops, linux, system-management]
aliases: [Process Management]
created: 2025-06-27
status: '#complete'
difficulty: '#intermediate'
cert-relevant: '#none'
---

# Process and System Management

> [!abstract] Overview
> Process and system management is the pulse-monitoring of your infrastructure. Every application, service, and daemon running on a Linux server is a process — and knowing how to observe, control, prioritize, and terminate them is what separates a competent DevOps engineer from someone who just SSH's in and hopes for the best. Combined with kernel tuning, scheduled automation, and centralized logging, these skills form the operational nervous system that keeps production environments healthy, performant, and auditable around the clock.

---

## Concept Overview

- **What it is** — Process management is the practice of monitoring, controlling, and optimizing the lifecycle of every running program on a Linux system — from the moment it spawns to the moment it exits or is killed.
  *Yeh woh practice hai jisme aap har running program ko monitor, control aur optimize karte ho — jab se woh start hota hai tab tak jab tak woh exit ya kill nahi hota.*

- **Why it matters** — A single runaway process can eat 100% CPU, exhaust memory, or fill up disk with logs — taking down your entire production stack. Proper process management prevents outages before they happen.
  *Ek bhi bigda hua process poora server down kar sakta hai — isliye yeh skill zaroori hai.*

- **Where it applies** — Every environment: bare-metal servers, cloud VMs, containers, CI/CD runners, Kubernetes nodes. If it runs Linux, it needs process management.

- **Responsibility Split** — Developers write the code, but DevOps engineers are responsible for ensuring that code runs efficiently, doesn't hog resources, recovers from crashes, and logs are rotated properly.

> [!tip] Desi Analogy
> Process management is like being a **traffic police officer** *(traffic policewala)* at a busy intersection. You control the flow of vehicles (processes), stop rogue drivers (runaway processes), let ambulances pass first (high-priority processes with `nice`), and redirect traffic when there's a jam (load balancing). Without the traffic police, it's pure chaos — just like a server without proper process management.

---

## Technical Deep Dive

### Process Monitoring & Control

Every running program in Linux is a **process** with a unique **PID** (Process ID). The kernel's scheduler decides which process gets CPU time.

**Viewing Processes with `ps`:**

```bash
# Show all processes with full details
ps aux

# Filter for a specific process
ps aux | grep nginx

# Show process tree (parent-child relationships)
ps auxf

# Show only your processes
ps -u $USER
```

*`ps aux` se aapko saare running processes dikh jaayenge — user, PID, CPU%, memory% sab kuch.*

**Interactive Monitoring with `top` and `htop`:**

```bash
# Launch top
top

# Inside top — useful keys:
# P → Sort by CPU usage
# M → Sort by Memory usage
# k → Kill a process (enter PID)
# q → Quit
# 1 → Show per-CPU core usage

# htop (more user-friendly, install first)
sudo apt install htop -y
htop
```

`htop` gives you a color-coded, scrollable, mouse-friendly interface — *yeh `top` ka upgraded version hai, zyada readable aur interactive.*

**Killing Processes — Signals:**

| Signal | Number | Meaning |
|--------|--------|---------|
| `SIGTERM` | 15 | Graceful termination — process can clean up |
| `SIGKILL` | 9 | Forceful kill — process cannot ignore this |
| `SIGHUP` | 1 | Hangup — often used to reload config |

```bash
# Graceful kill (default, sends SIGTERM)
kill 1234

# Same as above, explicit
kill -15 1234

# Force kill (when process won't die)
kill -9 1234

# Kill by name
pkill nginx
killall nginx

# Send SIGHUP to reload config
kill -HUP $(cat /var/run/nginx.pid)
```

*`kill -15` se process ko bolte ho "bhai, apna kaam khatam kar aur nikal." `kill -9` se bolte ho "abhi ke abhi niklo, koi bahana nahi."*

**Process Priority — `nice` and `renice`:**

Nice values range from **-20 (highest priority)** to **19 (lowest priority)**. Default is 0. Only root can set negative nice values.

```bash
# Start a process with low priority
nice -n 10 ./heavy_script.sh

# Start with high priority (root only)
sudo nice -n -15 ./critical_backup.sh

# Change priority of running process
renice -n 5 -p 1234

# Check nice value
ps -o pid,ni,comm -p 1234
```

**Background Processes — `nohup`, `disown`, `tmux`:**

```bash
# Run process that survives logout
nohup ./long_running_job.sh > /tmp/job.log 2>&1 &

# Disown a running background job
./script.sh &
disown %1

# tmux — terminal multiplexer (persistent sessions)
sudo apt install tmux -y
tmux new -s deploy          # Create named session
# Ctrl+b, d                 # Detach from session
tmux ls                     # List sessions
tmux attach -t deploy       # Reattach to session

# screen — older alternative
screen -S mysession         # Create session
# Ctrl+a, d                 # Detach
screen -r mysession         # Reattach
```

*`nohup` matlab "no hangup" — jab aap terminal band karo tab bhi process chalta rahega. `tmux` matlab aapka terminal session server pe zinda rehta hai.*

---

### Kernel Tuning & /proc Filesystem

The `/proc` filesystem is a **virtual filesystem** — it doesn't exist on disk. It's the kernel exposing its internal state as readable files. *Yeh ek virtual window hai jisse aap kernel ke andar dekh sakte ho.*

**Key /proc Files:**

```bash
# CPU information
cat /proc/cpuinfo | head -20

# Memory information
cat /proc/meminfo | head -10

# Specific process info (replace PID)
cat /proc/1234/status       # Process status, memory, state
ls -la /proc/1234/fd        # Open file descriptors
cat /proc/1234/cmdline      # Command that started the process
cat /proc/1234/environ      # Environment variables

# System-wide stats
cat /proc/loadavg           # Load averages (1, 5, 15 min)
cat /proc/uptime            # System uptime in seconds
```

**Resource Limits with `ulimit`:**

```bash
# Show all current limits
ulimit -a

# Show max open files (soft limit)
ulimit -n

# Show max user processes
ulimit -u

# Temporarily increase open files limit
ulimit -n 65535

# Permanent change — edit /etc/security/limits.conf
# Add these lines:
# deploy_user    soft    nofile    65535
# deploy_user    hard    nofile    65535
# deploy_user    soft    nproc     4096
# deploy_user    hard    nproc     4096
```

*`ulimit` se aap define karte ho ki ek user kitne resources use kar sakta hai — files, processes, memory sab.*

**Kernel Tuning with `sysctl`:**

```bash
# View all kernel parameters
sysctl -a | head -20

# Check specific values
sysctl vm.swappiness
sysctl net.core.somaxconn
sysctl fs.file-max

# Modify at runtime (temporary)
sudo sysctl -w vm.swappiness=10
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w fs.file-max=2097152

# Make persistent — add to /etc/sysctl.conf
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
echo "net.core.somaxconn=65535" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=2097152" | sudo tee -a /etc/sysctl.conf

# Apply changes from config file
sudo sysctl -p
```

| Parameter | What It Controls | Production Value |
|-----------|-----------------|-----------------|
| `vm.swappiness` | How aggressively kernel uses swap | 10 (less swap) |
| `net.core.somaxconn` | Max socket connections queued | 65535 |
| `fs.file-max` | System-wide max open files | 2097152 |
| `net.ipv4.tcp_max_syn_backlog` | TCP SYN queue size | 65535 |

---

### Scheduling & Logging

**Cron Syntax (5 Fields):**

```
┌───────────── minute (0–59)
│ ┌───────────── hour (0–23)
│ │ ┌───────────── day of month (1–31)
│ │ │ ┌───────────── month (1–12)
│ │ │ │ ┌───────────── day of week (0–7, 0 and 7 = Sunday)
│ │ │ │ │
* * * * *  command_to_run
```

```bash
# Edit crontab
crontab -e

# List current cron jobs
crontab -l

# Examples:
# Every 5 minutes
*/5 * * * * /opt/scripts/health_check.sh

# Daily at 2:30 AM
30 2 * * * /opt/scripts/db_backup.sh

# Every Monday at 9 AM
0 9 * * 1 /opt/scripts/weekly_report.sh

# First of every month at midnight
0 0 1 * * /opt/scripts/monthly_cleanup.sh

# Every 6 hours
0 */6 * * * /opt/scripts/sync_data.sh
```

*Cron = aapka alarm clock jo scheduled tasks chalata hai. 5 fields yaad rakho: minute, hour, day, month, weekday.*

**Systemd Timers (Modern Alternative to Cron):**

```ini
# /etc/systemd/system/backup.timer
[Unit]
Description=Daily Backup Timer

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
# /etc/systemd/system/backup.service
[Unit]
Description=Daily Backup Service

[Service]
Type=oneshot
ExecStart=/opt/scripts/db_backup.sh
```

```bash
# Enable and start the timer
sudo systemctl enable backup.timer
sudo systemctl start backup.timer

# List all active timers
systemctl list-timers --all

# OnBootSec example — run 5 min after boot
# OnBootSec=300
```

**Journalctl — Systemd Log Viewer:**

```bash
# View logs for a specific service
journalctl -u nginx

# Follow logs in real-time (like tail -f)
journalctl -u nginx -f

# Last 100 lines
journalctl -u nginx -n 100

# Logs since a specific time
journalctl -u nginx --since "1 hour ago"
journalctl --since "2025-06-27 00:00:00" --until "2025-06-27 06:00:00"

# Kernel messages only
journalctl -k

# Show logs with priority (error and above)
journalctl -p err
```

**Important Log Files in `/var/log`:**

| File | What It Contains |
|------|-----------------|
| `/var/log/syslog` | General system activity log |
| `/var/log/auth.log` | Authentication events (SSH, sudo) |
| `/var/log/kern.log` | Kernel messages |
| `/var/log/dpkg.log` | Package installation/removal |
| `/var/log/nginx/access.log` | Nginx access logs |
| `/var/log/nginx/error.log` | Nginx error logs |

**Logrotate Configuration:**

```bash
# /etc/logrotate.d/myapp
/var/log/myapp/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        systemctl reload myapp > /dev/null 2>&1 || true
    endscript
}
```

---

## Step-by-Step Lab

### Lab 1: Diagnose CPU Spike

**Objective:** Simulate a CPU spike, identify the culprit, and kill it.

```bash
# Step 1: Install stress tool
sudo apt install stress -y

# Step 2: Simulate CPU spike (4 cores for 60 seconds)
stress --cpu 4 --timeout 60 &
```

```bash
# Step 3: Identify the spike with top
top
# Expected output — stress processes at top with ~100% CPU each:
#   PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
#  5432 root      20   0    3860    104      0 R  99.7   0.0   0:15.23 stress
#  5433 root      20   0    3860    104      0 R  99.3   0.0   0:15.21 stress
```

```bash
# Step 4: Identify with ps
ps aux --sort=-%cpu | head -5
# Expected:
# USER  PID %CPU %MEM    VSZ   RSS TTY STAT START   TIME COMMAND
# root 5432 99.7  0.0   3860   104 ?   R    10:30  0:23 stress --cpu 4

# Step 5: Kill the rogue process
kill -15 5432
# If it doesn't stop:
kill -9 5432

# Step 6: Verify it's gone
ps aux | grep stress
# Expected: only the grep line itself
```

```bash
# Step 7: Analyze with pidstat (install sysstat first)
sudo apt install sysstat -y
pidstat -u 1 5
# Shows per-process CPU usage every 1 second, 5 times
```

---

### Lab 2: Tune Kernel Parameters

**Objective:** Optimize kernel settings for a production web server.

```bash
# Step 1: Check current values
sysctl vm.swappiness
# Expected: vm.swappiness = 60

sysctl fs.file-max
# Expected: fs.file-max = 9223372036854775807 (or similar default)

sysctl net.core.somaxconn
# Expected: net.core.somaxconn = 4096
```

```bash
# Step 2: Modify at runtime
sudo sysctl -w vm.swappiness=10
# Expected: vm.swappiness = 10

sudo sysctl -w fs.file-max=2097152
# Expected: fs.file-max = 2097152

sudo sysctl -w net.core.somaxconn=65535
# Expected: net.core.somaxconn = 65535
```

```bash
# Step 3: Make persistent
sudo tee -a /etc/sysctl.conf <<EOF
# Production tuning
vm.swappiness=10
fs.file-max=2097152
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
EOF

# Step 4: Apply and verify
sudo sysctl -p
# Expected: all four parameters echoed with new values

sysctl vm.swappiness fs.file-max net.core.somaxconn
# Expected:
# vm.swappiness = 10
# fs.file-max = 2097152
# net.core.somaxconn = 65535
```

---

### Lab 3: Setup Log Rotation

**Objective:** Create and test a logrotate configuration for a custom application.

```bash
# Step 1: Create sample log directory and file
sudo mkdir -p /var/log/myapp
sudo bash -c 'for i in $(seq 1 1000); do echo "$(date) - Log entry $i" >> /var/log/myapp/app.log; done'
ls -lh /var/log/myapp/app.log
# Expected: -rw-r--r-- 1 root root 45K Jun 27 10:30 /var/log/myapp/app.log
```

```bash
# Step 2: Create logrotate config
sudo tee /etc/logrotate.d/myapp <<EOF
/var/log/myapp/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0644 root root
}
EOF
```

```bash
# Step 3: Test with dry run (no actual rotation)
sudo logrotate -d /etc/logrotate.d/myapp
# Expected output:
# reading config file /etc/logrotate.d/myapp
# considering log /var/log/myapp/app.log
#   log needs rotating
# rotating log /var/log/myapp/app.log, log->rotateCount is 7
# ...
```

```bash
# Step 4: Force rotation
sudo logrotate -f /etc/logrotate.d/myapp

# Step 5: Verify
ls -lh /var/log/myapp/
# Expected:
# -rw-r--r-- 1 root root    0 Jun 27 10:35 app.log
# -rw-r--r-- 1 root root  45K Jun 27 10:30 app.log.1
```

---

## Common Commands Cheat Sheet

| Command | What It Does | Real Example |
|---------|-------------|--------------|
| `ps aux` | Show all running processes | `ps aux \| grep java` |
| `top` | Interactive process monitor | `top -bn1 \| head -20` (batch mode) |
| `htop` | Enhanced process monitor | `htop --sort-key=PERCENT_CPU` |
| `kill -15 PID` | Graceful termination | `kill -15 $(pgrep node)` |
| `kill -9 PID` | Force kill (last resort) | `kill -9 5432` |
| `nice -n 10 cmd` | Run with lower priority | `nice -n 10 tar czf backup.tar.gz /data` |
| `renice -n 5 -p PID` | Change running process priority | `renice -n 5 -p 1234` |
| `nohup cmd &` | Run surviving logout | `nohup ./deploy.sh > /tmp/deploy.log 2>&1 &` |
| `sysctl -w key=val` | Set kernel parameter | `sudo sysctl -w vm.swappiness=10` |
| `journalctl -u svc -f` | Follow service logs | `journalctl -u nginx -f --since '1 hour ago'` |
| `crontab -e` | Edit user cron jobs | `crontab -e` → add `0 2 * * * /opt/backup.sh` |
| `ulimit -n` | Check open file limit | `ulimit -n` → `1024` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---------|-------------|-----------------|
| `kill: No such process` | Process already exited or wrong PID | Run `ps aux \| grep <name>` to find the correct PID. The process may have been killed by OOM killer — check `dmesg \| grep -i oom`. |
| `Too many open files` | File descriptor limit (`ulimit -n`) too low | Check current limit: `ulimit -n`. Increase temporarily: `ulimit -n 65535`. Make permanent: add to `/etc/security/limits.conf` and increase `fs.file-max` via `sysctl`. |
| `crontab: no changes made to crontab` | Cron editor exited without saving | Open with `crontab -e`, make changes, save and quit (`:wq` in vim). Verify with `crontab -l`. Check `EDITOR` env var if wrong editor opens. |
| `bash: fork: retry: Resource temporarily unavailable` | Max user processes limit reached (`ulimit -u`) | Check limit: `ulimit -u`. Kill unnecessary processes: `pkill -u username`. Increase in `/etc/security/limits.conf` under `nproc`. |
| Zombie processes piling up (`Z` state in `ps`) | Parent process not calling `wait()` on children | Identify parent: `ps -eo pid,ppid,stat,cmd \| grep Z`. Fix requires restarting or fixing the parent process. Zombies consume no resources but pollute the process table. |
| `Permission denied` on cron job | Script missing execute permission or wrong PATH | Add `chmod +x /path/to/script.sh`. In crontab, use full paths for commands (e.g., `/usr/bin/python3` not just `python3`). Add `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin` at top of crontab. |

---

## Real-World Job Scenario

> [!example] Production Incident: 3 AM CPU Spike
>
> **Situation:** PagerDuty alert fires at 3 AM — `web-prod-03` CPU at 100%, response times spiking to 30 seconds, users getting 502 errors.
>
> **Junior Engineer Response:**
> 1. SSH into the server
> 2. Runs `top`, sees a Java process eating 400% CPU
> 3. Runs `kill -9` on the PID
> 4. Server recovers, goes back to sleep
> 5. Same thing happens next night — no root cause found
>
> **Senior Engineer Response:**
> 1. Checks monitoring dashboards (Grafana/Datadog) first to understand the scope — is it one server or all?
> 2. SSH into the server, runs `top` and `ps auxf` to identify the process and its parent
> 3. Before killing, captures diagnostic data:
>    ```bash
>    # Capture thread dump for Java
>    jstack 5432 > /tmp/thread_dump_$(date +%s).txt
>    # Capture process details
>    cat /proc/5432/status > /tmp/proc_status.txt
>    cat /proc/5432/cmdline > /tmp/proc_cmdline.txt
>    # Check what files it has open
>    ls -la /proc/5432/fd | wc -l
>    ```
> 4. Sends `SIGTERM` first (graceful): `kill -15 5432`
> 5. If unresponsive after 30 seconds, then `kill -9 5432`
> 6. Checks `journalctl -u myapp --since "2 hours ago"` for logs leading up to the spike
> 7. Checks `dmesg | tail -50` for OOM or kernel issues
> 8. Files a post-incident report with root cause, adds monitoring for the specific failure mode
> 9. Sets up `ulimit` and cgroup-based resource limits to prevent recurrence
>
> *Senior engineer sirf fire nahi bujhaata — woh jaanch karta hai ki aag lagi kyun, aur agle incident ko rokne ka system lagaata hai.*

---

## Interview Questions

**Q1: What is the difference between a zombie process and an orphan process?**
> A **zombie process** is one that has finished execution but still has an entry in the process table because its parent hasn't read its exit status (via `wait()` syscall). It shows as `Z` in `ps` output. An **orphan process** is one whose parent has terminated — the `init` process (PID 1) adopts it. Orphans continue running normally; zombies consume no resources but pollute the process table. To clean zombies, you must fix or restart the parent process.

**Q2: What is the difference between SIGTERM and SIGKILL?**
> `SIGTERM` (signal 15) requests graceful termination — the process can catch it, clean up resources (close file handles, flush buffers, remove temp files), and exit cleanly. `SIGKILL` (signal 9) forces immediate termination — the process cannot catch, block, or ignore it. The kernel directly removes the process. Always try `SIGTERM` first; use `SIGKILL` only as a last resort because it can leave corrupted files, orphaned child processes, and unreleased locks.

**Q3: What is the /proc filesystem and why is it important?**
> `/proc` is a virtual (pseudo) filesystem that exists only in memory — it provides a window into the kernel's internal data structures. Each running process has a directory `/proc/PID/` containing files like `status` (process state), `cmdline` (startup command), `fd/` (open file descriptors), and `environ` (environment variables). System-wide info lives in files like `/proc/cpuinfo`, `/proc/meminfo`, and `/proc/loadavg`. DevOps engineers use it for debugging, monitoring, and understanding system behavior without installing additional tools.

**Q4: What is the nice value range and how does it affect process scheduling?**
> Nice values range from **-20 to 19**. Lower values mean higher priority (more CPU time). Default is 0. Only root can set negative nice values (higher priority). A process with `nice -20` gets the most CPU time; `nice 19` gets the least. Use `nice -n <value> command` to start a process with a specific priority, and `renice -n <value> -p PID` to change a running process. In production, you'd use this to deprioritize batch jobs so they don't starve critical services.

**Q5: What is the difference between cron and systemd timers?**
> **Cron** is the traditional Unix job scheduler — simple, well-known, uses a 5-field syntax (`min hour day month weekday`). **Systemd timers** are the modern replacement, integrated with systemd's service management. Key differences: systemd timers support monotonic scheduling (`OnBootSec`, `OnUnitActiveSec`), can catch up on missed runs (`Persistent=true`), provide better logging via `journalctl`, support dependencies, and offer resource control via cgroups. Cron jobs have no dependency management and limited logging (usually just mailed output). For new setups, systemd timers are preferred; cron remains widely used in legacy systems.

---

## Related Notes

- [[00 DevOps Master Index]]
- [[LX-01 Linux for DevOps]]
- [[LX-02 Shell Scripting for DevOps]]
