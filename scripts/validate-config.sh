#!/bin/sh
###########################################
# Configuration Validation Script
# Validates DirectSlave configuration
###########################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

printf '%s\n' "=================================="
printf '%s\n' "DirectSlave Configuration Validator"
printf '%s\n' "=================================="
printf '\n'

# Check if config file exists
if [ ! -f "/usr/local/directslave/etc/directslave.conf" ]; then
    printf '%b\n' "${RED}ERROR:${NC} Configuration file not found!"
    exit 1
fi

printf '%s\n' "Checking configuration file..."

# Check critical directories
printf '%s' "  Checking directories... "
DIRS_OK=true

if [ ! -d "/usr/local/directslave/log" ]; then
    printf '%b\n' "${RED}FAILED${NC}"
    printf '%b\n' "    ${RED}ERROR:${NC} Log directory does not exist"
    ERRORS=$((ERRORS + 1))
    DIRS_OK=false
fi

if [ ! -d "/usr/local/directslave/run" ]; then
    printf '%b\n' "${RED}FAILED${NC}"
    printf '%b\n' "    ${RED}ERROR:${NC} Run directory does not exist"
    ERRORS=$((ERRORS + 1))
    DIRS_OK=false
fi

if [ ! -d "/etc/namedb/secondary" ]; then
    printf '%b\n' "${RED}FAILED${NC}"
    printf '%b\n' "    ${RED}ERROR:${NC} DNS zone directory does not exist"
    ERRORS=$((ERRORS + 1))
    DIRS_OK=false
fi

if [ "$DIRS_OK" = true ]; then
    printf '%b\n' "${GREEN}OK${NC}"
fi

# Check permissions
printf '%s' "  Checking permissions... "
PERMS_OK=true

if [ ! -w "/usr/local/directslave/log" ]; then
    printf '%b\n' "${YELLOW}WARNING${NC}"
    printf '%b\n' "    ${YELLOW}WARNING:${NC} Log directory is not writable"
    WARNINGS=$((WARNINGS + 1))
    PERMS_OK=false
fi

if [ ! -w "/usr/local/directslave/run" ]; then
    printf '%b\n' "${YELLOW}WARNING${NC}"
    printf '%b\n' "    ${YELLOW}WARNING:${NC} Run directory is not writable"
    WARNINGS=$((WARNINGS + 1))
    PERMS_OK=false
fi

if [ ! -w "/etc/namedb/secondary" ]; then
    printf '%b\n' "${RED}FAILED${NC}"
    printf '%b\n' "    ${RED}ERROR:${NC} DNS zone directory is not writable"
    ERRORS=$((ERRORS + 1))
    PERMS_OK=false
fi

if [ "$PERMS_OK" = true ]; then
    printf '%b\n' "${GREEN}OK${NC}"
fi

# Check if DirectSlave binary exists and is executable
printf '%s' "  Checking DirectSlave binary... "
if [ ! -f "/usr/local/directslave/bin/directslave" ]; then
    printf '%b\n' "${RED}FAILED${NC}"
    printf '%b\n' "    ${RED}ERROR:${NC} DirectSlave binary not found"
    ERRORS=$((ERRORS + 1))
elif [ ! -x "/usr/local/directslave/bin/directslave" ]; then
    printf '%b\n' "${RED}FAILED${NC}"
    printf '%b\n' "    ${RED}ERROR:${NC} DirectSlave binary is not executable"
    ERRORS=$((ERRORS + 1))
else
    printf '%b\n' "${GREEN}OK${NC}"
fi

# Check BIND/named
printf '%s' "  Checking BIND... "
if ! command -v named > /dev/null 2>&1; then
    printf '%b\n' "${RED}FAILED${NC}"
    printf '%b\n' "    ${RED}ERROR:${NC} BIND (named) is not installed"
    ERRORS=$((ERRORS + 1))
else
    printf '%b\n' "${GREEN}OK${NC}"
fi

# Check rndc
printf '%s' "  Checking rndc... "
if ! command -v rndc > /dev/null 2>&1; then
    printf '%b\n' "${YELLOW}WARNING${NC}"
    printf '%b\n' "    ${YELLOW}WARNING:${NC} rndc is not installed (zone reloading may not work)"
    WARNINGS=$((WARNINGS + 1))
else
    printf '%b\n' "${GREEN}OK${NC}"
fi

# Check SSL configuration if enabled
if grep -q "^ssl on" /usr/local/directslave/etc/directslave.conf 2>/dev/null; then
    printf '%s' "  Checking SSL configuration... "
    SSL_CERT=$(grep "^ssl_cert" /usr/local/directslave/etc/directslave.conf | awk '{print $2}')
    SSL_KEY=$(grep "^ssl_key" /usr/local/directslave/etc/directslave.conf | awk '{print $2}')

    SSL_OK=true

    if [ -z "$SSL_CERT" ] || [ ! -f "$SSL_CERT" ]; then
        printf '%b\n' "${YELLOW}WARNING${NC}"
        printf '%b\n' "    ${YELLOW}WARNING:${NC} SSL certificate file not found: $SSL_CERT"
        WARNINGS=$((WARNINGS + 1))
        SSL_OK=false
    fi

    if [ -z "$SSL_KEY" ] || [ ! -f "$SSL_KEY" ]; then
        printf '%b\n' "${YELLOW}WARNING${NC}"
        printf '%b\n' "    ${YELLOW}WARNING:${NC} SSL key file not found: $SSL_KEY"
        WARNINGS=$((WARNINGS + 1))
        SSL_OK=false
    fi

    if [ "$SSL_OK" = true ]; then
        printf '%b\n' "${GREEN}OK${NC}"
    fi
fi

printf '\n'
printf '%s\n' "=================================="
printf '%s\n' "Validation Summary"
printf '%s\n' "=================================="
printf '%b\n' "Errors: ${RED}${ERRORS}${NC}"
printf '%b\n' "Warnings: ${YELLOW}${WARNINGS}${NC}"
printf '\n'

if [ $ERRORS -gt 0 ]; then
    printf '%b\n' "${RED}Configuration validation FAILED${NC}"
    printf '%s\n' "Please fix the errors above before starting DirectSlave"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    printf '%b\n' "${YELLOW}Configuration validation completed with warnings${NC}"
    printf '%s\n' "DirectSlave may still work, but please review warnings above"
    exit 0
else
    printf '%b\n' "${GREEN}Configuration validation PASSED${NC}"
    printf '%s\n' "DirectSlave is ready to start"
    exit 0
fi
