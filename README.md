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

## Documentation

| Document | Description |
|----------|-------------|
| [Networking Guide](docs/DOCKER_COMPOSE_NETWORKING.md) | Host vs bridge networking modes explained |
| [SSL/TLS Setup](docs/SSL_SETUP.md) | Certificate management and Let's Encrypt configuration |
| [DirectAdmin Integration](docs/DIRECTADMIN_SETUP.md) | Connecting DirectSlave to DirectAdmin master |
| [Deployment Checklist](docs/DEPLOYMENT_CHECKLIST.md) | Step-by-step production deployment guide |
| [Developer Guide](docs/DEVELOPER.md) | Building, upgrading, CI/CD, and contributing |

## Docker Compose Options

Two networking modes are provided as separate docker-compose files. **Host networking is recommended** for production DNS servers due to superior performance and accurate client IP visibility.

| File | Networking | Use Case |
|------|-----------|----------|
| `docker-compose-host.yml` | Host (recommended) | Production - best DNS performance, true client IPs |
| `docker-compose-bridge.yml` | Bridge | Development, testing, or multi-instance setups |

### Quick Start with Host Networking (Recommended)

```bash
cp .env.example .env
# Edit .env with your values (DS_AUTH_KEY, CERTBOT_EMAIL, CERTBOT_DOMAIN)

docker compose -f docker-compose-host.yml build
docker compose -f docker-compose-host.yml up -d
```

### Quick Start with Bridge Networking

```bash
cp .env.example .env
# Edit .env with your values

docker compose -f docker-compose-bridge.yml build
docker compose -f docker-compose-bridge.yml up -d
```

See [docs/DOCKER_COMPOSE_NETWORKING.md](docs/DOCKER_COMPOSE_NETWORKING.md) for a detailed comparison and guidance on choosing a mode.

## Quick Start

### Prerequisites

