#!/usr/bin/env bash
# Wrapper to run webmail extractor with NixOS packages

nix-shell -p python311Packages.playwright chromium --run "
export PLAYWRIGHT_BROWSERS_PATH=/nix/store/$(ls /nix/store | grep chromium | head -1)
python /home/george/static/webmail_2fa_extractor.py
"
