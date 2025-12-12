#!/usr/bin/env bash
# Quick test of onet.pl IMAP connection

echo "Testing IMAP connection to onet.pl..."
echo ""
echo "Email: brittanyrubio@onet.pl"
echo "Server: imap.poczta.onet.pl:993"
echo ""

curl -v --url "imaps://imap.poczta.onet.pl:993" \
     --user "brittanyrubio@onet.pl:PurpleLemur#420" \
     --request "CAPABILITY" 2>&1 | \
     grep -E "(Connected|OK|Authentication|Login|failed|denied)" | \
     tail -15
