# Developer Guide

This document covers building, upgrading, and developing the DirectSlave Docker image locally.

For usage instructions, see [README.md](README.md).

## Building the Image Locally

### Prerequisites

- Docker 20.10+
- Docker Compose 1.29+ (optional)

### Build with Docker

```bash
docker build -t directslave .
```

### Build with Docker Compose

```bash
docker-compose build
```

The `docker-compose.yml` includes build arguments for version control:

```yaml
build:
  context: .
  dockerfile: Dockerfile
  args:
    DIRECTSLAVE_VERSION: "3.5.1"
    DIRECTSLAVE_VARIANT: "advanced-all"
    DIRECTSLAVE_BASE_URL: "https://directslave.com/download"
    DIRECTSLAVE_MD5: ""
```

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `DIRECTSLAVE_VERSION` | `3.5.1` | DirectSlave version to download |
| `DIRECTSLAVE_VARIANT` | `advanced-all` | DirectSlave variant |
| `DIRECTSLAVE_BASE_URL` | `https://directslave.com/download` | Download base URL |
| `DIRECTSLAVE_MD5` | `""` | MD5 checksum for verification (empty = skip) |

See `.build-args.example` for more details.

## DirectSlave Version Management

### Check Current Version

```bash
# From build args in docker-compose.yml
grep -A 5 "DIRECTSLAVE_VERSION" docker-compose.yml

# From container logs
docker logs directslave | grep "DirectSlave.*installation completed"
```

### Upgrade to New Version

**Step 1**: Find the new version at [DirectSlave Downloads](https://directslave.com/download). Note:
- Version number (e.g., `3.6.0`)
- Variant (e.g., `advanced-all`)
- MD5 checksum (for security verification)

**Step 2**: Update `docker-compose.yml` build args:

```yaml
build:
  args:
    DIRECTSLAVE_VERSION: "3.6.0"
    DIRECTSLAVE_VARIANT: "advanced-all"
    DIRECTSLAVE_MD5: "abc123..."
```

**Step 3**: Rebuild and restart:

```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

Your configuration, zones, and certificates are preserved in volumes during upgrades.

### Override Version from Command Line

```bash
docker-compose build \
  --build-arg DIRECTSLAVE_VERSION=3.6.0 \
  --build-arg DIRECTSLAVE_VARIANT=advanced-all \
  --build-arg DIRECTSLAVE_MD5=abc123...
```

### Rollback to Previous Version

```bash
# Edit docker-compose.yml back to previous version, then:
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### MD5 Verification

MD5 checksum verification is **highly recommended** for security:
- Ensures downloaded file hasn't been tampered with
- Prevents installation of corrupted files
- Build fails safely if checksum doesn't match

Find MD5 values at https://directslave.com/download.

To skip verification (not recommended): set `DIRECTSLAVE_MD5: ""` (empty string).

## Upgrade Docker Base Image

To update Alpine Linux and system packages:

```bash
docker pull alpine:latest
docker-compose build --no-cache
docker-compose down && docker-compose up -d
```

## Performance Tuning

### Resource Limits

For high traffic, add resource limits to `docker-compose.yml`:

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

### Host Network Mode

For production DNS with better query performance:

```yaml
services:
  directslave:
    network_mode: "host"
    # Remove the ports section when using host mode
```

**Note**: Host mode reduces isolation but improves DNS query performance.

## CI/CD Pipeline

### Automated Testing

Every push and pull request triggers:
- **Hadolint** - Dockerfile best practices validation
- **ShellCheck** - Shell script quality and security checks
- **Trivy** - Container vulnerability scanning (CRITICAL/HIGH)
- **Build verification** - Multi-platform Docker build (amd64 + arm64)

Weekly scheduled scans ensure ongoing security compliance.

### Publishing Docker Images

Multi-platform images are published to GitHub Container Registry on every release.

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

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly (run the CI checks locally if possible)
5. Submit a pull request

### Running Checks Locally

```bash
# Lint Dockerfile
hadolint Dockerfile

# Lint shell scripts
shellcheck entrypoint.sh scripts/*.sh

# Build image
docker-compose build

# Run container and test
docker-compose up -d
docker logs -f directslave
```
