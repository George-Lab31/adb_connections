# Nix shell for webmail automation with Playwright
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    python311
    python311Packages.playwright
    python311Packages.beautifulsoup4
    playwright-driver
    chromium
  ];

  shellHook = ''
    export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
    export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
    echo "Playwright environment ready!"
    echo "Run: python /home/george/static/webmail_2fa_extractor.py"
  '';
}
