#!/bin/zsh
# Optional real macOS dialog test. Requires Accessibility for the invoking host.
# Only a disposable fixture application is ever asked to quit.
set -eu
readonly PROJECT_ROOT=${0:A:h:h}
readonly TEST_ROOT=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codex-update-helper-ui.XXXXXX")
fixture_pid=''
cleanup() {
  if [[ -n $fixture_pid ]]; then /bin/kill "$fixture_pid" 2>/dev/null || true; fi
  /bin/rm -rf "$TEST_ROOT"
}
trap cleanup EXIT INT TERM
readonly APP="$TEST_ROOT/Quit Guard Fixture.app"
/bin/mkdir -p "$APP/Contents/MacOS"
/usr/bin/clang -fobjc-arc -Wall -Wextra -Werror -framework Cocoa "$PROJECT_ROOT/tests/quit-fixture.m" -o "$APP/Contents/MacOS/fixture"
/usr/bin/plutil -create xml1 "$APP/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleIdentifier -string dev.exprmntl.codex-update-helper.fixture "$APP/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleExecutable -string fixture "$APP/Contents/Info.plist"
/usr/bin/plutil -insert CFBundlePackageType -string APPL "$APP/Contents/Info.plist"
/usr/bin/clang -DQUIT_GUARD_TESTING -fobjc-arc -Wall -Wextra -Werror -framework Cocoa -framework ApplicationServices \
  "$PROJECT_ROOT/native/quit-guard.m" "$PROJECT_ROOT/native/settings.m" -o "$TEST_ROOT/guard"
"$TEST_ROOT/guard" --check-accessibility
for mode in scheduled active always; do
  fixture_mode=$mode
  [[ $mode == always ]] && fixture_mode=active
  : > "$TEST_ROOT/fixture.log"
  "$APP/Contents/MacOS/fixture" "$fixture_mode" >"$TEST_ROOT/fixture.log" 2>&1 &
  fixture_pid=$!
  for attempt in {1..100}; do
    [[ $(<"$TEST_ROOT/fixture.log") == *fixture-ready* ]] && break
    /bin/sleep 0.1
  done
  [[ $(<"$TEST_ROOT/fixture.log") == *fixture-ready* ]] || { /bin/cat "$TEST_ROOT/fixture.log"; exit 1; }
  result=0
  policy=idle-only
  [[ $mode == always ]] && policy=always
  output=$("$TEST_ROOT/guard" --quit "$fixture_pid" "$APP/Contents/MacOS/fixture" dev.exprmntl.codex-update-helper.fixture "$policy") || result=$?
  /bin/echo "$output"
  if [[ $mode != active ]]; then
    [[ $result == 0 ]] || exit 1
    [[ $output == *'Accepted'* && $output == *'quit gracefully'* ]] || exit 1
    wait "$fixture_pid"
  else
    [[ $result == 3 ]] || exit 1
    [[ $output == *'canceled the quit'* ]] || exit 1
    /bin/kill -0 "$fixture_pid"
    /bin/kill "$fixture_pid"
    wait "$fixture_pid" 2>/dev/null || true
  fi
  fixture_pid=''
  /bin/echo "ok - native $mode warning"
done
