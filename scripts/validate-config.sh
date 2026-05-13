#!/bin/bash
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

echo "=================================="
echo "DirectSlave Configuration Validator"
echo "=================================="
echo ""

# Check if config file exists
if [ ! -f "/usr/local/directslave/etc/directslave.conf" ]; then
    echo -e "${RED}ERROR:${NC} Configuration file not found!"
    exit 1
fi

echo "Checking configuration file..."

# Check critical directories
echo -n "  Checking directories... "
DIRS_OK=true

if [ ! -d "/usr/local/directslave/log" ]; then
    echo -e "${RED}FAILED${NC}"
    echo -e "    ${RED}ERROR:${NC} Log directory does not exist"
    ERRORS=$((ERRORS + 1))
    DIRS_OK=false
fi

if [ ! -d "/usr/local/directslave/run" ]; then
    echo -e "${RED}FAILED${NC}"
    echo -e "    ${RED}ERROR:${NC} Run directory does not exist"
    ERRORS=$((ERRORS + 1))
    DIRS_OK=false
fi

if [ ! -d "/etc/namedb/secondary" ]; then
    echo -e "${RED}FAILED${NC}"
    echo -e "    ${RED}ERROR:${NC} DNS zone directory does not exist"
    ERRORS=$((ERRORS + 1))
    DIRS_OK=false
fi

if [ "$DIRS_OK" = true ]; then
    echo -e "${GREEN}OK${NC}"
fi

# Check permissions
echo -n "  Checking permissions... "
PERMS_OK=true

if [ ! -w "/usr/local/directslave/log" ]; then
    echo -e "${YELLOW}WARNING${NC}"
    echo -e "    ${YELLOW}WARNING:${NC} Log directory is not writable"
    WARNINGS=$((WARNINGS + 1))
    PERMS_OK=false
fi

if [ ! -w "/usr/local/directslave/run" ]; then
    echo -e "${YELLOW}WARNING${NC}"
    echo -e "    ${YELLOW}WARNING:${NC} Run directory is not writable"
    WARNINGS=$((WARNINGS + 1))
    PERMS_OK=false
fi

if [ ! -w "/etc/namedb/secondary" ]; then
    echo -e "${RED}FAILED${NC}"
    echo -e "    ${RED}ERROR:${NC} DNS zone directory is not writable"
    ERRORS=$((ERRORS + 1))
    PERMS_OK=false
fi

if [ "$PERMS_OK" = true ]; then
    echo -e "${GREEN}OK${NC}"
fi

# Check if DirectSlave binary exists and is executable
echo -n "  Checking DirectSlave binary... "
if [ ! -f "/usr/local/directslave/bin/directslave" ]; then
    echo -e "${RED}FAILED${NC}"
    echo -e "    ${RED}ERROR:${NC} DirectSlave binary not found"
    ERRORS=$((ERRORS + 1))
elif [ ! -x "/usr/local/directslave/bin/directslave" ]; then
    echo -e "${RED}FAILED${NC}"
    echo -e "    ${RED}ERROR:${NC} DirectSlave binary is not executable"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}OK${NC}"
fi

# Check BIND/named
echo -n "  Checking BIND... "
if ! command -v named &> /dev/null; then
    echo -e "${RED}FAILED${NC}"
    echo -e "    ${RED}ERROR:${NC} BIND (named) is not installed"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}OK${NC}"
fi

# Check rndc
echo -n "  Checking rndc... "
if ! command -v rndc &> /dev/null; then
    echo -e "${YELLOW}WARNING${NC}"
    echo -e "    ${YELLOW}WARNING:${NC} rndc is not installed (zone reloading may not work)"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}OK${NC}"
fi

# Check SSL configuration if enabled
if grep -q "^ssl on" /usr/local/directslave/etc/directslave.conf 2>/dev/null; then
    echo -n "  Checking SSL configuration... "
    SSL_CERT=$(grep "^ssl_cert" /usr/local/directslave/etc/directslave.conf | awk '{print $2}')
    SSL_KEY=$(grep "^ssl_key" /usr/local/directslave/etc/directslave.conf | awk '{print $2}')
    
    SSL_OK=true
    
    if [ -z "$SSL_CERT" ] || [ ! -f "$SSL_CERT" ]; then
        echo -e "${YELLOW}WARNING${NC}"
        echo -e "    ${YELLOW}WARNING:${NC} SSL certificate file not found: $SSL_CERT"
        WARNINGS=$((WARNINGS + 1))
        SSL_OK=false
    fi
    
    if [ -z "$SSL_KEY" ] || [ ! -f "$SSL_KEY" ]; then
        echo -e "${YELLOW}WARNING${NC}"
        echo -e "    ${YELLOW}WARNING:${NC} SSL key file not found: $SSL_KEY"
        WARNINGS=$((WARNINGS + 1))
        SSL_OK=false
    fi
    
    if [ "$SSL_OK" = true ]; then
        echo -e "${GREEN}OK${NC}"
    fi
fi

echo ""
echo "=================================="
echo "Validation Summary"
echo "=================================="
echo -e "Errors: ${RED}${ERRORS}${NC}"
echo -e "Warnings: ${YELLOW}${WARNINGS}${NC}"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}Configuration validation FAILED${NC}"
    echo "Please fix the errors above before starting DirectSlave"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}Configuration validation completed with warnings${NC}"
    echo "DirectSlave may still work, but please review warnings above"
    exit 0
else
    echo -e "${GREEN}Configuration validation PASSED${NC}"
    echo "DirectSlave is ready to start"
    exit 0
fi
