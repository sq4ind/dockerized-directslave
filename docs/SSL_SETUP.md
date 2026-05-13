# SSL/TLS Certificate Setup Guide

This guide explains how SSL certificates work in DirectSlave Docker and how to configure them.

## Table of Contents

- [Overview](#overview)
- [Automatic SSL with Let's Encrypt](#automatic-ssl-with-lets-encrypt)
- [HTTP-01 Validation](#http-01-validation)
- [Manual Certificate Setup](#manual-certificate-setup)
- [Certificate Renewal](#certificate-renewal)
- [Troubleshooting](#troubleshooting)

## Overview

DirectSlave Docker supports three SSL certificate options:

1. **Automatic Let's Encrypt** (Recommended) - Free, automatic, auto-renewing
2. **Manual SSL Certificates** - Use your own certificates
3. **No SSL** - HTTP only (not recommended for production)

## Automatic SSL with Let's Encrypt

### How It Works

DirectSlave Docker uses [Certbot](https://certbot.eff.org/) to automatically obtain and renew free SSL certificates from [Let's Encrypt](https://letsencrypt.org/).

**Process:**
1. Container starts and checks for existing certificates
2. If none exist and `CERTBOT_ENABLED=true`, runs Certbot
3. Certbot validates domain ownership via HTTP-01 challenge
4. Let's Encrypt issues certificate (valid 90 days)
5. Certificate automatically configured in DirectSlave
6. Cron job checks daily for renewal (30 days before expiry)
7. After renewal, BIND is automatically reloaded

### Configuration

Edit `.env` file:

```bash
# Enable automatic SSL
CERTBOT_ENABLED=true

# Your email (for renewal notifications)
CERTBOT_EMAIL=admin@yourdomain.com

# Your domain name (must point to this server)
CERTBOT_DOMAIN=dns.yourdomain.com

# Validation method (http for HTTP-01)
CERTBOT_METHOD=http

# Enable SSL in DirectSlave
DS_SSL=on
```

### Requirements

**Critical requirements for Let's Encrypt:**

1. **Domain Name**: Must have a valid domain pointing to server
2. **Port 80 Access**: Must be accessible from internet
3. **Valid Email**: For renewal notifications
4. **No Conflicting Services**: Nothing else using port 80

**Verify requirements:**

```bash
# 1. Check domain points to your server
dig +short dns.yourdomain.com
# Should return your server's IP

# 2. Test port 80 accessibility
curl http://dns.yourdomain.com
# Should connect (can return error, but must connect)

# 3. Check nothing is using port 80
netstat -tuln | grep :80
# Should be empty before starting container
```

### First Certificate Generation

When starting the container for the first time with SSL enabled:

```bash
# Start container
docker-compose up -d

# Watch certificate generation in logs
docker logs -f directslave

# You should see:
# [INFO] Running certbot...
# [INFO] SSL certificate generated successfully!
```

**Certificate files location:**
- `/etc/letsencrypt/live/[DOMAIN]/fullchain.pem` - Certificate
- `/etc/letsencrypt/live/[DOMAIN]/privkey.pem` - Private key
- `/etc/letsencrypt/live/[DOMAIN]/chain.pem` - Certificate chain
- `/etc/letsencrypt/live/[DOMAIN]/cert.pem` - Certificate only

### Verification

Check if certificate was generated:

```bash
# List certificates
docker exec directslave certbot certificates

# Should show:
# Certificate Name: dns.yourdomain.com
#   Domains: dns.yourdomain.com
#   Expiry Date: 2026-08-11 (89 days)
#   Certificate Path: /etc/letsencrypt/live/dns.yourdomain.com/fullchain.pem
#   Private Key Path: /etc/letsencrypt/live/dns.yourdomain.com/privkey.pem

# Test HTTPS connection
curl -k https://dns.yourdomain.com:2224/

# Check SSL certificate via browser
# Navigate to: https://dns.yourdomain.com:2224/
```

## HTTP-01 Validation

### What is HTTP-01?

HTTP-01 is a domain validation method where Let's Encrypt verifies you control the domain by:

1. Providing a random token to Certbot
2. Certbot places token in `/.well-known/acme-challenge/[token]`
3. Let's Encrypt HTTP client fetches: `http://yourdomain.com/.well-known/acme-challenge/[token]`
4. If response matches, domain ownership is verified
5. Certificate is issued

### Port 80 Requirement

**Why port 80?**
- Let's Encrypt HTTP-01 validation only works on port 80
- Cannot use alternate ports
- Must be accessible from internet (public IP)

**When is port 80 used?**
- Initial certificate generation (30-60 seconds)
- Certificate renewal (every 60-90 days, 30-60 seconds)
- **Not used** for normal DirectSlave operation

### Firewall Configuration

Allow port 80 for HTTP-01 validation:

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow 80/tcp comment "Let's Encrypt HTTP-01"

# iptables
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4

# firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --reload
```

**Security Note:** Port 80 only needs to be open during validation. However, for automatic renewal, it should remain open or be opened automatically.

### Behind NAT/Router

If your server is behind NAT:

1. **Port Forwarding**: Forward port 80 from router to server
2. **Public IP**: Ensure domain points to router's public IP
3. **DMZ** (optional): Place server in DMZ for direct access

**Router configuration:**
```
External Port: 80
Internal IP: [Your Server IP]
Internal Port: 80
Protocol: TCP
```

### Behind Reverse Proxy

If using reverse proxy (nginx, Apache, Traefik):

**Option 1: Proxy /.well-known/acme-challenge/ to container**

Nginx example:
```nginx
location /.well-known/acme-challenge/ {
    proxy_pass http://directslave-container:80;
}
```

**Option 2: Use DNS validation instead** (see alternative methods below)

## Manual Certificate Setup

If you have existing SSL certificates or prefer manual management:

### Configuration

```bash
# Disable Certbot in .env
CERTBOT_ENABLED=false

# Enable SSL
DS_SSL=on
```

### Mount Certificates

**Option 1: Volume mount (recommended)**

```yaml
# docker-compose.yml
volumes:
  - ./ssl/server.crt:/usr/local/directslave/ssl/server.crt:ro
  - ./ssl/server.key:/usr/local/directslave/ssl/server.key:ro
```

**Option 2: Copy into running container**

```bash
# Copy certificate
docker cp /path/to/server.crt directslave:/usr/local/directslave/ssl/
docker cp /path/to/server.key directslave:/usr/local/directslave/ssl/

# Set permissions
docker exec directslave chown bind:bind /usr/local/directslave/ssl/server.*
docker exec directslave chmod 600 /usr/local/directslave/ssl/server.key

# Restart
docker-compose restart
```

### Certificate Requirements

- **Format**: PEM format (Base64 encoded)
- **Certificate**: Full chain (certificate + intermediates)
- **Private Key**: Unencrypted (no passphrase)
- **Permissions**: Readable by bind user

### Convert Certificate Formats

If your certificate is in different format:

```bash
# PFX/P12 to PEM
openssl pkcs12 -in certificate.pfx -out server.crt -clcerts -nokeys
openssl pkcs12 -in certificate.pfx -out server.key -nocerts -nodes

# DER to PEM
openssl x509 -inform der -in certificate.cer -out server.crt

# Create full chain
cat server.crt intermediate.crt root.crt > fullchain.crt
```

## Certificate Renewal

### Automatic Renewal (Let's Encrypt)

Renewal is fully automatic:

- **Check Frequency**: Daily at 3:00 AM (container time)
- **Renewal Trigger**: 30 days before expiry
- **Process**: Certbot renews → Hook script runs → BIND reloads
- **Notifications**: Sent to `CERTBOT_EMAIL`

**Monitoring renewal:**

```bash
# Check renewal cron job
docker exec directslave crontab -l

# View renewal logs
docker exec directslave cat /usr/local/directslave/log/cert-renewal.log

# Check certificate expiry
docker exec directslave certbot certificates

# Test renewal (dry run - doesn't actually renew)
docker exec directslave certbot renew --dry-run
```

### Force Manual Renewal

To force renewal before expiry:

```bash
# Force renewal
docker exec directslave certbot renew --force-renewal

# Check new certificate
docker exec directslave certbot certificates
```

### Renewal Hook Script

After each successful renewal, the hook script runs:

**Location**: `/usr/local/bin/cert-renewal-hook.sh`

**Actions**:
1. Logs renewal event
2. Reloads BIND to use new certificate
3. Optionally restarts DirectSlave (commented out by default)

**View hook logs:**
```bash
docker exec directslave cat /usr/local/directslave/log/cert-renewal.log
```

### Manual Certificate Renewal

For manually managed certificates:

1. Obtain new certificate from your provider
2. Replace files in mount or copy to container
3. Restart container:

```bash
docker-compose restart
```

## Troubleshooting

### Certificate Generation Failed

**Problem**: `Certificate generation failed!`

**Check:**

1. **Domain DNS**:
```bash
dig +short dns.yourdomain.com
# Must return your server's IP
```

2. **Port 80 accessibility**:
```bash
# From external network (not server itself):
curl -v http://dns.yourdomain.com

# Or use online tools:
# https://www.yougetsignal.com/tools/open-ports/
```

3. **Firewall**:
```bash
# Check if port 80 is open
sudo iptables -L -n | grep 80
sudo ufw status | grep 80
```

4. **Container logs**:
```bash
docker logs directslave 2>&1 | grep -i certbot
```

5. **Certbot logs**:
```bash
docker exec directslave cat /var/log/letsencrypt/letsencrypt.log
```

**Common causes:**
- Domain doesn't point to server
- Port 80 blocked by firewall
- Another service using port 80
- Rate limit hit (5 failures per hour per domain)

### Certificate Renewal Failed

**Problem**: Certificate not renewing automatically

**Check:**

1. **Cron is running**:
```bash
docker exec directslave ps aux | grep cron
# Should show: crond -b -l 8
```

2. **Test renewal**:
```bash
docker exec directslave certbot renew --dry-run
# Should succeed without errors
```

3. **Check renewal logs**:
```bash
docker exec directslave cat /var/log/letsencrypt/letsencrypt.log
```

4. **Manually renew**:
```bash
docker exec directslave certbot renew --force-renewal
```

### SSL Connection Errors

**Problem**: HTTPS not working

**Check:**

1. **Certificate exists**:
```bash
docker exec directslave ls -la /etc/letsencrypt/live/*/
```

2. **DirectSlave config**:
```bash
docker exec directslave grep ssl /usr/local/directslave/etc/directslave.conf
# Should show: ssl on
```

3. **Certificate paths**:
```bash
docker exec directslave grep ssl_cert /usr/local/directslave/etc/directslave.conf
docker exec directslave grep ssl_key /usr/local/directslave/etc/directslave.conf
# Paths must exist
```

4. **Test with curl**:
```bash
# Ignore certificate errors (testing connectivity)
curl -k https://dns.yourdomain.com:2224/

# Check certificate details
openssl s_client -connect dns.yourdomain.com:2224 -servername dns.yourdomain.com
```

### Rate Limits

Let's Encrypt has rate limits:

- **50 certificates** per registered domain per week
- **5 duplicate certificates** per week
- **5 validation failures** per account per hostname per hour

**If you hit rate limit:**
1. Wait for rate limit to reset (1 hour or 1 week)
2. Use staging environment for testing:
```bash
# Add to entrypoint.sh for testing
--staging
```
3. Check rate limit status: https://crt.sh/?q=yourdomain.com

### Certificate Permissions

**Problem**: Permission denied errors

**Fix permissions:**
```bash
docker exec directslave chown -R bind:bind /etc/letsencrypt
docker exec directslave chmod 600 /etc/letsencrypt/live/*/privkey.pem
docker-compose restart
```

### Wildcard Certificates

**Note**: HTTP-01 validation does **not** support wildcard certificates (*.yourdomain.com).

For wildcard certificates, you need DNS-01 validation (requires DNS provider API access).

## Best Practices

1. **Use Strong Domain**: Dedicated subdomain for DNS (dns.yourdomain.com)
2. **Monitor Expiry**: Set up monitoring for certificate expiry
3. **Keep Port 80 Open**: For automatic renewal
4. **Backup Certificates**: Include `/etc/letsencrypt` in backups
5. **Test Renewal**: Periodically test with `--dry-run`
6. **Use HTTPS**: Configure DirectAdmin to use port 2224 (HTTPS)
7. **Monitor Logs**: Check renewal logs regularly

## Additional Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://certbot.eff.org/docs/)
- [HTTP-01 Challenge](https://letsencrypt.org/docs/challenge-types/#http-01-challenge)
- [Rate Limits](https://letsencrypt.org/docs/rate-limits/)

---

**Need Help?** See main [README.md](../README.md) troubleshooting section or check container logs.
