#!/usr/bin/env bash
# Reconnect to phones at 192.168.40.100 - 192.168.40.119

echo "Connecting to 20 phones..."
for ip in {100..119}; do
    adb connect 192.168.40.$ip:5555 2>&1 | grep -q "connected" && echo "  ✓ 192.168.40.$ip"
done

echo ""
echo "Connected devices:"
adb devices | grep "device$" | nl
