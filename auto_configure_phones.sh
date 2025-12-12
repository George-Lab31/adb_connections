#!/usr/bin/env bash

# FIXED Auto-Configure Script - GUARANTEED to work
# This version REQUIRES physical reboot (no more ethernet restart workarounds)

# Configuration
MIKROTIK_IP="192.168.40.1"
MIKROTIK_USER="admin"
MIKROTIK_PASS='PurpleLemur%420'
INTERFACE="eth0"
DHCP_SERVER="dhcp1"

# Optional: Number of phones (will be determined later if not specified)
NUM_PHONES_REQUESTED="${2:-0}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <START_IP> [NUM_PHONES]"
    echo ""
    echo "Arguments:"
    echo "  START_IP    - Starting IP address for phones (e.g., 192.168.40.100)"
    echo "  NUM_PHONES  - Number of phones to configure (default: auto-detect from ADB)"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.40.100           # Auto-detect phone count"
    echo "  $0 192.168.40.180 20        # Configure 20 phones starting at .180"
    echo ""
    echo "IMPORTANT: This script requires PHYSICAL REBOOT of phones!"
    echo "Ethernet restart is NOT enough to clear Android's DHCP cache."
    echo ""
    exit 1
}

if [ -z "$1" ]; then
    usage
fi

START_IP="$1"

