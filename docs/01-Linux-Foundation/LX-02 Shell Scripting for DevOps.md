---
tags: [devops, linux, shell-scripting]
aliases: [Shell Scripting]
created: 2025-06-27
status: '#complete'
difficulty: '#intermediate'
cert-relevant: '#none'
---

# Shell Scripting for DevOps Engineers

> [!abstract]
> Shell scripting is the duct tape of DevOps automation — it binds together monitoring, deployment, provisioning, and incident response into repeatable, version-controlled workflows. Whether you are rotating backups at 2 AM, bulk-creating user accounts from a CSV, or wiring health checks into a CI/CD pipeline, a well-written Bash script replaces hours of manual clicking with a single `./run.sh`. Every DevOps engineer who wants to move beyond button-pressing must think in scripts.

---

## Concept Overview

**What it is** — A shell script is a plain-text file containing a sequence of Linux commands executed by a shell interpreter (usually Bash). It transforms repetitive terminal work into automated, reproducible programs.
*Shell script ek aisi text file hai jo Linux commands ko ek sequence mein execute karti hai — jaise ek recipe step-by-step follow hoti hai.*

**Why DevOps engineers use it** — Automation of infrastructure tasks (backups, log rotation, deployments), glue code between tools (Docker, Ansible, Terraform), and rapid prototyping of monitoring solutions.
*DevOps mein shell scripting isliye zaroori hai kyunki har baar manually commands type karna time waste hai — script likh do, cron mein daal do, kaam automatic hoga.*

**Where it runs** — Any Linux/macOS terminal, CI/CD runners (GitHub Actions, Jenkins agents), Docker containers, and cloud VMs.

**Responsibility Split** — Shell scripts handle orchestration and glue logic; heavy data processing or complex application logic should move to Python or Go.

> [!tip] Desi Analogy
> Think of a shell script as a **recipe (nuskha)**:
> - **Variables** = ingredients (flour, sugar, salt)
> - **Commands** = cooking steps (mix, heat, serve)
> - **Conditionals** = checks (agar dough soft hai toh aage badho)
> - **Loops** = repetition (har roti ko ek-ek karke sekna)
> - **Functions** = reusable sub-recipes (masala paste jo har dish mein use hoti hai)

---

## Technical Deep Dive

### Variables, Conditionals & Loops

**Variables** store data — no spaces around `=`, and quote expansions to prevent word splitting.
*Variables mein data store hota hai — yaad rakho `=` ke around space mat do, warna error aayega.*

```bash
#!/bin/bash

# Declaring variables
APP_NAME="my-api"
VERSION="2.1.0"
readonly MAX_RETRIES=5          # Cannot be reassigned
export LOG_LEVEL="info"         # Available to child processes

# Local variables inside functions
deploy() {
    local target_env="$1"       # Scoped to this function only
    echo "Deploying $APP_NAME v$VERSION to $target_env"
}
```

**Conditionals** — `if/elif/else` and `case` control the flow based on test results. Always use `[[ ]]` (Bash-specific, safer) over `[ ]`.
*Conditionals se script decide karti hai ki kaunsa raasta lena hai — jaise traffic signal: red toh ruko, green toh chalo.*

```bash
#!/bin/bash

DISK_USAGE=85
SERVICE_STATUS="running"

# if / elif / else
if [[ $DISK_USAGE -gt 90 ]]; then
    echo "CRITICAL: Disk usage at ${DISK_USAGE}%"
elif [[ $DISK_USAGE -gt 80 ]]; then
    echo "WARNING: Disk usage at ${DISK_USAGE}%"
else
    echo "OK: Disk usage at ${DISK_USAGE}%"
fi

# case statement — cleaner than chained if-elif
case "$SERVICE_STATUS" in
    running)   echo "Service is healthy" ;;
    stopped)   echo "Service is down — restarting..." ;;
    degraded)  echo "Service is degraded — investigating..." ;;
    *)         echo "Unknown status: $SERVICE_STATUS" ;;
esac
```

**Loops** — `for` iterates over lists, `while` runs while a condition is true, `until` runs until a condition becomes true.
*Loop ka matlab hai ek kaam baar-baar karna — jaise factory mein assembly line pe har product pe same step lagana.*

```bash
#!/bin/bash

# for loop — iterate over a list
SERVERS=("web01" "web02" "db01" "cache01")
for server in "${SERVERS[@]}"; do
    echo "Pinging $server..."
    ping -c 1 "$server" &>/dev/null && echo "  ✅ $server is up" || echo "  ❌ $server is down"
done

# while loop — read a file line by line
while IFS=',' read -r username group; do
    echo "Creating user: $username in group: $group"
done < users.csv

# until loop — retry until success
ATTEMPT=0
until curl -sf http://localhost:8080/health &>/dev/null; do
    ((ATTEMPT++))
    echo "Attempt $ATTEMPT: Service not ready, waiting..."
    sleep 5
    [[ $ATTEMPT -ge 10 ]] && { echo "Giving up after 10 attempts"; exit 1; }
done
echo "Service is healthy!"
```

