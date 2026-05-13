#!/bin/sh
set -e

###########################################
# DirectSlave Docker Entrypoint Script
# Handles initialization, SSL setup, and
# service startup for DirectSlave + BIND
###########################################

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    printf '%b\n' "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    printf '%b\n' "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    printf '%b\n' "${RED}[ERROR]${NC} $1"
}

###########################################
# 1. INITIALIZATION PHASE
###########################################
log_info "Starting DirectSlave initialization..."

# Set default environment variables if not provided
export DS_HOST="${DS_HOST:-*}"
export DS_PORT="${DS_PORT:-2222}"
export DS_SSLPORT="${DS_SSLPORT:-2224}"
export DS_SSL="${DS_SSL:-on}"
export DS_DEBUG="${DS_DEBUG:-0}"
export DS_BACKGROUND="${DS_BACKGROUND:-1}"
export DS_UID="${DS_UID:-53}"
export DS_GID="${DS_GID:-53}"
export NAMED_WORKDIR="${NAMED_WORKDIR:-/etc/namedb/secondary}"
export BIND_CONF_PATH="${BIND_CONF_PATH:-/etc/namedb/secondary/named.conf}"
export RETRY_TIME="${RETRY_TIME:-1200}"
export RNDC_PATH="${RNDC_PATH:-/usr/sbin/rndc}"
export NAMED_FORMAT="${NAMED_FORMAT:-text}"
export CERTBOT_ENABLED="${CERTBOT_ENABLED:-false}"
export CERTBOT_METHOD="${CERTBOT_METHOD:-http}"

# Verify critical environment variables
if [ -z "$DS_AUTH_KEY" ]; then
    log_error "DS_AUTH_KEY is not set! This is REQUIRED for security."
    log_error "Please set DS_AUTH_KEY to a strong random string (128+ characters recommended)."
    exit 1
fi

# Create necessary directories with proper permissions
log_info "Creating directory structure..."
mkdir -p /usr/local/directslave/bin
mkdir -p /usr/local/directslave/etc
mkdir -p /usr/local/directslave/log
mkdir -p /usr/local/directslave/run
mkdir -p /usr/local/directslave/scripts
mkdir -p /usr/local/directslave/ssl
mkdir -p /usr/local/directslave/www
mkdir -p "${NAMED_WORKDIR}"
mkdir -p /etc/letsencrypt
mkdir -p /var/lib/letsencrypt
mkdir -p /var/run/named
mkdir -p /var/cache/bind

# Set ownership
chown -R bind:bind /usr/local/directslave
chown -R bind:bind "${NAMED_WORKDIR}"
chown -R bind:bind /var/run/named
chown -R bind:bind /var/cache/bind

# Verify DirectSlave binary exists
if [ ! -f "/usr/local/directslave/bin/directslave" ]; then
    log_error "DirectSlave binary not found at /usr/local/directslave/bin/directslave"
    log_error "The Docker image may not have been built correctly."
    exit 1
fi

chmod +x /usr/local/directslave/bin/directslave

###########################################
# 2. SSL CERTIFICATE PHASE
###########################################
log_info "Checking SSL certificate configuration..."

CERT_PATH=""
KEY_PATH=""

