#!/usr/bin/env python3
"""
Batch Webmail 2FA Extractor
Processes multiple accounts from CSV for Instagram 2FA codes
"""

import csv
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from webmail_2fa_extractor import WebmailExtractor


def process_account(email, password, account_number, total_accounts):
    """Process a single account to get 2FA code"""
    print(f"\n[{account_number}/{total_accounts}] Processing: {email}")
    print("=" * 60)

    try:
        extractor = WebmailExtractor(email, password, headless=True)
        code = extractor.get_latest_instagram_code(wait_for_new=False, max_wait=10)

        if code:
            result = {
                'email': email,
                'code': code,
                'status': 'SUCCESS',
                'error': None
            }
            print(f"[+] {email}: Code = {code}")
        else:
            result = {
                'email': email,
                'code': None,
                'status': 'NO_CODE',
                'error': 'No Instagram email found'
            }
            print(f"[-] {email}: No code found")

        return result

    except Exception as e:
        result = {
            'email': email,
            'code': None,
            'status': 'ERROR',
            'error': str(e)
        }
        print(f"[-] {email}: Error - {e}")
        return result


def process_sequential(csv_file, max_accounts=None):
    """Process accounts one by one (slower but more reliable)"""
    print("=" * 60)
    print(" Batch Webmail 2FA Extractor - Sequential Mode")
    print("=" * 60)
    print()

    results = []
    processed = 0

    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        accounts = list(reader)

        if max_accounts:
            accounts = accounts[:max_accounts]

        total = len(accounts)

        for idx, row in enumerate(accounts, 1):
            email = row['email']
            password = row['password']

            result = process_account(email, password, idx, total)
            results.append(result)
            processed += 1

            # Small delay between accounts
            if idx < total:
                time.sleep(2)

    return results


def process_parallel(csv_file, max_accounts=None, max_workers=5):
    """Process accounts in parallel (faster but more resource intensive)"""
    print("=" * 60)
    print(f" Batch Webmail 2FA Extractor - Parallel Mode ({max_workers} workers)")
    print("=" * 60)
    print()

    results = []

    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        accounts = list(reader)

        if max_accounts:
            accounts = accounts[:max_accounts]

        total = len(accounts)

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = []

            for idx, row in enumerate(accounts, 1):
                email = row['email']
                password = row['password']

                future = executor.submit(process_account, email, password, idx, total)
                futures.append(future)

            for future in as_completed(futures):
                result = future.result()
                results.append(result)

    return results


def save_results(results, output_file):
    """Save results to CSV file"""
    print()
    print("=" * 60)
    print(" Saving Results")
    print("=" * 60)

    with open(output_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['email', 'code', 'status', 'error'])
        writer.writeheader()
        writer.writerows(results)

    print(f"[+] Results saved to: {output_file}")


def print_summary(results):
    """Print summary statistics"""
    print()
    print("=" * 60)
    print(" SUMMARY")
    print("=" * 60)

    total = len(results)
    success = sum(1 for r in results if r['status'] == 'SUCCESS')
    no_code = sum(1 for r in results if r['status'] == 'NO_CODE')
    errors = sum(1 for r in results if r['status'] == 'ERROR')

    print(f"Total Processed: {total}")
    print(f"Codes Found: {success} ({success/total*100:.1f}%)")
    print(f"No Code: {no_code} ({no_code/total*100:.1f}%)")
    print(f"Errors: {errors} ({errors/total*100:.1f}%)")

    if success > 0:
        print()
        print("Successful extractions:")
        for r in results:
            if r['status'] == 'SUCCESS':
                print(f"  {r['email']}: {r['code']}")


def main():
    """Main function"""
    print()
    print("=" * 60)
    print(" Batch Webmail 2FA Code Extractor")
    print("=" * 60)
    print()

    csv_file = "/home/george/dev/instagram-automation/onet_accounts.csv"
    output_file = "/home/george/static/2fa_codes_results.csv"

    print(f"CSV File: {csv_file}")
    print(f"Output: {output_file}")
    print()
    print("Options:")
    print("1. Test mode (first 5 accounts, sequential)")
    print("2. Small batch (first 50 accounts, sequential)")
    print("3. Large batch (all accounts, sequential) - ~2 hours")
    print("4. Parallel mode (all accounts, 10 workers) - ~20 minutes")
    print("5. Custom")
    print("6. Exit")
    print()

    choice = input("Select option (1-6): ").strip()

    if choice == "1":
        print()
        print("[*] Test mode: Processing first 5 accounts...")
        results = process_sequential(csv_file, max_accounts=5)
        save_results(results, output_file)
        print_summary(results)

    elif choice == "2":
        print()
        print("[*] Small batch: Processing first 50 accounts...")
        results = process_sequential(csv_file, max_accounts=50)
        save_results(results, output_file)
        print_summary(results)

    elif choice == "3":
        print()
        confirm = input("This will take ~2 hours. Continue? (yes/no): ")
        if confirm.lower() == 'yes':
            print()
            print("[*] Processing ALL accounts (sequential)...")
            results = process_sequential(csv_file)
            save_results(results, output_file)
            print_summary(results)

    elif choice == "4":
        print()
        confirm = input("This will start 10 browsers. Continue? (yes/no): ")
        if confirm.lower() == 'yes':
            print()
            print("[*] Processing ALL accounts (parallel)...")
            results = process_parallel(csv_file, max_workers=10)
            save_results(results, output_file)
            print_summary(results)

    elif choice == "5":
        print()
        num = int(input("Number of accounts to process: "))
        mode = input("Mode (sequential/parallel): ").strip().lower()

        if mode == 'parallel':
            workers = int(input("Number of parallel workers (1-20): "))
            results = process_parallel(csv_file, max_accounts=num, max_workers=workers)
        else:
            results = process_sequential(csv_file, max_accounts=num)

        save_results(results, output_file)
        print_summary(results)

    elif choice == "6":
        print("Goodbye!")
        sys.exit(0)

    else:
        print("Invalid option")


if __name__ == "__main__":
    main()