---

### Functions, Arrays & String Manipulation

**Functions** encapsulate reusable logic. Use `echo` to return strings (capture with `$()`), and `return` for exit codes (0 = success).
*Function ek reusable block hai — jaise ek masala paste recipe jo har sabzi mein kaam aati hai.*

```bash
#!/bin/bash

# Function definition and usage
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

# Return value via echo (capture with command substitution)
get_hostname() {
    echo "$(hostname -f)"
}

CURRENT_HOST=$(get_hostname)
log_message "INFO" "Running on $CURRENT_HOST"

# Return exit code
is_root() {
    [[ $EUID -eq 0 ]]    # Returns 0 (true) if root, 1 (false) otherwise
}

if is_root; then
    log_message "INFO" "Running as root"
else
    log_message "ERROR" "This script requires root privileges"
    exit 1
fi
```

**Arrays** — Bash supports indexed arrays and associative arrays (Bash 4+).

```bash
#!/bin/bash

# Indexed array
ENVIRONMENTS=("dev" "staging" "production")
echo "First env: ${ENVIRONMENTS[0]}"
echo "All envs: ${ENVIRONMENTS[@]}"
echo "Count: ${#ENVIRONMENTS[@]}"

# Associative array (Bash 4+)
declare -A SERVICE_PORTS
SERVICE_PORTS=( [nginx]=80 [api]=8080 [redis]=6379 [postgres]=5432 )

for svc in "${!SERVICE_PORTS[@]}"; do
    echo "$svc listens on port ${SERVICE_PORTS[$svc]}"
done
```

**String Manipulation & Parameter Expansion** — Bash has built-in operators to slice, strip, and transform strings without calling external tools.
*String manipulation se aap bina `sed`/`awk` ke hi text ko modify kar sakte ho — jaise `${var##*/}` se filepath mein se filename nikal lo.*

```bash
#!/bin/bash

FILEPATH="/var/log/nginx/access.log.gz"

echo "Filename:  ${FILEPATH##*/}"       # access.log.gz  (strip longest prefix match)
echo "Directory: ${FILEPATH%/*}"        # /var/log/nginx  (strip shortest suffix match)
echo "Extension: ${FILEPATH##*.}"       # gz
echo "No ext:    ${FILEPATH%%.*}"       # /var/log/nginx/access
echo "Uppercase: ${FILEPATH^^}"         # /VAR/LOG/NGINX/ACCESS.LOG.GZ
echo "Replace:   ${FILEPATH//log/LOG}"  # /var/LOG/nginx/access.LOG.gz

# Substring extraction
VERSION="v2.14.7"
MAJOR="${VERSION:1:1}"     # 2
MINOR="${VERSION:3:2}"     # 14
echo "Major: $MAJOR, Minor: $MINOR"

# Default values
echo "DB Host: ${DB_HOST:-localhost}"        # Use 'localhost' if DB_HOST is unset
echo "DB Port: ${DB_PORT:=5432}"             # Assign 5432 if DB_PORT is unset
```

**grep, sed & awk with Regex** — The power trio of text processing.

```bash
# grep — search patterns
grep -E '^(ERROR|WARN)' /var/log/app.log             # Lines starting with ERROR or WARN
grep -rn 'TODO\|FIXME' --include='*.sh' /opt/scripts/ # Recursive search in .sh files
grep -c 'Connection refused' /var/log/syslog          # Count matching lines
grep -oP 'user=\K\w+' /var/log/auth.log               # Extract username (Perl regex)

# sed — stream editor for find-replace
sed -i 's/DEBUG/INFO/g' config.yaml                    # In-place replace all DEBUG with INFO
sed -n '10,20p' /var/log/app.log                       # Print lines 10 to 20
sed '/^#/d' config.conf                                # Delete comment lines

# awk — column-based text processing
awk '{print $1, $4}' /var/log/nginx/access.log         # Print IP and timestamp
awk -F: '$3 >= 1000 {print $1}' /etc/passwd            # Users with UID >= 1000
df -h | awk 'NR>1 && $5+0 > 80 {print $6, $5}'        # Partitions over 80% usage
```

---

### Error Handling & Script Arguments

**`set -euo pipefail`** — The holy trinity of safe scripting.
*Ye teen flags lagane se script safe hoti hai — ek bhi error aaye toh turant ruk jaaye, koi variable undefined ho toh bhi error de.*

