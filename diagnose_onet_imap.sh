#!/usr/bin/env bash
#
# Onet.pl IMAP Diagnostic Tool
# Helps identify why authentication is failing
#

EMAIL="brittanyrubio@onet.pl"
PASSWORD="PurpleLemur#420"
IMAP_SERVER="imap.poczta.onet.pl"

echo "======================================"
echo " Onet.pl IMAP Diagnostic Tool"
echo "======================================"
echo ""
echo "Email: $EMAIL"
echo "Server: $IMAP_SERVER"
echo ""

echo "[1/5] Testing DNS resolution..."
if host $IMAP_SERVER > /dev/null 2>&1; then
    IP=$(host $IMAP_SERVER | grep "has address" | awk '{print $4}' | head -1)
    echo "✓ DNS resolved to: $IP"
else
    echo "✗ DNS resolution failed"
fi
echo ""

echo "[2/5] Testing TCP connection..."
if nc -zv $IMAP_SERVER 993 2>&1 | grep -q "succeeded\|open"; then
    echo "✓ TCP connection successful"
else
    echo "✗ TCP connection failed"
fi
echo ""

echo "[3/5] Testing SSL/TLS connection..."
if echo | openssl s_client -connect $IMAP_SERVER:993 -quiet 2>&1 | grep -q "OK"; then
    echo "✓ SSL/TLS connection successful"
else
    # Try with curl instead since openssl might not be available
    if curl -s --url "imaps://$IMAP_SERVER:993" 2>&1 | grep -q "OK\|ready"; then
        echo "✓ SSL/TLS connection successful (via curl)"
    else
        echo "? SSL/TLS check inconclusive"
    fi
fi
echo ""

echo "[4/5] Checking server capabilities..."
CAPS=$(curl -s --url "imaps://$IMAP_SERVER:993" --user "$EMAIL:WRONG_PASSWORD" 2>&1 | grep "CAPABILITY" | head -1)
if [ -n "$CAPS" ]; then
    echo "✓ Server capabilities:"
    echo "  $CAPS" | sed 's/.*CAPABILITY/  /'
else
    echo "? Could not retrieve capabilities"
fi
echo ""

echo "[5/5] Testing authentication..."
AUTH_RESULT=$(curl -s --url "imaps://$IMAP_SERVER:993" --user "$EMAIL:$PASSWORD" --request "STATUS INBOX (MESSAGES)" 2>&1)

if echo "$AUTH_RESULT" | grep -q "AUTHENTICATIONFAILED\|Login denied"; then
    echo "✗ AUTHENTICATION FAILED"
    echo ""
    echo "======================================"
    echo " DIAGNOSIS"
    echo "======================================"
    echo ""
    echo "Connection works, but login is rejected by the server."
    echo ""
    echo "This means ONE of these is the issue:"
    echo ""
    echo "1. WRONG PASSWORD"
    echo "   → The password might be incorrect"
    echo "   → Special characters might need escaping"
    echo "   → Password was recently changed but not yet active"
    echo ""
    echo "2. APP PASSWORD REQUIRED"
    echo "   → Onet.pl might require an app-specific password"
    echo "   → Look for 'Hasła aplikacji' in settings"
    echo ""
    echo "3. EXTERNAL ACCESS NOT FULLY ENABLED"
    echo "   → IMAP might be 'on' but external clients blocked"
    echo "   → Look for settings like:"
    echo "     • 'Dostęp dla klientów zewnętrznych'"
    echo "     • 'Zaufane aplikacje'"
    echo "     • 'Bezpieczne aplikacje'"
    echo ""
    echo "4. VERIFICATION REQUIRED"
    echo "   → First external login might need verification"
    echo "   → Check email for verification link"
    echo ""
    echo "5. SETTINGS PROPAGATION DELAY"
    echo "   → Wait 5-15 minutes after changing settings"
    echo ""
elif echo "$AUTH_RESULT" | grep -q "MESSAGES"; then
    echo "✓ AUTHENTICATION SUCCESSFUL!"
    MSG_COUNT=$(echo "$AUTH_RESULT" | grep -oP 'MESSAGES \K\d+')
    echo "  Messages in inbox: $MSG_COUNT"
    echo ""
    echo "======================================"
    echo " SUCCESS!"
    echo "======================================"
    echo ""
    echo "IMAP is working! You can now use:"
    echo "  ./onet_imap_2fa.sh"
else
    echo "? UNKNOWN RESULT"
    echo "$AUTH_RESULT"
fi

echo ""
echo "======================================"
echo " WEBMAIL CHECK"
echo "======================================"
echo ""
echo "Please verify you can log in at:"
echo "  https://poczta.onet.pl/"
echo ""
echo "With credentials:"
echo "  Email: $EMAIL"
echo "  Password: $PASSWORD"
echo ""
echo "If webmail login fails, the password is wrong."
echo "If webmail works but IMAP fails, check settings."
echo ""
