#!/usr/bin/env bash

# Force DHCP Renewal on all connected Android devices
# This script toggles airplane mode to force phones to renew DHCP leases

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Force DHCP Renewal via Airplane Mode${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if adb is available
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

echo -e "${GREEN}Found ${#devices[@]} device(s)${NC}"
echo ""

echo -e "${YELLOW}Enabling airplane mode on all devices...${NC}"
for i in "${!devices[@]}"; do
    device="${devices[$i]}"
    echo -n "  Device $((i+1))/${#devices[@]} ($device)... "
    adb -s "$device" shell cmd connectivity airplane-mode enable &>/dev/null
    echo -e "${GREEN}✓${NC}"
done

echo ""
echo -e "${YELLOW}Waiting 3 seconds...${NC}"
sleep 3
echo ""

echo -e "${YELLOW}Disabling airplane mode on all devices...${NC}"
for i in "${!devices[@]}"; do
    device="${devices[$i]}"
    echo -n "  Device $((i+1))/${#devices[@]} ($device)... "
    adb -s "$device" shell cmd connectivity airplane-mode disable &>/dev/null
    echo -e "${GREEN}✓${NC}"
done

echo ""
echo -e "${GREEN}✓ DHCP renewal triggered on all devices${NC}"
echo ""
echo "Phones will now request new DHCP leases from the router."
echo "Wait 10-20 seconds, then run ./reconnect_adb.sh to reconnect."
echo ""