```bash
#!/bin/bash
set -euo pipefail    # -e: exit on error, -u: error on undefined vars, -o pipefail: catch pipe errors

# trap — run cleanup code on EXIT, ERR, or signals
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"; echo "Cleaned up temp dir"' EXIT

# Use trap for robust error reporting
trap 'echo "ERROR on line $LINENO: command \"$BASH_COMMAND\" failed with exit code $?"' ERR

echo "Working in $TEMP_DIR"
cp important_file.txt "$TEMP_DIR/"
# If any command fails, trap fires and cleanup happens automatically
```

**Script Arguments** — `$1`, `$2` etc. for positional args, `$@` for all args as separate words, `$*` for all as one word, `$#` for count, `$?` for last exit code, `$$` for current PID.
*`$1` pehla argument hai jo script ko diya jaata hai, `$@` saare arguments alag-alag, `$#` total kitne arguments hain.*

```bash
#!/bin/bash
# Usage: ./deploy.sh <environment> <version>

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <environment> <version>"
    echo "Example: $0 production v2.1.0"
    exit 1
fi

ENVIRONMENT="$1"
VERSION="$2"
shift 2                     # Remove first 2 args; remaining are in $@
EXTRA_FLAGS=("$@")          # Capture any remaining arguments

echo "Deploying version $VERSION to $ENVIRONMENT"
echo "Extra flags: ${EXTRA_FLAGS[*]:-none}"
echo "Script PID: $$"
```

**Heredoc** — Embed multi-line strings or feed input to commands inline.

```bash
#!/bin/bash

# Generate a config file using heredoc
cat <<EOF > /tmp/nginx.conf
server {
    listen 80;
    server_name ${DOMAIN:-example.com};
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF

# Heredoc with suppressed tab indentation (<<-)
generate_report() {
	cat <<-REPORT
	=== System Report ===
	Hostname: $(hostname)
	Date:     $(date)
	Uptime:   $(uptime -p)
	REPORT
}
```

**Process Substitution** — `<(command)` treats command output as a file, useful for `diff` and `while read`.

```bash
# Compare sorted outputs of two commands without temp files
diff <(sort file1.txt) <(sort file2.txt)

# Compare installed packages between two servers
diff <(ssh web01 'rpm -qa | sort') <(ssh web02 'rpm -qa | sort')

# Feed command output as a file to another command
while IFS= read -r line; do
    echo "Processing: $line"
done < <(find /var/log -name '*.log' -mtime +7)
```

---

## Step-by-Step Lab: 5 Automation Scripts

> [!important]
> All scripts below are complete and copy-paste ready. Test them in a safe environment (VM or container) before using on production servers. Run each with `chmod +x script.sh && ./script.sh`.

---

### Script 1: Disk Usage Alert

Monitors all mounted partitions and sends a warning when usage exceeds a threshold.
*Ye script har partition ka disk usage check karti hai — agar 80% se zyada bhara hai toh alert deti hai.*

```bash
#!/bin/bash
# disk_alert.sh — Alert when disk usage exceeds threshold
set -euo pipefail

THRESHOLD=80
ALERT_LOG="/var/log/disk_alerts.log"
ADMIN_EMAIL="admin@example.com"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Disk Usage Check Started" >> "$ALERT_LOG"

# Parse df output, skip header, check each partition
while IFS= read -r line; do
    USAGE=$(echo "$line" | awk '{print $5}' | tr -d '%')
    PARTITION=$(echo "$line" | awk '{print $6}')
    FILESYSTEM=$(echo "$line" | awk '{print $1}')

    if [[ $USAGE -gt $THRESHOLD ]]; then
        ALERT_MSG="⚠️  WARNING: $PARTITION is at ${USAGE}% (on $FILESYSTEM)"
        echo "[$TIMESTAMP] $ALERT_MSG" >> "$ALERT_LOG"
        echo "$ALERT_MSG"

        # Send email alert (requires mailutils)
        # echo "$ALERT_MSG" | mail -s "Disk Alert: $PARTITION at ${USAGE}%" "$ADMIN_EMAIL"
    else
        echo "✅ OK: $PARTITION is at ${USAGE}%"
    fi
done < <(df -h --output=source,size,used,avail,pcent,target | tail -n +2 | grep -v 'tmpfs')

echo "[$TIMESTAMP] Disk Usage Check Completed" >> "$ALERT_LOG"
```

**Expected Output:**
```
✅ OK: / is at 45%
✅ OK: /home is at 62%
⚠️  WARNING: /var is at 87% (on /dev/sda3)
✅ OK: /boot is at 33%
```

---

### Script 2: Log Cleanup with Dry-Run

Deletes log files older than a specified number of days, with a safe dry-run mode.
*Ye script purani log files ko delete karti hai — pehle dry-run se dekh lo kya delete hoga, phir actually delete karo.*

