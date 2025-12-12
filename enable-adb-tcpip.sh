#!/usr/bin/env bash

# Script to enable ADB TCP/IP mode on all USB-connected devices

echo "Scanning for USB-connected ADB devices..."

# Get list of devices connected via USB (not network IPs)
usb_devices=$(adb devices | grep -v "List of devices" | grep -v ":" | awk '{print $1}' | grep -v "^$")

if [ -z "$usb_devices" ]; then
    echo "No USB-connected devices found."
    exit 1
fi

echo "Found USB devices:"
echo "$usb_devices"
echo ""

# Enable TCP/IP mode on port 5555 for each device
for device in $usb_devices; do
    echo "Enabling TCP/IP mode on device: $device"
    adb -s $device tcpip 5555

    if [ $? -eq 0 ]; then
        echo "✓ Successfully enabled TCP/IP mode on $device"
    else
        echo "✗ Failed to enable TCP/IP mode on $device"
    fi
    echo ""
done

echo "All USB devices have been configured for TCP/IP mode."
echo "You can now connect to them via 'adb connect <ip>:5555'"
