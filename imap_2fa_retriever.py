#!/usr/bin/env python3
"""
IMAP 2FA Code Retriever for Instagram
Connects to onet.pl email account and retrieves Instagram 2FA codes
"""

import imaplib
import email
from email.header import decode_header
import re
import time
from datetime import datetime, timedelta
import sys

class IMAP2FARetriever:
    def __init__(self, email_address, password):
        self.email_address = email_address
        self.password = password
        self.imap_server = "imap.poczta.onet.pl"
        self.imap_port = 993
        self.imap = None

    def connect(self):
        """Connect to IMAP server"""
        try:
            print(f"[*] Connecting to {self.imap_server}:{self.imap_port}...")
            self.imap = imaplib.IMAP4_SSL(self.imap_server, self.imap_port)
            print("[+] Connected to server")

            print(f"[*] Logging in as {self.email_address}...")
            self.imap.login(self.email_address, self.password)
            print("[+] Successfully logged in!")
            return True

        except imaplib.IMAP4.error as e:
            print(f"[-] IMAP login failed: {e}")
            return False
        except Exception as e:
            print(f"[-] Connection error: {e}")
            return False

    def select_mailbox(self, mailbox="INBOX"):
        """Select a mailbox"""
        try:
            status, messages = self.imap.select(mailbox)
            if status == "OK":
                num_messages = int(messages[0])
                print(f"[+] Selected {mailbox} - {num_messages} total messages")
                return True
            return False
        except Exception as e:
            print(f"[-] Error selecting mailbox: {e}")
            return False

    def decode_mime_header(self, header):
        """Decode MIME encoded email headers"""
        if header is None:
            return ""
        decoded_parts = decode_header(header)
        result = []
        for part, encoding in decoded_parts:
            if isinstance(part, bytes):
                result.append(part.decode(encoding or 'utf-8', errors='ignore'))
            else:
                result.append(str(part))
        return ''.join(result)

    def extract_instagram_code(self, email_message):
        """Extract Instagram 2FA code from email message"""
        # Common patterns for Instagram 2FA codes
        patterns = [
            r'\b(\d{6})\b',  # 6-digit code
            r'code is:?\s*(\d{6})',
            r'verification code:?\s*(\d{6})',
            r'security code:?\s*(\d{6})',
            r'Instagram:?\s*(\d{6})',
        ]

        body = ""

        # Extract email body
        if email_message.is_multipart():
            for part in email_message.walk():
                content_type = part.get_content_type()
                if content_type == "text/plain":
                    try:
                        payload = part.get_payload(decode=True)
                        if payload:
                            body += payload.decode('utf-8', errors='ignore')
                    except:
                        pass
                elif content_type == "text/html":
                    try:
                        payload = part.get_payload(decode=True)
                        if payload:
                            html_body = payload.decode('utf-8', errors='ignore')
                            # Remove HTML tags for searching
                            clean_html = re.sub('<[^<]+?>', ' ', html_body)
                            body += clean_html
                    except:
                        pass
        else:
            try:
                payload = email_message.get_payload(decode=True)
                if payload:
                    body = payload.decode('utf-8', errors='ignore')
            except:
                pass

        # Search for code using patterns
        for pattern in patterns:
            matches = re.findall(pattern, body, re.IGNORECASE)
            if matches:
                return matches[0]

        return None

    def get_instagram_2fa_code(self, max_wait_seconds=60, check_interval=5):
        """
        Wait for and retrieve Instagram 2FA code from email

        Args:
            max_wait_seconds: Maximum time to wait for new email (default 60 seconds)
            check_interval: Time between checks in seconds (default 5 seconds)
        """
        print(f"[*] Searching for Instagram 2FA emails...")

        # Search criteria for Instagram emails
        search_criteria = [
            '(FROM "Instagram")',
            '(FROM "instagram.com")',
            '(FROM "security@mail.instagram.com")',
        ]

        start_time = time.time()
        last_checked_uids = set()

        while (time.time() - start_time) < max_wait_seconds:
            try:
                # Check each search criteria
                for criteria in search_criteria:
                    # Search for recent emails (last 5 minutes)
                    since_date = (datetime.now() - timedelta(minutes=5)).strftime("%d-%b-%Y")
                    search = f'{criteria} SINCE {since_date}'

                    status, messages = self.imap.search(None, search)

                    if status != "OK" or not messages[0]:
                        continue

                    # Get list of email UIDs
                    email_uids = messages[0].split()

                    # Process only new emails
                    new_uids = [uid for uid in email_uids if uid not in last_checked_uids]

                    if not new_uids:
                        continue

                    # Check newest emails first
                    for uid in reversed(new_uids):
                        last_checked_uids.add(uid)

                        status, msg_data = self.imap.fetch(uid, "(RFC822)")

                        if status != "OK":
                            continue

                        # Parse email
                        email_message = email.message_from_bytes(msg_data[0][1])

                        # Get email details
                        subject = self.decode_mime_header(email_message["Subject"])
                        from_addr = self.decode_mime_header(email_message["From"])
                        date = email_message["Date"]

                        print(f"[*] Found email from: {from_addr}")
                        print(f"    Subject: {subject}")
                        print(f"    Date: {date}")

                        # Extract 2FA code
                        code = self.extract_instagram_code(email_message)

                        if code:
                            print(f"[+] Found Instagram 2FA code: {code}")
                            return code
                        else:
                            print(f"[-] No 2FA code found in this email")

                # Wait before checking again
                elapsed = time.time() - start_time
                remaining = max_wait_seconds - elapsed

                if remaining > 0:
                    wait_time = min(check_interval, remaining)
                    print(f"[*] No new codes found. Waiting {wait_time:.0f}s... ({remaining:.0f}s remaining)")
                    time.sleep(wait_time)

            except Exception as e:
                print(f"[-] Error during search: {e}")
                time.sleep(check_interval)

        print(f"[-] Timeout: No Instagram 2FA code found after {max_wait_seconds} seconds")
        return None

    def list_recent_emails(self, limit=10):
        """List recent emails for debugging"""
        try:
            print(f"[*] Fetching last {limit} emails...")

            status, messages = self.imap.search(None, "ALL")
            if status != "OK":
                print("[-] Failed to search messages")
                return

            email_uids = messages[0].split()

            if not email_uids:
                print("[-] No emails found in mailbox")
                return

            # Get the last N emails
            recent_uids = email_uids[-limit:]

            for i, uid in enumerate(reversed(recent_uids), 1):
                status, msg_data = self.imap.fetch(uid, "(RFC822)")

                if status != "OK":
                    continue

                email_message = email.message_from_bytes(msg_data[0][1])

                subject = self.decode_mime_header(email_message["Subject"])
                from_addr = self.decode_mime_header(email_message["From"])
                date = email_message["Date"]

                print(f"\n[{i}] {from_addr}")
                print(f"    Subject: {subject}")
                print(f"    Date: {date}")

        except Exception as e:
            print(f"[-] Error listing emails: {e}")

    def disconnect(self):
        """Disconnect from IMAP server"""
        if self.imap:
            try:
                self.imap.close()
                self.imap.logout()
                print("[+] Disconnected from server")
            except:
                pass