```bash
#!/bin/bash
# log_cleanup.sh — Delete old logs with dry-run safety
# Usage: ./log_cleanup.sh [--dry-run] [--days N] [--path /var/log]
set -euo pipefail

# Defaults
DRY_RUN=false
DAYS=30
LOG_PATH="/var/log"
TOTAL_SIZE=0
FILE_COUNT=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true; shift ;;
        --days)     DAYS="$2"; shift 2 ;;
        --path)     LOG_PATH="$2"; shift 2 ;;
        *)          echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Log Cleanup Script ==="
echo "Target:  $LOG_PATH"
echo "Max Age: $DAYS days"
echo "Mode:    $(${DRY_RUN} && echo 'DRY RUN (no files will be deleted)' || echo 'LIVE')"
echo "=========================="

# Find and process old log files
while IFS= read -r -d '' file; do
    FILE_SIZE=$(stat -c%s "$file" 2>/dev/null || echo 0)
    TOTAL_SIZE=$((TOTAL_SIZE + FILE_SIZE))
    ((FILE_COUNT++))

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would delete: $file ($(numfmt --to=iec $FILE_SIZE))"
    else
        rm -f "$file"
        echo "[DELETED] $file ($(numfmt --to=iec $FILE_SIZE))"
    fi
done < <(find "$LOG_PATH" -type f \( -name '*.log' -o -name '*.log.*' -o -name '*.gz' \) -mtime +"$DAYS" -print0 2>/dev/null)

echo ""
echo "Summary: $FILE_COUNT files, total $(numfmt --to=iec $TOTAL_SIZE)"
[[ "$DRY_RUN" == true ]] && echo "💡 Run without --dry-run to actually delete files."
```

**Expected Output (dry-run):**
```
=== Log Cleanup Script ===
Target:  /var/log
Max Age: 30 days
Mode:    DRY RUN (no files will be deleted)
==========================
[DRY-RUN] Would delete: /var/log/syslog.4.gz (1.2M)
[DRY-RUN] Would delete: /var/log/auth.log.3.gz (540K)
[DRY-RUN] Would delete: /var/log/nginx/access.log.5.gz (3.8M)

Summary: 3 files, total 5.5M
💡 Run without --dry-run to actually delete files.
```

---

### Script 3: Bulk User Creation from CSV

Reads a CSV file and creates Linux users with specified groups, passwords, and home directories.
*Ye script ek CSV file padh ke users create karti hai — jaise HR department se list aayi aur IT ne ek script se sab users bana diye.*

```bash
#!/bin/bash
# bulk_user_create.sh — Create users from CSV file
# CSV Format: username,full_name,group,shell
# Usage: sudo ./bulk_user_create.sh users.csv
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <csv_file>"
    exit 1
fi

CSV_FILE="$1"

if [[ ! -f "$CSV_FILE" ]]; then
    echo "ERROR: File '$CSV_FILE' not found"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

SUCCESS=0
FAILED=0
SKIPPED=0

echo "=== Bulk User Creation ==="
echo "Reading from: $CSV_FILE"
echo "=========================="

# Skip header line, read CSV
tail -n +2 "$CSV_FILE" | while IFS=',' read -r username full_name group user_shell; do
    # Trim whitespace
    username=$(echo "$username" | xargs)
    group=$(echo "$group" | xargs)
    user_shell=$(echo "${user_shell:-/bin/bash}" | xargs)

    # Skip empty lines
    [[ -z "$username" ]] && continue

    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo "⏭️  SKIPPED: User '$username' already exists"
        ((SKIPPED++))
        continue
    fi

    # Create group if it doesn't exist
    if ! getent group "$group" &>/dev/null; then
        groupadd "$group"
        echo "   Created group: $group"
    fi

    # Create user
    if useradd -m -g "$group" -s "$user_shell" -c "$full_name" "$username"; then
        # Set a temporary password (user must change on first login)
        echo "${username}:TempPass@123" | chpasswd
        passwd -e "$username" &>/dev/null    # Force password change

        echo "✅ CREATED: $username ($full_name) → group: $group, shell: $user_shell"
        ((SUCCESS++))
    else
        echo "❌ FAILED: Could not create user '$username'"
        ((FAILED++))
    fi
done

echo ""
echo "=== Summary ==="
echo "Created: $SUCCESS | Skipped: $SKIPPED | Failed: $FAILED"
```

**Sample `users.csv`:**
```csv
username,full_name,group,shell
ravi.kumar,Ravi Kumar,devops,/bin/bash
priya.sharma,Priya Sharma,developers,/bin/bash
amit.patel,Amit Patel,devops,/bin/zsh
neha.singh,Neha Singh,qa,/bin/bash
```

