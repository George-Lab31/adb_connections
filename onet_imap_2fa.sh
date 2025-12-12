#!/usr/bin/env bash
#
# Onet.pl IMAP 2FA Code Retriever for Instagram
# Retrieves Instagram 2FA codes from brittanyrubio@onet.pl
#

set -e

# Configuration
EMAIL="brittanyrubio@onet.pl"
# Using OLD password since new password (PurpleLemur#420) hasn't propagated to IMAP yet
# IMAP servers still using old password: dilse@342345
# Once IMAP works with new password, update this
PASSWORD="dilse@342345"
IMAP_SERVER="imaps://imap.poczta.onet.pl:993"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Onet.pl IMAP 2FA Code Retriever${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to test IMAP connection
test_connection() {
    echo -e "${YELLOW}[*] Testing IMAP connection...${NC}"

    # Test with curl
    RESULT=$(curl -s --url "$IMAP_SERVER" --user "$EMAIL:$PASSWORD" --request "STATUS INBOX (MESSAGES)" 2>&1)

    if echo "$RESULT" | grep -q "Login denied\|Authentication failed"; then
        echo -e "${RED}[-] Authentication failed!${NC}"
        echo ""
        echo -e "${YELLOW}This usually means one of the following:${NC}"
        echo "  1. IMAP/POP3 access is not enabled in your Onet.pl account settings"
        echo "  2. You need to generate an app-specific password"
        echo "  3. Your account has 2FA enabled and blocks external clients"
        echo ""
        echo -e "${BLUE}To fix this, please:${NC}"
        echo "  1. Go to https://poczta.onet.pl/"
        echo "  2. Log in with your credentials"
        echo "  3. Go to Settings (Ustawienia) → Security (Bezpieczeństwo)"
        echo "  4. Look for options like:"
        echo "     - 'Enable IMAP/POP3 access'"
        echo "     - 'External mail clients'"
        echo "     - 'App passwords' or 'Application passwords'"
        echo "  5. Enable IMAP access or generate an app password"
        echo "  6. If you generate an app password, update this script with it"
        echo ""
        return 1
    elif echo "$RESULT" | grep -q "MESSAGES"; then
        echo -e "${GREEN}[+] Successfully connected to IMAP!${NC}"

        # Extract message count
        MSG_COUNT=$(echo "$RESULT" | grep -oP 'MESSAGES \K\d+')
        echo -e "${GREEN}[+] Found $MSG_COUNT messages in INBOX${NC}"
        return 0
    else
        echo -e "${RED}[-] Unknown error:${NC}"
        echo "$RESULT"
        return 1
    fi
}

# Function to search for Instagram emails
search_instagram_emails() {
    echo ""
    echo -e "${YELLOW}[*] Searching for Instagram emails...${NC}"

    # List last 10 emails to see what we have
    MAILBOX_DATA=$(curl -s --url "$IMAP_SERVER/INBOX" --user "$EMAIL:$PASSWORD" -X "SEARCH FROM Instagram" 2>&1)

    if echo "$MAILBOX_DATA" | grep -q "Login denied"; then
        echo -e "${RED}[-] Authentication failed${NC}"
        return 1
    fi

    echo "$MAILBOX_DATA"
}

# Function to fetch latest email
fetch_latest_instagram_email() {
    echo ""
    echo -e "${YELLOW}[*] Fetching latest Instagram email...${NC}"

    # Get the latest message
    EMAIL_CONTENT=$(curl -s --url "$IMAP_SERVER/INBOX;MAILINDEX=1" --user "$EMAIL:$PASSWORD" 2>&1)

    if echo "$EMAIL_CONTENT" | grep -q "Login denied"; then
        echo -e "${RED}[-] Authentication failed${NC}"
        return 1
    fi

    echo "$EMAIL_CONTENT"

    # Try to extract 6-digit code
    CODE=$(echo "$EMAIL_CONTENT" | grep -oP '\b\d{6}\b' | head -1)

    if [ -n "$CODE" ]; then
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}   Instagram 2FA Code: $CODE${NC}"
        echo -e "${GREEN}========================================${NC}"
        return 0
    else
        echo -e "${YELLOW}[-] No 6-digit code found in latest email${NC}"
        return 1
    fi
}

