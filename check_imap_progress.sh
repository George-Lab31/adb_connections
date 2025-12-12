#!/usr/bin/env bash
#
# Check IMAP Test Progress
# Monitor the comprehensive IMAP test in real-time
#

RESULTS_FILE="/home/george/static/imap_all_results.txt"
WORKING_FILE="/home/george/static/imap_working_accounts.txt"

echo "========================================"
echo " IMAP Test Progress Monitor"
echo "========================================"
echo ""

# Check if test is running
if pgrep -f "test_all_imap_accounts.sh" > /dev/null; then
    echo "Status: ✅ TEST RUNNING"
else
    echo "Status: ⏸️  TEST COMPLETED or NOT RUNNING"
fi

echo ""

# Count results
if [[ -f "$RESULTS_FILE" ]]; then
    tested=$(wc -l < "$RESULTS_FILE")
    total=591

    working=$(grep -c "✅ WORKS" "$RESULTS_FILE" 2>/dev/null || echo "0")
    failed=$(grep -c "❌ FAIL" "$RESULTS_FILE" 2>/dev/null || echo "0")
    timeout=$(grep -c "⏱️  TIMEOUT" "$RESULTS_FILE" 2>/dev/null || echo "0")

    percent=$((tested * 100 / total))

    echo "Progress: $tested / $total ($percent%)"
    echo ""
    echo "Results:"
    echo "  ✅ Working: $working"
    echo "  ❌ Failed: $failed"
    echo "  ⏱️  Timeout: $timeout"
    echo ""

    if [[ $working -gt 0 ]]; then
        echo "🎉 FOUND WORKING ACCOUNTS!"
        echo ""
        echo "Working accounts:"
        cat "$WORKING_FILE" 2>/dev/null
        echo ""
    fi

    # Show last 5 results
    echo "Last 5 tests:"
    tail -5 "$RESULTS_FILE"
    echo ""

    # Estimate completion
    if pgrep -f "test_all_imap_accounts.sh" > /dev/null; then
        remaining=$((total - tested))
        # Estimate 3-4 seconds per account
        eta_seconds=$((remaining * 3))
        eta_minutes=$((eta_seconds / 60))

        echo "Estimated time remaining: ~${eta_minutes} minutes"
    fi
else
    echo "No results file found yet. Test may be starting..."
fi

echo ""
echo "========================================"
echo ""
echo "Run this script again to check progress:"
echo "  ./check_imap_progress.sh"
echo ""
