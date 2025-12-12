#!/usr/bin/env bash

# Make All Phone DHCP Leases Permanent (Static)
# Run this script to ensure phone IPs survive MikroTik reboots

MIKROTIK_IP="192.168.40.1"
MIKROTIK_USER="admin"
MIKROTIK_PASS='PurpleLemur%420'

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Make Phone Leases PERMANENT${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

SSH_CMD="sshpass -p '${MIKROTIK_PASS}' ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"

# Step 1: Check current status
echo -e "${YELLOW}Checking current phone leases...${NC}"
TOTAL=$(eval "$SSH_CMD" "/ip dhcp-server lease print count-only where comment~\"Android-Phone\"" 2>/dev/null)
echo "  Found: $TOTAL phone leases"
echo ""

# Step 2: Make all phone leases static (permanent)
echo -e "${YELLOW}Making all phone leases STATIC (permanent)...${NC}"
echo ""

RESULT=$(eval "$SSH_CMD" "/ip dhcp-server lease make-static [find comment~\"Android-Phone\"]" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ All phone leases are now STATIC${NC}"
else
    echo -e "${RED}Error: $RESULT${NC}"
    exit 1
fi

echo ""

# Step 3: Verify
echo -e "${YELLOW}Verifying...${NC}"
echo ""

eval "$SSH_CMD" "/ip dhcp-server lease print where comment~\"Android-Phone\"" 2>/dev/null | head -20

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  SUCCESS!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BOLD}What this means:${NC}"
echo ""
echo "✓ All phone DHCP leases are now PERMANENT"
echo "✓ Phone IPs will survive MikroTik reboots"
echo "✓ No more IP shuffling after router restart"
echo ""
echo -e "${YELLOW}IMPORTANT: You still need to reboot phones that have wrong IPs${NC}"
echo "           (making leases static doesn't fix phones with cached wrong IPs)"
echo ""
echo "Run this script:"
echo "  - After adding new phone batches"
echo "  - Before rebooting MikroTik (as prevention)"
echo "  - After MikroTik reboot (to fix any issues)"
echo ""
