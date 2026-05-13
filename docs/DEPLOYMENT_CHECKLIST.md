# DirectSlave Docker - Deployment Checklist

Use this checklist to ensure proper deployment of DirectSlave Docker.

## Pre-Deployment Checklist

### Server Requirements
- [ ] Docker 20.10+ installed
- [ ] Docker Compose 1.29+ installed
- [ ] Domain name registered and pointing to server
- [ ] Server has public IP address
- [ ] Sufficient disk space (5GB+ recommended)

### Network Requirements
- [ ] Port 53 (DNS) open to public
- [ ] Port 80 (HTTP) open to public (for Let's Encrypt)
- [ ] Port 2222 or 2224 accessible from DirectAdmin server
- [ ] Firewall configured

### DirectAdmin Requirements
- [ ] DirectAdmin installed and running
- [ ] Admin or reseller access
- [ ] MultiServer feature available
- [ ] Network connectivity to DirectSlave server

---

## Installation Checklist

### Step 1: Clone and Setup
- [ ] Repository cloned: `git clone <repo-url>`
- [ ] Changed to directory: `cd dockerized-directslave`
- [ ] Copied env file: `cp .env.example .env`

### Step 2: Configuration
- [ ] Generated strong auth key: `openssl rand -base64 96`
- [ ] Edited `.env` file with your values:
  - [ ] `DS_AUTH_KEY` set (128+ chars)
  - [ ] `CERTBOT_EMAIL` set (your email)
  - [ ] `CERTBOT_DOMAIN` set (your domain)
  - [ ] `CERTBOT_ENABLED` set to `true`
  - [ ] `DS_SSL` set to `on`

### Step 3: DNS Verification
- [ ] Domain points to server: `dig +short dns.yourdomain.com`
- [ ] Returns correct IP address

### Step 4: Build and Start
- [ ] Built container: `docker-compose build`
- [ ] Started container: `docker-compose up -d`
- [ ] Container is running: `docker ps | grep directslave`
- [ ] No errors in logs: `docker logs directslave`

### Step 5: SSL Verification (if enabled)
- [ ] Certificate generated successfully (check logs)
- [ ] Certificate exists: `docker exec directslave certbot certificates`
- [ ] HTTPS accessible: `curl -k https://dns.yourdomain.com:2224/`

### Step 6: DirectSlave Configuration
- [ ] Set password: `docker exec -it directslave /usr/local/directslave/bin/directslave --password admin:YourPassword`
- [ ] Validated config: `docker exec directslave /usr/local/bin/validate-config.sh`
- [ ] No errors in validation

### Step 7: Service Verification
- [ ] DirectSlave running: `docker exec directslave ps aux | grep directslave`
- [ ] BIND running: `docker exec directslave ps aux | grep named`
- [ ] BIND status OK: `docker exec directslave rndc status`

---

## DirectAdmin Integration Checklist

### Step 1: Enable MultiServer
- [ ] Logged into DirectAdmin
- [ ] Navigated to Admin Tools → MultiServer Setup
- [ ] MultiServer feature enabled

### Step 2: Add Server
- [ ] Clicked "Add New Server"
- [ ] Filled in server details:
  - [ ] Server Type: DNS
  - [ ] Server Name: (descriptive name)
  - [ ] Host: (your server IP or domain)
  - [ ] Port: 2222 or 2224
  - [ ] Username: admin
  - [ ] Password: (set in DirectSlave)
  - [ ] Use SSL: (checked for 2224)

### Step 3: Test Connection
- [ ] Clicked "Test Connection"
- [ ] Shows "DirectSlave GO/3.x connection OK"
- [ ] Saved server configuration

### Step 4: Test Replication
- [ ] Created test domain in DirectAdmin
- [ ] Waited 30-60 seconds
- [ ] Zone file exists: `docker exec directslave ls /etc/namedb/secondary/ | grep testdomain`
- [ ] DNS resolves: `dig @your-server-ip testdomain.com`

---

## Security Checklist

### Authentication
- [ ] Strong `DS_AUTH_KEY` used (128+ characters)
- [ ] Strong DirectSlave password set
- [ ] `.env` file permissions: `chmod 600 .env`
- [ ] `.env` not in version control

### Firewall
- [ ] Port 53 open to public (DNS)
- [ ] Port 80 open to public (Let's Encrypt)
- [ ] Port 2222/2224 restricted to DirectAdmin IP only
- [ ] Firewall rules saved and persistent

### SSL/TLS
- [ ] SSL enabled (`DS_SSL=on`)
- [ ] Valid certificate installed
- [ ] Certificate auto-renewal configured
- [ ] HTTPS working from DirectAdmin

### Updates
- [ ] Docker images updated
- [ ] Base image is latest Alpine
- [ ] Update schedule planned

---

## Monitoring Checklist

### Logging
- [ ] Log directory writable
- [ ] Logs being written:
  - [ ] access.log
  - [ ] error.log
  - [ ] action.log
- [ ] Log rotation configured (Docker handles this)

### Health Checks
- [ ] Container health check passing: `docker ps` (shows "healthy")
- [ ] Services responding
- [ ] DNS queries working

### Monitoring Setup
- [ ] Uptime monitoring configured (optional)
- [ ] Alert for container down (optional)
- [ ] Alert for certificate expiry (optional)
- [ ] Log monitoring (optional)

---

## Backup Checklist

### Initial Backup
- [ ] Backed up configuration: `docker run --rm -v directslave_config:/config -v $(pwd):/backup alpine tar czf /backup/config-backup.tar.gz /config`
- [ ] Backup stored securely
- [ ] Backup tested (restore to test environment)

### Backup Schedule
- [ ] Daily backup scheduled
- [ ] Backup includes:
  - [ ] Configuration volume
  - [ ] Zone files volume
  - [ ] SSL certificates volume
- [ ] Backup retention policy defined
- [ ] Offsite backup configured

---

## Production Readiness Checklist

### Performance
- [ ] Resource limits set (if needed)
- [ ] Network mode appropriate (bridge/host)
- [ ] DNS queries responding quickly

### Reliability
- [ ] Container restart policy: `unless-stopped`
- [ ] Health checks enabled
- [ ] Logs monitored
- [ ] Alert system configured

### Documentation
- [ ] Deployment documented
- [ ] Credentials stored securely
- [ ] Recovery procedures documented
- [ ] Team trained on operations

### Testing
- [ ] DNS resolution tested from multiple locations
- [ ] Zone replication working
- [ ] SSL certificate valid and trusted
- [ ] DirectAdmin integration working
- [ ] Failover tested (optional)

---

## Post-Deployment Checklist

### 24 Hours After
- [ ] No errors in logs
- [ ] All zones replicated
- [ ] DNS queries working
- [ ] Certificate renewal cron running

### 7 Days After
- [ ] Weekly backup completed
- [ ] No performance issues
- [ ] No security issues
- [ ] DirectAdmin reporting healthy

### 30 Days After
- [ ] Certificate renewal tested (dry-run)
- [ ] Backups verified
- [ ] Monitoring alerts tested
- [ ] Documentation reviewed

---

## Troubleshooting Reference

### Quick Commands
```bash
# View logs
docker logs -f directslave

# Validate configuration
docker exec directslave /usr/local/bin/validate-config.sh

# Check services
docker exec directslave ps aux

# Test DNS
dig @localhost example.com

# Check certificates
docker exec directslave certbot certificates

# Restart container
docker-compose restart
```

### Common Issues
- **Container won't start**: Check logs and .env configuration
- **SSL failed**: Verify domain DNS and port 80 accessibility
- **DirectAdmin connection failed**: Check firewall and credentials
- **DNS not working**: Check BIND status and zone files

### Getting Help
- [ ] Reviewed README.md
- [ ] Checked SSL_SETUP.md (for SSL issues)
- [ ] Checked DIRECTADMIN_SETUP.md (for integration issues)
- [ ] Reviewed container logs
- [ ] Validated configuration

---

## Sign-off

### Deployment Completed By
- **Name**: _______________________
- **Date**: _______________________
- **Environment**: [ ] Development  [ ] Staging  [ ] Production

### Verification
- [ ] All checklist items completed
- [ ] No errors or warnings
- [ ] System operational
- [ ] Documentation updated
- [ ] Team notified

### Notes
```
(Add any deployment-specific notes here)
```

---

**Status**: ⬜ Not Started | ⏳ In Progress | ✅ Complete

Use this checklist to ensure nothing is missed during deployment!
