#!/bin/sh
###########################################
# Certificate Renewal Hook Script
# Called by Certbot after successful renewal
# Copies certs to DirectSlave SSL dir and reloads
###########################################

LOG="/usr/local/directslave/log/cert-renewal.log"
PID_FILE="/usr/local/directslave/run/directslave.pid"
CERT_DEST="/usr/local/directslave/ssl"

echo "[$(date)] Certificate renewal hook triggered" >> "$LOG"

# Copy certificates to DirectSlave SSL directory
echo "[$(date)] Copying certificates to $CERT_DEST..." >> "$LOG"
for cert_dir in /etc/letsencrypt/live/*/; do
    if [ -d "$cert_dir" ]; then
        if cp "${cert_dir}fullchain.pem" "$CERT_DEST/server.crt" 2>/dev/null && \
           cp "${cert_dir}privkey.pem" "$CERT_DEST/server.key" 2>/dev/null; then
            echo "[$(date)] Copied certificates from $(basename "$cert_dir")" >> "$LOG"
        else
            echo "[$(date)] ERROR: Failed to copy certificates from $(basename "$cert_dir")" >> "$LOG"
        fi
    fi
done

# Fix permissions
echo "[$(date)] Setting certificate permissions..." >> "$LOG"
chmod 644 "$CERT_DEST/server.crt" 2>/dev/null || true
chmod 640 "$CERT_DEST/server.key" 2>/dev/null || true
chown bind:bind "$CERT_DEST/server.crt" "$CERT_DEST/server.key" 2>/dev/null || true
echo "[$(date)] Certificate permissions updated (644 for cert, 640 for key)" >> "$LOG"

# Reload DirectSlave to pick up new certificate
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "[$(date)] Sending HUP signal to DirectSlave (PID: $PID)..." >> "$LOG"
        kill -HUP "$PID"
        echo "[$(date)] DirectSlave signaled to reload certificate" >> "$LOG"
    else
        echo "[$(date)] WARNING: DirectSlave PID $PID not running" >> "$LOG"
    fi
else
    echo "[$(date)] WARNING: DirectSlave PID file not found" >> "$LOG"
fi

echo "[$(date)] Certificate renewal hook completed" >> "$LOG"
