#!/usr/bin/env bash

# DHCP Reservation Generator for Multiple ADB Devices
# Configuration
END_IP="192.168.40.220"
GATEWAY="192.168.40.1"
INTERFACE="eth0"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}DHCP Reservation Generator${NC}"
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

# Extract the base IP
IFS='.' read -ra IP_PARTS <<< "$START_IP"
BASE_IP="${IP_PARTS[0]}.${IP_PARTS[1]}.${IP_PARTS[2]}"
CURRENT_IP_SUFFIX=${IP_PARTS[3]}

# Maximum IP suffix
IFS='.' read -ra END_IP_PARTS <<< "$END_IP"
MAX_IP_SUFFIX=${END_IP_PARTS[3]}

# Arrays to store data
declare -a mac_addresses
declare -a device_serials
declare -a assigned_ips

echo -e "${BLUE}Extracting MAC addresses...${NC}"
echo ""

# Loop through each device to get MAC address
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

    # Get MAC address from eth0 interface
    MAC=$(adb -s "$device" shell "ip link show $INTERFACE" 2>/dev/null | grep "link/ether" | awk '{print $2}')

    if [ -z "$MAC" ]; then
        echo -e "  ${RED}ERROR: Could not get MAC address for $INTERFACE${NC}"
        echo "  Skipping this device..."
        echo ""
        continue
    fi

    # Get current IP
    CURRENT_IP=$(adb -s "$device" shell ip addr show "$INTERFACE" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1)

    echo "  MAC Address: $MAC"
    echo "  Current IP: ${CURRENT_IP:-None}"
    echo "  Will assign: $NEW_IP"
    echo ""

    # Store data
    mac_addresses+=("$MAC")
    device_serials+=("$device")
    assigned_ips+=("$NEW_IP")

    # Increment IP for next device
    CURRENT_IP_SUFFIX=$((CURRENT_IP_SUFFIX + 1))
done

# Generate configuration files
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Generating DHCP Reservation Configs${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create output directory
mkdir -p dhcp_configs

# 1. Generic dnsmasq format (used by many routers)
DNSMASQ_FILE="dhcp_configs/dnsmasq.conf"
echo "# DHCP Reservations for Android Devices" > "$DNSMASQ_FILE"
echo "# Generated on $(date)" >> "$DNSMASQ_FILE"
echo "" >> "$DNSMASQ_FILE"

for i in "${!mac_addresses[@]}"; do
    echo "dhcp-host=${mac_addresses[$i]},${assigned_ips[$i]}" >> "$DNSMASQ_FILE"
done

# 2. CSV format (for import to various routers)
CSV_FILE="dhcp_configs/reservations.csv"
echo "MAC Address,IP Address,Device Serial,Hostname" > "$CSV_FILE"

for i in "${!mac_addresses[@]}"; do
    HOSTNAME="android-device-$((i+1))"
    echo "${mac_addresses[$i]},${assigned_ips[$i]},${device_serials[$i]},${HOSTNAME}" >> "$CSV_FILE"
done

# 3. Human-readable format
READABLE_FILE="dhcp_configs/reservations.txt"
echo "DHCP Reservation Configuration" > "$READABLE_FILE"
echo "Generated on $(date)" >> "$READABLE_FILE"
echo "======================================" >> "$READABLE_FILE"
echo "" >> "$READABLE_FILE"
echo "Gateway: $GATEWAY" >> "$READABLE_FILE"
echo "Interface: $INTERFACE" >> "$READABLE_FILE"
echo "" >> "$READABLE_FILE"
echo "Reservations:" >> "$READABLE_FILE"
echo "--------------------------------------" >> "$READABLE_FILE"

for i in "${!mac_addresses[@]}"; do
    echo "" >> "$READABLE_FILE"
    echo "Device $((i+1)): ${device_serials[$i]}" >> "$READABLE_FILE"
    echo "  MAC Address: ${mac_addresses[$i]}" >> "$READABLE_FILE"
    echo "  Reserved IP: ${assigned_ips[$i]}" >> "$READABLE_FILE"
done

# 4. Router-specific formats

# OpenWrt/LEDE format
OPENWRT_FILE="dhcp_configs/openwrt.conf"
echo "# OpenWrt/LEDE DHCP static leases" > "$OPENWRT_FILE"
echo "# Add these to /etc/config/dhcp" >> "$OPENWRT_FILE"
echo "" >> "$OPENWRT_FILE"

for i in "${!mac_addresses[@]}"; do
    cat >> "$OPENWRT_FILE" << EOF
config host
    option name 'android-device-$((i+1))'
    option mac '${mac_addresses[$i]}'
    option ip '${assigned_ips[$i]}'

EOF
done

# pfSense/OPNsense format (JSON-like)
PFSENSE_FILE="dhcp_configs/pfsense.txt"
echo "# pfSense/OPNsense DHCP Static Mappings" > "$PFSENSE_FILE"
echo "# Configure via Services > DHCP Server > LAN > DHCP Static Mappings" >> "$PFSENSE_FILE"
echo "" >> "$PFSENSE_FILE"

for i in "${!mac_addresses[@]}"; do
    cat >> "$PFSENSE_FILE" << EOF
MAC Address: ${mac_addresses[$i]}
IP Address: ${assigned_ips[$i]}
Hostname: android-device-$((i+1))
Description: Android Device ${device_serials[$i]}
---
EOF
done

# MikroTik RouterOS format
MIKROTIK_FILE="dhcp_configs/mikrotik.rsc"
echo "# MikroTik RouterOS DHCP reservations" > "$MIKROTIK_FILE"
echo "# Run these commands in RouterOS terminal" >> "$MIKROTIK_FILE"
echo "" >> "$MIKROTIK_FILE"

for i in "${!mac_addresses[@]}"; do
    echo "/ip dhcp-server lease add address=${assigned_ips[$i]} mac-address=${mac_addresses[$i]} comment=\"android-device-$((i+1))\"" >> "$MIKROTIK_FILE"
done

echo -e "${GREEN}Configuration files generated in 'dhcp_configs/' directory:${NC}"
echo ""
echo "  1. dnsmasq.conf       - For routers using dnsmasq (DD-WRT, Tomato, etc.)"
echo "  2. reservations.csv   - Generic CSV format for import"
echo "  3. reservations.txt   - Human-readable format"
echo "  4. openwrt.conf       - For OpenWrt/LEDE routers"
echo "  5. pfsense.txt        - For pfSense/OPNsense firewalls"
echo "  6. mikrotik.rsc       - For MikroTik RouterOS"
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Total devices configured: ${#mac_addresses[@]}"
echo "IP Range: ${assigned_ips[0]} - ${assigned_ips[-1]}"
echo "Gateway: $GATEWAY"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "  1. Choose the configuration file that matches your router type"
echo "  2. Log into your router's admin interface"
echo "  3. Navigate to DHCP settings"
echo "  4. Add the static DHCP reservations (or import the CSV)"
echo "  5. Save and apply the configuration"
echo "  6. Reboot the phones or renew their DHCP leases"
echo ""
echo "To view the human-readable list:"
echo "  cat dhcp_configs/reservations.txt"
echo ""
