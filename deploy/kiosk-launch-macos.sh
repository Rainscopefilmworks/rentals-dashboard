#!/bin/bash
# Waits for the dashboard server to come up, then opens it fullscreen in
# Firefox kiosk mode, in its own dedicated profile — isolated from anyone's
# personal Firefox profile/history/extensions/logins on this machine, and
# configured to skip first-run/crash-restore prompts that --kiosk alone
# can't suppress. Installed as a launchd agent that runs at login, not run
# directly.

URL="http://localhost:${PORT:-3000}"
PROFILE_DIR="$HOME/Library/Application Support/rentals-dashboard/firefox-kiosk-profile"

mkdir -p "$PROFILE_DIR"

cat > "$PROFILE_DIR/user.js" <<'EOF'
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.tabs.warnOnClose", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("startup.homepage_welcome_url", "");
user_pref("startup.homepage_welcome_url.additional", "");
user_pref("datareporting.policy.dataSubmissionPolicyBypassNotification", true);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("signon.rememberSignons", false);
user_pref("browser.privatebrowsing.autostart", true);
EOF

for _ in $(seq 1 30); do
  curl -fs "$URL" > /dev/null 2>&1 && break
  sleep 1
done

open -na "Firefox" --args --profile "$PROFILE_DIR" --no-remote --kiosk "$URL"
