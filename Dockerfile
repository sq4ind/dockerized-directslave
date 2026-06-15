# ============================================================
# DirectSlave Docker - Multi-Stage Optimized Build
# ============================================================
# Stage 1: Builder  - Downloads and extracts DirectSlave
# Stage 2: Runtime  - Lean production image
# ============================================================

# Build arguments for DirectSlave version
ARG DIRECTSLAVE_VERSION=3.5.1
ARG DIRECTSLAVE_VARIANT=advanced-all
ARG DIRECTSLAVE_BASE_URL=https://directslave.com/download
ARG DIRECTSLAVE_MD5=""

# ============================================================
# STAGE 1: BUILDER
# Downloads, verifies, and extracts DirectSlave binary
# This stage is discarded - only artifacts are kept
# ============================================================
FROM alpine:3.24 AS builder

# Use ash with pipefail to catch pipe errors (fixes DL4006, SC3009)
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# TARGETARCH is automatically set by Docker BuildKit (amd64, arm64, etc.)
ARG TARGETARCH
ARG DIRECTSLAVE_VERSION
ARG DIRECTSLAVE_VARIANT
ARG DIRECTSLAVE_BASE_URL
ARG DIRECTSLAVE_MD5

RUN apk add --no-cache curl tar

WORKDIR /build

# Download, verify, extract, and select platform-specific binary
RUN DOWNLOAD_URL="${DIRECTSLAVE_BASE_URL}/directslave-${DIRECTSLAVE_VERSION}-${DIRECTSLAVE_VARIANT}.tar.gz" \
    && echo "-> Downloading DirectSlave ${DIRECTSLAVE_VERSION}-${DIRECTSLAVE_VARIANT}..." \
    && curl -fSL -o directslave.tar.gz "${DOWNLOAD_URL}" \
    && if [ -n "${DIRECTSLAVE_MD5}" ]; then \
         echo "-> Verifying MD5 checksum..." ; \
         echo "${DIRECTSLAVE_MD5}  directslave.tar.gz" | md5sum -c - || { \
           echo "ERROR: MD5 verification failed!" ; \
           echo "  Expected: ${DIRECTSLAVE_MD5}" ; \
           echo "  Got:      $(md5sum directslave.tar.gz | cut -d' ' -f1)" ; \
           exit 1 ; \
         } ; \
         echo "-> MD5 verified" ; \
       fi \
    && echo "-> Extracting..." \
    && tar -xzf directslave.tar.gz \
    && rm -f directslave.tar.gz \
    && echo "-> Selecting binary for architecture: ${TARGETARCH}" \
    && case "${TARGETARCH}" in \
         amd64) BINARY="directslave-linux-amd64" ;; \
         arm64) BINARY="directslave-linux-arm" ;; \
         *)     echo "ERROR: Unsupported architecture: ${TARGETARCH}" ; \
                echo "Supported: amd64, arm64" ; \
                echo "Available binaries:" ; \
                ls -la /build/directslave/bin/ ; \
                exit 1 ;; \
       esac \
    && test -f "/build/directslave/bin/${BINARY}" || { \
         echo "ERROR: Binary not found: /build/directslave/bin/${BINARY}" ; \
         echo "Available binaries:" ; \
         ls -la /build/directslave/bin/ ; \
         exit 1 ; \
       } \
    && cp "/build/directslave/bin/${BINARY}" /build/directslave/bin/directslave \
    && chmod +x /build/directslave/bin/directslave \
    && echo "-> DirectSlave ${DIRECTSLAVE_VERSION} ready (${TARGETARCH}: ${BINARY})"

# ============================================================
# STAGE 2: RUNTIME
# Lean production image with only necessary packages
# ============================================================
FROM alpine:3.24

# Use ash with pipefail to catch pipe errors (fixes DL4006, SC3009)
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

LABEL maintainer="DirectSlave Docker Project"
LABEL description="DirectSlave DNS server with BIND and automatic SSL via Certbot"
LABEL version="1.0"

# Install only runtime packages and set up system in a single layer
RUN apk add --no-cache \
      bind \
      bind-tools \
      certbot \
      curl \
      openssl \
      dcron \
      shadow \
      gettext \
      ca-certificates \
    && addgroup -g 53 -S bind 2>/dev/null || true \
    && adduser -u 53 -D -S -H -G bind bind 2>/dev/null || true \
    && mkdir -p \
      /usr/local/directslave/bin \
      /usr/local/directslave/etc \
      /usr/local/directslave/log \
      /usr/local/directslave/run \
      /usr/local/directslave/scripts \
      /usr/local/directslave/ssl \
      /usr/local/directslave/www \
      /etc/namedb/secondary \
      /var/run/named \
      /var/cache/bind \
      /etc/letsencrypt \
      /var/lib/letsencrypt \
      /var/log/named

# Copy only the selected DirectSlave binary from builder (platform-specific)
COPY --from=builder /build/directslave/bin/directslave /usr/local/directslave/bin/directslave
COPY --from=builder /build/directslave/etc/       /usr/local/directslave/etc/
COPY --from=builder /build/directslave/www/       /usr/local/directslave/www/
COPY --from=builder /build/directslave/scripts/   /usr/local/directslave/scripts/

# Copy local configuration templates and scripts
COPY config/directslave.conf.template /usr/local/directslave/etc/directslave.conf.template
COPY scripts/cert-renewal-hook.sh /usr/local/bin/cert-renewal-hook.sh
COPY scripts/validate-config.sh /usr/local/bin/validate-config.sh
COPY entrypoint.sh /entrypoint.sh

# Set permissions in a single layer
RUN chmod +x \
      /entrypoint.sh \
      /usr/local/bin/cert-renewal-hook.sh \
      /usr/local/bin/validate-config.sh \
      /usr/local/directslave/bin/directslave \
    && chown -R bind:bind \
      /usr/local/directslave \
      /etc/namedb/secondary \
      /var/run/named \
      /var/cache/bind \
      /var/log/named

# Expose ports
EXPOSE 2222 2224 53/udp 53/tcp 80

# Persistent volumes
VOLUME ["/usr/local/directslave/etc", "/usr/local/directslave/log", "/etc/namedb/secondary", "/etc/letsencrypt"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -sf http://localhost:2222/ || exit 1

WORKDIR /usr/local/directslave

ENTRYPOINT ["/entrypoint.sh"]
CMD ["directslave"]
