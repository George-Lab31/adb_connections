#!/usr/bin/env bash

# Force DHCP renewal for second batch of phones (140-159)
# Removes dynamic leases and forces phones to use static reservations

MIKROTIK_IP="192.168.40.1"
MIKROTIK_USER="admin"
MIKROTIK_PASS='PurpleLemur%420'

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Setup SSH
SSH_CMD="sshpass -p '${MIKROTIK_PASS}' ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Fix Second Batch DHCP Leases${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Remove ALL dynamic leases for second batch (MAC pattern e4:66:e5:2e:12:xx)
echo -e "${YELLOW}Removing dynamic leases for second batch...${NC}"
echo ""

# Get all dynamic lease IDs for MAC pattern e4:66:e5:2e:12:
LEASE_IDS=$(eval "$SSH_CMD" "/ip dhcp-server lease print where dynamic && mac-address~\"^E4:66:E5:2E:12\"" 2>/dev/null | grep -oE "^ *[0-9]+" | awk '{print $1}' | tr '\n' ',' | sed 's/,$//')

if [ -n "$LEASE_IDS" ]; then
    echo -e "${YELLOW}Found dynamic leases: $LEASE_IDS${NC}"
    echo -n "Removing... "
    eval "$SSH_CMD" "/ip dhcp-server lease remove $LEASE_IDS" 2>&1
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${GREEN}No dynamic leases found${NC}"
fi

echo ""
echo -e "${YELLOW}Waiting 2 seconds for MikroTik to process...${NC}"
sleep 2
echo ""

# Step 2: Force ethernet restart on all phones to trigger DHCP
echo -e "${YELLOW}Forcing ethernet restart on all phones...${NC}"
echo ""

devices=($(adb devices | grep -w "device" | awk '{print $1}'))

if [ ${#devices[@]} -eq 0 ]; then
    echo -e "${RED}No devices connected${NC}"
    exit 1
fi

for i in "${!devices[@]}"; do
    device="${devices[$i]}"
    echo -n "  Device $((i+1))/${#devices[@]} ($device): "

    # Stop eth0
    adb -s "$device" shell "ifconfig eth0 down" 2>/dev/null
    sleep 0.3

    # Start eth0
    adb -s "$device" shell "ifconfig eth0 up" 2>/dev/null
    sleep 0.3

    echo -e "${GREEN}✓${NC}"
done

echo ""
echo -e "${GREEN}✓ Ethernet restart complete${NC}"
echo ""
echo "Waiting 20 seconds for DHCP renewal..."
sleep 20
echo ""

# Step 3: Check status
echo -e "${BLUE}Checking lease status...${NC}"
echo ""
eval "$SSH_CMD" "/ip dhcp-server lease print where comment~\"Android-Phone\" && address~\"^192.168.40.1[4-5]\"" 2>/dev/null | grep -E "ADDRESS|Android-Phone|bound|waiting" | head -30

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "If phones still have wrong IPs, physically reboot them."
echo "Then run: ./reconnect_adb.sh"
echo ""
