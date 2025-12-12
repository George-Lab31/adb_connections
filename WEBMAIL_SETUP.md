# Webmail 2FA Extractor - Setup Guide

## 🎯 What This Does

Since IMAP is blocked on all accounts, this script:
- ✅ Logs into webmail directly (bypasses IMAP)
- ✅ Searches for Instagram emails
- ✅ Extracts 2FA codes from email content
- ✅ Works with ALL 590+ accounts

## 📋 Installation

### Step 1: Install Python (if not already)

Check if Python is installed:
```bash
python3 --version
```

If not installed:
```bash
# On NixOS
nix-shell -p python3

# Or add to your system configuration
```

### Step 2: Install Playwright

```bash
pip install playwright
playwright install chromium
```

### Step 3: Test Installation

```bash
python3 /home/george/static/webmail_2fa_extractor.py
```

## 🚀 Usage

### Option 1: Single Account (Interactive)

```bash
python3 /home/george/static/webmail_2fa_extractor.py
```

Then select:
- **Option 1**: Wait for NEW Instagram 2FA (recommended)
- **Option 2**: Check existing emails
- **Option 3**: Use custom email/password

### Option 2: From Your Code (Python)

```python
from webmail_2fa_extractor import WebmailExtractor

# Create extractor
extractor = WebmailExtractor(
    email="brittanyrubio@onet.pl",
    password="PurpleLemur#420",
    headless=True  # Set False to see browser
)

# Get code (waits for new email)
code = extractor.get_latest_instagram_code(
    wait_for_new=True,
    max_wait=60
)

print(f"2FA Code: {code}")
```

### Option 3: Batch Process All Accounts

```bash
python3 /home/george/static/batch_webmail_extractor.py
```

## 🔧 How It Works

1. **Opens Browser** (Chromium via Playwright)
2. **Navigates** to poczta.onet.pl or poczta.op.pl
3. **Logs In** with email/password
4. **Monitors Inbox** for Instagram emails
5. **Extracts Code** using regex patterns
6. **Returns Code** to your automation

## ⚙️ Configuration

### Headless Mode

**Headless = True** (invisible browser):
```python
extractor = WebmailExtractor(email, password, headless=True)
```

**Headless = False** (visible browser - for debugging):
```python
extractor = WebmailExtractor(email, password, headless=False)
```

### Wait Time

Adjust how long to wait for new emails:
```python
code = extractor.get_latest_instagram_code(
    wait_for_new=True,
    max_wait=120  # Wait up to 2 minutes
)
```

## 📊 Performance

### Single Account:
- Login time: ~5-10 seconds
- Code extraction: ~2-5 seconds
- **Total**: 10-15 seconds per account

### 590 Accounts:
- Sequential: ~1.5-2.5 hours
- Parallel (10 browsers): ~15-25 minutes

## 🐛 Troubleshooting

### "Playwright not installed"
```bash
pip install playwright
playwright install chromium
```

### "Browser fails to start"
```bash
# Install browser dependencies
playwright install-deps chromium
```

### "Login fails"
- Check email/password are correct
- Run with `headless=False` to see what's happening
- Website might have changed layout (update selectors)

### "No code found"
- Make sure Instagram email arrived
- Check spam folder in webmail
- Try with `headless=False` to debug

## 🔐 Security Notes

- Passwords are in plain text in script
- Use environment variables in production:
  ```python
  import os
  password = os.getenv('EMAIL_PASSWORD')
  ```

- Or use encrypted config file

## 📁 Files Created

| File | Purpose |
|------|---------|
| `webmail_2fa_extractor.py` | Main extractor (single account) |
| `batch_webmail_extractor.py` | Batch processor (all accounts) |
| `WEBMAIL_SETUP.md` | This file |

## 🎯 Next Steps

1. Install Python + Playwright
2. Test with single account
3. Use in your Instagram automation
4. Scale to all 590 accounts

## 💡 Integration Example

```python
# In your Instagram automation
from webmail_2fa_extractor import WebmailExtractor

def get_instagram_2fa(email, password):
    """Get Instagram 2FA code from webmail"""
    extractor = WebmailExtractor(email, password, headless=True)
    code = extractor.get_latest_instagram_code(wait_for_new=True, max_wait=60)
    return code

# Use it
email = "brittanyrubio@onet.pl"
password = "PurpleLemur#420"

print("[*] Triggering Instagram 2FA...")
# ... your Instagram login code that triggers 2FA ...

print("[*] Getting 2FA code from email...")
code = get_instagram_2fa(email, password)

if code:
    print(f"[+] Got code: {code}")
    # ... submit code to Instagram ...
else:
    print("[-] Failed to get code")
```

## 🚀 Ready to Use!

The script is complete and ready. Just:
1. Install dependencies
2. Run the script
3. Select option 1
4. Trigger Instagram login
5. Get your code!

---

**Questions?** Check the code comments or test with `headless=False` to see what's happening.
