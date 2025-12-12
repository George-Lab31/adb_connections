#!/usr/bin/env bash
#
# Run webmail extractor with proper NixOS environment
#

nix-shell -p python311 python311Packages.playwright python311Packages.beautifulsoup4 chromium --run "
export PLAYWRIGHT_BROWSERS_PATH=0
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
python /home/george/static/webmail_2fa_extractor.py
"
