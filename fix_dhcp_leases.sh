#!/usr/bin/env bash

# Fix DHCP Leases - Remove all Galaxy Z Flip4 leases and reconfigure
# This script cleans up conflicting leases and properly assigns IPs 192.168.40.120-139

# Configuration
MIKROTIK_IP="192.168.40.1"
MIKROTIK_USER="admin"
MIKROTIK_PASS='PurpleLemur%420'
START_IP="192.168.40.120"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DHCP Lease Cleanup and Reconfiguration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Setup SSH command
if ! command -v sshpass &> /dev/null; then
    SSH_CMD="ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"
else
    SSH_CMD="sshpass -p '${MIKROTIK_PASS}' ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"
fi

# Test connection
echo -e "${YELLOW}Testing MikroTik connection...${NC}"
if eval "$SSH_CMD" "system resource print" &>/dev/null; then
    echo -e "${GREEN}✓ Connected to MikroTik${NC}"
else
    echo -e "${RED}✗ Failed to connect to MikroTik${NC}"
    exit 1
fi
echo ""

# Step 1: Remove ALL Galaxy Z Flip4 leases
echo -e "${YELLOW}Step 1: Removing all existing Galaxy Z Flip4 leases...${NC}"
echo ""

# Remove by hostname pattern
echo -n "  Removing leases with hostname 'Galaxy-Z-Flip4'... "
RESULT=$(eval "$SSH_CMD" "ip dhcp-server lease remove [find host-name=\"Galaxy-Z-Flip4\"]" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ ${RESULT}${NC}"
fi

# Remove by comment pattern (Android-Phone-*)
echo -n "  Removing leases with comment 'Android-Phone-'... "
RESULT=$(eval "$SSH_CMD" "ip dhcp-server lease remove [find comment~\"Android-Phone-\"]" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ ${RESULT}${NC}"
fi

# Remove by MAC address pattern (E4:66:E5:2E:14:*)
echo -n "  Removing leases with MAC pattern E4:66:E5:2E:14:*... "
RESULT=$(eval "$SSH_CMD" "ip dhcp-server lease remove [find mac-address~\"^E4:66:E5:2E:14\"]" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ ${RESULT}${NC}"
fi

echo ""
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

# Step 2: Wait a moment for MikroTik to process the removals
echo -e "${YELLOW}Waiting for MikroTik to process removals...${NC}"
sleep 2
echo ""

# Step 3: Verify cleanup
echo -e "${YELLOW}Verifying cleanup...${NC}"
REMAINING=$(eval "$SSH_CMD" "ip dhcp-server lease print count-only where host-name=\"Galaxy-Z-Flip4\"" 2>/dev/null)
echo "Remaining Galaxy-Z-Flip4 leases: ${REMAINING:-0}"
echo ""

# Step 4: Run the auto DHCP script
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Step 2: Reconfiguring DHCP Leases${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

./mikrotik_auto_dhcp.sh "$MIKROTIK_IP" "$MIKROTIK_USER" "$MIKROTIK_PASS" "$START_IP"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Fix Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Force phones to renew DHCP (airplane mode on/off or run toggle script)"
echo "  2. Wait 10-20 seconds for phones to get new IPs"
echo "  3. Run ./reconnect_adb.sh to reconnect via new IPs"
echo ""