# Function to monitor for new emails
monitor_for_new_email() {
    echo ""
    echo -e "${YELLOW}[*] Monitoring for new Instagram 2FA emails...${NC}"
    echo -e "${YELLOW}[*] Trigger Instagram 2FA now!${NC}"
    echo -e "${YELLOW}[*] Monitoring for 60 seconds...${NC}"

    # Get initial message count
    INITIAL_COUNT=$(curl -s --url "$IMAP_SERVER" --user "$EMAIL:$PASSWORD" --request "STATUS INBOX (MESSAGES)" 2>&1 | grep -oP 'MESSAGES \K\d+')

    if [ -z "$INITIAL_COUNT" ]; then
        echo -e "${RED}[-] Failed to get initial message count${NC}"
        return 1
    fi

    echo -e "${BLUE}[*] Current message count: $INITIAL_COUNT${NC}"

    # Monitor for 60 seconds
    for i in {1..12}; do
        sleep 5

        CURRENT_COUNT=$(curl -s --url "$IMAP_SERVER" --user "$EMAIL:$PASSWORD" --request "STATUS INBOX (MESSAGES)" 2>&1 | grep -oP 'MESSAGES \K\d+')

        if [ "$CURRENT_COUNT" -gt "$INITIAL_COUNT" ]; then
            echo -e "${GREEN}[+] New email detected!${NC}"
            fetch_latest_instagram_email
            return 0
        fi

        echo -ne "\r${YELLOW}[*] Waiting... $((60 - i*5)) seconds remaining${NC}"
    done

    echo ""
    echo -e "${RED}[-] Timeout: No new emails received${NC}"
    return 1
}

# Function to list recent emails
list_recent_emails() {
    echo ""
    echo -e "${YELLOW}[*] Listing recent emails...${NC}"

    # Get message count
    MSG_COUNT=$(curl -s --url "$IMAP_SERVER" --user "$EMAIL:$PASSWORD" --request "STATUS INBOX (MESSAGES)" 2>&1 | grep -oP 'MESSAGES \K\d+')

    if [ -z "$MSG_COUNT" ]; then
        echo -e "${RED}[-] Failed to get message count${NC}"
        return 1
    fi

    echo -e "${BLUE}[*] Total messages: $MSG_COUNT${NC}"
    echo ""

    # Fetch last 5 email subjects
    for i in $(seq 1 5); do
        if [ $i -gt $MSG_COUNT ]; then
            break
        fi

        HEADER=$(curl -s --url "$IMAP_SERVER/INBOX;MAILINDEX=$i" --user "$EMAIL:$PASSWORD" --request "BODY[HEADER.FIELDS (FROM SUBJECT DATE)]" 2>&1)

        echo -e "${BLUE}[$i]${NC}"
        echo "$HEADER" | grep -E "From:|Subject:|Date:"
        echo ""
    done
}

# Main menu
main_menu() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Select an option:${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo "1. Test IMAP connection"
    echo "2. Monitor for new Instagram 2FA code (60s)"
    echo "3. Fetch latest email and extract code"
    echo "4. List recent emails"
    echo "5. Exit"
    echo -e "${BLUE}========================================${NC}"
    echo -n "Enter choice [1-5]: "

    read choice

    case $choice in
        1)
            test_connection
            ;;
        2)
            if test_connection; then
                monitor_for_new_email
            fi
            ;;
        3)
            if test_connection; then
                fetch_latest_instagram_email
            fi
            ;;
        4)
            if test_connection; then
                list_recent_emails
            fi
            ;;
        5)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac

    # Return to menu
    main_menu
}

# Run main menu
main_menu
