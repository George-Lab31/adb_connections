#!/usr/bin/env bash

# MikroTik DHCP Lease Reassignment Script
# This script pulls existing DHCP leases from MikroTik and reassigns them to a new IP range
#
# Usage: ./mikrotik_reassign_dhcp.sh [MIKROTIK_IP] [USERNAME] [PASSWORD] [START_IP]
# Example: ./mikrotik_reassign_dhcp.sh 192.168.40.1 admin mypassword 192.168.40.100

# Configuration
END_IP="192.168.40.220"
FILTER_PATTERN="Galaxy-Z-Flip4"  # Only reassign devices matching this hostname pattern

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}MikroTik DHCP Lease Reassignment${NC}"
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
    read -p "Enter the starting IP address (e.g., 192.168.40.100): " START_IP
fi

# Validate IP format
if ! [[ $START_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}ERROR: Invalid IP address format${NC}"
    exit 1
fi

echo ""

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
if eval "$SSH_CMD" "/system resource print" &>/dev/null; then
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

# Get DHCP server name
echo -e "${YELLOW}Detecting DHCP server configuration...${NC}"
DHCP_SERVER=$(eval "$SSH_CMD" "/ip dhcp-server print detail" 2>/dev/null | grep "name=" | head -n1 | sed 's/.*name=\"\?\([^\" ]*\).*/\1/')

if [ -z "$DHCP_SERVER" ]; then
    echo -e "${RED}ERROR: Could not detect DHCP server${NC}"
    echo "Please ensure DHCP server is configured on your MikroTik"
    exit 1
fi

echo -e "${GREEN}Found DHCP server: $DHCP_SERVER${NC}"
echo ""

# Get all existing leases with the filter pattern
echo -e "${YELLOW}Fetching existing DHCP leases...${NC}"
LEASE_DATA=$(eval "$SSH_CMD" "/ip dhcp-server lease print detail where host-name~\"$FILTER_PATTERN\"" 2>/dev/null)

if [ -z "$LEASE_DATA" ]; then
    echo -e "${RED}ERROR: No leases found matching pattern: $FILTER_PATTERN${NC}"
    echo "Showing all leases instead..."
    eval "$SSH_CMD" "/ip dhcp-server lease print"
    exit 1
fi

# Parse lease data to extract MAC addresses
declare -a mac_addresses
declare -a old_ips
declare -a comments

# Extract MAC addresses and current IPs from lease data
while IFS= read -r line; do
    if [[ $line =~ mac-address=([0-9A-Fa-f:]+) ]]; then
        MAC="${BASH_REMATCH[1]}"
    fi
    if [[ $line =~ address=([0-9.]+) ]]; then
        IP="${BASH_REMATCH[1]}"
    fi
    if [[ $line =~ comment=\"([^\"]+)\" ]] || [[ $line =~ ;;;\ (.+)$ ]]; then
        COMMENT="${BASH_REMATCH[1]}"
    fi
    if [[ $line =~ host-name=\"([^\"]+)\" ]]; then
        HOSTNAME="${BASH_REMATCH[1]}"
        # When we have all three pieces, store them
        if [ -n "$MAC" ] && [ -n "$IP" ]; then
            mac_addresses+=("$MAC")
            old_ips+=("$IP")
            if [ -n "$COMMENT" ]; then
                comments+=("$COMMENT")
            else
                comments+=("Android-Phone-${#mac_addresses[@]}")
            fi
            # Reset for next lease
            MAC=""
            IP=""
            COMMENT=""
        fi
    fi
done <<< "$LEASE_DATA"

if [ ${#mac_addresses[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: Could not parse any MAC addresses from leases${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#mac_addresses[@]} device(s) to reassign${NC}"
echo ""

# Extract the base IP
IFS='.' read -ra IP_PARTS <<< "$START_IP"
BASE_IP="${IP_PARTS[0]}.${IP_PARTS[1]}.${IP_PARTS[2]}"
CURRENT_IP_SUFFIX=${IP_PARTS[3]}

# Maximum IP suffix
IFS='.' read -ra END_IP_PARTS <<< "$END_IP"
MAX_IP_SUFFIX=${END_IP_PARTS[3]}

# Show what will be reassigned
echo -e "${BLUE}Reassignment Plan:${NC}"
echo ""
declare -a assigned_ips

for i in "${!mac_addresses[@]}"; do
    if [ $CURRENT_IP_SUFFIX -gt $MAX_IP_SUFFIX ]; then
        echo -e "${RED}ERROR: Ran out of available IPs!${NC}"
        exit 1
    fi

    NEW_IP="${BASE_IP}.${CURRENT_IP_SUFFIX}"
    assigned_ips+=("$NEW_IP")

    echo "  [$((i+1))] ${mac_addresses[$i]}: ${old_ips[$i]} → $NEW_IP (${comments[$i]})"

    CURRENT_IP_SUFFIX=$((CURRENT_IP_SUFFIX + 1))
done

echo ""
read -p "Proceed with reassignment? (y/n): " CONFIRM

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Reassigning DHCP Leases${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0

for i in "${!mac_addresses[@]}"; do
    MAC="${mac_addresses[$i]}"
    NEW_IP="${assigned_ips[$i]}"
    COMMENT="${comments[$i]}"

    echo -n "  [$((i+1))/${#mac_addresses[@]}] $MAC → $NEW_IP ... "

    # Remove existing lease with this MAC
    eval "$SSH_CMD" "/ip dhcp-server lease remove [find mac-address=\"$MAC\"]" 2>/dev/null

    # Remove any lease using this new IP
    eval "$SSH_CMD" "/ip dhcp-server lease remove [find address=\"$NEW_IP\"]" 2>/dev/null

    # Small delay
    sleep 0.1

    # Create new static lease
    if eval "$SSH_CMD" "/ip dhcp-server lease add address=$NEW_IP mac-address=$MAC server=$DHCP_SERVER comment=\"$COMMENT\"" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((FAIL_COUNT++))
    fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Reassignment Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Successfully reassigned: ${GREEN}$SUCCESS_COUNT${NC} devices"
if [ $FAIL_COUNT -gt 0 ]; then
    echo "Failed: ${RED}$FAIL_COUNT${NC} devices"
fi
echo ""
echo "New IP Range: ${assigned_ips[0]} - ${assigned_ips[-1]}"
echo ""

# Verify leases
echo -e "${YELLOW}Verifying static leases on MikroTik...${NC}"
echo ""
eval "$SSH_CMD" "/ip dhcp-server lease print where host-name~\"$FILTER_PATTERN\"" 2>/dev/null

echo ""
echo -e "${GREEN}Reassignment complete!${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: You must now force the devices to renew their DHCP leases:${NC}"
echo "  1. Reboot all devices, OR"
echo "  2. Use ADB to force network restart (if devices are online)"
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
echo "After devices renew DHCP, run: ./$RECONNECT_SCRIPT"
echo ""
