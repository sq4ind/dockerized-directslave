# DirectAdmin Integration Guide

This guide explains how to integrate DirectSlave Docker with your DirectAdmin master server.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [DirectSlave Setup](#directslave-setup)
- [DirectAdmin Configuration](#directadmin-configuration)
- [Testing the Connection](#testing-the-connection)
- [Troubleshooting](#troubleshooting)

## Overview

DirectAdmin's MultiServer feature allows you to automatically replicate DNS zones to secondary (slave) DNS servers. DirectSlave acts as a secondary DNS server and provides a DirectAdmin-compatible API for zone management.

**Architecture:**

```
┌─────────────────────┐         ┌──────────────────────┐
│  DirectAdmin        │         │  DirectSlave Docker  │
│  (Master Server)    │         │  (Slave Server)      │
│                     │         │                      │
│  - Zone Management  │ ──────> │  - DirectSlave API   │
│  - MultiServer API  │  HTTP   │  - BIND DNS Server   │
│  - Web Interface    │  :2222  │  - Zone Replication  │
└─────────────────────┘         └──────────────────────┘
                                          │
                                          │ DNS Queries
                                          │ Port 53
                                          ▼
                                  ┌──────────────┐
                                  │  DNS Clients │
                                  └──────────────┘
```

## Prerequisites

### On DirectAdmin Server

- DirectAdmin installed and running
- Admin or reseller access
- MultiServer feature available (most licenses include it)
- Network connectivity to DirectSlave server

### On DirectSlave Server

- DirectSlave Docker container running
- Ports accessible from DirectAdmin server:
  - **2222** (HTTP) or **2224** (HTTPS)
  - **53** (DNS - UDP/TCP)
- Authentication credentials configured
- Domain name pointing to server (if using SSL)

### Network Requirements

- DirectAdmin server can reach DirectSlave ports (2222/2224)
- Internet users can reach DirectSlave DNS port (53)
- Firewall allows required ports

## DirectSlave Setup

### 1. Start DirectSlave Container

```bash
# Navigate to project directory
cd dockerized-directslave

# Copy and configure .env
cp .env.example .env
nano .env

# Start container
docker-compose up -d

# Verify it's running
docker ps | grep directslave
```

### 2. Configure Authentication

Set up username and password for DirectAdmin to authenticate:

```bash
# Set authentication credentials
# Replace 'admin' with your preferred username
# Replace 'your-secure-password' with a strong password
docker exec -it directslave /usr/local/directslave/bin/directslave --password admin:your-secure-password

# Verify password was set
docker exec directslave ls -la /usr/local/directslave/etc/passwd
```

**Important**: 
- Use a **strong, unique password**
- Remember these credentials - you'll need them for DirectAdmin configuration
- Multiple users can be added with additional `--password` commands

### 3. Verify DirectSlave is Running

```bash
# Check if DirectSlave process is running
docker exec directslave ps aux | grep directslave

# Check logs
docker logs directslave

# Test HTTP endpoint (from DirectAdmin server)
curl http://YOUR_DIRECTSLAVE_IP:2222/

# Test HTTPS endpoint (if SSL enabled)
curl https://YOUR_DIRECTSLAVE_DOMAIN:2224/
```

### 4. Get Server Information

Note these details for DirectAdmin configuration:

- **IP Address**: DirectSlave server IP
- **Hostname**: DirectSlave server hostname/domain
- **Port**: 2222 (HTTP) or 2224 (HTTPS)
- **Username**: Set in step 2 (e.g., "admin")
- **Password**: Set in step 2

## DirectAdmin Configuration

### 1. Access DirectAdmin

Log in to your DirectAdmin server:

```
https://your-directadmin-server:2222/
```

### 2. Enable MultiServer Feature

**As Admin:**

1. Navigate to: **Admin Level** → **Admin Tools**
2. Click: **MultiServer Setup**
3. If not enabled, click **Enable MultiServer**

![DirectAdmin MultiServer](https://help.directadmin.com/images/multiserver.png)

### 3. Add DirectSlave Server

**In MultiServer Setup:**

1. Click **"Add New Server"** or **"Create Server"**

2. Fill in the form:

   | Field | Value | Example |
   |-------|-------|---------|
   | **Server Type** | Select "DNS" | DNS |
   | **Server Name** | Descriptive name | DirectSlave-1 |
   | **Host** | DirectSlave server IP or domain | 192.168.1.100 or dns.example.com |
   | **Port** | 2222 (HTTP) or 2224 (HTTPS) | 2222 |
   | **Username** | Set in DirectSlave --password | admin |
   | **Password** | Set in DirectSlave --password | your-secure-password |
   | **Use SSL** | Check if using port 2224 | ☑ (for 2224) or ☐ (for 2222) |
   | **Verify SSL** | Check for valid certificates | ☐ (for self-signed) or ☑ (for Let's Encrypt) |

3. Click **"Test Connection"**

4. Should see: **"DirectSlave GO/3.x connection OK"** ✓

5. Click **"Add Server"** or **"Save"**

### 4. Configure DNS Cluster

After adding the server, configure which domains should replicate:

**Option 1: All Domains (Recommended)**
- DirectAdmin automatically replicates all zones to all DNS servers in cluster

**Option 2: Specific Domains**
1. Navigate to: **DNS Management** → **DNS Cluster**
2. Select domains to replicate
3. Choose DirectSlave server
4. Click **"Apply"**

### 5. Enable Automatic Replication

Ensure new domains are automatically added:

1. Navigate to: **Admin Settings** → **DNS Administration**
2. Enable: **"Add new domains to DNS cluster automatically"**
3. Save settings

## Testing the Connection

### Test 1: Connection Test in DirectAdmin

In **MultiServer Setup** page:

1. Find your DirectSlave server
2. Click **"Test Connection"** button
3. Should display: **"DirectSlave GO/3.x connection OK"** ✓

**If test fails**, see [Troubleshooting](#troubleshooting) section.

### Test 2: Create Test Domain

Create a test domain to verify replication:

1. In DirectAdmin, navigate to: **Account Manager** → **Create Account**
2. Create a test account with domain: `test.yourdomain.com`
3. Wait 30-60 seconds for replication

**Verify on DirectSlave:**

```bash
# Check if zone file was created
docker exec directslave ls -la /etc/namedb/secondary/ | grep test.yourdomain.com

# Should show: test.yourdomain.com.db

# Check DirectSlave action log
docker exec directslave tail -f /usr/local/directslave/log/action.log

# Should show: Domain test.yourdomain.com created
```

### Test 3: DNS Resolution

Test if DNS queries work:

```bash
# From any computer with dig installed
dig @YOUR_DIRECTSLAVE_IP test.yourdomain.com

# Should return DNS records

# Check SOA record
dig @YOUR_DIRECTSLAVE_IP test.yourdomain.com SOA

# Check NS records
dig @YOUR_DIRECTSLAVE_IP test.yourdomain.com NS
```

### Test 4: Zone Transfer

Verify AXFR zone transfer works:

```bash
# From DirectAdmin server or any allowed host
dig @YOUR_DIRECTSLAVE_IP test.yourdomain.com AXFR

# Should return full zone data
```

## Advanced Configuration

### Using HTTPS (Recommended)

For secure communication, use HTTPS (port 2224):

**DirectSlave Configuration (.env):**
```bash
DS_SSL=on
DS_SSLPORT=2224
CERTBOT_ENABLED=true
CERTBOT_DOMAIN=dns.yourdomain.com
CERTBOT_EMAIL=admin@yourdomain.com
```

**DirectAdmin Configuration:**
- Port: `2224`
- Use SSL: `☑` (checked)
- Verify SSL: `☑` (if using valid Let's Encrypt cert)

### Multiple DirectAdmin Servers

To serve multiple DirectAdmin masters:

1. Add authentication for each:
```bash
docker exec -it directslave /usr/local/directslave/bin/directslave --password da1-admin:password1
docker exec -it directslave /usr/local/directslave/bin/directslave --password da2-admin:password2
```

2. Configure each DirectAdmin server independently
3. Each can use same or different credentials

### IP Restrictions

Restrict access to DirectSlave API to only DirectAdmin servers:

**Using firewall (recommended):**
```bash
# Allow DirectAdmin server IP only
iptables -A INPUT -p tcp --dport 2222 -s DIRECTADMIN_IP -j ACCEPT
iptables -A INPUT -p tcp --dport 2224 -s DIRECTADMIN_IP -j ACCEPT

# Block all others
iptables -A INPUT -p tcp --dport 2222 -j DROP
iptables -A INPUT -p tcp --dport 2224 -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### Custom Port

If you need to use different ports:

**docker-compose.yml:**
```yaml
ports:
  - "8080:2222"  # Map external 8080 to internal 2222
```

**DirectAdmin configuration:**
- Port: `8080`

## Monitoring

### Check Replication Status

**On DirectAdmin:**
1. Navigate to: **DNS Management** → **MultiServer**
2. View server status and last sync time

**On DirectSlave:**
```bash
# View action log
docker exec directslave tail -f /usr/local/directslave/log/action.log

# Count replicated zones
docker exec directslave ls /etc/namedb/secondary/*.db | wc -l

# View access log
docker exec directslave tail -f /usr/local/directslave/log/access.log
```

### Set Up Monitoring

Monitor DirectSlave availability:

```bash
# Simple HTTP check (every 5 minutes)
*/5 * * * * curl -f http://YOUR_DIRECTSLAVE_IP:2222/ || echo "DirectSlave down!" | mail -s "Alert" admin@example.com
```

**Or use monitoring tools:**
- Nagios
- Zabbix
- Prometheus + Grafana
- Uptime Robot

## Troubleshooting

### Connection Failed

**Error in DirectAdmin**: "Connection failed" or timeout

**Possible causes:**

1. **Firewall blocking ports**
   ```bash
   # On DirectSlave server, check firewall
   iptables -L -n | grep 2222
   ufw status | grep 2222
   
   # Test from DirectAdmin server
   telnet DIRECTSLAVE_IP 2222
   curl http://DIRECTSLAVE_IP:2222/
   ```

2. **DirectSlave not running**
   ```bash
   docker ps | grep directslave
   docker logs directslave
   ```

3. **Wrong IP/Port**
   - Verify IP address is correct
   - Verify port matches container configuration

4. **Network routing issues**
   ```bash
   # From DirectAdmin server
   ping DIRECTSLAVE_IP
   traceroute DIRECTSLAVE_IP
   ```

### Authentication Failed

**Error**: "Invalid credentials" or "Authentication failed"

**Solutions:**

1. **Verify credentials were set**:
   ```bash
   docker exec directslave cat /usr/local/directslave/etc/passwd
   # Should show username (password is hashed)
   ```

2. **Reset password**:
   ```bash
   docker exec -it directslave /usr/local/directslave/bin/directslave --password admin:new-password
   ```

3. **Check username matches**:
   - Username in DirectAdmin must match username in DirectSlave

### SSL Certificate Errors

**Error**: "SSL certificate verification failed"

**Solutions:**

1. **For self-signed certificates**:
   - In DirectAdmin, uncheck "Verify SSL"

2. **For Let's Encrypt**:
   - Verify certificate is valid:
   ```bash
   docker exec directslave certbot certificates
   ```
   - Check certificate matches domain

3. **Use HTTP instead**:
   - Change port to 2222
   - Uncheck "Use SSL" in DirectAdmin

### Zones Not Replicating

**Problem**: Zones not appearing on DirectSlave

**Check:**

1. **DirectAdmin logs**:
   - Check DirectAdmin error logs for replication errors

2. **DirectSlave logs**:
   ```bash
   docker exec directslave tail -f /usr/local/directslave/log/action.log
   docker exec directslave tail -f /usr/local/directslave/log/error.log
   ```

3. **BIND errors**:
   ```bash
   docker exec directslave tail -f /var/log/named/named.log
   ```

4. **Permissions**:
   ```bash
   docker exec directslave ls -la /etc/namedb/secondary/
   # Should be owned by bind:bind
   ```

5. **Manual trigger**:
   - In DirectAdmin, manually trigger zone sync
   - Navigate to domain → DNS Management → "Sync to cluster"

### DNS Queries Not Working

**Problem**: DNS queries timing out or returning errors

**Check:**

1. **BIND is running**:
   ```bash
   docker exec directslave ps aux | grep named
   docker exec directslave rndc status
   ```

2. **Port 53 accessible**:
   ```bash
   # From external host
   dig @DIRECTSLAVE_IP example.com
   nc -zvu DIRECTSLAVE_IP 53  # UDP
   nc -zv DIRECTSLAVE_IP 53   # TCP
   ```

3. **Zone files exist**:
   ```bash
   docker exec directslave ls -la /etc/namedb/secondary/
   ```

4. **BIND configuration**:
   ```bash
   docker exec directslave named-checkconf /etc/bind/named.conf
   ```

5. **Query BIND directly**:
   ```bash
   docker exec directslave dig @localhost example.com
   ```

## Best Practices

1. **Use HTTPS**: Always use SSL (port 2224) for production
2. **Strong Passwords**: Use strong, unique passwords
3. **IP Restrictions**: Limit access to DirectAdmin IPs only
4. **Monitoring**: Set up availability monitoring
5. **Backups**: Regularly backup DirectSlave volumes
6. **Logging**: Monitor logs for errors and unauthorized access
7. **Updates**: Keep Docker images updated
8. **Documentation**: Document your specific configuration

## Additional Resources

- [DirectAdmin MultiServer Documentation](https://help.directadmin.com/item.php?id=284)
- [DirectSlave Official Site](https://directslave.com)
- [Main README](../README.md)
- [SSL Setup Guide](SSL_SETUP.md)

---

**Need Help?** Check container logs and DirectAdmin logs for specific error messages.
