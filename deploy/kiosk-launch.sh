#!/bin/bash
# Waits for the dashboard server to come up, then opens it fullscreen in
# Firefox kiosk mode. Called via Hyprland exec-once, not run directly.

URL="http://localhost:${PORT:-3000}"

for _ in $(seq 1 30); do
  curl -fs "$URL" > /dev/null 2>&1 && break
  sleep 1
done

export MOZ_ENABLE_WAYLAND=1

exec firefox \
  --kiosk \
  --no-remote \
  --private-window \
  "$URL"
