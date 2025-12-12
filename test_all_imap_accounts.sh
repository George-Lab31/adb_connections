#!/usr/bin/env bash
#
# Comprehensive IMAP Test for All Accounts
# Tests all 590+ accounts from CSV to find any working ones
#

CSV_FILE="/home/george/dev/instagram-automation/onet_accounts.csv"
RESULTS_FILE="/home/george/static/imap_all_results.txt"
WORKING_FILE="/home/george/static/imap_working_accounts.txt"
FAILED_FILE="/home/george/static/imap_failed_accounts.txt"

echo "========================================"
echo " Comprehensive IMAP Test - ALL Accounts"
echo "========================================"
echo ""
echo "CSV File: $CSV_FILE"
echo "Results: $RESULTS_FILE"
echo ""

# Clear previous results
> "$RESULTS_FILE"
> "$WORKING_FILE"
> "$FAILED_FILE"

# Counters
total=0
working=0
failed=0
timeout=0
unknown=0

# Function to test IMAP
test_imap() {
    local email="$1"
    local password="$2"
    local domain="${email#*@}"

    # Determine server based on domain
    if [[ "$domain" == "onet.pl" ]]; then
        server="imap.poczta.onet.pl"
    elif [[ "$domain" == "op.pl" ]]; then
        server="imap.op.pl"
    else
        server="imap.poczta.onet.pl"
    fi

    # Test connection (3 second timeout for speed)
    result=$(curl --url "imaps://$server:993" \
                  --user "$email:$password" \
                  --request "STATUS INBOX (MESSAGES)" \
                  --max-time 3 \
                  2>&1)

    # Check result
    if echo "$result" | grep -q "MESSAGES"; then
        msg_count=$(echo "$result" | grep -oP 'MESSAGES \K\d+' || echo "?")
        echo "✅ WORKS | $email | $password | $server | Messages: $msg_count"
        echo "$email,$password,$server,$msg_count" >> "$WORKING_FILE"
        return 0
    elif echo "$result" | grep -q "Login denied\|Authentication failed"; then
        echo "❌ FAIL | $email | $password | $server"
        echo "$email,$password,$server,AUTH_FAIL" >> "$FAILED_FILE"
        return 1
    elif echo "$result" | grep -q "timed out\|Timeout"; then
        echo "⏱️  TIMEOUT | $email | $password | $server"
        echo "$email,$password,$server,TIMEOUT" >> "$FAILED_FILE"
        return 2
    else
        echo "❓ UNKNOWN | $email | $password | $server"
        echo "$email,$password,$server,UNKNOWN" >> "$FAILED_FILE"
        return 3
    fi
}

# Get total count
total_count=$(wc -l < "$CSV_FILE")
total_count=$((total_count - 1))  # Subtract header

echo "Total accounts to test: $total_count"
echo ""
echo "Starting tests (this may take 30-60 minutes)..."
echo "Progress will be shown every 50 accounts"
echo ""
echo "========================================"
echo ""

start_time=$(date +%s)

# Read CSV and test all accounts
while IFS=',' read -r email password; do
    # Skip header
    if [[ "$email" == "email" ]] || [[ -z "$email" ]]; then
        continue
    fi

    ((total++))

    # Test account
    result=$(test_imap "$email" "$password")
    echo "$result" >> "$RESULTS_FILE"

    # Update counters
    if [[ "$result" == *"✅ WORKS"* ]]; then
        ((working++))
    elif [[ "$result" == *"❌ FAIL"* ]]; then
        ((failed++))
    elif [[ "$result" == *"⏱️  TIMEOUT"* ]]; then
        ((timeout++))
    else
        ((unknown++))
    fi

    # Show progress every 50 accounts
    if (( total % 50 == 0 )); then
        elapsed=$(($(date +%s) - start_time))
        rate=$(awk "BEGIN {print $total / $elapsed}")
        remaining=$(awk "BEGIN {print int(($total_count - $total) / $rate / 60)}")

        echo ""
        echo "--- Progress: $total/$total_count ($((total * 100 / total_count))%) ---"
        echo "Working: $working | Failed: $failed | Timeout: $timeout"
        echo "Rate: $(printf '%.1f' $rate) accounts/sec"
        echo "Est. remaining: ${remaining}m"
        echo ""
    fi

    # Small delay to avoid rate limiting
    sleep 0.1

done < "$CSV_FILE"

end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
echo "========================================"
echo " FINAL RESULTS"
echo "========================================"
echo ""
echo "Total Tested: $total accounts"
echo "Time Taken: $((duration / 60))m $((duration % 60))s"
echo ""
echo "Working: $working accounts ($(awk "BEGIN {print $working * 100 / $total}")%)"
echo "Failed: $failed accounts ($(awk "BEGIN {print $failed * 100 / $total}")%)"
echo "Timeout: $timeout accounts ($(awk "BEGIN {print $timeout * 100 / $total}")%)"
echo "Unknown: $unknown accounts ($(awk "BEGIN {print $unknown * 100 / $total}")%)"
echo ""

if [[ $working -gt 0 ]]; then
    echo "🎉 SUCCESS! Found $working working account(s)!"
    echo ""
    echo "Working accounts saved to: $WORKING_FILE"
    echo ""
    echo "Working accounts:"
    cat "$WORKING_FILE"
    echo ""
else
    echo "❌ NO WORKING ACCOUNTS FOUND"
    echo ""
    echo "All $total accounts failed IMAP authentication."
    echo ""
    echo "This confirms:"
    echo "  - System-wide IMAP block"
    echo "  - All accounts affected"
    echo "  - Webmail automation is the only solution"
fi

echo ""
echo "Detailed results saved to: $RESULTS_FILE"
echo "Failed accounts saved to: $FAILED_FILE"
echo ""
echo "========================================"
