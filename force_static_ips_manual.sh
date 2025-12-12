#!/usr/bin/env bash

# Manually assign static IPs to phones to match MikroTik config
# This bypasses DHCP entirely and sets IPs directly

INTERFACE="eth0"
BASE_IP="192.168.40"
START_IP_SUFFIX=120
GATEWAY="192.168.40.1"
NETMASK="24"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Manually assigning static IPs to match DHCP reservations...${NC}"
echo ""

# Get connected devices
devices=($(adb devices | grep -w "device" | awk '{print $1}'))

if [ ${#devices[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No ADB devices found${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#devices[@]} device(s)${NC}"
echo ""

IP_SUFFIX=$START_IP_SUFFIX

for i in "${!devices[@]}"; do
    device="${devices[$i]}"
    NEW_IP="${BASE_IP}.${IP_SUFFIX}"

    echo -e "${YELLOW}Device $((i+1))/${#devices[@]} ($device) → $NEW_IP${NC}"

    # Flush existing IP
    echo -n "  Flushing old IP... "
    adb -s "$device" shell "ip addr flush dev $INTERFACE" 2>/dev/null
    echo -e "${GREEN}✓${NC}"

    # Set new IP
    echo -n "  Setting new IP $NEW_IP/$NETMASK... "
    adb -s "$device" shell "ip addr add $NEW_IP/$NETMASK dev $INTERFACE" 2>/dev/null
    echo -e "${GREEN}✓${NC}"

    # Set default route
    echo -n "  Setting gateway $GATEWAY... "
    adb -s "$device" shell "ip route add default via $GATEWAY dev $INTERFACE" 2>/dev/null
    echo -e "${GREEN}✓${NC}"

    echo ""

    IP_SUFFIX=$((IP_SUFFIX + 1))
done

echo -e "${GREEN}✓ IP assignment complete!${NC}"
echo ""
echo "Wait 5-10 seconds, then run ./reconnect_adb.sh to reconnect to new IPs"
echo ""
