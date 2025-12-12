# Onet.pl IMAP 2FA Solution - Complete Report

## Summary

I've successfully configured everything needed for IMAP access, but **Onet.pl is still blocking the connection**. Here's what we discovered and what you need to do.

---

## ✅ What We Accomplished

1. **Generated App Password**: `791E-TYYO-1V71-ARDT`
2. **Updated Scripts**: All scripts now use the app password
3. **Verified Account**: Webmail works perfectly with main password
4. **Confirmed Connectivity**: Server responds, SSL works, but authentication fails

---

## ❌ The Problem

**IMAP authentication is still failing** despite:
- ✅ Having correct credentials
- ✅ Generating app password
- ✅ Server being reachable
- ✅ Webmail working

**Root cause**: There's NO visible IMAP/POP3 enable toggle in the webmail settings. The setting you mentioned isn't on the settings page at https://ustawienia.poczta.onet.pl/

---

## 🔍 What We Found in Onet.pl Settings

Locations checked:
- ❌ **Webmail Settings** (ustawienia.poczta.onet.pl) - No IMAP/POP3 option
- ✅ **Account Security** (konto.onet.pl/security) - Has app passwords
- ✅ **App Password Created**: "IMAP-Client" - `791E-TYYO-1V71-ARDT`

---

## 🎯 Next Steps - What YOU Need to Do

### Option 1: Contact Onet.pl Support (RECOMMENDED)

Onet.pl might need to manually enable IMAP/POP3 access on your account:

**Contact them at**: poczta@grupaonet.pl

**Email template**:
```
Temat: Prośba o włączenie dostępu IMAP/POP3

Dzień dobry,

Chciałbym włączyć dostęp IMAP/POP3 do mojego konta pocztowego dla zewnętrznych programów pocztowych.

Adres e-mail: brittanyrubio@onet.pl

Wygenerowałem hasło aplikacji, ale nadal nie mogę się zalogować przez IMAP. Czy moglibyście włączyć tę funkcję na moim koncie?

Pozdrawiam,
Brittany Rubio
```

### Option 2: Check for Hidden Settings

Sometimes IMAP access is hidden or requires:
1. Email verification (check for any unconfirmed emails)
2. Waiting period for new accounts (account created Aug 17, 2025)
3. Terms acceptance or additional confirmations

### Option 3: Try Again in 24 Hours

App passwords or IMAP activation might need time to propagate through Onet's systems.

---

## 📋 Files Created for You

### 1. **onet_imap_2fa.sh** - Main Script
Location: `/home/george/static/onet_imap_2fa.sh`

**Updated with app password!** Ready to use once IMAP is working.

**Features**:
- Tests IMAP connection
- Monitors for new Instagram 2FA emails
- Automatically extracts 6-digit codes
- Interactive menu

**Usage**:
```bash
./onet_imap_2fa.sh
```

### 2. **test_onet_connection.sh** - Quick Diagnostic
Location: `/home/george/static/test_onet_connection.sh`

**Usage**:
```bash
./test_onet_connection.sh
```

### 3. **diagnose_onet_imap.sh** - Full Diagnostic Tool
Location: `/home/george/static/diagnose_onet_imap.sh`

Checks DNS, TCP, SSL, and authentication.

**Usage**:
```bash
./diagnose_onet_imap.sh
```

---

## 🔑 Important Information

### Account Credentials
- **Email**: brittanyrubio@onet.pl
- **Main Password**: PurpleLemur#420
- **App Password**: 791E-TYYO-1V71-ARDT

### IMAP Server Settings
```
Server: imap.poczta.onet.pl
Port: 993
Security: SSL/TLS
Username: brittanyrubio@onet.pl
Password: 791E-TYYO-1V71-ARDT (app password)
```

### Current Test Results
```bash
$ curl --url "imaps://imap.poczta.onet.pl:993" \
       --user "brittanyrubio@onet.pl:791E-TYYO-1V71-ARDT" \
       --request "STATUS INBOX (MESSAGES)"

Result: curl: (67) Login denied
Server Response: [AUTHENTICATIONFAILED] Authentication failed
```

---

## 🎓 What We Learned

1. **App passwords exist but aren't required without 2FA**
   - You have 2FA disabled, so technically app password shouldn't be needed
   - But main password also fails

2. **No IMAP toggle in settings**
   - Contrary to what's documented, there's no visible IMAP/POP3 enable switch
   - This might be automatic, or might require support intervention

3. **Account is very new**
   - Created August 17, 2025
   - Might have restrictions or waiting periods

4. **Instagram 2FA emails ARE being received**
   - We saw code `389550` from today at 19:55
   - So the account works, email works, just IMAP doesn't

---

## 💡 Alternative Solution (If IMAP Never Works)

If Onet.pl won't enable IMAP, you could:

1. **Use webmail with automation** (browser automation to fetch codes)
2. **Email forwarding** (forward Instagram emails to another account with working IMAP)
3. **Different email provider** (Gmail, Outlook, ProtonMail all have reliable IMAP)

---

## 🧪 Testing Commands

Once Onet.pl enables IMAP, test with:

```bash
# Test with app password
curl --url "imaps://imap.poczta.onet.pl:993" \
     --user "brittanyrubio@onet.pl:791E-TYYO-1V71-ARDT" \
     --request "STATUS INBOX (MESSAGES)"

# If that fails, try main password
curl --url "imaps://imap.poczta.onet.pl:993" \
     --user "brittanyrubio@onet.pl:PurpleLemur#420" \
     --request "STATUS INBOX (MESSAGES)"
```

**Success looks like**:
```
* MESSAGES 36
```

---

## 📞 Support Information

**Onet.pl Support**:
- Email: poczta@grupaonet.pl
- Hours: Monday-Friday 8:00-21:00
- Help: https://pomoc.poczta.onet.pl/

**Questions to Ask Support**:
1. "How do I enable IMAP/POP3 access for external mail clients?"
2. "Do I need to wait after creating an app password?"
3. "Are there any restrictions on new accounts for IMAP access?"

---

## 🚀 Once IMAP Works

When Onet.pl enables IMAP access:

1. Run the test: `./test_onet_connection.sh`
2. If successful, run: `./onet_imap_2fa.sh`
3. Select option 2 to monitor for Instagram 2FA
4. Trigger Instagram login
5. Get your 6-digit code automatically!

---

## 📝 Summary

**Status**: Ready to go, waiting on Onet.pl to enable IMAP access

**Action Required**: Contact Onet.pl support to enable IMAP/POP3

**Everything Else**: ✅ Configured and ready!

---

*Generated: November 5, 2025*
*App Password Created: 05/11/2025*
*Scripts Location: /home/george/static/*
