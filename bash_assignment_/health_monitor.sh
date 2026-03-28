#!/bin/bash

SERVICE_FILE="services.txt"
LOG_FILE="/var/log/health_monitor.log"
DRY_RUN=false

# Counters
total=0
healthy=0
recovered=0
failed=0

# Argument parsing
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "Running in DRY-RUN mode (no actual restarts)"
fi

# File checks
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "Error: services.txt file not found!"
    exit 1
fi

if [[ ! -s "$SERVICE_FILE" ]]; then
    echo "Error: services.txt is empty!"
    exit 1
fi

# Logging function
log_event() {
    local severity=$1
    local service=$2
    local message=$3

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp [$severity] $service - $message" | sudo tee -a "$LOG_FILE" > /dev/null
}

# Process services
while read -r service; do
    ((total++))

    status=$(systemctl is-active "$service" 2>/dev/null)

    if [[ "$status" == "active" ]]; then
        ((healthy++))
        log_event "INFO" "$service" "Service is running"
    else
        echo "Service $service is down. Attempting restart..."

        if [[ "$DRY_RUN" == false ]]; then
            sudo systemctl restart "$service"
            sleep 5
        else
            echo "[DRY-RUN] Would restart $service"
        fi

        status=$(systemctl is-active "$service" 2>/dev/null)

        if [[ "$status" == "active" ]]; then
            ((recovered++))
            log_event "RECOVERED" "$service" "Service restarted successfully"
        else
            ((failed++))
            log_event "FAILED" "$service" "Service failed to restart"
        fi
    fi

done < "$SERVICE_FILE"

# Summary
echo ""
echo "========= SUMMARY ========="
echo "Total Services Checked : $total"
echo "Healthy               : $healthy"
echo "Recovered             : $recovered"
echo "Failed                : $failed"
echo "=========================="