**Expected Output:**
```
=== Bulk User Creation ===
Reading from: users.csv
==========================
   Created group: devops
✅ CREATED: ravi.kumar (Ravi Kumar) → group: devops, shell: /bin/bash
   Created group: developers
✅ CREATED: priya.sharma (Priya Sharma) → group: developers, shell: /bin/bash
✅ CREATED: amit.patel (Amit Patel) → group: devops, shell: /bin/zsh
   Created group: qa
✅ CREATED: neha.singh (Neha Singh) → group: qa, shell: /bin/bash

=== Summary ===
Created: 4 | Skipped: 0 | Failed: 0
```

---

### Script 4: Service Health Checker

Monitors multiple services, restarts any that are down, and logs all actions.
*Ye script services ka health check karti hai — agar koi service down hai toh restart karti hai aur log mein likhti hai.*

```bash
#!/bin/bash
# service_health.sh — Check services, restart if down, log everything
set -uo pipefail     # Not using -e because we expect some commands to fail

SERVICES=("nginx" "docker" "sshd" "redis-server" "postgresql")
LOG_FILE="/var/log/service_health.log"
MAX_RESTART_ATTEMPTS=3
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log() {
    local level="$1"
    local msg="$2"
    echo "[$TIMESTAMP] [$level] $msg" | tee -a "$LOG_FILE"
}

restart_service() {
    local service="$1"
    local attempt=1

    while [[ $attempt -le $MAX_RESTART_ATTEMPTS ]]; do
        log "ACTION" "Restarting $service (attempt $attempt/$MAX_RESTART_ATTEMPTS)"
        if systemctl restart "$service" 2>/dev/null; then
            sleep 2
            if systemctl is-active --quiet "$service"; then
                log "SUCCESS" "$service restarted successfully"
                return 0
            fi
        fi
        ((attempt++))
        sleep 3
    done

    log "CRITICAL" "$service failed to restart after $MAX_RESTART_ATTEMPTS attempts"
    return 1
}

echo "========================================="
log "INFO" "Service Health Check Started"
echo "========================================="

HEALTHY=0
RESTARTED=0
FAILED=0
NOT_INSTALLED=0

for service in "${SERVICES[@]}"; do
    # Check if service unit exists
    if ! systemctl list-unit-files "${service}.service" &>/dev/null; then
        log "SKIP" "$service is not installed"
        ((NOT_INSTALLED++))
        continue
    fi

    if systemctl is-active --quiet "$service"; then
        log "OK" "$service is running ✅"
        ((HEALTHY++))
    else
        log "WARNING" "$service is NOT running ❌"
        if restart_service "$service"; then
            ((RESTARTED++))
        else
            ((FAILED++))
        fi
    fi
done

echo ""
echo "========================================="
log "INFO" "Health Check Complete"
echo "Healthy: $HEALTHY | Restarted: $RESTARTED | Failed: $FAILED | Not Installed: $NOT_INSTALLED"
echo "========================================="

# Exit with error if any service is still down
[[ $FAILED -gt 0 ]] && exit 1
exit 0
```

**Expected Output:**
```
=========================================
[2025-06-27 10:30:00] [INFO] Service Health Check Started
=========================================
[2025-06-27 10:30:00] [OK] nginx is running ✅
[2025-06-27 10:30:00] [OK] docker is running ✅
[2025-06-27 10:30:00] [OK] sshd is running ✅
[2025-06-27 10:30:00] [WARNING] redis-server is NOT running ❌
[2025-06-27 10:30:00] [ACTION] Restarting redis-server (attempt 1/3)
[2025-06-27 10:30:02] [SUCCESS] redis-server restarted successfully
[2025-06-27 10:30:02] [OK] postgresql is running ✅

=========================================
[2025-06-27 10:30:02] [INFO] Health Check Complete
Healthy: 4 | Restarted: 1 | Failed: 0 | Not Installed: 0
=========================================
```

---

### Script 5: Backup Rotation

Creates a tar.gz backup of a specified directory, keeps the last N backups, and deletes older ones.
*Ye script backup banati hai date ke saath aur purane backups delete karti hai — jaise ghar mein last 7 din ka akhbaar rakhte ho, baaki raddi mein dete ho.*

