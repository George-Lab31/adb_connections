#!/usr/bin/env bash

# Remove DHCP leases ONLY for currently connected ADB devices
# Safe - doesn't touch other existing static leases

MIKROTIK_IP="192.168.40.1"
MIKROTIK_USER="admin"
MIKROTIK_PASS='PurpleLemur%420'
INTERFACE="eth0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SSH_CMD="sshpass -p '${MIKROTIK_PASS}' ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Remove Leases for Connected Devices${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check ADB
if ! command -v adb &> /dev/null; then
    echo -e "${RED}ERROR: adb not found${NC}"
    exit 1
fi

# Get connected devices
devices=($(adb devices | grep -w "device" | awk '{print $1}'))

if [ ${#devices[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No ADB devices found${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#devices[@]} ADB device(s)${NC}"
echo ""

# Collect MACs
echo "Collecting MAC addresses..."
declare -a mac_addresses

for device in "${devices[@]}"; do
    MAC=$(adb -s "$device" shell cat /sys/class/net/$INTERFACE/address 2>/dev/null | tr -d '\r\n')
    if [ -n "$MAC" ]; then
        echo "  $device → $MAC"
        mac_addresses+=("$MAC")
    fi
done

if [ ${#mac_addresses[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No MACs collected${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}This will remove ONLY leases for these ${#mac_addresses[@]} MACs${NC}"
echo -e "${GREEN}Your other existing phone batches will NOT be affected${NC}"
echo ""
read -p "Continue? (yes/no): " -r
echo ""

if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Remove leases for each MAC
REMOVED=0
NOT_FOUND=0

for MAC in "${mac_addresses[@]}"; do
    LEASE_COUNT=$(eval "$SSH_CMD" "/ip dhcp-server lease print count-only where mac-address=\"$MAC\"" 2>/dev/null)

    if [ "$LEASE_COUNT" -gt 0 ]; then
        echo -n "  Removing $LEASE_COUNT lease(s) for $MAC... "
        eval "$SSH_CMD" "/ip dhcp-server lease remove [find mac-address=\"$MAC\"]" 2>/dev/null
        sleep 0.5

        # Verify removal
        REMAINING=$(eval "$SSH_CMD" "/ip dhcp-server lease print count-only where mac-address=\"$MAC\"" 2>/dev/null)
        if [ "$REMAINING" -eq 0 ]; then
            echo -e "${GREEN}✓${NC}"
            ((REMOVED++))
        else
            echo -e "${RED}✗ ($REMAINING still remain)${NC}"
        fi
    else
        ((NOT_FOUND++))
    fi
done

echo ""
echo -e "${GREEN}✓ Removed leases for $REMOVED MAC(s)${NC}"
if [ $NOT_FOUND -gt 0 ]; then
    echo -e "  ($NOT_FOUND MAC(s) had no existing leases)"
fi
echo ""
echo "You can now run: ${BLUE}./auto_configure_phones.sh <START_IP>${NC}"
echo ""
