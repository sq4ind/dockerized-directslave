# DirectSlave Docker - Dockerized DirectSlave DNS Server

A fully containerized DirectSlave DNS server with automatic SSL certificate management via Let's Encrypt, running on Alpine Linux with BIND DNS server.

## Overview

DirectSlave is a fast and easy slave DNS management system designed to work with DirectAdmin powered servers. This Docker implementation provides:

- **Alpine Linux base** - Minimal, secure, and efficient
- **BIND DNS server** - Industry-standard authoritative DNS
- **Automatic SSL/TLS** - Let's Encrypt certificates via Certbot
- **Easy configuration** - Environment variable based setup
- **Persistent storage** - Volumes for configs, zones, and certificates
- **Health monitoring** - Built-in health checks
- **Production ready** - Graceful shutdown, logging, and error handling

## Architecture

```
┌─────────────────────────────────────────┐
│         Docker Container                │
│                                         │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │  DirectSlave │  │   BIND (named)  │ │
│  │              │  │                 │ │
│  │  HTTP: 2222  │  │   DNS: 53       │ │
│  │  HTTPS: 2224 │  │   UDP/TCP       │ │
│  └──────────────┘  └─────────────────┘ │
│         │                   │           │
│         └───────┬───────────┘           │
│                 │                       │
│         ┌───────▼────────┐              │
│         │  Certbot       │              │
│         │  (Auto SSL)    │              │
│         └────────────────┘              │
└─────────────────────────────────────────┘
          │              │
          │              │
    ┌─────▼────┐   ┌────▼──────┐
    │DirectAdmin│   │DNS Clients│
    │  Master   │   │           │
    └───────────┘   └───────────┘
```

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 1.29+
- Domain name pointing to your server
- Port 53 (DNS), 80 (HTTP), 2222, 2224 accessible

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/yourusername/dockerized-directslave.git
cd dockerized-directslave

# Copy environment template
cp .env.example .env

# Edit .env file with your settings
nano .env
```

### 2. Critical Configuration

Edit `.env` and set these **required** values:

```bash
# CRITICAL: Change to a strong random string (128+ chars)
DS_AUTH_KEY=your-very-long-random-string-here

# Your email for Let's Encrypt notifications
CERTBOT_EMAIL=admin@yourdomain.com

# Your domain name (must point to this server)
CERTBOT_DOMAIN=dns.yourdomain.com

# Enable automatic SSL
CERTBOT_ENABLED=true
```

Generate a strong auth key:
```bash
openssl rand -base64 96
```

### 3. Build and Start

```bash
# Build and start the container
docker-compose up -d

