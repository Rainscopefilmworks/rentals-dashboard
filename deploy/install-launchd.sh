#!/bin/bash
# Installs the Rentals Dashboard as a launchd user agent so it starts on
# login/boot and restarts automatically if it crashes.
#
# Run this from inside the cloned repo on the target Mac:
#   ./deploy/install-launchd.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_PATH="$(command -v node)"
LABEL="com.rainscope.rentals-dashboard"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/rentals-dashboard"

if [ ! -f "$REPO_DIR/.env" ]; then
  echo "Error: $REPO_DIR/.env not found. Copy .env.example to .env and fill in DB credentials first." >&2
  exit 1
fi

if [ ! -d "$REPO_DIR/node_modules" ]; then
  echo "Error: node_modules not found. Run 'npm install' in $REPO_DIR first." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${NODE_PATH}</string>
    <string>${REPO_DIR}/server.js</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${REPO_DIR}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/out.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/err.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "Installed ${LABEL}."
echo "Dashboard should be running at http://localhost:3000"
echo "Logs: ${LOG_DIR}/out.log and ${LOG_DIR}/err.log"
echo
echo "To uninstall: launchctl unload ${PLIST_PATH} && rm ${PLIST_PATH}"
