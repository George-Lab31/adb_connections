#!/usr/bin/env bash
#
# Bulk IMAP Account Tester
# Tests multiple onet.pl/op.pl accounts to find patterns
#

CSV_FILE="/home/george/dev/instagram-automation/onet_accounts.csv"
RESULTS_FILE="/home/george/static/imap_test_results.txt"

echo "========================================"
echo " Bulk IMAP Account Tester"
echo "========================================"
echo ""
echo "Testing accounts from: $CSV_FILE"
echo "Results will be saved to: $RESULTS_FILE"
echo ""

# Clear previous results
> "$RESULTS_FILE"

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
        server="imap.poczta.onet.pl"  # fallback
    fi

    # Test connection (with 5 second timeout)
    result=$(curl --url "imaps://$server:993" \
                  --user "$email:$password" \
                  --request "STATUS INBOX (MESSAGES)" \
                  --max-time 5 \
                  2>&1)

    # Check result
    if echo "$result" | grep -q "MESSAGES"; then
        # Extract message count
        msg_count=$(echo "$result" | grep -oP 'MESSAGES \K\d+' || echo "?")
        echo "✅ WORKS | $email | $password | $server | Messages: $msg_count"
        return 0
    elif echo "$result" | grep -q "Login denied\|Authentication failed"; then
        echo "❌ AUTH FAIL | $email | $password | $server"
        return 1
    elif echo "$result" | grep -q "timed out\|Timeout"; then
        echo "⏱️  TIMEOUT | $email | $password | $server"
        return 2
    else
        echo "❓ UNKNOWN | $email | $password | $server"
        return 3
    fi
}

# Parse CSV and test accounts
# We'll test a representative sample to save time

echo "Parsing CSV and selecting test accounts..."
echo ""

# Test strategy:
# 1. Test 5 onet.pl accounts
# 2. Test 5 op.pl accounts
# 3. Test accounts with different passwords
# 4. Skip header line

tested=0
working=0
failed=0

echo "Starting tests..."
echo "================"
echo ""

# Read CSV and test accounts
while IFS=',' read -r email password; do
    # Skip header
    if [[ "$email" == "email" ]] || [[ -z "$email" ]]; then
        continue
    fi

    # Test first 10 accounts as a sample
    if [[ $tested -ge 10 ]]; then
        break
    fi

    echo "[$((tested+1))/10] Testing: $email"
    result=$(test_imap "$email" "$password")
    echo "$result" | tee -a "$RESULTS_FILE"

    if [[ "$result" == *"✅ WORKS"* ]]; then
        ((working++))
    elif [[ "$result" == *"❌ AUTH FAIL"* ]]; then
        ((failed++))
    fi

    ((tested++))
    echo ""

    # Small delay to avoid rate limiting
    sleep 1

done < "$CSV_FILE"

echo ""
echo "========================================"
echo " SUMMARY"
echo "========================================"
echo "Tested: $tested accounts"
echo "Working: $working accounts ✅"
echo "Failed: $failed accounts ❌"
echo ""
echo "Full results saved to: $RESULTS_FILE"
echo ""

if [[ $working -gt 0 ]]; then
    echo "🎉 SUCCESS! Some accounts are working!"
    echo ""
    echo "Working accounts:"
    grep "✅ WORKS" "$RESULTS_FILE"
    echo ""
    echo "This means IMAP is functional, but specific accounts"
    echo "might have issues (age, verification, etc.)"
elif [[ $failed -eq $tested ]]; then
    echo "❌ ALL ACCOUNTS FAILED"
    echo ""
    echo "This suggests a system-wide issue:"
    echo "  - IP block"
    echo "  - All accounts need verification"
    echo "  - Service-wide IMAP restriction"
fi

echo ""
echo "========================================"
