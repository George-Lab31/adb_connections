#!/usr/bin/env bash

# ULTIMATE Auto-Configure Script for Android Phones
# This script AUTOMATICALLY handles DHCP pool configuration
# Works for ANY future batch of phones - NO manual pool adjustment needed!

# Configuration
MIKROTIK_IP="192.168.40.1"
MIKROTIK_USER="admin"
MIKROTIK_PASS='PurpleLemur%420'
INTERFACE="eth0"
DHCP_SERVER="dhcp1"

# Reserved range for ALL phones (supports up to 100 phones)
PHONE_RANGE_START=120
PHONE_RANGE_END=220

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Usage function
usage() {
    echo "Usage: $0 <START_IP>"
    echo ""
    echo "Example: $0 192.168.40.160"
    echo ""
    echo "This script will:"
    echo "  1. Verify DHCP pool excludes phone range ($PHONE_RANGE_START-$PHONE_RANGE_END)"
    echo "  2. Auto-fix pool if needed"
    echo "  3. Remove conflicting dynamic leases"
    echo "  4. Create static DHCP reservations"
    echo "  5. Force phones to renew DHCP"
    echo ""
    exit 1
}

# Check arguments
if [ -z "$1" ]; then
    usage
fi

START_IP="$1"

# Validate IP format
if ! [[ $START_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}ERROR: Invalid IP address format${NC}"
    exit 1
fi

# Extract IP components
IFS='.' read -ra IP_PARTS <<< "$START_IP"
BASE_IP="${IP_PARTS[0]}.${IP_PARTS[1]}.${IP_PARTS[2]}"
START_SUFFIX=${IP_PARTS[3]}

# Validate START_IP is within phone range
if [ $START_SUFFIX -lt $PHONE_RANGE_START ] || [ $START_SUFFIX -gt $PHONE_RANGE_END ]; then
    echo -e "${RED}ERROR: START_IP must be in range $BASE_IP.$PHONE_RANGE_START - $BASE_IP.$PHONE_RANGE_END${NC}"
    exit 1
fi

# Setup SSH
SSH_CMD="sshpass -p '${MIKROTIK_PASS}' ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Auto-Configure Phone DHCP${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo "Start IP: $START_IP"
echo "Phone Range: $BASE_IP.$PHONE_RANGE_START - $BASE_IP.$PHONE_RANGE_END"
echo ""

# Step 1: Check and fix DHCP pool
echo -e "${YELLOW}Step 1: Verifying DHCP Pool Configuration...${NC}"
echo ""

CURRENT_POOL=$(eval "$SSH_CMD" "/ip pool print detail where name=dhcp_pool0" 2>/dev/null | grep "ranges=" | sed 's/.*ranges=\(.*\)/\1/')
echo "Current pool: $CURRENT_POOL"

CORRECT_POOL="$BASE_IP.2-$BASE_IP.119,$BASE_IP.221-$BASE_IP.254"

if [ "$CURRENT_POOL" != "$CORRECT_POOL" ]; then
    echo -e "${YELLOW}⚠ Pool needs updating to exclude phone range ($PHONE_RANGE_START-$PHONE_RANGE_END)${NC}"
    echo -n "Updating DHCP pool... "
    eval "$SSH_CMD" "/ip pool set dhcp_pool0 ranges=$CORRECT_POOL" 2>&1
    echo -e "${GREEN}✓${NC}"
    echo "New pool: $CORRECT_POOL"
else
    echo -e "${GREEN}✓ Pool already configured correctly${NC}"
fi

echo ""

# Step 2: Check ADB devices
echo -e "${YELLOW}Step 2: Detecting ADB Devices...${NC}"
echo ""

if ! command -v adb &> /dev/null; then
    echo -e "${RED}ERROR: adb not found${NC}"
    exit 1
fi

devices=($(adb devices | grep -w "device" | awk '{print $1}'))

if [ ${#devices[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No ADB devices found${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#devices[@]} device(s)${NC}"
echo ""

# Step 3: Extract MAC addresses and prepare assignments
echo -e "${YELLOW}Step 3: Extracting MAC Addresses...${NC}"
echo ""

declare -a mac_addresses
declare -a assigned_ips

CURRENT_SUFFIX=$START_SUFFIX

for i in "${!devices[@]}"; do
    device="${devices[$i]}"
    NEW_IP="${BASE_IP}.${CURRENT_SUFFIX}"

    echo -e "Device $((i+1))/${#devices[@]}: ${device}"

    MAC=$(adb -s "$device" shell cat /sys/class/net/$INTERFACE/address 2>/dev/null | tr -d '\r\n')

    if [ -z "$MAC" ]; then
        echo -e "  ${RED}ERROR: Could not get MAC address${NC}"
        continue
    fi

    echo "  MAC: $MAC → IP: $NEW_IP"

    mac_addresses+=("$MAC")
    assigned_ips+=("$NEW_IP")

    CURRENT_SUFFIX=$((CURRENT_SUFFIX + 1))
done

echo ""

# Step 4: Remove conflicting dynamic leases
echo -e "${YELLOW}Step 4: Removing Conflicting Dynamic Leases...${NC}"
echo ""

# Get first two bytes of first MAC to identify this batch
FIRST_MAC="${mac_addresses[0]}"
MAC_PREFIX=$(echo "$FIRST_MAC" | cut -d: -f1-5 | tr '[:lower:]' '[:upper:]')

echo "Removing dynamic leases for MAC pattern: ${MAC_PREFIX}:*"

eval "$SSH_CMD" "/ip dhcp-server lease remove [find dynamic && mac-address~\"^${MAC_PREFIX}\"]" 2>&1
echo -e "${GREEN}✓ Dynamic leases removed${NC}"
echo ""

sleep 2

# Step 5: Create static reservations
echo -e "${YELLOW}Step 5: Creating Static DHCP Reservations...${NC}"
echo ""

SUCCESS=0
FAILED=0

for i in "${!mac_addresses[@]}"; do
    MAC="${mac_addresses[$i]}"
    IP="${assigned_ips[$i]}"
    COMMENT="Android-Phone-$((i+1))"

    echo -n "  [$((i+1))/${#mac_addresses[@]}] $MAC → $IP ... "

    # Remove any existing lease for this MAC or IP
    eval "$SSH_CMD" "/ip dhcp-server lease remove [find mac-address=\"$MAC\"]" 2>/dev/null
    eval "$SSH_CMD" "/ip dhcp-server lease remove [find address=\"$IP\"]" 2>/dev/null

    sleep 0.1

    # Create static lease
    if eval "$SSH_CMD" "/ip dhcp-server lease add address=$IP mac-address=$MAC server=$DHCP_SERVER comment=\"$COMMENT\" disabled=no" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        ((SUCCESS++))
    else
        echo -e "${RED}✗${NC}"
        ((FAILED++))
    fi
done

echo ""
echo -e "${GREEN}Successfully configured: $SUCCESS devices${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED devices${NC}"
fi
echo ""

# Step 6: Force DHCP renewal
echo -e "${YELLOW}Step 6: Forcing DHCP Renewal...${NC}"
echo ""

for i in "${!devices[@]}"; do
    device="${devices[$i]}"
    echo -n "  Device $((i+1))/${#devices[@]}: "

    adb -s "$device" shell "ifconfig $INTERFACE down" 2>/dev/null
    sleep 0.2
    adb -s "$device" shell "ifconfig $INTERFACE up" 2>/dev/null

    echo -e "${GREEN}✓${NC}"
done

echo ""
echo -e "${GREEN}✓ Ethernet restart complete${NC}"
echo ""

# Step 7: Create reconnect script
RECONNECT_SCRIPT="reconnect_adb.sh"
echo "Creating $RECONNECT_SCRIPT..."

cat > "$RECONNECT_SCRIPT" << EOF
#!/usr/bin/env bash
# Auto-generated reconnect script

for ip in {${assigned_ips[0]##*.}..${assigned_ips[-1]##*.}}; do
    adb connect $BASE_IP.\$ip:5555
done

echo ""
echo "Connected devices:"
adb devices | grep "device\$" | nl
EOF

chmod +x "$RECONNECT_SCRIPT"

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Configuration Complete!${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${GREEN}✓ DHCP pool configured correctly${NC}"
echo -e "${GREEN}✓ Dynamic leases removed${NC}"
echo -e "${GREEN}✓ Static reservations created${NC}"
echo -e "${GREEN}✓ Ethernet restart triggered${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Physically REBOOT all phones"
echo "  2. Wait 2 minutes for phones to acquire new IPs"
echo "  3. Run: ./$RECONNECT_SCRIPT"
echo ""
echo "IP Range assigned: ${assigned_ips[0]} - ${assigned_ips[-1]}"
echo ""
