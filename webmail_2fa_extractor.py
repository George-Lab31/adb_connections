#!/usr/bin/env python3
"""
Webmail 2FA Code Extractor
Uses Playwright to extract Instagram 2FA codes from Onet.pl/Op.pl webmail
Bypasses IMAP entirely by accessing webmail directly
"""

import re
import sys
import time
from datetime import datetime

try:
    from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout
except ImportError:
    print("ERROR: Playwright not installed!")
    print("Install with: pip install playwright")
    print("Then run: playwright install chromium")
    sys.exit(1)


class WebmailExtractor:
    def __init__(self, email, password, headless=True):
        self.email = email
        self.password = password
        self.headless = headless
        self.domain = email.split('@')[1]

        # Determine webmail URL based on domain
        if 'onet.pl' in self.domain:
            self.webmail_url = 'https://poczta.onet.pl/'
        elif 'op.pl' in self.domain:
            self.webmail_url = 'https://poczta.op.pl/'
        else:
            self.webmail_url = 'https://poczta.onet.pl/'

        self.browser = None
        self.page = None
        self.context = None

    def start_browser(self):
        """Initialize Playwright browser"""
        print(f"[*] Starting browser (headless={self.headless})...")
        self.playwright = sync_playwright().start()
        self.browser = self.playwright.chromium.launch(headless=self.headless)
        self.context = self.browser.new_context(
            viewport={'width': 1280, 'height': 720},
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        )
        self.page = self.context.new_page()
        print("[+] Browser started")

    def login(self):
        """Log into webmail"""
        print(f"[*] Navigating to {self.webmail_url}...")
        self.page.goto(self.webmail_url, wait_until='networkidle', timeout=30000)

        print(f"[*] Logging in as {self.email}...")

        try:
            # Wait for email input
            self.page.wait_for_selector('input[name="login"], input[type="email"], input#login', timeout=10000)

            # Enter email
            email_input = self.page.locator('input[name="login"], input[type="email"], input#login').first
            email_input.fill(self.email)
            print("[+] Email entered")

            # Click next/continue button if it exists
            try:
                next_button = self.page.locator('button:has-text("Dalej"), button:has-text("Next"), button[type="submit"]').first
                next_button.click()
                time.sleep(1)
            except:
                pass

            # Enter password
            password_input = self.page.locator('input[type="password"], input[name="password"]').first
            password_input.wait_for(timeout=5000)
            password_input.fill(self.password)
            print("[+] Password entered")

            # Click login button
            login_button = self.page.locator('button:has-text("Zaloguj"), button:has-text("Login"), button[type="submit"]').first
            login_button.click()
            print("[*] Logging in...")

            # Wait for inbox to load
            self.page.wait_for_url('**/poczta.**', timeout=30000)
            print("[+] Successfully logged in!")

            # Handle any "trust device" prompts
            try:
                skip_button = self.page.locator('button:has-text("Pomiń"), button:has-text("Skip"), button:has-text("Przypomnij")').first
                skip_button.click(timeout=3000)
                print("[+] Skipped trust device prompt")
            except:
                pass

            return True

        except Exception as e:
            print(f"[-] Login failed: {e}")
            return False

    def search_instagram_emails(self, max_wait=60):
        """Search for Instagram 2FA emails"""
        print(f"[*] Searching for Instagram 2FA emails (max {max_wait}s)...")

        start_time = time.time()

        while (time.time() - start_time) < max_wait:
            try:
                # Look for Instagram emails in the inbox
                # Check email list for Instagram sender
                instagram_emails = self.page.locator('[role="button"], button, a').filter(has_text='Instagram')

                count = instagram_emails.count()

                if count > 0:
                    print(f"[+] Found {count} Instagram email(s)")

                    # Click the first (most recent) one
                    instagram_emails.first.click()
                    time.sleep(2)

                    # Get email content
                    email_content = self.page.content()

                    # Extract 2FA code
                    code = self.extract_code_from_content(email_content)

                    if code:
                        return code
                    else:
                        print("[-] No code found in email, checking next...")
                        # Try next email if available
                        if count > 1:
                            # Go back to list
                            try:
                                self.page.go_back()
                                time.sleep(1)
                            except:
                                pass

                # Wait a bit before checking again
                elapsed = time.time() - start_time
                remaining = max_wait - elapsed

                if remaining > 0:
                    print(f"[*] No new Instagram email yet, waiting... ({remaining:.0f}s remaining)")
                    time.sleep(5)

                    # Refresh inbox
                    try:
                        self.page.reload()
                        time.sleep(2)
                    except:
                        pass
                else:
                    break

            except Exception as e:
                print(f"[-] Error searching emails: {e}")
                time.sleep(5)

        print("[-] Timeout: No Instagram 2FA code found")
        return None

    def extract_code_from_content(self, html_content):
        """Extract 6-digit code from email HTML"""
        print("[*] Extracting 2FA code from email content...")

        # Common patterns for Instagram 2FA codes
        patterns = [
            r'\b(\d{6})\b',  # Any 6-digit number
            r'code is:?\s*(\d{6})',
            r'verification code:?\s*(\d{6})',
            r'security code:?\s*(\d{6})',
            r'Instagram.*?(\d{6})',
            r'confirm your identity:?\s*(\d{6})',
        ]

        # Remove HTML tags for easier searching
        text = re.sub('<[^<]+?>', ' ', html_content)

        # Try each pattern
        for pattern in patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            if matches:
                # Filter out common non-code numbers (like years, etc.)
                for match in matches:
                    code = match
                    # Basic validation: should be 6 digits
                    if len(code) == 6 and code.isdigit():
                        # Not a year
                        if not (code.startswith('19') or code.startswith('20')):
                            print(f"[+] Found code: {code}")
                            return code

        print("[-] No valid 6-digit code found in email")
        return None

    def get_latest_instagram_code(self, wait_for_new=True, max_wait=60):
        """
        Get the latest Instagram 2FA code

        Args:
            wait_for_new: If True, wait for a new email. If False, check existing.
            max_wait: Maximum seconds to wait for new email
        """
        try:
            self.start_browser()

            if not self.login():
                return None

            # Give inbox time to fully load
            time.sleep(3)

            if wait_for_new:
                print(f"[*] Monitoring inbox for NEW Instagram 2FA email...")
                print(f"[*] Trigger Instagram login now!")
                code = self.search_instagram_emails(max_wait=max_wait)
            else:
                print(f"[*] Checking existing emails...")
                code = self.search_instagram_emails(max_wait=10)

            return code

        except Exception as e:
            print(f"[-] Error: {e}")
            import traceback
            traceback.print_exc()
            return None

        finally:
            self.cleanup()

    def cleanup(self):
        """Close browser and cleanup"""
        if self.page:
            try:
                self.page.close()
            except:
                pass

        if self.context:
            try:
                self.context.close()
            except:
                pass

        if self.browser:
            try:
                self.browser.close()
            except:
                pass

        if hasattr(self, 'playwright'):
            try:
                self.playwright.stop()
            except:
                pass

        print("[+] Browser closed")