# Watch the logs
docker logs -f directslave
```

### 4. Set DirectSlave Password

```bash
# Set authentication credentials for DirectAdmin
docker exec -it directslave /usr/local/directslave/bin/directslave --password admin:your-secure-password
```

### 5. Configure DirectAdmin

See [DIRECTADMIN_SETUP.md](docs/DIRECTADMIN_SETUP.md) for detailed DirectAdmin configuration.

## Configuration

### Environment Variables

All configuration is done via environment variables in `.env` file. See `.env.example` for complete documentation.

**Core Settings:**
- `DS_HOST` - Bind address (* for all)
- `DS_PORT` - HTTP port (default: 2222)
- `DS_SSLPORT` - HTTPS port (default: 2224)
- `DS_SSL` - Enable SSL (on/off)
- `DS_AUTH_KEY` - **CRITICAL** - Cookie encryption key for DirectSlave web interface (see below)

**SSL Settings:**
- `CERTBOT_ENABLED` - Enable auto SSL (true/false)
- `CERTBOT_EMAIL` - Email for Let's Encrypt
- `CERTBOT_DOMAIN` - Your domain name
- `CERTBOT_METHOD` - Validation method (http)

**DNS Settings:**
- `NAMED_WORKDIR` - Zone file directory
- `BIND_CONF_PATH` - BIND config path
- `RETRY_TIME` - Zone retry interval

### Volumes

Persistent data is stored in named Docker volumes:

| Volume | Purpose | Location |
|--------|---------|----------|
| `directslave_config` | Configuration & auth | `/usr/local/directslave/etc` |
| `directslave_logs` | Application logs | `/usr/local/directslave/log` |
| `directslave_zones` | DNS zone files | `/etc/namedb/secondary` |
| `letsencrypt` | SSL certificates | `/etc/letsencrypt` |

### Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 2222 | TCP | DirectSlave HTTP (DirectAdmin API) |
| 2224 | TCP | DirectSlave HTTPS (Secure API) |
| 53 | UDP/TCP | DNS queries |
| 80 | TCP | Let's Encrypt validation (temporary) |

## Understanding DS_AUTH_KEY

### What is DS_AUTH_KEY?

`DS_AUTH_KEY` is the **cookie encryption key** used by DirectSlave's web interface for session management.

**Purpose:**
- Encrypts session cookies when users log into DirectSlave web interface
- Prevents cookie tampering and session hijacking
- Validates user sessions on each request

**Not the same as:**
- ❌ DirectAdmin API password (set via `--password` command)
- ❌ SSL certificate key
- ❌ SSH key

### Why Is It Critical?

Without a strong `DS_AUTH_KEY`:
- Attackers could forge session cookies
- Unauthorized access to DirectSlave management
- Session hijacking possible
- Security breach risk

### Requirements

- **Length**: 128+ random characters recommended (64 minimum)
- **Randomness**: Use cryptographically secure random generator
- **Uniqueness**: Different for each installation
- **Characters**: Mix of letters, numbers, and symbols

### Generate Secure Key

```bash
# Best method (generates 128 chars)
openssl rand -base64 96

# Alternative (generates 64 chars)
openssl rand -base64 48

# Or use this one-liner
head -c 96 /dev/urandom | base64
```

### Configuration

Set in `.env` file:
```bash
DS_AUTH_KEY=your-generated-random-string-here-128-chars-minimum
```

**Important**: 
- Never use example values from documentation
- Keep it secret (don't commit to version control)
- Change it if compromised
- Use different keys for dev/staging/production

### How It Works

```
User → Logs in → DirectSlave validates credentials
                      ↓
            Creates encrypted cookie using DS_AUTH_KEY
                      ↓
            Cookie sent to browser
                      ↓
Browser → Sends cookie with request
                      ↓
            DirectSlave decrypts with DS_AUTH_KEY
                      ↓
            Validates session → Grants access
```

If `DS_AUTH_KEY` doesn't match or is weak, session validation fails.

## SSL Certificate Management

DirectSlave Docker uses Let's Encrypt for automatic SSL certificates via HTTP-01 validation.

### How It Works

1. **First Start**: Container automatically requests certificate from Let's Encrypt
2. **Validation**: Let's Encrypt verifies domain ownership via HTTP-01 (port 80)
3. **Installation**: Certificate automatically configured in DirectSlave
4. **Auto-Renewal**: Cron job checks daily, renews 30 days before expiry
5. **Reload**: BIND automatically reloaded after renewal

### Requirements

- Port 80 must be accessible from internet
- Domain must point to server IP
- Valid email address for notifications

### Manual Certificate Management

If you prefer manual certificates:

```bash
# Disable Certbot
CERTBOT_ENABLED=false

# Mount your certificates
volumes:
  - ./ssl/server.crt:/usr/local/directslave/ssl/server.crt:ro
  - ./ssl/server.key:/usr/local/directslave/ssl/server.key:ro
```

See [docs/SSL_SETUP.md](docs/SSL_SETUP.md) for detailed SSL documentation.

## DirectAdmin Integration

### On DirectAdmin Server

1. Enable MultiServer feature in DirectAdmin
2. Navigate to: **Server Manager** → **Multi Server Setup**
3. Add new server with:
   - **IP**: Your DirectSlave server IP
   - **Port**: 2222 (or 2224 for HTTPS)
   - **Username**: admin (or custom)
   - **Password**: Password you set with `--password`
4. Test connection

### Test Connection

```bash
# From DirectAdmin, test connection should show:
# "DirectSlave GO/3.x connection OK"
```

See [docs/DIRECTADMIN_SETUP.md](docs/DIRECTADMIN_SETUP.md) for detailed setup guide.

## Common Operations

### View Logs

```bash
# Container logs
docker logs directslave