- Docker 20.10+
- Domain name pointing to your server
- Ports 53 (DNS), 80 (HTTP/Let's Encrypt), 2222, 2224 accessible

### 1. Generate Auth Key

```bash
openssl rand -base64 96
```

Save this value - you'll need it for `DS_AUTH_KEY` below.

### 2. Run the Container

```bash
docker run -d \
  --name directslave \
  --hostname directslave \
  -e DS_HOST="*" \
  -e DS_PORT="2222" \
  -e DS_SSLPORT="2224" \
  -e DS_SSL="on" \
  -e DS_DEBUG="0" \
  -e DS_BACKGROUND="1" \
  -e DS_AUTH_KEY="YOUR_128_CHAR_RANDOM_KEY_HERE" \
  -e CERTBOT_ENABLED="true" \
  -e CERTBOT_EMAIL="admin@yourdomain.com" \
  -e CERTBOT_DOMAIN="dns.yourdomain.com" \
  -e CERTBOT_METHOD="http" \
  -e NAMED_WORKDIR="/etc/namedb/secondary" \
  -e BIND_CONF_PATH="/etc/namedb/secondary/named.conf" \
  -e RETRY_TIME="1200" \
  -e RNDC_PATH="/usr/sbin/rndc" \
  -e NAMED_FORMAT="text" \
  -e DS_UID="53" \
  -e DS_GID="53" \
  -e TZ="UTC" \
  -v directslave_config:/usr/local/directslave/etc \
  -v directslave_logs:/usr/local/directslave/log \
  -v directslave_zones:/etc/namedb/secondary \
  -v letsencrypt:/etc/letsencrypt \
  -p 2222:2222 \
  -p 2224:2224 \
  -p 53:53/udp \
  -p 53:53/tcp \
  -p 80:80 \
  --restart unless-stopped \
  ghcr.io/sq4ind/dockerized-directslave:latest
```

### 3. Set DirectSlave Password

```bash
docker exec -it directslave /usr/local/directslave/bin/directslave --password admin:your-secure-password
```

### 4. Configure DirectAdmin

1. Login to DirectAdmin
2. Go to: **Admin Tools** → **MultiServer Setup**
3. Add server:
   - Host: `dns.yourdomain.com`
   - Port: `2222` (or `2224` for HTTPS)
   - Username: `admin`
   - Password: the password you set above
4. Click **Test Connection** → Should show "connection OK"

See [docs/DIRECTADMIN_SETUP.md](docs/DIRECTADMIN_SETUP.md) for detailed DirectAdmin configuration.

## Environment Variables

| Variable | Required | Default | Example | Description |
|----------|----------|---------|---------|-------------|
| `DS_HOST` | No | `*` | `*` | Bind address (`*` for all interfaces, or specific IP) |
| `DS_PORT` | No | `2222` | `2222` | DirectSlave HTTP port |
| `DS_SSLPORT` | No | `2224` | `2224` | DirectSlave HTTPS port |
| `DS_SSL` | No | `on` | `on` | Enable SSL (`on`/`off`) |
| `DS_DEBUG` | No | `0` | `0` | Debug mode (`0`=off, `1`=on) |
| `DS_BACKGROUND` | No | `1` | `1` | Background mode (managed by entrypoint) |
| `DS_AUTH_KEY` | **Yes** | — | `k8Tj2m...` (128+ chars) | Cookie encryption key for web interface sessions |
| `CERTBOT_ENABLED` | No | `true` | `true` | Enable automatic SSL via Let's Encrypt |
| `CERTBOT_EMAIL` | **Yes*** | — | `admin@yourdomain.com` | Email for Let's Encrypt notifications |
| `CERTBOT_DOMAIN` | **Yes*** | — | `dns.yourdomain.com` | Domain for SSL certificate (must resolve to server) |
| `CERTBOT_METHOD` | No | `http` | `http` | Validation method (HTTP-01) |
| `NAMED_WORKDIR` | No | `/etc/namedb/secondary` | `/etc/namedb/secondary` | Directory for DNS zone files |
| `BIND_CONF_PATH` | No | `/etc/namedb/secondary/named.conf` | `/etc/namedb/secondary/named.conf` | BIND configuration file path |
| `RETRY_TIME` | No | `1200` | `1200` | Zone retry interval in seconds |
| `RNDC_PATH` | No | `/usr/sbin/rndc` | `/usr/sbin/rndc` | Path to rndc binary |
| `NAMED_FORMAT` | No | `text` | `text` | Zone file format (`text`/`binary`) |
| `DS_UID` | No | `53` | `53` | User ID for DirectSlave/BIND processes |
| `DS_GID` | No | `53` | `53` | Group ID for DirectSlave/BIND processes |
| `DIRECTADMIN_IP` | No | — | `192.168.1.100` | Master DirectAdmin server IP (documentation only) |
| `DIRECTADMIN_PORT` | No | `2222` | `2222` | DirectAdmin API port (documentation only) |
| `TZ` | No | `UTC` | `America/New_York` | Container timezone |

> \* Required only when `CERTBOT_ENABLED=true`

## Volumes

Persistent data is stored in named Docker volumes:

| Volume | Container Path | Purpose |
|--------|----------------|---------|
| `directslave_config` | `/usr/local/directslave/etc` | Configuration & authentication |
| `directslave_logs` | `/usr/local/directslave/log` | Application logs |
| `directslave_zones` | `/etc/namedb/secondary` | DNS zone files |
| `letsencrypt` | `/etc/letsencrypt` | SSL certificates |

## Ports

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
- DirectAdmin API password (set via `--password` command)
- SSL certificate key
- SSH key

### Why Is It Critical?

Without a strong `DS_AUTH_KEY`:
- Attackers could forge session cookies
- Unauthorized access to DirectSlave management
- Session hijacking possible

### Requirements

- **Length**: 128+ random characters recommended (64 minimum)
- **Randomness**: Use cryptographically secure random generator
- **Uniqueness**: Different for each installation

### Generate Secure Key

```bash
# Best method (generates 128 chars)
openssl rand -base64 96

# Alternative (generates 64 chars)
openssl rand -base64 48
```

**Important**: 
- Never use example values from documentation
- Keep it secret (don't commit to version control)
- Change it if compromised
- Use different keys for dev/staging/production

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

If you prefer manual certificates, disable Certbot and mount your own:

```bash
docker run -d \
  --name directslave \
  -e CERTBOT_ENABLED="false" \
  -v ./ssl/server.crt:/usr/local/directslave/ssl/server.crt:ro \
  -v ./ssl/server.key:/usr/local/directslave/ssl/server.key:ro \
  ... # other flags as above
  ghcr.io/sq4ind/dockerized-directslave:latest
```

See [docs/SSL_SETUP.md](docs/SSL_SETUP.md) for detailed SSL documentation.

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

# View current users
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

### Restart / Reload

```bash
# Restart container
docker restart directslave

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

```bash
# Fix permissions inside container
docker exec directslave chown -R bind:bind /usr/local/directslave
docker exec directslave chown -R bind:bind /etc/namedb/secondary

# Restart container
docker restart directslave
```

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
# Set restrictive permissions on any env file
chmod 600 .env

# Never commit sensitive values to version control
```

### Third-Party Software Notice

This project downloads and packages DirectSlave (BSD License, copyright Roman Mazur, 2012-2022) from https://directslave.com. We verify binary integrity via MD5 checksum but do **not** take responsibility for DirectSlave's security or functionality. See the [Disclaimer](#disclaimer---third-party-software) section for details.

## Support & Contributing

### Getting Help

- Check the [Troubleshooting](#troubleshooting) section below
- Check [docs/SSL_SETUP.md](docs/SSL_SETUP.md) for SSL issues
- Check [docs/DIRECTADMIN_SETUP.md](docs/DIRECTADMIN_SETUP.md) for integration issues
- Check [docs/DEPLOYMENT_CHECKLIST.md](docs/DEPLOYMENT_CHECKLIST.md) for deployment guidance
- Review DirectSlave logs
- Check Docker container logs
- Validate configuration

### Reporting Issues

When reporting issues, include:
1. Docker version: `docker --version`
2. Container logs: `docker logs directslave`
3. Configuration (sanitized - remove sensitive data)
4. Error messages

### Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

See [docs/DEVELOPER.md](docs/DEVELOPER.md) for build instructions and development workflow.

## For Developers

See [docs/DEVELOPER.md](docs/DEVELOPER.md) for:
- Building the Docker image locally
- DirectSlave version management & upgrading
- Performance tuning
- CI/CD pipeline details

## License

- **This Docker project**: MIT License (see [LICENSE](LICENSE) file)
- **DirectSlave software**: BSD License (copyright Roman Mazur, 2012-2022)

## Disclaimer - Third-Party Software

### DirectSlave Binary

This project includes DirectSlave software downloaded directly from https://directslave.com

**DirectSlave Details:**

| Field | Value |
|-------|-------|
| License | BSD License |
| Copyright | Roman Mazur, 2012-2022 |
| Source | https://directslave.com |
| Contact | roman.mazur@gmail.com |
| Current Version | 3.5.1 |
| MD5 (tar.gz) | `b0ac9946aa2780138cd625663739840a` |

**This Docker project:**
- Downloads DirectSlave from the official source
- Verifies binary integrity using MD5 checksums (see Dockerfile)
- Packages DirectSlave into a Docker container for easier deployment
- Does **NOT** modify the DirectSlave binary or source code
- Does **NOT** take responsibility for DirectSlave's security or functionality
- Does **NOT** warrant DirectSlave's suitability for any particular use case

**Your Responsibility:**

Users are responsible for:
1. **Security Assessment** - Reviewing DirectSlave's security posture independently
2. **Updates** - Keeping DirectSlave updated when new versions are released
3. **License Compliance** - Understanding and complying with DirectSlave's BSD License
4. **Suitability** - Assessing whether DirectSlave meets your security and operational requirements
5. **Issue Reporting** - Reporting DirectSlave bugs to Roman Mazur (roman.mazur@gmail.com), not this project

### Security Scanning Notes

Trivy vulnerability scans are suppressed for DirectSlave binaries (see `.trivyignore`).
This does **not** mean the binaries are vulnerability-free. Scans are suppressed because:
1. DirectSlave is a third-party closed-source binary
2. Trivy cannot analyze it effectively without source code
3. Binary verification via MD5 checksum is our integrity measure

You should **independently verify** DirectSlave's security before using in production.
See [.github/SECURITY.md](.github/SECURITY.md) for full security policy.

## Credits

- **DirectSlave**: Roman Mazur (roman.mazur@gmail.com)
- **Docker Implementation**: sq4ind
- **BIND**: ISC (Internet Systems Consortium)
- **Certbot**: Electronic Frontier Foundation (EFF)
- **Alpine Linux**: Alpine Linux Development Team

## References

- [DirectSlave Official Site](https://directslave.com)
- [DirectAdmin Documentation](https://help.directadmin.com/)
- [BIND Documentation](https://www.isc.org/bind/)
- [Certbot Documentation](https://certbot.eff.org/)
- [Docker Documentation](https://docs.docker.com/)
