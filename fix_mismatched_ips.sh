#!/usr/bin/env bash

# Fix Phones with Mismatched IPs
# This script identifies phones at wrong IPs and provides instructions to fix them

INTERFACE="eth0"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Find Phones with Wrong IPs${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Collect current phone IPs and MACs
echo -e "${YELLOW}Step 1: Scanning connected phones...${NC}"
echo ""

devices=($(adb devices | grep "device$" | awk '{print $1}'))

if [ ${#devices[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No ADB devices found${NC}"
    exit 1
fi

echo "Found ${#devices[@]} phones"
echo ""

# Create temp file
> /tmp/current_phones.txt

for device in "${devices[@]}"; do
    current_ip=$(echo $device | cut -d: -f1)
    mac=$(adb -s "$device" shell cat /sys/class/net/$INTERFACE/address 2>/dev/null | tr -d '\r\n' | tr '[:lower:]' '[:upper:]')

    if [ -n "$mac" ]; then
        echo "$current_ip|$mac" >> /tmp/current_phones.txt
    fi
done

echo "✓ Collected $(wc -l < /tmp/current_phones.txt) phone MACs"
echo ""

# Step 2: Get configured IPs from MikroTik
echo -e "${YELLOW}Step 2: Getting configured IPs from MikroTik...${NC}"
echo ""

sshpass -p 'PurpleLemur%420' ssh -o StrictHostKeyChecking=no admin@192.168.40.1 \
  "/ip dhcp-server lease print where comment~\"Android-Phone\"" 2>/dev/null | \
  grep -v "^Flags" | grep -v "^Columns" | grep -v "^#" | \
  awk '{if (NF >= 3) print $2"|"$3}' | grep "192.168.40" > /tmp/configured_ips.txt

echo "✓ Collected $(wc -l < /tmp/configured_ips.txt) configured IPs"
echo ""

# Step 3: Find mismatches
echo -e "${YELLOW}Step 3: Finding mismatches...${NC}"
echo ""

> /tmp/mismatches.txt

while IFS='|' read current_ip mac; do
    configured_ip=$(grep "$mac" /tmp/configured_ips.txt | cut -d'|' -f1)

    if [ -n "$configured_ip" ] && [ "$current_ip" != "$configured_ip" ]; then
        echo "$mac|$current_ip|$configured_ip" >> /tmp/mismatches.txt
    fi
done < /tmp/current_phones.txt

MISMATCH_COUNT=$(wc -l < /tmp/mismatches.txt)

if [ $MISMATCH_COUNT -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✓ ALL PHONES AT CORRECT IPS!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    exit 0
fi

# Display mismatches
echo -e "${RED}Found $MISMATCH_COUNT phone(s) at WRONG IPs:${NC}"
echo ""
echo -e "${BOLD}MAC Address        | Current IP       | Should Be${NC}"
echo "-------------------|------------------|------------------"

cat /tmp/mismatches.txt | while IFS='|' read mac curr should; do
    printf "%-18s | ${RED}%-16s${NC} | ${GREEN}%s${NC}\n" "$mac" "$curr" "$should"
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  How to Fix${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Option 1: Disconnect and reboot individual phones${NC}"
echo ""

cat /tmp/mismatches.txt | while IFS='|' read mac curr should; do
    echo "adb disconnect $curr:5555"
done

echo ""
echo "Then PHYSICALLY REBOOT those phones"
echo "Wait 2 minutes"
echo "./reconnect_adb.sh"
echo ""
echo -e "${YELLOW}Option 2: Reboot all phones with wrong IPs at once${NC}"
echo ""
echo "1. Disconnect from ADB (they'll stay at wrong IPs)"
echo "2. Physically power off all phones with wrong IPs"
echo "3. Wait 10 seconds"
echo "4. Power on all phones"
echo "5. Wait 2 minutes"
echo "6. ./reconnect_adb.sh"
echo ""
echo -e "${RED}IMPORTANT: Only physical reboot clears Android's DHCP cache!${NC}"
echo ""
