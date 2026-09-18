#!/bin/bash
# Waits for the dashboard server to come up, then opens it fullscreen in
# Firefox kiosk mode. Installed as a launchd agent that runs at login,
# not run directly.

URL="http://localhost:${PORT:-3000}"

for _ in $(seq 1 30); do
  curl -fs "$URL" > /dev/null 2>&1 && break
  sleep 1
done

open -na "Firefox" --args --kiosk --private-window "$URL"
