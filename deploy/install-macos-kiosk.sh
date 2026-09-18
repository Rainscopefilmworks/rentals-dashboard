#!/bin/bash
# Sets up the Rentals Dashboard on a Mac (Apple Silicon or Intel) to run as
# a launchd service and open fullscreen in Firefox kiosk mode on login.
#
# Run this from inside the cloned repo on the target Mac:
#   ./deploy/install-macos-kiosk.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_PATH="$(command -v node)"
SERVER_LABEL="com.rainscope.rentals-dashboard"
KIOSK_LABEL="com.rainscope.rentals-dashboard-kiosk"
SERVER_PLIST="$HOME/Library/LaunchAgents/${SERVER_LABEL}.plist"
KIOSK_PLIST="$HOME/Library/LaunchAgents/${KIOSK_LABEL}.plist"
LOG_DIR="$HOME/Library/Logs/rentals-dashboard"
PORT="${PORT:-3000}"

if [ ! -f "$REPO_DIR/.env" ]; then
  echo "Error: $REPO_DIR/.env not found. Copy .env.example to .env and fill in DB credentials first." >&2
  exit 1
fi

if [ ! -d "$REPO_DIR/node_modules" ]; then
  echo "Error: node_modules not found. Run 'npm install' in $REPO_DIR first." >&2
  exit 1
fi

if [ ! -d "/Applications/Firefox.app" ]; then
  echo "Error: Firefox not found in /Applications. Install it first: https://www.mozilla.org/firefox/" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
chmod +x "$REPO_DIR/deploy/kiosk-launch-macos.sh"

# --- server: launchd agent, starts on login/boot, restarts on crash ---
cat > "$SERVER_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${SERVER_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${NODE_PATH}</string>
    <string>${REPO_DIR}/server.js</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${REPO_DIR}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PORT</key>
    <string>${PORT}</string>
  </dict>
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

# --- kiosk browser: launchd agent, opens Firefox fullscreen on login ---
cat > "$KIOSK_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${KIOSK_LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${REPO_DIR}/deploy/kiosk-launch-macos.sh</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PORT</key>
    <string>${PORT}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/kiosk.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/kiosk-err.log</string>
</dict>
</plist>
EOF

launchctl unload "$SERVER_PLIST" 2>/dev/null || true
launchctl load "$SERVER_PLIST"

launchctl unload "$KIOSK_PLIST" 2>/dev/null || true
launchctl load "$KIOSK_PLIST"

echo "Installed ${SERVER_LABEL} and ${KIOSK_LABEL}."
echo "Dashboard should be running at http://localhost:${PORT}"
echo "Firefox should open fullscreen (kiosk mode) within a few seconds."
echo "Logs: ${LOG_DIR}/"
echo
echo "Worth doing manually afterward:"
echo "- If an external monitor is connected (built-in display also active): System"
echo "  Settings > Displays > Arrange, drag the menu bar strip onto the external"
echo "  monitor to make it the primary display. Firefox (like every app) opens new"
echo "  windows on whichever display is primary — there's no reliable launch flag"
echo "  to target a specific monitor, so this is the one-time fix for the dashboard"
echo "  opening on the wrong screen."
echo "- Enable auto-login for this account (System Settings > Users & Groups) so both"
echo "  agents start right after a reboot, without anyone signing in first — launchd"
echo "  RunAtLoad agents only fire once a user session starts."
echo "- Disable display sleep and screen lock (System Settings > Lock Screen, and"
echo "  Displays > Advanced) so the kiosk doesn't blank or lock while unattended."
echo
echo "To uninstall:"
echo "  launchctl unload ${SERVER_PLIST} && rm ${SERVER_PLIST}"
echo "  launchctl unload ${KIOSK_PLIST} && rm ${KIOSK_PLIST}"
