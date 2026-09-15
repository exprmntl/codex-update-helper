#!/bin/zsh
set -eu
readonly PROJECT_ROOT=${0:A:h:h}
readonly LABEL=dev.exprmntl.codex-update-helper
readonly APP="$HOME/Applications/Codex Update Helper.app"
readonly PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
readonly LOG_DIR="$HOME/Library/Logs/Codex Update Helper"
readonly BACKUP_DIR="$HOME/Library/Application Support/Codex Update Helper/backups/$(/bin/date +%Y%m%d-%H%M%S)"

/bin/zsh "$PROJECT_ROOT/scripts/build-app.sh"
/bin/mkdir -p "$HOME/Applications" "${PLIST:h}" "$LOG_DIR" "$BACKUP_DIR"
if [[ -f $PLIST ]]; then /bin/cp "$PLIST" "$BACKUP_DIR/$LABEL.plist"; fi
if [[ -d $APP ]]; then /usr/bin/ditto "$APP" "$BACKUP_DIR/Codex Update Helper.app"; fi

# Never interrupt an updater that may be in the middle of quitting/installing.
if /bin/launchctl print "gui/$UID/$LABEL" 2>/dev/null | /usr/bin/grep -q 'state = running'; then
  /bin/echo 'An update check is running. Wait for it to finish, then retry.' >&2
  exit 1
fi
/bin/launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
/usr/bin/ditto "$PROJECT_ROOT/build/Codex Update Helper.app" "$APP"
/usr/bin/plutil -create xml1 "$PLIST"
/usr/bin/plutil -insert Label -string "$LABEL" "$PLIST"
/usr/bin/plutil -insert ProgramArguments -json '[]' "$PLIST"
/usr/bin/plutil -insert ProgramArguments.0 -string "$APP/Contents/Resources/codex-update-helper" "$PLIST"
/usr/bin/plutil -insert ProgramArguments.1 -string run "$PLIST"
/usr/bin/plutil -insert ProgramArguments.2 -string --scheduled "$PLIST"
/usr/bin/plutil -insert RunAtLoad -bool true "$PLIST"
/usr/bin/plutil -insert ProcessType -string Background "$PLIST"
/usr/bin/plutil -insert StandardOutPath -string "$LOG_DIR/service.log" "$PLIST"
/usr/bin/plutil -insert StandardErrorPath -string "$LOG_DIR/service.error.log" "$PLIST"
# A lightweight minute tick reads settings, so changes apply without reinstalling.
# The helper enforces the configured window and retry interval itself.
/usr/bin/plutil -insert StartInterval -integer 60 "$PLIST"
/usr/bin/plutil -lint "$PLIST"
/bin/launchctl bootstrap "gui/$UID" "$PLIST"
/bin/echo "Installed updater service. Previous files: $BACKUP_DIR"
"$APP/Contents/Resources/codex-update-helper" config show
/bin/echo "Enable Codex Update Helper in System Settings > Privacy & Security > Accessibility."