```bash
#!/bin/bash
# backup_rotation.sh — Create dated backups, keep last N, delete older
# Usage: ./backup_rotation.sh /path/to/source /path/to/backup/dir [retention_count]
set -euo pipefail

SOURCE="${1:?Usage: $0 <source_dir> <backup_dir> [retention_count]}"
BACKUP_DIR="${2:?Backup directory required}"
RETENTION=${3:-7}

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
SOURCE_NAME=$(basename "$SOURCE")
BACKUP_FILE="${BACKUP_DIR}/${SOURCE_NAME}_backup_${TIMESTAMP}.tar.gz"

# Cleanup trap
TEMP_FILES=()
cleanup() {
    for f in "${TEMP_FILES[@]:-}"; do
        [[ -f "$f" ]] && rm -f "$f"
    done
}
trap cleanup EXIT

# Validation
if [[ ! -d "$SOURCE" ]]; then
    echo "ERROR: Source directory '$SOURCE' does not exist"
    exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "=== Backup Rotation Script ==="
echo "Source:    $SOURCE"
echo "Backup:   $BACKUP_DIR"
echo "Retention: Last $RETENTION backups"
echo "==============================="

# Step 1: Create the backup
echo ""
echo "📦 Creating backup..."
START_TIME=$(date +%s)

if tar -czf "$BACKUP_FILE" -C "$(dirname "$SOURCE")" "$SOURCE_NAME" 2>/dev/null; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    BACKUP_SIZE=$(du -sh "$BACKUP_FILE" | awk '{print $1}')
    echo "✅ Backup created: $(basename "$BACKUP_FILE") ($BACKUP_SIZE) in ${DURATION}s"
else
    echo "❌ Backup creation failed!"
    exit 1
fi

# Step 2: Generate checksum
sha256sum "$BACKUP_FILE" > "${BACKUP_FILE}.sha256"
echo "🔒 Checksum saved: $(basename "${BACKUP_FILE}.sha256")"

# Step 3: Rotate old backups (keep last N)
echo ""
echo "🔄 Rotating old backups (keeping last $RETENTION)..."

EXISTING_BACKUPS=$(find "$BACKUP_DIR" -maxdepth 1 -name "${SOURCE_NAME}_backup_*.tar.gz" -type f | sort -r)
BACKUP_COUNT=$(echo "$EXISTING_BACKUPS" | grep -c . || true)
DELETED=0

if [[ $BACKUP_COUNT -gt $RETENTION ]]; then
    echo "$EXISTING_BACKUPS" | tail -n +$((RETENTION + 1)) | while read -r old_backup; do
        rm -f "$old_backup" "${old_backup}.sha256"
        echo "   🗑️  Deleted: $(basename "$old_backup")"
        ((DELETED++))
    done
fi

echo ""
echo "=== Backup Summary ==="
echo "New backup:  $(basename "$BACKUP_FILE")"
echo "Size:        $BACKUP_SIZE"
echo "Total kept:  $(echo "$EXISTING_BACKUPS" | head -n "$RETENTION" | grep -c . || echo 0)"
echo "Deleted:     $DELETED old backup(s)"
echo "======================"
```

**Expected Output:**
```
=== Backup Rotation Script ===
Source:    /opt/myapp
Backup:   /backup/myapp
Retention: Last 7 backups
===============================

📦 Creating backup...
✅ Backup created: myapp_backup_20250627_103000.tar.gz (245M) in 12s
🔒 Checksum saved: myapp_backup_20250627_103000.tar.gz.sha256

🔄 Rotating old backups (keeping last 7)...
   🗑️  Deleted: myapp_backup_20250619_103000.tar.gz
   🗑️  Deleted: myapp_backup_20250618_103000.tar.gz

=== Backup Summary ===
New backup:  myapp_backup_20250627_103000.tar.gz
Size:        245M
Total kept:  7
Deleted:     2 old backup(s)
======================
```

---

## Common Commands Cheat Sheet

| Command / Syntax | What It Does | Real Example |
|---|---|---|
| `test -f file` or `[[ -f file ]]` | Check if file exists and is a regular file | `[[ -f /etc/nginx/nginx.conf ]] && echo "Config exists"` |
| `test -d dir` or `[[ -d dir ]]` | Check if directory exists | `[[ -d /var/log/app ]] \|\| mkdir -p /var/log/app` |
| `test -z "$var"` | True if string is empty (zero length) | `[[ -z "$DB_HOST" ]] && echo "DB_HOST is not set"` |
| `grep -E 'pattern'` | Extended regex search (ERE) | `grep -E '^(ERROR\|FATAL)' /var/log/app.log` |
| `grep -rn 'text' --include='*.sh'` | Recursive search with line numbers, filtered by extension | `grep -rn 'rm -rf' --include='*.sh' /opt/scripts/` |
| `sed -i 's/old/new/g' file` | In-place find and replace (global) | `sed -i 's/PORT=8080/PORT=3000/g' .env` |
| `sed -n '10,20p' file` | Print specific line range | `sed -n '50,60p' /var/log/syslog` |
| `awk -F: '{print $1, $3}' file` | Split by delimiter, print specific columns | `awk -F: '$3 >= 1000 {print $1}' /etc/passwd` |
| `xargs` | Convert stdin to command arguments | `find /tmp -name '*.tmp' -mtime +7 \| xargs rm -f` |
| `tee` | Write to file AND stdout simultaneously | `./deploy.sh 2>&1 \| tee deploy.log` |
| `command1 \|\| command2` | Run command2 only if command1 fails | `systemctl start nginx \|\| echo "Nginx failed to start"` |
| `command1 && command2` | Run command2 only if command1 succeeds | `make build && make test && make deploy` |