if [ "$CERTBOT_ENABLED" = "true" ]; then
    log_info "Certbot is enabled. Checking for existing certificates..."
    
    if [ -z "$CERTBOT_DOMAIN" ]; then
        log_error "CERTBOT_DOMAIN is required when CERTBOT_ENABLED=true"
        exit 1
    fi
    
    if [ -z "$CERTBOT_EMAIL" ]; then
        log_error "CERTBOT_EMAIL is required when CERTBOT_ENABLED=true"
        exit 1
    fi
    
    CERT_DIR="/etc/letsencrypt/live/${CERTBOT_DOMAIN}"
    
    if [ -f "${CERT_DIR}/fullchain.pem" ] && [ -f "${CERT_DIR}/privkey.pem" ]; then
        log_info "Existing SSL certificates found for ${CERTBOT_DOMAIN}"
        CERT_PATH="${CERT_DIR}/fullchain.pem"
        KEY_PATH="${CERT_DIR}/privkey.pem"
    else
        log_info "No existing certificates found. Generating new SSL certificate..."
        log_info "Using HTTP-01 validation method for domain: ${CERTBOT_DOMAIN}"
        log_warn "Port 80 must be accessible from the internet for this to work!"
        
        # Run certbot in standalone mode with HTTP-01 validation
        log_info "Running certbot..."
        certbot certonly \
            --standalone \
            --non-interactive \
            --agree-tos \
            --email "${CERTBOT_EMAIL}" \
            -d "${CERTBOT_DOMAIN}" \
            --preferred-challenges http \
            --http-01-port 80 \
            --keep-until-expiring \
            || {
                log_error "Certificate generation failed!"
                log_error "Common issues:"
                log_error "  1. Port 80 is not accessible from the internet"
                log_error "  2. Domain ${CERTBOT_DOMAIN} does not point to this server"
                log_error "  3. Firewall blocking port 80"
                log_warn "DirectSlave will continue without SSL..."
                export DS_SSL="off"
            }
        
        if [ -f "${CERT_DIR}/fullchain.pem" ]; then
            log_info "SSL certificate generated successfully!"
            CERT_PATH="${CERT_DIR}/fullchain.pem"
            KEY_PATH="${CERT_DIR}/privkey.pem"
        fi
    fi
    
    # Set up automatic renewal via cron
    if [ -n "$CERT_PATH" ]; then
        log_info "Setting up automatic certificate renewal..."
        echo "0 3 * * * certbot renew --quiet --deploy-hook /usr/local/bin/cert-renewal-hook.sh" | crontab -
        crond -b -l 8
        log_info "Cron daemon started for certificate auto-renewal"
    fi
else
    log_info "Certbot is disabled. Checking for manual SSL certificates..."
    
    # Check if manual certificates exist
    if [ -f "/usr/local/directslave/ssl/server.crt" ] && [ -f "/usr/local/directslave/ssl/server.key" ]; then
        log_info "Manual SSL certificates found in /usr/local/directslave/ssl/"
        CERT_PATH="/usr/local/directslave/ssl/server.crt"
        KEY_PATH="/usr/local/directslave/ssl/server.key"
    else
        log_warn "No SSL certificates found. SSL will be disabled."
        export DS_SSL="off"
    fi
fi

# Export certificate paths for config template
export SSL_CERT_PATH="${CERT_PATH}"
export SSL_KEY_PATH="${KEY_PATH}"

###########################################
# 3. CONFIG GENERATION PHASE
###########################################
log_info "Generating DirectSlave configuration..."

# Check if template exists
if [ ! -f "/usr/local/directslave/etc/directslave.conf.template" ]; then
    log_error "Configuration template not found!"
    exit 1
fi

# Use envsubst to populate template with environment variables
envsubst < /usr/local/directslave/etc/directslave.conf.template > /usr/local/directslave/etc/directslave.conf

# Create default passwd file if it doesn't exist
if [ ! -f "/usr/local/directslave/etc/passwd" ]; then
    log_info "Creating default authentication file..."
    touch /usr/local/directslave/etc/passwd
    chown bind:bind /usr/local/directslave/etc/passwd
    chmod 600 /usr/local/directslave/etc/passwd
fi

# Validate configuration if script exists
if [ -f "/usr/local/bin/validate-config.sh" ]; then
    log_info "Validating configuration..."
    /usr/local/bin/validate-config.sh || log_warn "Configuration validation had warnings"
fi

chown bind:bind /usr/local/directslave/etc/directslave.conf

log_info "DirectSlave configuration generated at /usr/local/directslave/etc/directslave.conf"

###########################################
# 4. BIND SETUP PHASE
###########################################
log_info "Setting up BIND (named)..."

