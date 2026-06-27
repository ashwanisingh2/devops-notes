#!/bin/bash
# Description: Production-ready disk usage alert script.
# Usage: ./disk_alert.sh
set -euo pipefail # God mode error handling

THRESHOLD=80
# awk aur df use karke / partition ka percentage nikalna
USAGE=$(df / | grep / | awk '{ print $5 }' | sed 's/%//g')

if [ "$USAGE" -gt "$THRESHOLD" ]; then
    echo "CRITICAL: Disk space is at ${USAGE}%"
    # Example email alert (uncomment and configure if mailx is installed)
    # echo "Disk space is critically high: ${USAGE}%" | mail -s "Disk Alert" admin@company.com
else
    echo "OK: Disk space is at ${USAGE}%"
fi
