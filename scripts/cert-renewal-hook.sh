#!/bin/sh
###########################################
# Certificate Renewal Hook Script
# Called by Certbot after successful renewal
# Signals DirectSlave to reload new certs
###########################################

LOG="/usr/local/directslave/log/cert-renewal.log"
PID_FILE="/usr/local/directslave/run/directslave.pid"

echo "[$(date)] Certificate renewed successfully" >> "$LOG"

# Reload DirectSlave so it picks up the new certificate
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "[$(date)] Sending HUP signal to DirectSlave (PID: $PID)..." >> "$LOG"
        kill -HUP "$PID"
        echo "[$(date)] DirectSlave signaled to reload" >> "$LOG"
    else
        echo "[$(date)] WARNING: DirectSlave PID $PID not running" >> "$LOG"
    fi
else
    echo "[$(date)] WARNING: DirectSlave PID file not found" >> "$LOG"
fi
