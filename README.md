# Rentals Dashboard

Local, read-only dashboard over the Rainscope Rentals `projects` table. Shows three sections:

- **Going Out** — orders shipping in the next 7 days (`projects_dates_use_start`)
- **Currently Out** — orders active right now
- **Coming Back** — orders returning in the next 7 days (`projects_dates_use_end`)

Styled with the [Rainscope Design System](https://github.com/Rainscopefilmworks/rainscope-design-system) Rentals lane (onyx + ocean blue). Token CSS is copied into `public/tokens/`.

## Setup

1. Install dependencies:

   ```bash
   npm install
   ```

2. Fill in `.env` with your DB connection details:

   ```
   DB_HOST=
   DB_PORT=3306
   DB_USER=
   DB_PASSWORD=
   DB_NAME=
   PORT=3000
   ```

   Use a MySQL user with **SELECT-only** grants — this app never writes to the database, but it's good practice to enforce that at the DB level too.

3. Start the server:

   ```bash
   npm start
   ```

4. Open [http://localhost:3000](http://localhost:3000).

The dashboard auto-refreshes: the server polls the DB every 10s in the background and pushes a live reload to any open tab when the data actually changes (see the "● Live" indicator in the footer).

## Run with Docker

With `.env` filled in (step 2 above), build and start the container:

```bash
docker compose up -d --build
```

Then open [http://localhost:3000](http://localhost:3000) (or whatever `PORT` is set to in `.env` — it sets the host port; the app always listens on 3000 inside the container). The container restarts automatically unless stopped, and has a healthcheck (`docker compose ps` shows its status).

- **DB on the same machine:** inside the container `localhost` means the container itself, so set `DB_HOST=host.docker.internal` to reach a MySQL server running on the host.
- Logs: `docker compose logs -f`
- Stop: `docker compose down`

Without Compose:

```bash
docker build -t rentals-dashboard .
docker run -d --name rentals-dashboard --env-file .env -p 3000:3000 --restart unless-stopped rentals-dashboard
```

**Updating:** the image is built from the checked-out code (`build: .`), not pulled from a registry. So Dockge's **Update** button (which runs `docker compose pull`) won't pick up new commits. In the stack's folder, run:

```bash
git pull
docker compose up -d --build
```

Then restart the kiosk browser (or reboot the kiosk machine). An open page doesn't reload on its own when the container restarts.

## Deploy as a kiosk (Debian / cage)

This is the current wall display: a Debian 13 server (`rs-server`) driving a 4096x2160 TV **mounted vertically**. The server runs in Docker (see above). The screen is driven by [cage](https://github.com/cage-kiosk/cage), a minimal Wayland compositor that runs one app fullscreen, with Chromium in kiosk mode inside it. There's no X server, so use `wlr-randr` rather than `xrandr` for anything display-related.

On portrait screens the dashboard automatically switches its four panels to a 2x2 grid.

1. Install the packages:

   ```bash
   sudo apt install cage chromium wlr-randr curl
   ```

2. Create a `kiosk` user, if there isn't one, and install the launcher as its startup script:

   ```bash
   sudo useradd -m -s /bin/bash kiosk
   sudo cp deploy/kiosk-launch-cage.sh /home/kiosk/kiosk.sh
   sudo chown kiosk:kiosk /home/kiosk/kiosk.sh
   sudo chmod +x /home/kiosk/kiosk.sh
   ```

3. Auto-login `kiosk` on tty1 and start the launcher from its login shell. This is the standard Debian approach; rs-server's own autologin config wasn't recorded when this section was written.

   ```bash
   sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
   printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin kiosk --noclear %%I $TERM\n' \
     | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf
   echo '[ "$(tty)" = /dev/tty1 ] && exec /home/kiosk/kiosk.sh' | sudo tee -a /home/kiosk/.bash_profile
   sudo chown kiosk:kiosk /home/kiosk/.bash_profile
   sudo reboot
   ```

What [`deploy/kiosk-launch-cage.sh`](deploy/kiosk-launch-cage.sh) does: it waits for `localhost:3000` to respond and starts cage. Inside cage, it rotates the output (`wlr-randr --output HDMI-A-1 --transform 270`) before starting Chromium, so Chromium opens at portrait size. The rotation runs in a retry loop. A single attempt right after cage starts fails with `drmModePageFlip failed: Device or resource busy`, and Chromium then opens in landscape. Output goes to `/home/kiosk/kiosk.log`. A good boot logs `kiosk: rotation applied after N attempt(s)`:

```bash
sudo grep "kiosk:" /home/kiosk/kiosk.log | tail -2
```

**Adjusting the display:**
- **Different TV or port:** the launcher assumes the output is named `HDMI-A-1`. To list outputs and check the current rotation from an SSH session:

  ```bash
  sudo -u kiosk env XDG_RUNTIME_DIR=/run/user/$(id -u kiosk) WAYLAND_DISPLAY=wayland-0 wlr-randr
  ```

  Check the socket name with `sudo ls /run/user/$(id -u kiosk)` if `wayland-0` doesn't work.
- **Upside down:** change both `270`s in `kiosk.sh` to `90`.
- **Smoother scrolling:** the TV defaults to 4096x2160 at 24 Hz. Adding `--mode 3840x2160@30` to the `wlr-randr --output …` line gives 30 Hz.
- **GPU compositing:** Chromium is started with `--disable-gpu-compositing`, so compositing happens on the CPU. Removing that flag moves it to the GPU. Put the flag back if the screen comes up black or flickers.
- After editing `kiosk.sh`, reboot to apply it.

## Deploy as a kiosk (macOS / Apple Silicon)

For a Mac driving the wall display: one script installs the server as a `launchd` user agent and opens it fullscreen in Firefox kiosk mode on login.

```bash
git clone https://github.com/Rainscopefilmworks/rentals-dashboard.git
cd rentals-dashboard
npm install
cp .env.example .env   # then edit .env with real DB credentials
./deploy/install-macos-kiosk.sh
```

This:
- Installs `com.rainscope.rentals-dashboard` as a launchd agent (`launchctl list | grep rentals-dashboard`) — starts on login/boot, restarts on crash
- Installs `com.rainscope.rentals-dashboard-kiosk` as a second launchd agent that waits for the server to respond, then opens Firefox fullscreen (`--kiosk`) pointed at the dashboard, in its own dedicated profile (`~/Library/Application Support/rentals-dashboard/firefox-kiosk-profile`) — isolated from anyone's personal Firefox history/extensions/saved logins on the machine, always-private-browsing, and pre-configured to skip first-run/crash-restore prompts that `--kiosk` alone can't suppress
- Requires Firefox to already be installed in `/Applications` (https://www.mozilla.org/firefox/)

Logs go to `~/Library/Logs/rentals-dashboard/`.

**Worth doing manually afterward:**
- If the built-in display stays active alongside an external monitor (e.g. a laptop with the lid open): System Settings → Displays → Arrange, drag the menu bar strip onto the external monitor to make it the primary display. Firefox — like every macOS app — opens new windows on whichever display is primary, and there's no reliable launch flag to target a specific monitor instead, so this is the one-time fix if the dashboard opens on the wrong screen.
- Enable auto-login for this account (System Settings → Users & Groups) — `RunAtLoad` launchd agents only fire once a user session starts, so without auto-login the kiosk won't come back up on its own after a reboot or power loss.
- Disable display sleep and screen lock (System Settings → Lock Screen, and Displays → Advanced) so the dashboard doesn't blank or lock while unattended.

To uninstall:

```bash
launchctl unload ~/Library/LaunchAgents/com.rainscope.rentals-dashboard.plist
rm ~/Library/LaunchAgents/com.rainscope.rentals-dashboard.plist
launchctl unload ~/Library/LaunchAgents/com.rainscope.rentals-dashboard-kiosk.plist
rm ~/Library/LaunchAgents/com.rainscope.rentals-dashboard-kiosk.plist
rm -rf ~/Library/Application\ Support/rentals-dashboard/firefox-kiosk-profile
```

### Deploy as a background service only (no kiosk browser)

If you just want the server running in the background — e.g. for local development, or a machine that isn't the wall display — `./deploy/install-launchd.sh` installs only the `com.rainscope.rentals-dashboard` launchd agent, the same way. Uninstall with:

```bash
launchctl unload ~/Library/LaunchAgents/com.rainscope.rentals-dashboard.plist
rm ~/Library/LaunchAgents/com.rainscope.rentals-dashboard.plist
```

### Deploy as a kiosk (Omarchy / Hyprland)

Not currently used (the wall display runs Debian/cage, above), but kept here in case that changes. For a machine running [Omarchy](https://omarchy.org) (Arch Linux + Hyprland): one script installs the server as a systemd user service and opens it fullscreen in Firefox kiosk mode on login.

```bash
git clone https://github.com/Rainscopefilmworks/rentals-dashboard.git
cd rentals-dashboard
npm install
cp .env.example .env   # then edit .env with real DB credentials
./deploy/install-omarchy-kiosk.sh
```

This:
- Installs `deploy/rentals-dashboard.service` as a systemd user unit (`systemctl --user status rentals-dashboard.service`), auto-restarting on failure, and enables lingering so it survives without an active login session
- Appends an `exec-once` line to your Hyprland `autostart.conf` (or `hyprland.conf` if that file doesn't exist) that runs `deploy/kiosk-launch.sh` — this waits for the server to respond, then launches Firefox fullscreen (`--kiosk`, in a private window) pointed at the dashboard
- Requires `firefox` to already be installed (`sudo pacman -S firefox`)

Reload Hyprland to pick up the new autostart entry without a full reboot: `hyprctl reload`. On the next login (or reboot), the dashboard starts automatically and opens fullscreen.

**Worth doing manually afterward:** disable idle screen-lock/blank for the kiosk session (via `hypridle`'s config) so the dashboard doesn't lock or sleep while unattended — this isn't scripted here since it'd affect the whole session, not just this app.

To uninstall the service:

```bash
systemctl --user disable --now rentals-dashboard.service
rm ~/.config/systemd/user/rentals-dashboard.service
```

Then remove the `exec-once` line for `kiosk-launch.sh` from your Hyprland config.