# DirectSlave action log
docker exec directslave tail -f /usr/local/directslave/log/action.log

# DirectSlave error log
docker exec directslave tail -f /usr/local/directslave/log/error.log

# BIND logs
docker exec directslave tail -f /var/log/named/named.log
```

### Validate Configuration

```bash
docker exec directslave /usr/local/bin/validate-config.sh
```

### Add/Update Authentication

```bash
# Add or update user
docker exec -it directslave /usr/local/directslave/bin/directslave --password username:password

# View current users (if supported)
docker exec directslave cat /usr/local/directslave/etc/passwd
```

### Check DNS Zones

```bash
# List zone files
docker exec directslave ls -la /etc/namedb/secondary/

# Check BIND status
docker exec directslave rndc status

# Test DNS resolution
dig @localhost example.com
```

### Restart Services

```bash
# Restart container (recommended)
docker-compose restart

# Reload BIND only
docker exec directslave rndc reload

# Reload specific zone
docker exec directslave rndc reload example.com
```

### Certificate Management

```bash
# Check certificate status
docker exec directslave certbot certificates

# Force certificate renewal
docker exec directslave certbot renew --force-renewal

# View renewal logs
docker exec directslave cat /usr/local/directslave/log/cert-renewal.log
```

### Backup Data

```bash
# Backup all volumes
docker run --rm \
  -v directslave_config:/config \
  -v directslave_logs:/logs \
  -v directslave_zones:/zones \
  -v letsencrypt:/letsencrypt \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/directslave-backup-$(date +%Y%m%d).tar.gz \
  /config /logs /zones /letsencrypt

# Backup configuration only
docker run --rm \
  -v directslave_config:/config \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/directslave-config-$(date +%Y%m%d).tar.gz /config
```

### Restore Data

```bash
# Restore from backup
docker run --rm \
  -v directslave_config:/config \
  -v directslave_logs:/logs \
  -v directslave_zones:/zones \
  -v letsencrypt:/letsencrypt \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/directslave-backup-YYYYMMDD.tar.gz -C /
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs for errors
docker logs directslave

# Verify environment variables
docker exec directslave env | grep DS_

# Validate configuration
docker exec directslave /usr/local/bin/validate-config.sh
```

### SSL Certificate Issues

**Problem**: Certificate generation fails

**Solutions**:
1. Verify domain points to server: `dig +short yourdomain.com`
2. Check port 80 is accessible: `curl http://yourdomain.com`
3. Verify firewall allows port 80
4. Check Certbot logs: `docker exec directslave cat /var/log/letsencrypt/letsencrypt.log`

**Problem**: Certificate not renewing

**Solutions**:
1. Check cron is running: `docker exec directslave ps | grep cron`
2. Manually test renewal: `docker exec directslave certbot renew --dry-run`
3. Check renewal logs: `docker exec directslave cat /usr/local/directslave/log/cert-renewal.log`

### DirectAdmin Connection Issues

**Problem**: DirectAdmin shows "Connection Failed"

**Solutions**:
1. Verify DirectSlave is running: `docker exec directslave ps aux`
2. Test port accessibility: `telnet your-server-ip 2222`
3. Check authentication: Verify password was set correctly
4. Check DirectSlave logs: `docker exec directslave tail /usr/local/directslave/log/error.log`
5. Verify firewall allows ports 2222/2224

### DNS Not Resolving

**Problem**: DNS queries not working

**Solutions**:
1. Check BIND is running: `docker exec directslave rndc status`
2. Verify zone files exist: `docker exec directslave ls /etc/namedb/secondary/`
3. Check BIND logs: `docker exec directslave tail /var/log/named/named.log`
4. Test locally: `docker exec directslave dig @localhost example.com`
5. Verify port 53 is accessible from internet

