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

## Deploy as a kiosk (Omarchy / Hyprland)

For the wall-mounted iMac running [Omarchy](https://omarchy.org) (Arch Linux + Hyprland): one script installs the server as a systemd user service and opens it fullscreen in Chromium kiosk mode on login.

```bash
git clone https://github.com/Rainscopefilmworks/rentals-dashboard.git
cd rentals-dashboard
npm install
cp .env.example .env   # then edit .env with real DB credentials
./deploy/install-omarchy-kiosk.sh
```

This:
- Installs `deploy/rentals-dashboard.service` as a systemd user unit (`systemctl --user status rentals-dashboard.service`), auto-restarting on failure, and enables lingering so it survives without an active login session
- Appends an `exec-once` line to your Hyprland `autostart.conf` (or `hyprland.conf` if that file doesn't exist) that runs `deploy/kiosk-launch.sh` — this waits for the server to respond, then launches Chromium fullscreen (`--kiosk`) pointed at the dashboard
- Requires `chromium` to already be installed (`sudo pacman -S chromium`)

Reload Hyprland to pick up the new autostart entry without a full reboot: `hyprctl reload`. On the next login (or reboot), the dashboard starts automatically and opens fullscreen.

**Worth doing manually afterward:** disable idle screen-lock/blank for the kiosk session (via `hypridle`'s config) so the dashboard doesn't lock or sleep while unattended — this isn't scripted here since it'd affect the whole session, not just this app.

To uninstall the service:

```bash
systemctl --user disable --now rentals-dashboard.service
rm ~/.config/systemd/user/rentals-dashboard.service
```

Then remove the `exec-once` line for `kiosk-launch.sh` from your Hyprland config.

### Deploy as a background service (macOS)

If this ever runs on an actual Mac instead: `./deploy/install-launchd.sh` installs it as a `launchd` user agent (`com.rainscope.rentals-dashboard`) the same way — starts on login/boot, restarts on crash. Logs go to `~/Library/Logs/rentals-dashboard/`. Uninstall with:

```bash
launchctl unload ~/Library/LaunchAgents/com.rainscope.rentals-dashboard.plist
rm ~/Library/LaunchAgents/com.rainscope.rentals-dashboard.plist
```
