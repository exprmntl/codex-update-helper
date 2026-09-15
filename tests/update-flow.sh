#!/bin/zsh
set -eu
readonly TEST_ROOT=$1
export CODEX_UPDATE_HELPER_APP_PATH="$TEST_ROOT/Applications/ChatGPT.app"
source "$2"
# These overrides are confined to this test process, never service configuration.
verify_app_identity() { return 0; }
enable_automatic_updates() { return 0; }
in_update_window() { return 0; }
idle_seconds() { /bin/echo 2000; }
acquire_lock() { return 0; }
installed_bundle_id() { /bin/echo "$BUNDLE_ID"; }
installed_version() { /bin/echo 1.0; }
installed_build() { /bin/cat "$TEST_ROOT/build-number"; }
is_app_running() { [[ -f "$TEST_ROOT/app-running" ]]; }
find_newest_staged_update() { STAGED_BUILD=12; STAGED_VERSION=1.2; STAGED_APP=$APP_PATH; }
open_app_if_needed() {
  if [[ $1 == true ]] && ! is_app_running; then /usr/bin/touch "$TEST_ROOT/reopened"; fi
}
# Use functions around the quit boundary so no actual process or permission
# checks can escape the fixture. Defined here after sourcing the production code.
run_case() {
  local mode=$1
  /bin/echo 10 > "$TEST_ROOT/build-number"
  /usr/bin/touch "$TEST_ROOT/app-running"
  /bin/rm -f "$TEST_ROOT/reopened" "$TEST_ROOT/requested"
  CODEX_TEST_MODE=$mode run_update --force >"$TEST_ROOT/flow-$mode.out" 2>&1
}

# Shell functions replace only the small external boundary wrappers.
quit_guard_ready() { [[ $CODEX_TEST_MODE != missing ]]; }
running_app_pid() { /bin/echo 12345; }
request_guarded_quit() {
  /usr/bin/touch "$TEST_ROOT/requested"
  if [[ $CODEX_TEST_MODE == cancel ]]; then return 3; fi
  /bin/rm "$TEST_ROOT/app-running"
  if [[ $CODEX_TEST_MODE == success ]]; then /bin/echo 12 > "$TEST_ROOT/build-number"; fi
}
poll_count() { /bin/echo 1; }
wait_for_poll() { return 0; }

run_case success
[[ -f "$TEST_ROOT/reopened" && -f "$TEST_ROOT/requested" ]] || exit 1
run_case cancel
[[ ! -f "$TEST_ROOT/reopened" && -f "$TEST_ROOT/app-running" ]] || exit 1
run_case missing
[[ ! -f "$TEST_ROOT/requested" && -f "$TEST_ROOT/app-running" ]] || exit 1
if run_case timeout; then exit 1; fi
[[ -f "$TEST_ROOT/reopened" ]] || exit 1