# Create /etc/bind/named.conf from Alpine's authoritative template if it doesn't exist
if [ ! -f "/etc/bind/named.conf" ]; then
    log_info "Creating BIND configuration from Alpine authoritative template..."
    cp /etc/bind/named.conf.authoritative /etc/bind/named.conf
    # Update listen addresses to bind on all interfaces (required for a slave DNS server)
    sed -i 's/listen-on { 127.0.0.1; };/listen-on { any; };/' /etc/bind/named.conf
    sed -i 's/listen-on-v6 { none; };/listen-on-v6 { any; };/' /etc/bind/named.conf
fi

# Add rndc key include if not already present
if ! grep -q 'include "/etc/bind/rndc.key"' /etc/bind/named.conf 2>/dev/null; then
    log_info "Adding rndc key include to BIND configuration..."
    printf '\n// RNDC key for remote control\ninclude "/etc/bind/rndc.key";\n' >> /etc/bind/named.conf
fi

# Add controls block if not already present
if ! grep -q 'controls {' /etc/bind/named.conf 2>/dev/null; then
    log_info "Adding controls block to BIND configuration..."
    printf '\ncontrols {\n    inet 127.0.0.1 port 953 allow { localhost; } keys { "rndc-key"; };\n};\n' >> /etc/bind/named.conf
fi

# Add DirectSlave zones include if not already present
if ! grep -q 'include "/etc/namedb/secondary/named.conf"' /etc/bind/named.conf 2>/dev/null; then
    log_info "Adding DirectSlave zones include to BIND configuration..."
    printf '\n// Include DirectSlave managed zones\ninclude "/etc/namedb/secondary/named.conf";\n' >> /etc/bind/named.conf
fi

# Create empty DirectSlave zones file if it doesn't exist yet
# DirectSlave will manage this file, but BIND needs it to exist at startup
if [ ! -f "/etc/namedb/secondary/named.conf" ]; then
    touch /etc/namedb/secondary/named.conf
    chown bind:bind /etc/namedb/secondary/named.conf
fi

# Validate BIND configuration
log_info "Validating BIND configuration..."
named-checkconf /etc/bind/named.conf || {
    log_error "BIND configuration validation failed!"
    exit 1
}

log_info "BIND configuration validated successfully"

###########################################
# 5. SERVICE START PHASE
###########################################
log_info "Starting services..."

# Start BIND (named) in background
log_info "Starting BIND DNS server..."
named -u bind -c /etc/bind/named.conf -g &
NAMED_PID=$!

# Give BIND a moment to start
sleep 2

# Check if BIND started successfully
if ! kill -0 $NAMED_PID 2>/dev/null; then
    log_error "BIND failed to start!"
    exit 1
fi

log_info "BIND started successfully (PID: $NAMED_PID)"

# Wait a bit more for BIND to fully initialize
sleep 3

# Start DirectSlave
log_info "Starting DirectSlave..."
log_info "DirectSlave will listen on:"
log_info "  - HTTP: ${DS_HOST}:${DS_PORT}"
if [ "$DS_SSL" = "on" ]; then
    log_info "  - HTTPS: ${DS_HOST}:${DS_SSLPORT}"
fi

# Change to DirectSlave directory
cd /usr/local/directslave

# Function to handle shutdown signals
shutdown() {
    log_info "Received shutdown signal, stopping services..."
    
    # Stop DirectSlave
    if [ -f "/usr/local/directslave/run/directslave.pid" ]; then
        log_info "Stopping DirectSlave..."
        kill "$(cat /usr/local/directslave/run/directslave.pid)" 2>/dev/null || true
    fi
    
    # Stop BIND
    log_info "Stopping BIND..."
    kill $NAMED_PID 2>/dev/null || true
    
    log_info "Shutdown complete"
    exit 0
}

# Trap signals for graceful shutdown
trap shutdown TERM INT

# Start DirectSlave in foreground (so Docker can capture logs)
if [ "$DS_DEBUG" = "1" ]; then
    log_info "Starting DirectSlave in debug mode..."
    exec /usr/local/directslave/bin/directslave --debug
else
    log_info "Starting DirectSlave in normal mode..."
    # Run in foreground for Docker
    exec /usr/local/directslave/bin/directslave --foreground
fi