def main():
    # Configuration
    EMAIL = "brittanyrubio@onet.pl"
    PASSWORD = "PurpleLemur#420"

    print("=" * 60)
    print("Instagram 2FA Code Retriever for onet.pl")
    print("=" * 60)

    # Create retriever instance
    retriever = IMAP2FARetriever(EMAIL, PASSWORD)

    # Connect to IMAP server
    if not retriever.connect():
        print("\n[-] Failed to connect. Please check:")
        print("    1. Email address is correct")
        print("    2. Password is correct")
        print("    3. IMAP is enabled in onet.pl settings")
        print("    4. No firewall blocking port 993")
        sys.exit(1)

    # Select INBOX
    if not retriever.select_mailbox("INBOX"):
        print("[-] Failed to select INBOX")
        retriever.disconnect()
        sys.exit(1)

    # Show menu
    print("\n" + "=" * 60)
    print("Select an option:")
    print("1. Wait for new Instagram 2FA code (60 seconds)")
    print("2. Search existing emails for 2FA code")
    print("3. List recent 10 emails")
    print("4. Exit")
    print("=" * 60)

    try:
        choice = input("\nEnter choice (1-4): ").strip()

        if choice == "1":
            print("\n[*] Monitoring for new Instagram 2FA emails...")
            print("[*] Trigger Instagram 2FA now!")
            code = retriever.get_instagram_2fa_code(max_wait_seconds=60, check_interval=5)
            if code:
                print(f"\n{'=' * 60}")
                print(f"SUCCESS! Your Instagram 2FA code is: {code}")
                print(f"{'=' * 60}")
            else:
                print("\n[-] No code found. Try option 2 to check existing emails.")

        elif choice == "2":
            print("\n[*] Searching existing emails...")
            code = retriever.get_instagram_2fa_code(max_wait_seconds=5, check_interval=1)
            if code:
                print(f"\n{'=' * 60}")
                print(f"SUCCESS! Your Instagram 2FA code is: {code}")
                print(f"{'=' * 60}")
            else:
                print("\n[-] No code found in recent emails.")

        elif choice == "3":
            retriever.list_recent_emails(limit=10)

        elif choice == "4":
            print("[*] Exiting...")

        else:
            print("[-] Invalid choice")

    except KeyboardInterrupt:
        print("\n[*] Interrupted by user")
    except Exception as e:
        print(f"[-] Error: {e}")
    finally:
        retriever.disconnect()


if __name__ == "__main__":
    main()
