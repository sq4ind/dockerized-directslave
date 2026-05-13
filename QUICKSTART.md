# DirectSlave Docker - Quick Start Guide

This is a rapid deployment guide for DirectSlave. For detailed documentation, see [README.md](README.md).

## Prerequisites

- Docker 20.10+
- Docker Compose 1.29+
- Domain pointing to your server
- Ports 53, 80, 2222, 2224 accessible

## 5-Minute Setup

### 1. Clone and Configure

```bash
git clone https://github.com/yourusername/dockerized-directslave.git
cd dockerized-directslave
cp .env.example .env
```

### 2. Edit .env

**Required settings:**

```bash
# Generate strong key (run this command):
openssl rand -base64 96

# Then edit .env:
DS_AUTH_KEY=<paste-the-generated-key-here>
CERTBOT_EMAIL=admin@yourdomain.com
CERTBOT_DOMAIN=dns.yourdomain.com
CERTBOT_ENABLED=true
```

### 3. Start Container

```bash
docker-compose up -d
docker logs -f directslave
```

Wait for:
```
[INFO] SSL certificate generated successfully!
[INFO] Starting DirectSlave...
```

### 4. Set Password

```bash
docker exec -it directslave /usr/local/directslave/bin/directslave --password admin:YourSecurePassword123
```

### 5. Configure DirectAdmin

1. Login to DirectAdmin
2. Go to: **Admin Tools** → **MultiServer Setup**
3. Add server:
   - Host: `dns.yourdomain.com`
   - Port: `2222` or `2224` (if SSL)
   - Username: `admin`
   - Password: `YourSecurePassword123`
4. Click **Test Connection** → Should show "connection OK"
5. Save

### 6. Test

```bash
# Check zone replication
docker exec directslave ls /etc/namedb/secondary/

# Test DNS
dig @your-server-ip yourdomain.com
```

## Common Commands

```bash
# View logs
docker logs -f directslave

# Restart
docker-compose restart

# Stop
docker-compose down

# Rebuild
docker-compose build --no-cache

# Backup
docker run --rm -v directslave_config:/config -v $(pwd):/backup alpine tar czf /backup/backup.tar.gz /config

# Check certificates
docker exec directslave certbot certificates

# Validate config
docker exec directslave /usr/local/bin/validate-config.sh
```

## Troubleshooting

**Container won't start:**
```bash
docker logs directslave
```

**SSL certificate failed:**
- Verify domain points to server: `dig +short dns.yourdomain.com`
- Check port 80 is open: `curl http://dns.yourdomain.com`

**DirectAdmin connection failed:**
- Test from DA server: `curl http://your-directslave-ip:2222/`
- Check firewall allows port 2222

**DNS not working:**
```bash
docker exec directslave rndc status
docker exec directslave dig @localhost yourdomain.com
```

## Next Steps

- Read full [README.md](README.md)
- Configure SSL: [docs/SSL_SETUP.md](docs/SSL_SETUP.md)
- DirectAdmin setup: [docs/DIRECTADMIN_SETUP.md](docs/DIRECTADMIN_SETUP.md)
- Set up firewall rules (restrict ports 2222/2224 to DA server)
- Configure monitoring
- Schedule backups

## Support

- Check logs: `docker logs directslave`
- Validate config: `docker exec directslave /usr/local/bin/validate-config.sh`
- Review documentation in `docs/` directory

---

**Production checklist:**
- ✓ Strong DS_AUTH_KEY (128+ chars)
- ✓ SSL enabled and working
- ✓ Firewall configured
- ✓ Monitoring set up
- ✓ Backups scheduled
- ✓ DNS working from internet
