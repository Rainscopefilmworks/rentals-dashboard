#!/bin/sh
# Debian kiosk launcher (cage + Chromium) for the vertically mounted TV.
# Copy to /home/kiosk/kiosk.sh and run it from the kiosk user's autologin
# on tty1 — see "Deploy as a kiosk (Debian / cage)" in the README.
#
# Waits for the dashboard server to come up, then starts cage (a Wayland
# compositor that runs one app fullscreen) with Chromium in kiosk mode.

exec >>/home/kiosk/kiosk.log 2>&1
URL="http://localhost:3000"
until curl -s -o /dev/null "$URL"; do sleep 2; done
# The TV is mounted vertically: rotate the output inside cage before Chromium
# starts, so Chromium opens at portrait size and the dashboard picks its 2x2
# layout. Retries because right after cage starts the output is still busy
# and rejects the change ("drmModePageFlip failed: Device or resource busy").
exec cage -d -- sh -c '
  i=0
  until wlr-randr | grep -q "Transform: 270"; do
    wlr-randr --output HDMI-A-1 --transform 270
    i=$((i + 1))
    if [ "$i" -ge 30 ]; then
      echo "kiosk: rotation never applied"
      break
    fi
    sleep 1
  done
  echo "kiosk: rotation applied after $i attempt(s)"
  sleep 1
  exec chromium --kiosk --incognito --noerrdialogs --disable-infobars \
    --no-first-run --password-store=basic --ozone-platform=wayland \
    --disable-gpu-compositing "$1"
' sh "$URL"