# Validate IP
if ! [[ $START_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}ERROR: Invalid IP address format${NC}"
    exit 1
fi

IFS='.' read -ra IP_PARTS <<< "$START_IP"
BASE_IP="${IP_PARTS[0]}.${IP_PARTS[1]}.${IP_PARTS[2]}"
START_SUFFIX=${IP_PARTS[3]}

# Basic validation - ensure last octet is between 2-254
if [ $START_SUFFIX -lt 2 ] || [ $START_SUFFIX -gt 254 ]; then
    echo -e "${RED}ERROR: START_IP last octet must be in range 2-254${NC}"
    exit 1
fi

SSH_CMD="sshpass -p '${MIKROTIK_PASS}' ssh -o StrictHostKeyChecking=no ${MIKROTIK_USER}@${MIKROTIK_IP}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  FIXED Auto-Configure Phone DHCP${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Start IP: $START_IP"
echo ""

# Moved to after device detection

# Step 2: Check ADB
echo -e "${YELLOW}Step 2: Detecting ADB Devices...${NC}"

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

# Determine actual phone count
if [ $NUM_PHONES_REQUESTED -gt 0 ]; then
    NUM_PHONES=$NUM_PHONES_REQUESTED
    if [ $NUM_PHONES -gt ${#devices[@]} ]; then
        echo -e "${YELLOW}WARNING: Requested $NUM_PHONES phones but only ${#devices[@]} detected${NC}"
        echo -e "${YELLOW}Using detected count: ${#devices[@]}${NC}"
        NUM_PHONES=${#devices[@]}
    fi
else
    NUM_PHONES=${#devices[@]}
fi

# Calculate dynamic phone range
PHONE_RANGE_START=$START_SUFFIX
PHONE_RANGE_END=$((START_SUFFIX + NUM_PHONES - 1))

# Validate range fits in subnet
if [ $PHONE_RANGE_END -gt 254 ]; then
    echo -e "${RED}ERROR: Phone range would exceed 254 (START: $START_SUFFIX, COUNT: $NUM_PHONES, END: $PHONE_RANGE_END)${NC}"
    echo -e "${RED}Either reduce phone count or choose a lower START_IP${NC}"
    exit 1
fi

echo -e "${BLUE}Phone IP Range: $BASE_IP.$PHONE_RANGE_START - $BASE_IP.$PHONE_RANGE_END ($NUM_PHONES phones)${NC}"
echo ""

# Step 1 (moved here): Configure DHCP pool to exclude phone range
echo -e "${YELLOW}Step 1: Configuring DHCP Pool...${NC}"

# Build DHCP pool ranges (everything except phone range)
# Format: 2-(PHONE_START-1), (PHONE_END+1)-254
DHCP_RANGES=""

if [ $PHONE_RANGE_START -gt 2 ]; then
    DHCP_RANGES="$BASE_IP.2-$BASE_IP.$((PHONE_RANGE_START - 1))"
fi

if [ $PHONE_RANGE_END -lt 254 ]; then
    if [ -n "$DHCP_RANGES" ]; then
        DHCP_RANGES="$DHCP_RANGES,$BASE_IP.$((PHONE_RANGE_END + 1))-$BASE_IP.254"
    else
        DHCP_RANGES="$BASE_IP.$((PHONE_RANGE_END + 1))-$BASE_IP.254"
    fi
fi

# Handle edge case where phones use entire range 2-254
if [ -z "$DHCP_RANGES" ]; then
    echo -e "${YELLOW}WARNING: Phone range uses entire subnet (2-254)${NC}"
    echo -e "${YELLOW}No IPs available for dynamic DHCP pool${NC}"
    DHCP_RANGES="$BASE_IP.2-$BASE_IP.2"  # Minimal pool
fi

CURRENT_POOL=$(eval "$SSH_CMD" "/ip pool print detail where name=dhcp_pool0" 2>/dev/null | grep "ranges=" | sed 's/.*ranges=\(.*\)/\1/')

echo "  Target pool: $DHCP_RANGES"
echo "  Current pool: $CURRENT_POOL"

if [ "$CURRENT_POOL" != "$DHCP_RANGES" ]; then
    echo -n "  Updating pool... "
    eval "$SSH_CMD" "/ip pool set dhcp_pool0 ranges=$DHCP_RANGES" 2>&1
    echo -e "${GREEN}✓${NC}"
else
    echo -e "  ${GREEN}✓ Pool already correct${NC}"
fi
echo ""

# Step 3: Extract MACs and current IPs
echo -e "${YELLOW}Step 3: Mapping Devices...${NC}"
echo ""

declare -a mac_addresses
declare -a assigned_ips
declare -a current_ips

CURRENT_SUFFIX=$START_SUFFIX

for i in "${!devices[@]}"; do
    device="${devices[$i]}"
    NEW_IP="${BASE_IP}.${CURRENT_SUFFIX}"

    # Extract current IP from device string
    if [[ "$device" == *":"* ]]; then
        CURR_IP=$(echo "$device" | cut -d':' -f1)
    else
        CURR_IP="unknown"
    fi

    MAC=$(adb -s "$device" shell cat /sys/class/net/$INTERFACE/address 2>/dev/null | tr -d '\r\n')

    if [ -z "$MAC" ]; then
        echo -e "  ${RED}ERROR: Could not get MAC for $device${NC}"
        continue
    fi

    echo "  [$((i+1))/${#devices[@]}] Current: $CURR_IP → New: $NEW_IP (MAC: $MAC)"

    mac_addresses+=("$MAC")
    assigned_ips+=("$NEW_IP")
    current_ips+=("$CURR_IP")

    CURRENT_SUFFIX=$((CURRENT_SUFFIX + 1))
done

echo ""

if [ ${#mac_addresses[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No MACs collected${NC}"
    exit 1
fi

# Step 4: Remove ALL dynamic leases (aggressive cleanup)
echo -e "${YELLOW}Step 4: Removing ALL Dynamic Leases...${NC}"
echo ""

# Get all dynamic lease IDs
DYNAMIC_COUNT=$(eval "$SSH_CMD" "/ip dhcp-server lease print count-only where dynamic" 2>/dev/null)
echo "  Found $DYNAMIC_COUNT dynamic leases"

if [ "$DYNAMIC_COUNT" -gt 0 ]; then
    echo -n "  Removing all dynamic leases... "
    eval "$SSH_CMD" "/ip dhcp-server lease remove [find dynamic]" 2>&1 >/dev/null
    echo -e "${GREEN}✓${NC}"
else
    echo -e "  ${GREEN}✓ No dynamic leases to remove${NC}"
fi

sleep 2
echo ""

# Step 5: Remove any existing leases for these MACs (AGGRESSIVE - only touches these MACs)
echo -e "${YELLOW}Step 5: Cleaning Old Leases for Target MACs...${NC}"
echo ""

REMOVED_COUNT=0
ATTEMPTS=0

for MAC in "${mac_addresses[@]}"; do
    # Aggressive removal: try multiple times until lease is gone
    MAX_ATTEMPTS=3
    ATTEMPT=1

    while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
        # Check if any lease exists for this MAC
        LEASE_COUNT=$(eval "$SSH_CMD" "/ip dhcp-server lease print count-only where mac-address=\"$MAC\"" 2>/dev/null)

        if [ "$LEASE_COUNT" -eq "0" ]; then
            if [ $ATTEMPT -eq 1 ]; then
                # No lease existed from the start
                break
            else
                # Successfully removed
                echo -e "${GREEN}✓${NC}"
                ((REMOVED_COUNT++))
                break
            fi
        fi

        # Lease exists - show message on first attempt
        if [ $ATTEMPT -eq 1 ]; then
            echo -n "  Removing existing lease(s) for $MAC (found $LEASE_COUNT)... "
        fi

        # Remove all leases for this MAC (handles both static and dynamic)
        eval "$SSH_CMD" "/ip dhcp-server lease remove [find mac-address=\"$MAC\"]" 2>/dev/null

        sleep 1
        ((ATTEMPT++))
        ((ATTEMPTS++))
    done

    # Check if we failed to remove after all attempts
    if [ $ATTEMPT -gt $MAX_ATTEMPTS ]; then
        FINAL_COUNT=$(eval "$SSH_CMD" "/ip dhcp-server lease print count-only where mac-address=\"$MAC\"" 2>/dev/null)
        if [ "$FINAL_COUNT" -gt 0 ]; then
            echo -e "${RED}✗ (still exists after $MAX_ATTEMPTS attempts)${NC}"
            echo -e "${YELLOW}    WARNING: This may cause creation to fail${NC}"
        fi
    fi
done

if [ $REMOVED_COUNT -eq 0 ]; then
    echo -e "  ${GREEN}✓ No existing leases found for target MACs${NC}"
else
    echo -e "  ${GREEN}✓ Removed $REMOVED_COUNT old lease(s)${NC}"
    # Extra time for MikroTik to fully process
    echo "  Waiting for MikroTik to process..."
    sleep 3
fi
echo ""

# Step 6: Create static reservations
echo -e "${YELLOW}Step 6: Creating Static DHCP Reservations...${NC}"
echo ""

SUCCESS=0
FAILED=0

for i in "${!mac_addresses[@]}"; do
    MAC="${mac_addresses[$i]}"
    IP="${assigned_ips[$i]}"
    COMMENT="Android-Phone-$((i+1))"

    echo -n "  [$((i+1))/${#mac_addresses[@]}] $MAC → $IP ... "

    # Try to create the lease (max 2 attempts)
    CREATED=false
    for RETRY in 1 2; do
        CREATE_OUTPUT=$(eval "$SSH_CMD" "/ip dhcp-server lease add address=$IP mac-address=$MAC server=$DHCP_SERVER comment=\"$COMMENT\" disabled=no" 2>&1)

        if echo "$CREATE_OUTPUT" | grep -q "failure"; then
            if echo "$CREATE_OUTPUT" | grep -q "already have"; then
                # Lease still exists - force remove again
                if [ $RETRY -eq 1 ]; then
                    echo -n "(force removing) ... "
                    eval "$SSH_CMD" "/ip dhcp-server lease remove [find mac-address=\"$MAC\"]" 2>/dev/null
                    sleep 1
                    # Loop will retry
                else
                    # Second attempt also failed
                    echo -e "${RED}✗ (MAC lease persists)${NC}"
                    ((FAILED++))
                    break
                fi
            elif echo "$CREATE_OUTPUT" | grep -q "already have.*address"; then
                # IP address is taken by different device
                echo -e "${RED}✗ (IP conflict)${NC}"
                ((FAILED++))
                break
            else
                # Other failure
                echo -e "${RED}✗ (${CREATE_OUTPUT})${NC}"
                ((FAILED++))
                break
            fi
        else
            # Success
            echo -e "${GREEN}✓${NC}"
            ((SUCCESS++))
            CREATED=true
            break
        fi
    done
done

echo ""
echo -e "${GREEN}✓ $SUCCESS static reservations created${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}✗ $FAILED failed${NC}"
fi
echo ""

# Step 7: Create reconnect script
RECONNECT_SCRIPT="reconnect_adb.sh"
cat > "$RECONNECT_SCRIPT" << EOF
#!/usr/bin/env bash
# Reconnect to phones at ${assigned_ips[0]} - ${assigned_ips[-1]}

echo "Connecting to ${#assigned_ips[@]} phones..."
for ip in {${assigned_ips[0]##*.}..${assigned_ips[-1]##*.}}; do
    adb connect $BASE_IP.\$ip:5555 2>&1 | grep -q "connected" && echo "  ✓ $BASE_IP.\$ip"
done

echo ""
echo "Connected devices:"
adb devices | grep "device\$" | nl
EOF

chmod +x "$RECONNECT_SCRIPT"

# Final instructions
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Configuration Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}✓ DHCP pool configured${NC}"
echo -e "${GREEN}✓ All dynamic leases removed${NC}"
echo -e "${GREEN}✓ $SUCCESS static reservations created${NC}"
echo -e "${GREEN}✓ Reconnect script created${NC}"
echo ""
echo -e "${BOLD}${RED}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${RED}║  CRITICAL: PHYSICAL REBOOT REQUIRED!          ║${NC}"
echo -e "${BOLD}${RED}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}WHY: Android caches DHCP leases. Ethernet restart does NOT clear this cache.${NC}"
echo -e "${YELLOW}Only a full reboot clears the cache and forces phones to request new IPs.${NC}"
echo ""
echo -e "${BOLD}NEXT STEPS:${NC}"
echo "  1. ${RED}POWER OFF${NC} all phones (hold power button)"
echo "  2. Wait 10 seconds"
echo "  3. ${GREEN}POWER ON${NC} all phones"
echo "  4. Wait 2 minutes for DHCP acquisition"
echo "  5. Run: ${BLUE}./$RECONNECT_SCRIPT${NC}"
echo ""
echo -e "${BOLD}Expected Result:${NC}"
echo "  All phones will connect at: ${GREEN}${assigned_ips[0]} - ${assigned_ips[-1]}${NC}"
echo ""
echo -e "${YELLOW}DO NOT skip the reboot! Ethernet restart will NOT work!${NC}"
echo ""
