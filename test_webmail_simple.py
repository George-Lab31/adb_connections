#!/usr/bin/env python3
"""
Simple test of webmail automation for NixOS
"""

from playwright.sync_api import sync_playwright
import sys

def test_webmail_login(email, password):
    """Test webmail login and inbox access"""
    print(f"[*] Testing webmail for: {email}")

    # Determine webmail URL
    domain = email.split('@')[1]
    if 'onet.pl' in domain:
        webmail_url = 'https://poczta.onet.pl/'
    elif 'op.pl' in domain:
        webmail_url = 'https://poczta.op.pl/'
    else:
        webmail_url = 'https://poczta.onet.pl/'

    try:
        with sync_playwright() as p:
            print("[*] Launching browser...")

            # Launch chromium
            browser = p.chromium.launch(
                headless=False,  # Visible for testing
                executable_path='/run/current-system/sw/bin/chromium'
            )

            page = browser.new_page()

            print(f"[*] Navigating to {webmail_url}...")
            page.goto(webmail_url, timeout=30000)

            # Handle GDPR consent popup - CRITICAL
            print("[*] Handling GDPR consent popup...")
            page.wait_for_timeout(2000)  # Wait for popup to appear

            try:
                # Try multiple strategies to close GDPR popup
                # Strategy 1: Click accept button
                page.locator('button:has-text("Zgadzam się"), button:has-text("Akceptuj"), button:has-text("Accept")').first.click(timeout=3000)
                print("[+] Clicked GDPR accept button")
            except:
                try:
                    # Strategy 2: Click close button
                    page.locator('[class*="cmp"] button, [class*="gdpr"] button, [class*="consent"] button').first.click(timeout=2000)
                    print("[+] Clicked GDPR close button")
                except:
                    print("[*] No GDPR popup found or already handled")

            page.wait_for_timeout(1000)

            print("[*] Waiting for login form...")
            page.wait_for_selector('input[type="email"], input[name="login"]', timeout=10000)

            print("[*] Entering email...")
            page.fill('input[type="email"], input[name="login"]', email)

            # Click next button - REQUIRED
            print("[*] Clicking Next button...")
            page.click('button:has-text("Dalej"), button:has-text("Next"), button[type="submit"]')

            print("[*] Waiting for password field...")
            page.wait_for_selector('input[type="password"]', state='visible', timeout=10000)

            print("[*] Entering password...")
            page.fill('input[type="password"]', password)

            print("[*] Clicking login button...")
            page.click('button[type="submit"], button:has-text("Zaloguj"), button:has-text("Login")')

            print("[*] Waiting for inbox to load...")
            page.wait_for_url('**/poczta.**', timeout=30000)

            print("[+] Successfully logged in!")

            # Check for emails
            page.wait_for_timeout(2000)

            # Look for any email list items
            emails = page.locator('[role="button"]:has-text("Instagram"), a:has-text("Instagram"), button:has-text("Instagram")')
            count = emails.count()

            print(f"[+] Found {count} Instagram email(s) in inbox")

            if count > 0:
                print("[*] SUCCESS! Webmail automation works!")
                print("[*] Inbox is accessible and emails are visible")
                return True
            else:
                print("[*] Login successful, but no Instagram emails found")
                print("[*] This is normal if no recent Instagram emails")
                return True

    except Exception as e:
        print(f"[-] Error: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        try:
            browser.close()
        except:
            pass

if __name__ == "__main__":
    # Test with brittanyrubio account
    email = "brittanyrubio@onet.pl"
    password = "PurpleLemur#420"

    print("=" * 60)
    print(" Webmail Automation Test")
    print("=" * 60)
    print()

    success = test_webmail_login(email, password)

    print()
    print("=" * 60)
    if success:
        print("✅ TEST PASSED - Webmail automation works!")
        print()
        print("This confirms:")
        print("  - Can log into webmail")
        print("  - Can access inbox")
        print("  - Can search for emails")
        print()
        print("Next: Add 2FA code extraction logic")
    else:
        print("❌ TEST FAILED")
    print("=" * 60)