### Permission Issues

**Problem**: Permission denied errors

**Solutions**:
```bash
# Fix permissions inside container
docker exec directslave chown -R bind:bind /usr/local/directslave
docker exec directslave chown -R bind:bind /etc/namedb/secondary

# Restart container
docker-compose restart
```

### High Memory Usage

**Solutions**:
```bash
# Check processes
docker exec directslave ps aux --sort=-%mem

# Set memory limits in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 512M
```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more detailed troubleshooting guide.

## Security Considerations

### Best Practices

1. **Strong Authentication Key**: Use 128+ character random string for `DS_AUTH_KEY`
2. **Firewall Rules**: Restrict ports 2222/2224 to DirectAdmin server IP only
3. **Use HTTPS**: Configure DirectAdmin to use port 2224 (HTTPS) instead of 2222
4. **Regular Updates**: Keep Docker images updated
5. **Backup Regularly**: Backup volumes, especially configuration and zones
6. **Monitor Logs**: Regularly review logs for suspicious activity
7. **SSL Certificates**: Keep certificates valid and auto-renewing

### Firewall Configuration Example

```bash
# Allow DNS from anywhere
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT

# Allow HTTP for Let's Encrypt validation
iptables -A INPUT -p tcp --dport 80 -j ACCEPT

# Restrict DirectSlave ports to DirectAdmin server only
iptables -A INPUT -p tcp --dport 2222 -s YOUR_DIRECTADMIN_IP -j ACCEPT
iptables -A INPUT -p tcp --dport 2224 -s YOUR_DIRECTADMIN_IP -j ACCEPT

# Drop all other access to DirectSlave ports
iptables -A INPUT -p tcp --dport 2222 -j DROP
iptables -A INPUT -p tcp --dport 2224 -j DROP
```

### Environment File Security

```bash
# Ensure .env is not in version control
echo ".env" >> .gitignore

# Set restrictive permissions
chmod 600 .env

# Never commit sensitive values
```

## Upgrading

### DirectSlave Version Management

DirectSlave version is controlled via build arguments in `docker-compose.yml`. The default version is **3.5.1**.

#### Check Current Version

```bash
# Check build arguments in docker-compose.yml
grep -A 5 "DIRECTSLAVE_VERSION" docker-compose.yml

# Or check during container build logs
docker logs directslave | grep "DirectSlave.*installation completed"
```

#### Upgrade to New DirectSlave Version

**Step 1**: Find the new version

