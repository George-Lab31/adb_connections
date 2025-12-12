#!/usr/bin/env bash

# Automated MikroTik DHCP Reservation Script
# This script extracts MAC addresses from ADB devices and configures
# static DHCP leases on a MikroTik router via SSH
#
# Usage: ./mikrotik_auto_dhcp.sh [MIKROTIK_IP] [USERNAME] [PASSWORD] [START_IP]
# Example: ./mikrotik_auto_dhcp.sh 192.168.40.1 admin PurpleLemur%420 192.168.40.120

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
echo -e "${BLUE}MikroTik Auto DHCP Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get MikroTik connection details from arguments or prompt
if [ -n "$1" ]; then
    MIKROTIK_IP="$1"
else
    read -p "Enter MikroTik router IP address: " MIKROTIK_IP
fi

if [ -n "$2" ]; then
    MIKROTIK_USER="$2"
else
    read -p "Enter MikroTik username (default: admin): " MIKROTIK_USER
    MIKROTIK_USER=${MIKROTIK_USER:-admin}
fi

if [ -n "$3" ]; then
    MIKROTIK_PASS="$3"
else
    read -sp "Enter MikroTik password: " MIKROTIK_PASS
    echo ""
fi
echo ""

# Prompt for starting IP
if [ -n "$4" ]; then
    START_IP="$4"
else
    read -p "Enter the starting IP address (e.g., 192.168.40.120): " START_IP
fi

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

# Check if sshpass is installed (for password authentication)
if ! command -v sshpass &> /dev/null; then
    echo -e "${YELLOW}WARNING: sshpass not installed${NC}"
    echo "Attempting SSH connection without sshpass..."
    echo "You may be prompted for password multiple times."
    echo ""
    SSH_CMD="ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"
else
    SSH_CMD="sshpass -p '${MIKROTIK_PASS}' ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"
fi

# Test connection to MikroTik
echo -e "${YELLOW}Testing connection to MikroTik...${NC}"
if eval "$SSH_CMD" "system resource print" &>/dev/null; then
    echo -e "${GREEN}✓ Successfully connected to MikroTik${NC}"
else
    echo -e "${RED}ERROR: Could not connect to MikroTik${NC}"
    echo "Please check:"
    echo "  - Router IP address is correct"
    echo "  - Username and password are correct"
    echo "  - SSH service is enabled on the router"
    exit 1
fi
echo ""

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

echo -e "${BLUE}Extracting MAC addresses from devices...${NC}"
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

    # Get MAC address from eth0 interface using sysfs (works without special permissions)
    MAC=$(adb -s "$device" shell cat /sys/class/net/$INTERFACE/address 2>/dev/null | tr -d '\r\n')

    if [ -z "$MAC" ]; then
        echo -e "  ${RED}ERROR: Could not get MAC address for $INTERFACE${NC}"
        echo "  Skipping this device..."
        echo ""
        continue
    fi

    # Get current IP (extract from device name if it's network ADB)
    if [[ "$device" == *":"* ]]; then
        CURRENT_IP=$(echo "$device" | cut -d':' -f1)
    else
        # Try to get IP from ip addr command
        CURRENT_IP=$(adb -s "$device" shell "ip addr show $INTERFACE 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d'/' -f1" 2>/dev/null | tr -d '\r\n')
    fi

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

if [ ${#mac_addresses[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No MAC addresses collected${NC}"
    exit 1
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Configuring MikroTik DHCP Server${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Get DHCP server name
echo -e "${YELLOW}Detecting DHCP server configuration...${NC}"
DHCP_SERVER=$(eval "$SSH_CMD" "ip dhcp-server print detail" 2>/dev/null | grep "name=" | head -n1 | sed 's/.*name=\([^ ]*\).*/\1/')

if [ -z "$DHCP_SERVER" ]; then
    echo -e "${RED}ERROR: Could not detect DHCP server${NC}"
    echo "Please ensure DHCP server is configured on your MikroTik"
    exit 1
fi

echo -e "${GREEN}Found DHCP server: $DHCP_SERVER${NC}"
echo ""

# Configure static leases
echo -e "${YELLOW}Creating static DHCP leases...${NC}"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0

for i in "${!mac_addresses[@]}"; do
    MAC="${mac_addresses[$i]}"
    IP="${assigned_ips[$i]}"
    DEVICE="${device_serials[$i]}"
    COMMENT="Android-Phone-$((i+1))"

    echo -n "  [$((i+1))/${#mac_addresses[@]}] $MAC -> $IP ... "

    # Force remove any existing leases that might conflict
    # 1. Remove any lease with this MAC address (both static and dynamic)
    eval "$SSH_CMD" "/ip dhcp-server lease remove [find mac-address=\"$MAC\"]" 2>/dev/null

    # 2. Remove any lease (static or dynamic) using this IP address
    eval "$SSH_CMD" "/ip dhcp-server lease remove [find address=\"$IP\"]" 2>/dev/null

    # Small delay to ensure removal completes
    sleep 0.1

    # Create static lease with make-static flag to prevent dynamic override
    if eval "$SSH_CMD" "/ip dhcp-server lease add address=$IP mac-address=$MAC server=$DHCP_SERVER comment=\"$COMMENT\" disabled=no" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((FAIL_COUNT++))
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Configuration Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Successfully configured: ${GREEN}$SUCCESS_COUNT${NC} devices"
if [ $FAIL_COUNT -gt 0 ]; then
    echo "Failed: ${RED}$FAIL_COUNT${NC} devices"
fi
echo ""
echo "IP Range: ${assigned_ips[0]} - ${assigned_ips[-1]}"
echo "DHCP Server: $DHCP_SERVER"
echo ""

# Verify leases
echo -e "${YELLOW}Verifying static leases on MikroTik...${NC}"
echo ""
eval "$SSH_CMD" "/ip dhcp-server lease print where dynamic=no" 2>/dev/null

echo ""
echo -e "${GREEN}Configuration complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Reboot all phones or force DHCP renewal"
echo "  2. Reconnect via ADB to the new IPs if needed"
echo ""
echo "To reconnect via ADB network after phones reboot:"
for i in "${!assigned_ips[@]}"; do
    echo "  adb connect ${assigned_ips[$i]}:5555"
done
echo ""

# Create reconnect script
RECONNECT_SCRIPT="reconnect_adb.sh"
echo "#!/usr/bin/env bash" > "$RECONNECT_SCRIPT"
echo "# Reconnect to all phones via ADB network" >> "$RECONNECT_SCRIPT"
echo "" >> "$RECONNECT_SCRIPT"
for IP in "${assigned_ips[@]}"; do
    echo "adb connect $IP:5555" >> "$RECONNECT_SCRIPT"
done
echo "" >> "$RECONNECT_SCRIPT"
echo "echo 'Done! Checking connected devices...'" >> "$RECONNECT_SCRIPT"
echo "adb devices" >> "$RECONNECT_SCRIPT"
chmod +x "$RECONNECT_SCRIPT"

echo -e "${GREEN}Created reconnect script: $RECONNECT_SCRIPT${NC}"
echo "Run it after phones reboot: ./$RECONNECT_SCRIPT"
echo ""
