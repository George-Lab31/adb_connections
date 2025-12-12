# Android Phone Network Setup - Complete Summary

## Current Configuration

### Phone Inventory
- **Batch 1:** 20 phones (MAC: E4:66:E5:2E:14:xx) → IPs: 192.168.40.120-139 ✓
- **Batch 2:** 20 phones (MAC: E4:66:E5:2E:12:xx) → IPs: 192.168.40.140-159
- **Total:** 40 phones

### MikroTik DHCP Configuration

#### DHCP Pool (Permanent Fix Applied)
```
Pool Name: dhcp_pool0
Ranges:
  - 192.168.40.2 - 192.168.40.119   (118 IPs for dynamic assignment)
  - 192.168.40.160 - 192.168.40.254 (95 IPs for dynamic assignment)

EXCLUDED from pool:
  - 192.168.40.120 - 192.168.40.159 (Reserved for static phone assignments)
```

#### Static DHCP Reservations
```
Batch 1: 192.168.40.120-139 (20 phones) - ACTIVE
Batch 2: 192.168.40.140-159 (20 phones) - Configured, pending reboot
```

## Problem & Solution

### What Was Wrong
1. DHCP pool included the static IP ranges (120-159)
2. When phones rebooted simultaneously, they grabbed **dynamic** IPs instead of static reservations
3. Phones ended up with random IPs (3, 4, 6, 9, 11-31, etc.)

### Permanent Fix Applied
1. ✓ Modified DHCP pool to **exclude** 192.168.40.120-159
2. ✓ Created 40 static DHCP reservations (120-139 and 140-159)
3. ✓ Dynamic leases can no longer conflict with static reservations

## How It Works Now

### For Current Phones
After reboot, phones will:
1. Request DHCP lease
2. MikroTik checks MAC address
3. Finds static reservation → assigns correct IP (120-159)
4. DHCP pool cannot offer 120-159 (excluded range)
5. Phone gets static IP **every time**

### For Future Phones
When adding new phones:
1. Connect phone to network
2. Run: `./mikrotik_auto_dhcp.sh 192.168.40.1 admin 'PASSWORD' <START_IP>`
3. Script creates static reservations
4. Reboot phone
5. Phone gets static IP automatically

**Example for 3rd batch (20 more phones):**
```bash
./mikrotik_auto_dhcp.sh 192.168.40.1 admin 'PurpleLemur%420' 192.168.40.160
```

Then update DHCP pool to exclude 160-179:
```bash
sshpass -p 'PurpleLemur%420' ssh admin@192.168.40.1 \
  "/ip pool set dhcp_pool0 ranges=192.168.40.2-192.168.40.119,192.168.40.180-192.168.40.254"
```

## Scripts Available

### Main Scripts
1. **mikrotik_auto_dhcp.sh** - Create static DHCP reservations
   ```bash
   ./mikrotik_auto_dhcp.sh 192.168.40.1 admin 'PASSWORD' <START_IP>
   ```

2. **reconnect_adb.sh** - Reconnect to all 40 phones
   ```bash
   ./reconnect_adb.sh
   ```

3. **enable-adb-tcpip.sh** - Enable network ADB on USB-connected phones
   ```bash
   ./enable-adb-tcpip.sh
   ```

### Utility Scripts
- **fix_dhcp_leases.sh** - Clean all leases and reconfigure
- **force_ethernet_dhcp_renew.sh** - Force DHCP renewal via ethernet restart
- **force_dhcp_renew.sh** - Force renewal via airplane mode toggle
- **force_dhcp_renew_batch2.sh** - Fix batch 2 specific issues

## Workflow for Adding New Phones

### Step 1: Initial Setup (USB)
```bash
# Connect new phones via USB
./enable-adb-tcpip.sh
```

### Step 2: Create Static Reservations
```bash
# Disconnect all phones, connect new phones via ethernet
adb disconnect

# Wait for new phones to appear at random IPs
adb devices

# Create static reservations (adjust START_IP as needed)
./mikrotik_auto_dhcp.sh 192.168.40.1 admin 'PurpleLemur%420' 192.168.40.160
```

### Step 3: Update DHCP Pool
```bash
# Exclude the new static range from dynamic pool
# Example: If you assigned 160-179, exclude that range
sshpass -p 'PurpleLemur%420' ssh admin@192.168.40.1 \
  "/ip pool set dhcp_pool0 ranges=192.168.40.2-192.168.40.119,192.168.40.180-192.168.40.254"
```

### Step 4: Reboot Phones
```bash
# Physically reboot the new phones
# Wait 2 minutes
./reconnect_adb.sh
```

## Current Status

### Batch 1 (120-139)
- ✓ All 20 phones active and bound
- ✓ Using static IPs correctly
- ✓ Stable across reboots

### Batch 2 (140-159)
- ✓ Static reservations created
- ⏳ Waiting for phone reboot to activate
- ⏳ Currently at IPs 12-31 (will change after reboot)

## Next Steps

**For Batch 2:**
1. Reboot all 20 phones (currently at 192.168.40.12-31)
2. Wait 2 minutes for DHCP renewal
3. Run: `./reconnect_adb.sh`
4. Verify all 40 phones connected at correct IPs (120-159)

## Network Map

```
MikroTik Router: 192.168.40.1
Gateway: 192.168.40.1

Dynamic Pool (available for other devices):
├─ 192.168.40.2 - 192.168.40.119
└─ 192.168.40.160 - 192.168.40.254

Static Reservations (phones only):
├─ 192.168.40.120-139 → Batch 1 (20 Galaxy Z Flip4)
└─ 192.168.40.140-159 → Batch 2 (20 phones)

Other Static Devices:
├─ 192.168.40.5   → nixos-dev
├─ 192.168.40.8   → CN20KPDQB0
├─ 192.168.40.67  → CN20KPDQ4L
├─ 192.168.40.86  → Omni
├─ 192.168.40.92  → TNAS
├─ 192.168.40.228 → nixos
└─ 192.168.40.254 → nixos
```

## Troubleshooting

### Phones get wrong IPs after reboot
**Solution:** Check if DHCP pool excludes static ranges
```bash
sshpass -p 'PurpleLemur%420' ssh admin@192.168.40.1 "/ip pool print detail"
```
Should show: `ranges=192.168.40.2-192.168.40.119,192.168.40.160-192.168.40.254`

### Static lease shows "waiting" instead of "bound"
**Solution:** Phone hasn't requested DHCP yet, reboot the phone

### Can't connect via ADB after IP change
**Solution:**
```bash
adb disconnect
./reconnect_adb.sh
```

### Need to reset everything
**Solution:**
```bash
./fix_dhcp_leases.sh
# Then reboot all phones
```

## Files Modified

### Configuration Changes on MikroTik
- `/ip pool dhcp_pool0` - Ranges modified to exclude 120-159
- `/ip dhcp-server lease` - 40 static reservations added

### Scripts Created
All scripts located in: `/home/george/static/`

---

**Last Updated:** 2025-10-19
**Configuration Status:** ✓ Production Ready