def main():
    """Main function for CLI usage"""
    print("=" * 60)
    print(" Webmail Instagram 2FA Code Extractor")
    print("=" * 60)
    print()

    # Example usage with your account
    email = "brittanyrubio@onet.pl"
    password = "PurpleLemur#420"

    print(f"Email: {email}")
    print()
    print("Options:")
    print("1. Wait for NEW Instagram 2FA email (60 seconds)")
    print("2. Check existing emails for 2FA code")
    print("3. Custom email/password")
    print("4. Exit")
    print()

    choice = input("Select option (1-4): ").strip()

    if choice == "1":
        print()
        print("[*] Will monitor for new Instagram 2FA email")
        print("[*] TRIGGER INSTAGRAM LOGIN NOW!")
        print()

        extractor = WebmailExtractor(email, password, headless=False)
        code = extractor.get_latest_instagram_code(wait_for_new=True, max_wait=60)

        if code:
            print()
            print("=" * 60)
            print(f"   SUCCESS! Instagram 2FA Code: {code}")
            print("=" * 60)
        else:
            print()
            print("[-] Failed to extract code")

    elif choice == "2":
        print()
        print("[*] Checking existing emails...")
        print()

        extractor = WebmailExtractor(email, password, headless=False)
        code = extractor.get_latest_instagram_code(wait_for_new=False, max_wait=10)

        if code:
            print()
            print("=" * 60)
            print(f"   Instagram 2FA Code: {code}")
            print("=" * 60)
        else:
            print()
            print("[-] No code found in recent emails")

    elif choice == "3":
        print()
        custom_email = input("Enter email: ").strip()
        custom_password = input("Enter password: ").strip()

        print()
        print("[*] Monitoring for Instagram 2FA email...")
        print()

        extractor = WebmailExtractor(custom_email, custom_password, headless=False)
        code = extractor.get_latest_instagram_code(wait_for_new=True, max_wait=60)

        if code:
            print()
            print("=" * 60)
            print(f"   Instagram 2FA Code: {code}")
            print("=" * 60)
        else:
            print()
            print("[-] Failed to extract code")

    elif choice == "4":
        print("Goodbye!")
        sys.exit(0)

    else:
        print("Invalid option")


if __name__ == "__main__":
    main()
