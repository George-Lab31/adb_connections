#!/usr/bin/env bash

# Force DHCP renewal for batch 3 phones

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== STEP 3: Forcing Batch 3 DHCP Renewal ===${NC}"
echo ""

devices=($(adb devices | grep "device$" | awk '{print $1}'))
echo "Found ${#devices[@]} devices"
echo ""

for i in "${!devices[@]}"; do
    device="${devices[$i]}"
    echo -n "  Device $((i+1))/${#devices[@]} ($device): "

    adb -s "$device" shell "ifconfig eth0 down" 2>/dev/null
    sleep 0.3
    adb -s "$device" shell "ifconfig eth0 up" 2>/dev/null

    echo -e "${GREEN}✓${NC}"
done

echo ""
echo -e "${GREEN}✓ Ethernet restart complete${NC}"
echo ""
echo "Waiting 20 seconds for DHCP renewal..."
sleep 20

echo ""
echo "Checking lease status..."
sshpass -p 'PurpleLemur%420' ssh -o StrictHostKeyChecking=no admin@192.168.40.1 \
  "/ip dhcp-server lease print where address~\"^192.168.40.16\" && comment~\"Android-Phone\"" 2>/dev/null | \
  grep -E "bound|waiting" | head -5

echo ""
echo -e "${GREEN}Done!${NC}"
echo ""
echo "Now reboot batch 3 phones physically for guaranteed IP assignment."
echo "Then run: ./reconnect_adb.sh"