---

## Troubleshooting Guide

| Problem | Likely Cause | Step-by-Step Fix |
|---|---|---|
| `[: too many arguments` or `unary operator expected` | Variable is unquoted and contains spaces or is empty, causing word splitting in `[ ]` test | 1. Always double-quote variables: `[ "$var" = "value" ]` 2. Better yet, use `[[ ]]` which handles empty/spaces: `[[ $var == "value" ]]` 3. For numeric tests, use `(( ))`: `(( count > 5 ))` |
| `bad substitution` | Using Bash-only syntax (like `${var,,}`, `${var^^}`, associative arrays) in `sh` instead of `bash`, or typo in parameter expansion | 1. Check shebang is `#!/bin/bash`, not `#!/bin/sh` 2. Run with `bash script.sh`, not `sh script.sh` 3. Verify variable name has no typos: `echo "${VARR}"` → should be `${VAR}` |
| `permission denied` when running `./script.sh` | Script file is not executable | 1. Add execute permission: `chmod +x script.sh` 2. Or run explicitly: `bash script.sh` 3. Check ownership: `ls -la script.sh` — ensure your user owns it or is in the correct group |
| `syntax error near unexpected token` | Missing `then` after `if`, missing `do` after `for/while`, unclosed quotes, or Windows line endings (CRLF `\r\n`) | 1. Check for missing keywords: every `if` needs `then`, every `for/while` needs `do` 2. Fix Windows line endings: `sed -i 's/\r$//' script.sh` or `dos2unix script.sh` 3. Use `bash -n script.sh` to syntax-check without running |
| `command not found` for a script function | Function was defined after it was called, or defined in a subshell (piped context) | 1. Move function definitions to the top of the script, before any calls 2. Avoid defining functions inside piped blocks: `cat file \| while read line; do ...` runs in a subshell 3. Use `type function_name` to verify the function is in scope |
| Script works interactively but fails in cron | Cron has a minimal `$PATH`, and doesn't source `.bashrc` or `.profile` | 1. Use absolute paths for all commands: `/usr/bin/curl` instead of `curl` 2. Set PATH at the top of the script: `export PATH="/usr/local/bin:/usr/bin:/bin"` 3. Redirect cron output for debugging: `* * * * * /opt/scripts/job.sh >> /var/log/cron_job.log 2>&1` |
| `integer expression expected` | Using string comparison operator for numbers, or variable contains non-numeric characters | 1. Use `-eq`, `-gt`, `-lt` for integer comparison: `[[ $count -gt 5 ]]` 2. Ensure variable is numeric: `[[ $var =~ ^[0-9]+$ ]] && echo "Is a number"` 3. Strip non-numeric chars: `count=$(echo "$raw" \| tr -dc '0-9')` |

---

## Real-World Job Scenario

> [!example] Scenario: CI/CD Pipeline Automation
> **Situation:** Your company uses Jenkins for CI/CD. The deployment pipeline for a microservices application involves building Docker images, running tests, pushing to a registry, and deploying to Kubernetes. Currently, each step is triggered manually by a team member clicking buttons in the Jenkins UI.
>
> **The Problem:** Deployments take 45 minutes of manual babysitting. On Fridays, two deployments were missed because the engineer forgot to click "Deploy to Staging" after tests passed. A production deployment failed silently because nobody checked the health endpoint after rollout.

**Junior DevOps Engineer approach:**
- Writes a single 200-line monolithic script that does everything
- Hardcodes server IPs, image tags, and namespace names
- Uses `set +e` to ignore errors so the script "always succeeds"
- Doesn't log anything — relies on Jenkins console output
- No rollback mechanism — if deployment fails, manually `kubectl rollout undo`

**Senior DevOps Engineer approach:**
- Breaks automation into modular scripts: `build.sh`, `test.sh`, `push.sh`, `deploy.sh`, `healthcheck.sh`
- Uses environment variables and config files for all environment-specific values
- Implements `set -euo pipefail` with `trap` for cleanup and error reporting
- Each script logs to a structured log file with timestamps and severity levels
- `deploy.sh` includes automatic rollback:

