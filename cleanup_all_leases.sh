#!/usr/bin/env bash

# Cleanup All DHCP Leases - Use this to reset before running auto_configure_phones.sh

MIKROTIK_IP="192.168.40.1"
MIKROTIK_USER="admin"
MIKROTIK_PASS='PurpleLemur%420'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SSH_CMD="sshpass -p '${MIKROTIK_PASS}' ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Cleanup All DHCP Leases${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${RED}⚠️  WARNING: NUCLEAR OPTION${NC}"
echo -e "${RED}This will remove ALL static and dynamic leases!${NC}"
echo -e "${RED}Including existing phone batches (120-139, 140-159, etc.)${NC}"
echo ""
echo -e "${YELLOW}Only use this if:${NC}"
echo "  1. You want to completely reconfigure from scratch"
echo "  2. The main script keeps failing to remove specific leases"
echo "  3. You're willing to reconfigure ALL phones"
echo ""

# Count current leases
STATIC_COUNT=$(eval "$SSH_CMD" "/ip dhcp-server lease print count-only where !dynamic" 2>/dev/null)
DYNAMIC_COUNT=$(eval "$SSH_CMD" "/ip dhcp-server lease print count-only where dynamic" 2>/dev/null)

echo "Current leases:"
echo "  Static:  $STATIC_COUNT"
echo "  Dynamic: $DYNAMIC_COUNT"
echo ""

if [ "$STATIC_COUNT" -eq 0 ] && [ "$DYNAMIC_COUNT" -eq 0 ]; then
    echo -e "${GREEN}✓ No leases to clean${NC}"
    exit 0
fi

echo -e "${YELLOW}This will remove ALL DHCP leases (static and dynamic)${NC}"
read -p "Continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Remove all dynamic leases
if [ "$DYNAMIC_COUNT" -gt 0 ]; then
    echo -n "Removing $DYNAMIC_COUNT dynamic leases... "
    eval "$SSH_CMD" "/ip dhcp-server lease remove [find dynamic]" 2>&1 >/dev/null
    echo -e "${GREEN}✓${NC}"
fi

# Remove all static leases
if [ "$STATIC_COUNT" -gt 0 ]; then
    echo -n "Removing $STATIC_COUNT static leases... "
    eval "$SSH_CMD" "/ip dhcp-server lease remove [find !dynamic]" 2>&1 >/dev/null
    echo -e "${GREEN}✓${NC}"
fi

sleep 2

# Verify cleanup
REMAINING=$(eval "$SSH_CMD" "/ip dhcp-server lease print count-only" 2>/dev/null)

echo ""
if [ "$REMAINING" -eq 0 ]; then
    echo -e "${GREEN}✓ All leases removed successfully${NC}"
    echo ""
    echo "You can now run: ${BLUE}./auto_configure_phones.sh <START_IP>${NC}"
else
    echo -e "${YELLOW}⚠ Warning: $REMAINING lease(s) still remain${NC}"
    echo "You may need to remove them manually via MikroTik web interface"
fi
echo ""
