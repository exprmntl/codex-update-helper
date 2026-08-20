#!/bin/zsh

set -eu
setopt PIPE_FAIL
unsetopt BG_NICE

readonly PROJECT_ROOT=${0:A:h:h}
readonly HELPER="$PROJECT_ROOT/bin/codex-update-helper"
TEST_ROOT=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-update-helper-tests.XXXXXX")

cleanup() {
  /bin/rm -rf "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

fail() {
  /bin/echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack=$1
  local needle=$2
  [[ $haystack == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack=$1
  local needle=$2
  [[ $haystack != *"$needle"* ]] || fail "expected output not to contain: $needle"
}

make_app() {
  local app_path=$1
  local bundle_id=$2
  local version=$3
  local build=$4
  /bin/mkdir -p "$app_path/Contents"
  /usr/bin/plutil -create xml1 "$app_path/Contents/Info.plist"
  /usr/bin/plutil -insert CFBundleIdentifier -string "$bundle_id" "$app_path/Contents/Info.plist"
  /usr/bin/plutil -insert CFBundleShortVersionString -string "$version" "$app_path/Contents/Info.plist"
  /usr/bin/plutil -insert CFBundleVersion -string "$build" "$app_path/Contents/Info.plist"
}

run_helper() {
  CODEX_UPDATE_HELPER_APP_PATH="$TEST_ROOT/Applications/ChatGPT.app" \
  CODEX_UPDATE_HELPER_BUNDLE_ID="dev.exprmntl.codex-update-helper.fixture" \
  CODEX_UPDATE_HELPER_PROCESS_NAME="codex-helper-no-process" \
  CODEX_UPDATE_HELPER_EXECUTABLE_PATH="${CODEX_UPDATE_HELPER_TEST_EXECUTABLE_PATH:-$TEST_ROOT/no-such-process}" \
  CODEX_UPDATE_HELPER_SPARKLE_DIR="$TEST_ROOT/Sparkle/Installation" \
  CODEX_UPDATE_HELPER_SKIP_SIGNATURE_CHECK=1 \
  CODEX_UPDATE_HELPER_MAX_WAIT_SECONDS=1 \
  CODEX_UPDATE_HELPER_POLL_SECONDS=1 \
  "$HELPER" "$@"
}

/bin/echo "1..10"

/bin/zsh -n "$HELPER"
/bin/echo "ok 1 - zsh syntax"

[[ $("$HELPER" version) == 0.1.0 ]] || fail "unexpected version"
/bin/echo "ok 2 - version"

help_output=$("$HELPER" help)
assert_contains "$help_output" "run [--dry-run] [--force]"
/bin/echo "ok 3 - help"

make_app "$TEST_ROOT/Applications/ChatGPT.app" "dev.exprmntl.codex-update-helper.fixture" "1.0.0" "10"
/bin/mkdir -p "$TEST_ROOT/Sparkle/Installation"
status_output=$(run_helper status)
assert_contains "$status_output" "Installed: 1.0.0 (build 10)"
assert_contains "$status_output" "Staged: none"
/bin/echo "ok 4 - fixture status"

no_update_output=$(run_helper run --dry-run)
assert_contains "$no_update_output" "No staged update is newer"
/bin/echo "ok 5 - no-update dry run"

make_app "$TEST_ROOT/Sparkle/Installation/older/ChatGPT.app" "dev.exprmntl.codex-update-helper.fixture" "1.1.0" "11"
make_app "$TEST_ROOT/Sparkle/Installation/newer/ChatGPT.app" "dev.exprmntl.codex-update-helper.fixture" "1.2.0" "12"
staged_output=$(run_helper status)
assert_contains "$staged_output" "Staged: 1.2.0 (build 12)"
/bin/echo "ok 6 - newest staged build selected"

dry_run_output=$(run_helper run --dry-run --force)
assert_contains "$dry_run_output" "Would wait for Sparkle"
assert_not_contains "$dry_run_output" "Updated Codex"
/bin/echo "ok 7 - forced dry run remains non-mutating"

idle_output=$(CODEX_UPDATE_HELPER_RUNNING_OVERRIDE=1 \
  CODEX_UPDATE_HELPER_IDLE_SECONDS_OVERRIDE=0 run_helper run --dry-run)
assert_contains "$idle_output" "deferring until 900s"
/bin/echo "ok 8 - active app is protected by idle guard"

forced_running_output=$(CODEX_UPDATE_HELPER_RUNNING_OVERRIDE=1 \
  CODEX_UPDATE_HELPER_IDLE_SECONDS_OVERRIDE=0 run_helper run --dry-run --force)
assert_contains "$forced_running_output" "Would request a graceful Codex quit"
/bin/echo "ok 9 - force bypasses only idle guard"

make_app "$TEST_ROOT/Sparkle/Installation/newer/ChatGPT.app" "dev.exprmntl.wrong" "1.3.0" "13"
if run_helper run --dry-run --force >"$TEST_ROOT/invalid.out" 2>&1; then
  fail "invalid staged bundle should fail"
fi
invalid_output=$(<"$TEST_ROOT/invalid.out")
assert_contains "$invalid_output" "expected 'dev.exprmntl.codex-update-helper.fixture'"
/bin/echo "ok 10 - invalid staged identity rejected"
