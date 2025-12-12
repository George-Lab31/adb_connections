#!/usr/bin/env bash
#
# Test if password has propagated to IMAP servers
# Run this script periodically to check if IMAP access is working
#

EMAIL="brittanyrubio@onet.pl"
# Test with OLD password first (what IMAP server should have)
OLD_PASSWORD="dilse@342345"
# Then test with NEW password (to see when it propagates)
NEW_PASSWORD="PurpleLemur#420"
PASSWORD="$OLD_PASSWORD"  # Try old first
IMAP_SERVER="imaps://imap.poczta.onet.pl:993"

echo "========================================"
echo " Onet.pl IMAP Password Propagation Test"
echo "========================================"
echo ""
echo "Testing IMAP access for: $EMAIL"
echo "Server: $IMAP_SERVER"
echo ""
echo "This will test if your password change has propagated to IMAP servers..."
echo ""

# Test connection
RESULT=$(curl --url "$IMAP_SERVER" --user "$EMAIL:$PASSWORD" --request "STATUS INBOX (MESSAGES)" --max-time 10 2>&1)

if echo "$RESULT" | grep -q "MESSAGES"; then
    # Success!
    MSG_COUNT=$(echo "$RESULT" | grep -oP 'MESSAGES \K\d+')

    echo "✅ ✅ ✅  SUCCESS!  ✅ ✅ ✅"
    echo ""
    echo "IMAP authentication is working!"
    echo "Messages in inbox: $MSG_COUNT"
    echo ""
    echo "You can now use the 2FA retrieval script:"
    echo "  ./onet_imap_2fa.sh"
    echo ""
    exit 0

elif echo "$RESULT" | grep -q "Login denied\|Authentication failed"; then
    # Still failing
    echo "❌ IMAP authentication still failing"
    echo ""
    echo "This means the password hasn't propagated yet."
    echo ""
    echo "What to do:"
    echo "  1. Wait a few more hours"
    echo "  2. Run this script again later: ./test_password_propagation.sh"
    echo "  3. If still failing after 24 hours, contact Onet support"
    echo ""
    echo "Technical details:"
    echo "  - Password was changed: Nov 5, 2025"
    echo "  - Webmail: Working ✓"
    echo "  - IMAP: Not yet ✗"
    echo ""
    exit 1

else
    # Other error
    echo "⚠️  Unexpected result"
    echo ""
    echo "Output:"
    echo "$RESULT"
    echo ""
    exit 2
fi