```bash
#!/bin/bash
set -euo pipefail

NAMESPACE="$1"
SERVICE="$2"
IMAGE_TAG="$3"

# Record current revision for rollback
PREV_REVISION=$(kubectl rollout history deployment/"$SERVICE" -n "$NAMESPACE" | tail -2 | head -1 | awk '{print $1}')

trap 'echo "Deployment failed — rolling back to revision $PREV_REVISION"; \
      kubectl rollout undo deployment/"$SERVICE" -n "$NAMESPACE" --to-revision="$PREV_REVISION"' ERR

# Deploy
kubectl set image deployment/"$SERVICE" "$SERVICE=$IMAGE_TAG" -n "$NAMESPACE"
kubectl rollout status deployment/"$SERVICE" -n "$NAMESPACE" --timeout=300s

# Health check
for i in $(seq 1 10); do
    HTTP_CODE=$(curl -sf -o /dev/null -w '%{http_code}' "https://${SERVICE}.${NAMESPACE}.svc/health" || echo "000")
    [[ "$HTTP_CODE" == "200" ]] && { echo "✅ Health check passed"; exit 0; }
    echo "Attempt $i: HTTP $HTTP_CODE — waiting..."
    sleep 5
done

echo "Health check failed after 10 attempts"
exit 1    # This triggers the ERR trap → automatic rollback
```

> *Senior engineer ka script modular hai, error handle karta hai, aur failure pe automatically rollback karta hai — yahi production-ready scripting hoti hai.*

---

## Interview Questions

**Q1: What is the difference between `set -e` and `set -u`?**

`set -e` (errexit) causes the script to exit immediately if any command returns a non-zero exit code. This prevents errors from cascading silently. `set -u` (nounset) causes the script to exit if any undefined variable is referenced — this catches typos and missing environment variables early. Together with `set -o pipefail` (which ensures a pipeline returns the exit code of the first failing command, not just the last), they form the defensive scripting trinity: `set -euo pipefail`.
*`set -e` se script error pe ruk jaati hai, `set -u` se undefined variable pe error aata hai — dono milke script ko safe banate hain.*

**Q2: What is the difference between `$@` and `$*`?**

Both represent all positional parameters, but they behave differently when double-quoted. `"$@"` expands each parameter as a separate quoted word — if you passed `"hello world" "foo"`, then `"$@"` gives two arguments: `hello world` and `foo`. `"$*"` joins all parameters into a single string separated by the first character of `$IFS` (default: space) — so `"$*"` gives one argument: `hello world foo`. Always use `"$@"` when passing arguments to another command to preserve word boundaries.
*`"$@"` har argument ko alag rakhta hai, `"$*"` sab ko ek string mein jod deta hai — almost hamesha `"$@"` use karo.*

**Q3: How does `trap` work in Bash?**

`trap` registers a command or function to be executed when the shell receives a specific signal or event. Common usage: `trap 'cleanup_function' EXIT` runs the cleanup function whenever the script exits (normally or due to error). `trap 'handler' ERR` runs on any command failure (when `set -e` is active). `trap 'echo "Caught SIGINT"' INT` handles Ctrl+C. Traps are essential for resource cleanup — deleting temp files, releasing locks, rolling back partial changes. Multiple signals can be trapped: `trap cleanup EXIT ERR INT TERM`.
*`trap` ek event handler hai — jaise alarm lagana ki "jab script khatam ho toh safai kar do". `EXIT` pe lagao toh chahe script crash ho ya normally end ho, cleanup hamesha chalega.*

**Q4: When would you use `awk` vs `sed`?**

`sed` (stream editor) is best for line-oriented text transformations — find and replace, delete lines, insert/append text. It operates on whole lines. Use it for: modifying config files (`sed -i 's/old/new/g' file`), extracting line ranges (`sed -n '10,20p'`), deleting patterns (`sed '/^#/d'`). `awk` is a full programming language designed for column-oriented data processing. It excels when you need to: split lines by delimiters (`-F:`), perform calculations on fields, filter rows based on field values, and generate formatted reports. Rule of thumb: if you're doing find/replace on lines → `sed`; if you're working with columns/fields → `awk`.
*`sed` lines pe kaam karta hai (find-replace, delete), `awk` columns pe kaam karta hai (CSV parse, field extraction) — dono ka role alag hai.*

**Q5: What is a shebang line and why is it important?**

The shebang (`#!`) is the first line of a script that tells the operating system which interpreter to use for executing the file. `#!/bin/bash` runs the script with Bash, `#!/usr/bin/env python3` with Python 3. Without a shebang, the system uses the current shell (which might be `sh`, `dash`, or `zsh`), potentially causing syntax errors if the script uses Bash-specific features like `[[ ]]`, arrays, or `${var,,}`. Best practice: use `#!/usr/bin/env bash` for portability — it finds `bash` wherever it's installed in `$PATH`, rather than hardcoding `/bin/bash` which may not exist on all systems (e.g., NixOS, FreeBSD).
*Shebang line script ko batati hai ki kaunsa interpreter use karna hai — agar nahi likhi toh system default shell use karega jo Bash nahi bhi ho sakta.*

---

## Related Notes

- [[00 DevOps Master Index]]
- [[LX-01 Linux for DevOps]]
- [[LX-03 Process and System Management]]
