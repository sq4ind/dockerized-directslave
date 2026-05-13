# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly.

### How to Report

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Instead, use [GitHub Security Advisories](../../security/advisories/new) to report privately
3. Or email the maintainers directly (see repository contacts)

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 7 days
- **Fix/Patch**: Best effort, typically within 30 days for critical issues

---

## Security Constraints

### Base Image: Alpine Linux

- **Pinned to**: Major version 3.x (currently 3.23)
- **Policy**: Patch and minor updates are automatically applied via Dependabot
- **Major upgrades** (e.g., 3.x to 4.x): Require manual review and testing
- **Rationale**: Alpine provides minimal attack surface with frequent security patches

### DirectSlave Version

- **Manually controlled** via `docker-compose.yml` build args
- **Version pinning** ensures reproducible and predictable builds
- **MD5 verification**: Enabled in Dockerfile to prevent supply chain attacks
- **Update process**: Manual - check https://directslave.com/download for new releases

### Dependency Management

- **Dependabot** monitors all dependencies weekly (Mondays 06:00 UTC)
- **Auto-merge**: Security patches (patch/minor) are automatically merged after CI passes
- **Manual review required**: Major version bumps
- **GitHub Actions**: Pinned to specific versions, auto-updated for patch/minor

### Container Security

- **Multi-stage build**: Builder stage discarded, only runtime artifacts kept
- **Non-root user**: BIND runs as `bind` user (UID 53)
- **Minimal packages**: Only runtime dependencies installed
- **No shell access**: Production containers should not expose shell
- **Read-only filesystem**: Recommended for production (except volumes)

---

## Supply Chain Security

### Build Provenance

- All published images include **build attestation** (SLSA provenance)
- **SBOM** (Software Bill of Materials) generated and attached to every release
- Verifiable via: `gh attestation verify ghcr.io/sq4ind/dockerized-directslave:latest`

### Image Verification

Pull and verify the image integrity:

```bash
# Verify attestation
gh attestation verify ghcr.io/sq4ind/dockerized-directslave:1.0.0 \
  --owner sq4ind

# Check SBOM (attached to release)
# Download sbom.spdx.json from the GitHub Release assets
```

### Trusted Sources

| Component | Source | License | Verification |
|-----------|--------|---------|--------------|
| Alpine Linux | Docker Hub (official) | MIT | Docker Content Trust |
| DirectSlave | directslave.com | BSD License | MD5 checksum |
| BIND | Alpine APK repository | MPL 2.0 | APK signature verification |
| Certbot | Alpine APK repository | Apache 2.0 | APK signature verification |

---

## Third-Party Software - DirectSlave Binary

### Trust Model

| Component | Source | License | Responsibility |
|-----------|--------|---------|----------------|
| DirectSlave Binary | https://directslave.com | BSD License | Roman Mazur |
| DirectSlave Docker | This repository | MIT License | sq4ind |

### DirectSlave Verification

- **Download Location**: https://directslave.com/download
- **Current Version**: 3.5.1
- **MD5 Checksum**: `b0ac9946aa2780138cd625663739840a`
- **Dockerfile Verification**: MD5 check enabled in builder stage (see `Dockerfile`)

### Why DirectSlave Scans Are Suppressed

Trivy vulnerability scans are suppressed for DirectSlave binaries (see `.trivyignore`) because:

1. DirectSlave is a closed-source pre-compiled Go binary
2. Trivy cannot analyze binary security without source code access
3. We verify download integrity via MD5 checksum instead
4. Users should conduct their own independent security assessment

### Security Responsibility

**What we verify:**
- Binary integrity (MD5 checksum match during Docker build)
- Docker image structure and expected files
- Alpine packages are up-to-date (via Dependabot)
- Entrypoint and helper scripts (via ShellCheck)
- Configuration templates are secure

**What you must verify:**
- DirectSlave's internal security
- DirectSlave's runtime behavior
- DirectSlave's suitability for your use case
- DirectSlave's compliance with your security policies

### Reporting Issues

- **DirectSlave bugs/security**: Contact roman.mazur@gmail.com
- **Docker packaging issues**: Open a GitHub issue in this repository
- **Alpine/BIND/Certbot issues**: Report to respective upstream projects

---

## CI/CD Security

### Automated Checks (on every push/PR)

1. **Hadolint** - Dockerfile best practices
2. **ShellCheck** - Shell script security and quality
3. **Trivy** - Container vulnerability scanning (CRITICAL + HIGH severity)
4. **Build verification** - Multi-platform build integrity

### Scheduled Scans

- **Weekly** (Mondays): Full vulnerability scan of the latest image
- Results uploaded to GitHub Security tab (SARIF format)

### Branch Protection (Recommended)

See [branch-protection-setup.md](branch-protection-setup.md) for configuration instructions.

---

## Best Practices for Users

### Deployment Security

1. **Never use default values** for `DS_AUTH_KEY` - generate a strong 128+ char random key
2. **Restrict network access** to ports 2222/2224 (DirectSlave API) to trusted IPs only
3. **Use HTTPS** (port 2224) for all DirectAdmin communication
4. **Enable SSL** via Certbot or provide your own certificates
5. **Set `.env` permissions** to `600` (owner read/write only)

### Environment Variables

```bash
# Generate strong auth key
openssl rand -base64 96

# Restrict .env file permissions
chmod 600 .env

# Never commit .env to version control (already in .gitignore)
```

### Firewall Rules

```bash
# Allow DNS from anywhere
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT

# Restrict DirectSlave API to DirectAdmin server only
iptables -A INPUT -p tcp --dport 2222 -s YOUR_DIRECTADMIN_IP -j ACCEPT
iptables -A INPUT -p tcp --dport 2224 -s YOUR_DIRECTADMIN_IP -j ACCEPT
iptables -A INPUT -p tcp --dport 2222 -j DROP
iptables -A INPUT -p tcp --dport 2224 -j DROP
```

### Regular Maintenance

- Review Trivy scan results weekly (GitHub Security tab)
- Update DirectSlave version when new releases are available
- Rotate `DS_AUTH_KEY` periodically (requires container restart)
- Back up volumes regularly (especially `/usr/local/directslave/etc` and `/etc/letsencrypt`)
