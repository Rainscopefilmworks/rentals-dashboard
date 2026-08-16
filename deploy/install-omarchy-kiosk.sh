#!/bin/bash
# Sets up the Rentals Dashboard to run as a systemd user service and open
# fullscreen in kiosk mode on login, for Omarchy (Hyprland on Arch).
#
# Run this from inside the cloned repo on the target machine:
#   ./deploy/install-omarchy-kiosk.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -f "$REPO_DIR/.env" ]; then
  echo "Error: $REPO_DIR/.env not found. Copy .env.example to .env and fill in DB credentials first." >&2
  exit 1
fi

if [ ! -d "$REPO_DIR/node_modules" ]; then
  echo "Error: node_modules not found. Run 'npm install' in $REPO_DIR first." >&2
  exit 1
fi

if ! command -v chromium >/dev/null 2>&1; then
  echo "Error: chromium not found. Install it first (e.g. 'sudo pacman -S chromium')." >&2
  exit 1
fi

# --- systemd user service for the dashboard server ---
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"
cp "$REPO_DIR/deploy/rentals-dashboard.service" "$SYSTEMD_USER_DIR/rentals-dashboard.service"

systemctl --user daemon-reload
systemctl --user enable --now rentals-dashboard.service

# Let the user service keep running without an active login session.
loginctl enable-linger "$USER" 2>/dev/null || true

# --- kiosk browser autostart on Hyprland ---
chmod +x "$REPO_DIR/deploy/kiosk-launch.sh"

HYPR_DIR="$HOME/.config/hypr"
AUTOSTART_CONF="$HYPR_DIR/autostart.conf"
if [ ! -f "$AUTOSTART_CONF" ]; then
  AUTOSTART_CONF="$HYPR_DIR/hyprland.conf"
fi

EXEC_LINE="exec-once = $REPO_DIR/deploy/kiosk-launch.sh"
if [ -f "$AUTOSTART_CONF" ]; then
  if ! grep -qF "$EXEC_LINE" "$AUTOSTART_CONF"; then
    printf '\n# Rentals Dashboard kiosk\n%s\n' "$EXEC_LINE" >> "$AUTOSTART_CONF"
    echo "Added kiosk autostart line to $AUTOSTART_CONF"
  else
    echo "Kiosk autostart line already present in $AUTOSTART_CONF"
  fi
else
  echo "Warning: could not find $HYPR_DIR/autostart.conf or hyprland.conf." >&2
  echo "Add this line to your Hyprland config manually:" >&2
  echo "  $EXEC_LINE" >&2
fi

echo
echo "Done."
echo "- Server: systemctl --user status rentals-dashboard.service"
echo "- Kiosk browser launches automatically on next Hyprland login/reload."
echo "- To reload Hyprland config now: hyprctl reload"
