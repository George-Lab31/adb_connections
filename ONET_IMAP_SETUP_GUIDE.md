# Onet.pl IMAP 2FA Setup Guide

## Current Status: Authentication Failing

The IMAP connection to `brittanyrubio@onet.pl` is currently failing with authentication errors.

**What we tested:**
- ✅ Connection to imap.poczta.onet.pl:993 works
- ✅ SSL certificate is valid
- ✅ Server supports IMAP and responds correctly
- ❌ Authentication fails for both IMAP and POP3

## Why Is This Happening?

Onet.pl likely requires you to **enable external mail client access** or use an **app-specific password** for security reasons. Even though you can log in via webmail, external IMAP/POP3 clients may be blocked by default.

## Steps to Fix

### Step 1: Enable IMAP Access in Onet.pl Settings

1. **Go to Onet.pl webmail:**
   - Visit: https://poczta.onet.pl/
   - Log in with: `brittanyrubio@onet.pl` and `PurpleLemur#420`

2. **Navigate to Settings:**
   - Look for "Ustawienia" (Settings) - usually in top right corner
   - Go to "Bezpieczeństwo" (Security) or "Konta zewnętrzne" (External accounts)

3. **Enable IMAP/POP3 Access:**
   - Look for one of these options:
     - "Dostęp IMAP/POP3" (IMAP/POP3 Access)
     - "Klienty poczty zewnętrznej" (External mail clients)
     - "Dostęp dla aplikacji" (App access)
   - **Enable it** if it's currently disabled

### Step 2: Check for App-Specific Passwords

Some email providers require app-specific passwords for security. Check if onet.pl offers this:

1. In Settings → Security, look for:
   - "Hasła aplikacji" (App passwords)
   - "Hasła dla programów pocztowych" (Mail client passwords)

2. If available:
   - Generate a new app-specific password
   - **IMPORTANT:** Copy this password
   - Update the script with this new password instead of your main password

### Step 3: Check Two-Factor Authentication (2FA)

1. In Settings → Security, check if 2FA is enabled on your email account
2. If enabled, you **must** use an app-specific password (see Step 2)

### Step 4: Alternative - Check POP3 Settings

If IMAP settings are not available, check for POP3 settings:
- They might be in the same location as IMAP settings
- Enabling one usually enables both

## Common Setting Locations in Onet.pl

Based on similar Polish email services, try these paths:

1. **Ustawienia → Ogólne → Dostęp IMAP/POP3**
   (Settings → General → IMAP/POP3 Access)

2. **Ustawienia → Bezpieczeństwo → Aplikacje zewnętrzne**
   (Settings → Security → External applications)

3. **Ustawienia → Konto → Klienty pocztowe**
   (Settings → Account → Mail clients)

## After Enabling IMAP Access

Once you've enabled IMAP access or generated an app password:

### If you generated an app-specific password:

Edit the script at `/home/george/static/onet_imap_2fa.sh` and update line 10:

```bash
PASSWORD="YOUR_APP_SPECIFIC_PASSWORD_HERE"
```

### Test the connection:

```bash
./onet_imap_2fa.sh
```

Select option 1 to test the IMAP connection.

## Using the Script

Once authentication works, the script offers several options:

### Option 1: Test Connection
- Verifies IMAP credentials work
- Shows message count

### Option 2: Monitor for New 2FA Code (Recommended)
- Waits for new Instagram 2FA email (60 seconds)
- Automatically extracts the 6-digit code
- **Usage:**
  1. Run the script and select option 2
  2. Trigger Instagram 2FA login
  3. Wait for the code to appear

### Option 3: Fetch Latest Email
- Retrieves the most recent email
- Attempts to extract 2FA code
- Useful if you already received the email

### Option 4: List Recent Emails
- Shows last 5 emails for debugging
- Helps verify emails are being received

## Alternative: Manual Web Access

If IMAP cannot be enabled, you can:

1. Use webmail (https://poczta.onet.pl/)
2. Manually check for Instagram emails
3. Copy the 2FA code from there

## Troubleshooting

### Still getting authentication errors?

1. **Double-check credentials:**
   - Email: `brittanyrubio@onet.pl`
   - Password: Make sure special characters are correct

2. **Check for account lockout:**
   - Too many failed login attempts might temporarily lock the account
   - Wait 15-30 minutes before trying again

3. **Contact Onet.pl support:**
   - If settings don't have IMAP options
   - They might need to enable it on their end

### Alternative protocols:

If IMAP doesn't work, we can try:
- **POP3:** pop3.poczta.onet.pl:995
- **Webmail scraping:** Using curl to access web interface

## Technical Details

**IMAP Server Settings:**
- Server: `imap.poczta.onet.pl`
- Port: 993
- Security: SSL/TLS
- Authentication: PLAIN, LOGIN, XOAUTH2

**Current Error:**
```
< A002 NO [AUTHENTICATIONFAILED] Authentication failed.
```

This is a server-side rejection, not a connection issue, confirming it's a credentials/permissions problem.

## Next Steps

1. ✅ Log into https://poczta.onet.pl/
2. ✅ Enable IMAP access in settings
3. ✅ Generate app password if required
4. ✅ Update script with app password (if needed)
5. ✅ Run `./onet_imap_2fa.sh` to test

---

**Need help?** Let me know what you see in the Onet.pl settings and we can adjust the approach.
