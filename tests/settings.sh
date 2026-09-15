#!/bin/zsh
set -eu
readonly TEST_ROOT=$1 HELPER_SOURCE=$2 GUARD=$3
export CODEX_UPDATE_HELPER_SETTINGS_PATH="$TEST_ROOT/settings.plist"
export CODEX_UPDATE_HELPER_QUIT_HELPER="$GUARD"
export CODEX_UPDATE_HELPER_CHECK_STATE="$TEST_ROOT/last-check"
export CODEX_UPDATE_HELPER_APP_PATH="$TEST_ROOT/Applications/ChatGPT.app"

"$GUARD" --config show > "$TEST_ROOT/defaults.json"
[[ $(/usr/bin/plutil -extract restart-policy raw "$TEST_ROOT/defaults.json") == idle-only ]]
[[ $(/usr/bin/plutil -extract start-time raw "$TEST_ROOT/defaults.json") == 02:00 ]]
[[ $(/usr/bin/plutil -extract end-time raw "$TEST_ROOT/defaults.json") == 03:00 ]]
[[ $(/usr/bin/plutil -extract timezone raw "$TEST_ROOT/defaults.json") == America/New_York ]]
[[ $(/usr/bin/plutil -extract idle-minutes raw "$TEST_ROOT/defaults.json") == 15 ]]
[[ $(/usr/bin/plutil -extract retry-minutes raw "$TEST_ROOT/defaults.json") == 15 ]]
[[ $(/usr/bin/plutil -extract reopen raw "$TEST_ROOT/defaults.json") == true ]]
"$HELPER_SOURCE" config set start-time 23:30 end-time 02:15 idle-minutes 0 retry-minutes 7 restart-policy always reopen false > /dev/null
"$HELPER_SOURCE" config show > "$TEST_ROOT/saved.json"
[[ $(/usr/bin/plutil -extract start-time raw "$TEST_ROOT/saved.json") == 23:30 ]]
[[ $(/usr/bin/plutil -extract reopen raw "$TEST_ROOT/saved.json") == false ]]
/bin/cp "$CODEX_UPDATE_HELPER_SETTINGS_PATH" "$TEST_ROOT/before-invalid.plist"
for pair in 'start-time 24:00' 'timezone fake/zone' 'restart-policy unknown' 'reopen maybe' 'idle-minutes -1' 'retry-minutes 0' 'unknown x'; do
  if "$HELPER_SOURCE" config set ${(z)pair} >/dev/null 2>&1; then /bin/echo "Accepted invalid settings: $pair"; exit 1; fi
  /usr/bin/cmp "$CODEX_UPDATE_HELPER_SETTINGS_PATH" "$TEST_ROOT/before-invalid.plist"
done
if "$HELPER_SOURCE" config set start-time 04:00 end-time 04:00 >/dev/null 2>&1; then exit 1; fi

source "$HELPER_SOURCE"
load_settings
[[ $RESTART_POLICY == always && $REOPEN == false && $MIN_IDLE_SECONDS == 0 && $RETRY_MINUTES == 7 ]]
current_update_time() { /bin/echo "$test_time"; }
for test_time in 23:30 23:59 00:00 02:14; do in_update_window; done
for test_time in 23:29 02:15 14:00; do if in_update_window; then exit 1; fi; done

SCHEDULED=true
scheduled_check_due
if scheduled_check_due; then exit 1; fi
RETRY_MINUTES=8
scheduled_check_due # changes take effect immediately despite the previous delay
SCHEDULED=false
scheduled_check_due # manual checks are never throttled

# Always mode skips the keyboard/mouse idle gate, yet respects the time window.
enable_automatic_updates() { return 0; }
verify_app_identity() { return 0; }
acquire_lock() { return 0; }
installed_bundle_id() { /bin/echo "$BUNDLE_ID"; }
installed_build() { /bin/echo 10; }
installed_version() { /bin/echo 1.0; }
find_newest_staged_update() { STAGED_BUILD=12; STAGED_VERSION=1.2; STAGED_APP=$APP_PATH; }
is_app_running() { return 0; }
idle_seconds() { /bin/echo 0; }
test_time=00:00
output=$(run_update --dry-run)
[[ $output == *'restart policy: always; reopen: false'* ]]
test_time=14:00
output=$(run_update --dry-run)
[[ $output == *'Outside update window'* ]]

# Configured reopen=false must not reach the open command for a closed app.
is_app_running() { /usr/bin/touch "$TEST_ROOT/unexpected-running-check"; return 0; }
open_app_if_needed true
[[ ! -f "$TEST_ROOT/unexpected-running-check" ]]

"$GUARD" --config reset >/dev/null
load_settings
[[ $UPDATE_START_TIME == 02:00 && $UPDATE_END_TIME == 03:00 && $RESTART_POLICY == idle-only && $REOPEN == true && $MIN_IDLE_SECONDS == 900 ]]
printf 'not a plist' > "$CODEX_UPDATE_HELPER_SETTINGS_PATH"
if "$HELPER_SOURCE" run --dry-run >/dev/null 2>&1; then exit 1; fi
"$GUARD" --config reset >/dev/null # recovery works even when the file is corrupt
