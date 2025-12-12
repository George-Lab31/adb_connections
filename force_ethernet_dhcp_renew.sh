#!/usr/bin/env bash

# Force Ethernet DHCP Renewal
# Directly restarts the ethernet interface to force DHCP renewal

INTERFACE="eth0"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Forcing ethernet DHCP renewal on all devices...${NC}"
echo ""

# Get connected devices
devices=($(adb devices | grep -w "device" | awk '{print $1}'))

if [ ${#devices[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No ADB devices found${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#devices[@]} device(s)${NC}"
echo ""

for i in "${!devices[@]}"; do
    device="${devices[$i]}"
    echo -e "${YELLOW}Device $((i+1))/${#devices[@]} ($device)${NC}"

    # Method 1: Stop and start the interface
    echo -n "  Stopping eth0... "
    adb -s "$device" shell "su -c 'ifconfig $INTERFACE down'" 2>/dev/null || \
    adb -s "$device" shell "ifconfig $INTERFACE down" 2>/dev/null
    echo -e "${GREEN}✓${NC}"

    sleep 0.5

    echo -n "  Starting eth0... "
    adb -s "$device" shell "su -c 'ifconfig $INTERFACE up'" 2>/dev/null || \
    adb -s "$device" shell "ifconfig $INTERFACE up" 2>/dev/null
    echo -e "${GREEN}✓${NC}"

    sleep 0.5

    # Method 2: Explicitly request DHCP renewal
    echo -n "  Requesting DHCP renewal... "
    adb -s "$device" shell "su -c 'dhcpcd -n $INTERFACE'" 2>/dev/null || \
    adb -s "$device" shell "dhcpcd -n $INTERFACE" 2>/dev/null || \
    echo -e "${YELLOW}(dhcpcd not available)${NC}"
    echo ""
done

echo ""
echo -e "${GREEN}✓ Ethernet DHCP renewal triggered${NC}"
echo ""
echo "Wait 10-15 seconds for phones to get new IPs, then run ./reconnect_adb.sh"
echo ""
