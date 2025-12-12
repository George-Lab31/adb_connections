#!/usr/bin/env bash

# Fix a single phone that has wrong IP

MIKROTIK_IP="192.168.40.1"
MIKROTIK_USER="admin"
MIKROTIK_PASS='PurpleLemur%420'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo "Usage: $0 <CURRENT_IP>"
    echo ""
    echo "Example: $0 192.168.40.19"
    echo ""
    echo "This will:"
    echo "  1. Get MAC address from phone at CURRENT_IP"
    echo "  2. Show what IP that MAC should have (from MikroTik)"
    echo "  3. Instruct you to reboot the phone"
    exit 1
fi

CURRENT_IP="$1"
INTERFACE="eth0"

SSH_CMD="sshpass -p '${MIKROTIK_PASS}' ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Fix Single Phone IP${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get MAC from phone
echo "Getting MAC address from phone at $CURRENT_IP..."
MAC=$(adb -s "$CURRENT_IP:5555" shell cat /sys/class/net/$INTERFACE/address 2>/dev/null | tr -d '\r\n')

if [ -z "$MAC" ]; then
    echo -e "${RED}ERROR: Could not connect to phone at $CURRENT_IP${NC}"
    echo "Make sure ADB is connected: adb connect $CURRENT_IP:5555"
    exit 1
fi

echo -e "${GREEN}✓ MAC: $MAC${NC}"
echo ""

# Check MikroTik for static lease
echo "Checking MikroTik for static lease..."
LEASE_INFO=$(eval "$SSH_CMD" "/ip dhcp-server lease print detail where mac-address=\"$MAC\" and !dynamic" 2>/dev/null)

if [ -z "$LEASE_INFO" ]; then
    echo -e "${RED}✗ No static lease found for this MAC${NC}"
    echo ""
    echo "This phone has no static reservation on MikroTik."
    echo "Run: ${BLUE}./auto_configure_phones.sh <START_IP>${NC} to create one"
    exit 1
fi

# Extract assigned IP
ASSIGNED_IP=$(echo "$LEASE_INFO" | grep "address=" | sed 's/.*address=\([0-9.]*\).*/\1/')

echo -e "${GREEN}✓ Static lease exists${NC}"
echo ""
echo -e "${BOLD}Current IP:  ${RED}$CURRENT_IP${NC} ${BOLD}(wrong)${NC}"
echo -e "${BOLD}Should be:   ${GREEN}$ASSIGNED_IP${NC} ${BOLD}(configured in MikroTik)${NC}"
echo ""

if [ "$CURRENT_IP" == "$ASSIGNED_IP" ]; then
    echo -e "${GREEN}✓ Phone already has correct IP!${NC}"
    exit 0
fi

# Check if there's a dynamic lease at current IP
DYNAMIC_AT_CURRENT=$(eval "$SSH_CMD" "/ip dhcp-server lease print count-only where address=\"$CURRENT_IP\" and dynamic" 2>/dev/null)

if [ "$DYNAMIC_AT_CURRENT" -gt 0 ]; then
    echo -e "${YELLOW}Found dynamic lease at $CURRENT_IP${NC}"
    echo -n "Removing dynamic lease... "
    eval "$SSH_CMD" "/ip dhcp-server lease remove [find address=\"$CURRENT_IP\" and dynamic]" 2>/dev/null
    echo -e "${GREEN}✓${NC}"
    echo ""
fi

echo -e "${BOLD}${RED}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}║  ACTION REQUIRED: REBOOT THIS PHONE           ║${NC}"
echo -e "${BOLD}${RED}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo "Steps:"
echo "  1. ${RED}POWER OFF${NC} the phone at $CURRENT_IP"
echo "  2. Wait 10 seconds"
echo "  3. ${GREEN}POWER ON${NC} the phone"
echo "  4. Wait 1 minute for DHCP"
echo "  5. Reconnect: ${BLUE}adb connect $ASSIGNED_IP:5555${NC}"
echo ""
echo -e "${YELLOW}WHY: Android caches DHCP leases. Only a physical reboot clears it.${NC}"
echo ""
