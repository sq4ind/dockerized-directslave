# Docker Compose Networking Guide

This guide explains the two networking modes available for DirectSlave Docker and helps you choose the right one for your deployment.

## Table of Contents

- [Overview](#overview)
- [Host Networking (Recommended)](#host-networking-recommended)
- [Bridge Networking](#bridge-networking)
- [Comparison](#comparison)
- [Choosing the Right Mode](#choosing-the-right-mode)
- [Usage](#usage)
- [Switching Between Modes](#switching-between-modes)
- [Troubleshooting](#troubleshooting)

## Overview

DirectSlave Docker provides two docker-compose files with different networking configurations:

| File | Mode | Best For |
|------|------|----------|
| `docker-compose-host.yml` | Host | Production DNS servers, best performance |
| `docker-compose-bridge.yml` | Bridge | Development, testing, multi-instance setups |

## Host Networking (Recommended)

**File:** `docker-compose-host.yml`

In host networking mode, the container shares the host's network namespace directly. There is no network isolation between the container and the host.

### How It Works

```
┌─────────────────────────────────────────────────┐
│                  Host Machine                    │
│                                                 │
│   Host Network Stack (shared with container)    │
│   ┌──────────────────────────────────────────┐  │
│   │  :53/udp  :53/tcp  :80  :2222  :2224    │  │
│   └──────────────────────────────────────────┘  │
│          │         │      │     │       │       │
│   ┌──────▼─────────▼──────▼─────▼───────▼───┐  │
│   │         DirectSlave Container            │  │
│   │   BIND (named)  │  DirectSlave  │ Certbot│  │
│   └──────────────────────────────────────────┘  │
│                                                 │
└─────────────────────────────────────────────────┘
```

### Advantages

- **Best performance** - No NAT/iptables overhead for DNS queries
- **True source IPs** - Container sees actual client IPs (important for DNS ACLs)
- **Simpler firewall** - No Docker-managed iptables chains; your host firewall rules apply directly
- **Lower latency** - Critical for high-volume DNS query handling
- **EDNS Client Subnet** - Works correctly without additional configuration

### Disadvantages

- **No isolation** - Container processes bind directly to host interfaces
- **Port conflicts** - Fails if ports 53, 80, 2222, or 2224 are already in use on host
- **Single instance** - Cannot run multiple DirectSlave containers on the same host
- **Linux only** - Host networking is not supported on Docker Desktop for macOS/Windows

### Configuration

```yaml
services:
  directslave:
    network_mode: "host"
    # No 'ports' section needed - services bind directly to host
    # No 'networks' section needed
```

### Prerequisites

Ensure these ports are free on the host before starting:

```bash
# Check for port conflicts
ss -tlnp | grep -E ':(53|80|2222|2224)\s'

# If systemd-resolved occupies port 53 (common on Ubuntu):
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

## Bridge Networking

**File:** `docker-compose-bridge.yml`

In bridge mode, Docker creates an isolated network and uses NAT (iptables) to forward traffic from host ports to container ports.

### How It Works

```
┌───────────────────────────────────────────────────────┐
│                    Host Machine                        │
│                                                       │
│   Host Network Stack                                  │
│   ┌────────────────────────────────────────────────┐  │
│   │  :53/udp  :53/tcp  :80  :2222  :2224          │  │
│   └─────┬────────┬───────┬────┬───────┬────────────┘  │
│         │  NAT   │       │    │       │               │
│   ┌─────▼────────▼───────▼────▼───────▼────────────┐  │
│   │         Docker Bridge Network                   │  │
│   │         (172.17.0.0/16 or custom)               │  │
│   │                                                 │  │
│   │   ┌─────────────────────────────────────────┐   │  │
│   │   │      DirectSlave Container              │   │  │
│   │   │  172.17.0.x                             │   │  │
│   │   │  BIND (named) │ DirectSlave │ Certbot   │   │  │
│   │   └─────────────────────────────────────────┘   │  │
│   └─────────────────────────────────────────────────┘  │
│                                                       │
└───────────────────────────────────────────────────────┘
```

### Advantages

- **Network isolation** - Container has its own network namespace
- **Port flexibility** - Remap ports (e.g., host 5353 to container 53)
- **Multi-instance** - Run multiple DirectSlave containers with different port mappings
- **Cross-platform** - Works on Linux, macOS (Docker Desktop), and Windows (Docker Desktop)
- **Standard Docker** - Familiar model for most Docker users

### Disadvantages

- **NAT overhead** - Slight performance penalty for every packet (iptables traversal)
- **Source IP masking** - Container may see Docker gateway IP instead of true client IP
- **Docker iptables** - Docker inserts its own firewall rules, potentially bypassing host firewall (UFW/firewalld)
- **DNS performance** - Higher latency compared to host mode under heavy query loads

### Configuration

```yaml
services:
  directslave:
    ports:
      - "2222:2222"
      - "2224:2224"
      - "53:53/udp"
      - "53:53/tcp"
      - "80:80"
```

### Docker and Firewall Interaction

When using bridge mode, Docker adds its own iptables rules that may bypass your host firewall (e.g., UFW, firewalld). To prevent this:

```bash
# /etc/docker/daemon.json
{
  "iptables": false
}
```

**Warning**: Disabling Docker iptables management means you must manually configure NAT rules. This is an advanced setup. See [Docker documentation on iptables](https://docs.docker.com/network/iptables/) for details.

## Comparison

| Feature | Host Mode | Bridge Mode |
|---------|-----------|-------------|
| **Performance** | Best (no NAT) | Good (NAT overhead) |
| **DNS query latency** | Lowest | Slightly higher |
| **True client IPs** | Yes | No (sees gateway IP) |
| **Network isolation** | None | Full |
| **Port remapping** | No | Yes |
| **Multiple instances** | No | Yes |
| **Firewall simplicity** | Simple (host rules apply) | Complex (Docker iptables) |
| **Cross-platform** | Linux only | All platforms |
| **Port conflict risk** | Higher | Lower |
| **Setup complexity** | Simpler (fewer config lines) | Standard |

## Choosing the Right Mode

### Use Host Networking When:

- Running a **production DNS server** that handles real query traffic
- You need **accurate client source IPs** in BIND logs/ACLs
- You want the **lowest possible query latency**
- You have **dedicated ports** available (53, 80, 2222, 2224)
- You're running on **Linux** (not Docker Desktop)
- You run **one DirectSlave instance** per host

### Use Bridge Networking When:

- Running in **development or testing** environments
- You need to **remap ports** (e.g., avoid conflicts with existing services)
- You want **network isolation** between container and host
- You're running on **macOS or Windows** (Docker Desktop)
- You need **multiple DirectSlave instances** on the same host
- You prefer **standard Docker networking** practices

## Usage

### Host Mode

```bash
# Build
docker compose -f docker-compose-host.yml build

# Start
docker compose -f docker-compose-host.yml up -d

# Stop
docker compose -f docker-compose-host.yml down

# View logs
docker compose -f docker-compose-host.yml logs -f
```

### Bridge Mode

```bash
# Build
docker compose -f docker-compose-bridge.yml build

# Start
docker compose -f docker-compose-bridge.yml up -d

# Stop
docker compose -f docker-compose-bridge.yml down

# View logs
docker compose -f docker-compose-bridge.yml logs -f
```

### Using an Alias (Optional)

To avoid typing the filename every time, set a shell alias:

```bash
# Add to ~/.bashrc or ~/.zshrc
alias dc-directslave='docker compose -f docker-compose-host.yml'

# Then use:
dc-directslave up -d
dc-directslave logs -f
dc-directslave down
```

## Switching Between Modes

### From Bridge to Host

1. Stop the bridge deployment:
   ```bash
   docker compose -f docker-compose-bridge.yml down
   ```

2. Verify ports are free:
   ```bash
   ss -tlnp | grep -E ':(53|80|2222|2224)\s'
   ```

3. Start with host networking:
   ```bash
   docker compose -f docker-compose-host.yml up -d
   ```

Volumes are shared between both configurations, so all data (zones, certificates, config) is preserved.

### From Host to Bridge

1. Stop the host deployment:
   ```bash
   docker compose -f docker-compose-host.yml down
   ```

2. Start with bridge networking:
   ```bash
   docker compose -f docker-compose-bridge.yml up -d
   ```

## Troubleshooting

### Port Already in Use (Host Mode)

```
Error: bind: address already in use
```

**Solution**: Identify and stop the conflicting service:
```bash
# Find what's using port 53
ss -tlnp | grep ':53\s'
lsof -i :53

# Common culprit: systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Update /etc/resolv.conf to use external DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
```

### Cannot Reach Container (Bridge Mode)

```bash
# Verify port mappings are active
docker port directslave

# Check Docker iptables rules
sudo iptables -t nat -L DOCKER -n

# Test from host
curl http://localhost:2222/
dig @localhost example.com
```

### DNS Queries Showing Wrong Source IP (Bridge Mode)

This is expected behavior in bridge mode. The container sees the Docker gateway IP (e.g., 172.17.0.1) as the source for all external queries.

**Solutions**:
1. Switch to host networking mode (recommended for production)
2. Use Docker's `--userland-proxy=false` to preserve source IPs for TCP (not UDP)

### Container Health Check Failing

```bash
# Check if DirectSlave is actually listening
docker exec directslave curl -f http://localhost:2222/

# Check process status
docker exec directslave ps aux | grep directslave

# Review startup logs
docker logs directslave
```

### Performance Issues Under Heavy Load

If you experience high latency or dropped DNS queries:

1. **Switch to host networking** - Eliminates NAT overhead
2. **Increase file descriptors**:
   ```yaml
   services:
     directslave:
       ulimits:
         nofile:
           soft: 65536
           hard: 65536
   ```
3. **Tune kernel parameters** (host mode):
   ```bash
   sysctl -w net.core.rmem_max=8388608
   sysctl -w net.core.wmem_max=8388608
   ```

## Port Reference

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 53 | UDP | BIND | DNS queries (primary) |
| 53 | TCP | BIND | DNS queries (large responses, zone transfers) |
| 80 | TCP | Certbot | Let's Encrypt HTTP-01 validation |
| 2222 | TCP | DirectSlave | HTTP API (DirectAdmin communication) |
| 2224 | TCP | DirectSlave | HTTPS API (secure DirectAdmin communication) |

## Further Reading

- [Docker Networking Overview](https://docs.docker.com/network/)
- [Docker Host Networking](https://docs.docker.com/network/drivers/host/)
- [Docker Bridge Networking](https://docs.docker.com/network/drivers/bridge/)
- [Docker and iptables](https://docs.docker.com/network/iptables/)
- [BIND Performance Tuning](https://www.isc.org/docs/)
