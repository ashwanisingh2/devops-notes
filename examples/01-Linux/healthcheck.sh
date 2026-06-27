#!/bin/bash
# Description: Healthcheck script to automatically restart a failing service.
# Run this via cron: */5 * * * * /opt/scripts/healthcheck.sh
set -euo pipefail

SERVICE_NAME="myapp"

if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "$(date): Service $SERVICE_NAME is down! Restarting..."
    systemctl restart "$SERVICE_NAME"
    
    # Optional: Send alert
    # echo "Alert: $SERVICE_NAME was restarted on $(hostname)" | mail -s "Service Alert" admin@company.com
else
    echo "$(date): Service $SERVICE_NAME is running normally."
fi
