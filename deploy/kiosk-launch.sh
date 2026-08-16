#!/bin/bash
# Waits for the dashboard server to come up, then opens it fullscreen in
# kiosk mode. Called via Hyprland exec-once, not run directly.

URL="http://localhost:${PORT:-3000}"

for _ in $(seq 1 30); do
  curl -fs "$URL" > /dev/null 2>&1 && break
  sleep 1
done

exec chromium \
  --ozone-platform=wayland \
  --kiosk \
  --noerrdialogs \
  --disable-infobars \
  --disable-session-crashed-bubble \
  --incognito \
  "$URL"
