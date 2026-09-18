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

## Deploy as a kiosk (macOS / Apple Silicon)

For the wall-mounted Mac: one script installs the server as a `launchd` user agent and opens it fullscreen in Firefox kiosk mode on login.

```bash
git clone https://github.com/Rainscopefilmworks/rentals-dashboard.git
cd rentals-dashboard
npm install
cp .env.example .env   # then edit .env with real DB credentials
./deploy/install-macos-kiosk.sh
```

This:
- Installs `com.rainscope.rentals-dashboard` as a launchd agent (`launchctl list | grep rentals-dashboard`) — starts on login/boot, restarts on crash
- Installs `com.rainscope.rentals-dashboard-kiosk` as a second launchd agent that waits for the server to respond, then opens Firefox fullscreen (`--kiosk`, in a private window) pointed at the dashboard
- Requires Firefox to already be installed in `/Applications` (https://www.mozilla.org/firefox/)

Logs go to `~/Library/Logs/rentals-dashboard/`.

**Worth doing manually afterward:**
- Enable auto-login for this account (System Settings → Users & Groups) — `RunAtLoad` launchd agents only fire once a user session starts, so without auto-login the kiosk won't come back up on its own after a reboot or power loss.
- Disable display sleep and screen lock (System Settings → Lock Screen, and Displays → Advanced) so the dashboard doesn't blank or lock while unattended.

To uninstall:

```bash
launchctl unload ~/Library/LaunchAgents/com.rainscope.rentals-dashboard.plist
rm ~/Library/LaunchAgents/com.rainscope.rentals-dashboard.plist
launchctl unload ~/Library/LaunchAgents/com.rainscope.rentals-dashboard-kiosk.plist
rm ~/Library/LaunchAgents/com.rainscope.rentals-dashboard-kiosk.plist
```

### Deploy as a background service only (no kiosk browser)

If you just want the server running in the background — e.g. for local development, or a machine that isn't the wall display — `./deploy/install-launchd.sh` installs only the `com.rainscope.rentals-dashboard` launchd agent, the same way. Uninstall with:

```bash
launchctl unload ~/Library/LaunchAgents/com.rainscope.rentals-dashboard.plist
rm ~/Library/LaunchAgents/com.rainscope.rentals-dashboard.plist
```

### Deploy as a kiosk (Omarchy / Hyprland)

Not currently used — the wall-mounted display is a Mac — but kept here in case that changes. For a machine running [Omarchy](https://omarchy.org) (Arch Linux + Hyprland): one script installs the server as a systemd user service and opens it fullscreen in Firefox kiosk mode on login.

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