Visit [DirectSlave Downloads](https://directslave.com/download) and note:
- Version number (e.g., `3.6.0`)
- Variant (e.g., `advanced-all`)
- MD5 checksum (for security verification)

**Step 2**: Update `docker-compose.yml`

Edit the build args section:

```yaml
build:
  context: .
  dockerfile: Dockerfile
  args:
    DIRECTSLAVE_VERSION: "3.6.0"          # New version
    DIRECTSLAVE_VARIANT: "advanced-all"   # Variant
    DIRECTSLAVE_MD5: "abc123..."          # MD5 from download page
```

**Step 3**: Rebuild and restart

```bash
# Stop current container
docker-compose down

# Rebuild with new version (no-cache ensures fresh download)
docker-compose build --no-cache

# Start with new version
docker-compose up -d

# Verify new version installed
docker logs directslave | grep "DirectSlave.*installation completed"
```

**Note**: Your configuration, zones, and certificates are preserved in volumes during upgrades.

#### Version Pinning

The current setup pins DirectSlave to a specific version (default: 3.5.1). This ensures:
- ✅ **Reproducible builds** - Same version every time
- ✅ **No surprises** - Explicit version control
- ✅ **Testable** - Can test specific versions before deploying
- ✅ **Rollback capability** - Can revert to previous version if needed

#### Alternative: Build from Command Line

You can override versions without editing docker-compose.yml:

```bash
docker-compose build \
  --build-arg DIRECTSLAVE_VERSION=3.6.0 \
  --build-arg DIRECTSLAVE_VARIANT=advanced-all \
  --build-arg DIRECTSLAVE_MD5=abc123...
```

#### MD5 Verification

MD5 checksum verification is **highly recommended** for security:

- Ensures downloaded file hasn't been tampered with
- Prevents installation of corrupted files
- Build fails safely if checksum doesn't match

**Find MD5**: Visit https://directslave.com/download and copy the MD5 hash for your version.

**Skip verification** (not recommended): Set `DIRECTSLAVE_MD5: ""` (empty string)

#### Rollback to Previous Version

If a new version has issues:

```bash
# Edit docker-compose.yml back to previous version
# DIRECTSLAVE_VERSION: "3.5.1"

# Rebuild
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Upgrade Docker Base Image

To update Alpine Linux and system packages:

```bash
# Pull latest Alpine base
docker pull alpine:latest

# Rebuild (picks up latest packages)
docker-compose build --no-cache

# Restart
docker-compose down
docker-compose up -d
```

### Version Documentation

For detailed version configuration, see `.build-args.example` file.

## Performance Tuning

### For High Traffic

Edit `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'
      memory: 1G
    reservations:
      cpus: '1.0'
      memory: 512M
```

### For Production DNS

Consider using **host network mode** for better DNS performance:

```yaml
services:
  directslave:
    network_mode: "host"
    # Remove ports section when using host mode
```

**Note**: Host mode reduces isolation but improves DNS query performance.

## CI/CD & Docker Image

### Automated Testing

Every push and pull request triggers the CI pipeline:
- **Hadolint** - Dockerfile best practices validation
- **ShellCheck** - Shell script quality and security checks
- **Trivy** - Container vulnerability scanning (CRITICAL/HIGH)
- **Build verification** - Multi-platform Docker build (amd64 + arm64)

Weekly scheduled scans ensure ongoing security compliance.

### Pre-built Docker Image

Multi-platform images are published to GitHub Container Registry on every release:

```bash
# Pull the latest release
docker pull ghcr.io/sq4ind/dockerized-directslave:latest

# Pull a specific version
docker pull ghcr.io/sq4ind/dockerized-directslave:1.0.0
```

Supported platforms: `linux/amd64`, `linux/arm64`

### Creating a Release

```bash
# Tag and push (CI must pass first)
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

Then create a GitHub Release matching the tag. The publish workflow automatically builds and pushes the multi-platform image to GHCR.

### Security & Dependency Updates

- **Dependabot** monitors Alpine base image and GitHub Actions weekly
- Patch/minor security updates are auto-merged after CI passes
- Major version upgrades require manual review
- See [.github/SECURITY.md](.github/SECURITY.md) for full security policy

---

## Support & Contributing

### Getting Help

- Check [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- Review DirectSlave logs
- Check Docker container logs
- Validate configuration

### Reporting Issues

When reporting issues, include:
1. Docker version: `docker --version`
2. Docker Compose version: `docker-compose --version`
3. Container logs: `docker logs directslave`
4. Configuration (sanitized - remove sensitive data)
5. Error messages

### Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This Docker implementation is provided under the terms specified in the LICENSE file.

DirectSlave itself is copyright Roman Mazur (http://mazur.net.ua/).

## Credits

- **DirectSlave**: Roman Mazur (roman.mazur@gmail.com)
- **Docker Implementation**: [Your Name/Organization]
- **BIND**: ISC (Internet Systems Consortium)
- **Certbot**: Electronic Frontier Foundation (EFF)
- **Alpine Linux**: Alpine Linux Development Team

## References

- [DirectSlave Official Site](https://directslave.com)
- [DirectAdmin Documentation](https://help.directadmin.com/)
- [BIND Documentation](https://www.isc.org/bind/)
- [Certbot Documentation](https://certbot.eff.org/)
- [Docker Documentation](https://docs.docker.com/)

---

**Version**: 1.0  
**Last Updated**: 2026-05-13
