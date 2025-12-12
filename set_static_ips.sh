#!/usr/bin/env bash

# Static IP Assignment Script for Multiple ADB Devices
# Configuration
END_IP="192.168.40.220"
GATEWAY="192.168.40.1"
DNS="8.8.8.8"
INTERFACE="eth0"
NETMASK="255.255.255.0"
PREFIX_LENGTH="24"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ADB Static IP Assignment Script${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Prompt for starting IP
read -p "Enter the starting IP address (e.g., 192.168.40.120): " START_IP

# Validate IP format
if ! [[ $START_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}ERROR: Invalid IP address format${NC}"
    exit 1
fi

echo ""

# Check if adb is installed
if ! command -v adb &> /dev/null; then
    echo -e "${RED}ERROR: adb is not installed or not in PATH${NC}"
    exit 1
fi

# Get list of connected devices
echo -e "${YELLOW}Detecting connected ADB devices...${NC}"
devices=($(adb devices | grep -w "device" | awk '{print $1}'))

if [ ${#devices[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No ADB devices found${NC}"
    echo "Make sure devices are connected and authorized"
    exit 1
fi

echo -e "${GREEN}Found ${#devices[@]} device(s)${NC}"
echo ""

# Extract the base IP (192.168.40)
IFS='.' read -ra IP_PARTS <<< "$START_IP"
BASE_IP="${IP_PARTS[0]}.${IP_PARTS[1]}.${IP_PARTS[2]}"
CURRENT_IP_SUFFIX=${IP_PARTS[3]}

# Maximum IP suffix
IFS='.' read -ra END_IP_PARTS <<< "$END_IP"
MAX_IP_SUFFIX=${END_IP_PARTS[3]}

# Array to store assignments
declare -a assignments

echo -e "${BLUE}Starting IP assignment...${NC}"
echo ""

# Loop through each device
for i in "${!devices[@]}"; do
    device="${devices[$i]}"

    # Calculate new IP
    if [ $CURRENT_IP_SUFFIX -gt $MAX_IP_SUFFIX ]; then
        echo -e "${RED}ERROR: Ran out of available IPs!${NC}"
        echo "Maximum IP reached. Please expand your IP range."
        exit 1
    fi

    NEW_IP="${BASE_IP}.${CURRENT_IP_SUFFIX}"

    echo -e "${YELLOW}Device $((i+1))/${#devices[@]}: ${device}${NC}"

    # Get current IP (if any)
    CURRENT_IP=$(adb -s "$device" shell ip addr show "$INTERFACE" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

    if [ -z "$CURRENT_IP" ]; then
        echo "  Current IP: None or interface not found"
    else
        echo "  Current IP: $CURRENT_IP"
    fi

    echo -e "  ${GREEN}Assigning IP: ${NEW_IP}${NC}"

    # Configure static IP on the device (NON-ROOT methods for Android 11+)

    # Method 1: Using cmd connectivity (Android 11+)
    # Set static IP configuration
    adb -s "$device" shell "cmd connectivity set-static-ip $INTERFACE $NEW_IP $PREFIX_LENGTH $GATEWAY $DNS" 2>/dev/null

    # Method 2: Using ip command directly (some devices allow without root)
    adb -s "$device" shell "ip addr flush dev $INTERFACE" 2>/dev/null
    adb -s "$device" shell "ip addr add $NEW_IP/$PREFIX_LENGTH dev $INTERFACE" 2>/dev/null
    adb -s "$device" shell "ip link set $INTERFACE up" 2>/dev/null
    adb -s "$device" shell "ip route add default via $GATEWAY dev $INTERFACE" 2>/dev/null

    # Method 3: Using settings put (for some system properties)
    adb -s "$device" shell "settings put global ethernet_static_ip $NEW_IP" 2>/dev/null
    adb -s "$device" shell "settings put global ethernet_static_gateway $GATEWAY" 2>/dev/null
    adb -s "$device" shell "settings put global ethernet_static_dns1 $DNS" 2>/dev/null
    adb -s "$device" shell "settings put global ethernet_static_mask $NETMASK" 2>/dev/null

    # Method 4: Try using svc command
    adb -s "$device" shell "svc ethernet set-static-ip $INTERFACE $NEW_IP $NETMASK $GATEWAY $DNS" 2>/dev/null

    # Verify the assignment
    sleep 1
    VERIFY_IP=$(adb -s "$device" shell ip addr show "$INTERFACE" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

    if [ "$VERIFY_IP" == "$NEW_IP" ]; then
        echo -e "  ${GREEN}✓ Successfully configured!${NC}"
    else
        echo -e "  ${YELLOW}⚠ Warning: Could not verify IP assignment${NC}"
        echo "  This may require root access on the device"
    fi

    # Store assignment
    assignments+=("$device -> $NEW_IP")

    echo ""

    # Increment IP for next device
    CURRENT_IP_SUFFIX=$((CURRENT_IP_SUFFIX + 1))
done

# Print summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Assignment Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Gateway: $GATEWAY"
echo "DNS Server: $DNS"
echo "Interface: $INTERFACE"
echo ""
echo "Device Assignments:"
for assignment in "${assignments[@]}"; do
    echo "  $assignment"
done
echo ""

echo -e "${GREEN}Script completed!${NC}"
echo ""
echo "NOTE: If assignments failed, this could be due to:"
echo "  1. Devices not authorized for ADB (check phone screens)"
echo "  2. The $INTERFACE interface doesn't exist or is named differently"
echo "  3. Android security restrictions (some OEMs block network changes)"
echo "  4. Need to enable 'USB debugging (Security settings)' in Developer Options"
echo ""
echo "To verify current IP, run: adb shell ip addr show $INTERFACE"
echo "To list available interfaces, run: adb shell ip link"
echo ""
echo "If non-root methods don't work, you may need to:"
echo "  - Root the devices, OR"
echo "  - Configure DHCP reservations on your router, OR"
echo "  - Manually configure static IPs in Android Settings"
