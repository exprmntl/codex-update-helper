# Codex Update Helper

<img src="assets/AppIcon.png" alt="Codex Update Helper moon and update arrow icon" width="112">

Keep the Codex desktop app current on macOS, even when it stays open for days.

Codex already downloads and verifies its own updates with Sparkle. This helper finishes staged updates during **2–3 a.m. Eastern**, asks Codex to quit gracefully, waits for Sparkle to install, and reopens Codex only if it was open before.

> Unofficial community utility. Not affiliated with or endorsed by OpenAI.

## Install

From the repository on macOS (Xcode Command Line Tools are required to build):

```bash
zsh scripts/install-local.sh
open "$HOME/Applications/Codex Update Helper.app"
```

Enable **Codex Update Helper** once in **System Settings → Privacy & Security → Accessibility**. If it is not listed, use **+** and select the app in your home folder's Applications directory. The helper defers before requesting a quit until this permission is available. Rebuilding an ad-hoc signed helper may require re-enabling its permission.

The local installer backs up and replaces the existing `dev.exprmntl.codex-update-helper` LaunchAgent, including an older Homebrew installation. It installs a self-contained app under `~/Applications`; no checkout is needed at runtime. Existing Homebrew files are preserved. Do not run `brew services restart codex-update-helper` afterward: that restores the older Homebrew service configuration. Use the local installer to reinstall this version.

By default, the service attempts updates every 15 minutes between **02:00 inclusive and 03:00 exclusive in `America/New_York`**, following daylight saving time independently of the Mac's timezone. It also requires 15 minutes of keyboard/mouse inactivity. A busy Mac is retried during that hour, then the following night. If the Mac sleeps through the window, the helper skips the daytime wake-up; it does not wake the Mac. The spring-forward date has no 2 a.m. hour, so that night's default update window is skipped.

Codex's own quit dialog distinguishes active local tasks and worktrees still starting from merely having scheduled tasks enabled. By default, the helper accepts only the exact English scheduled-tasks-only warning. It cancels a recognized quit dialog with any other warning, including active work, and never clicks an unrelated dialog. Unknown/localized dialog structures are left alone and time out without a forced quit.

## Settings

Open **Codex Update Helper** from your home folder's Applications directory, or run `./bin/codex-update-helper settings`. The settings window lets you change the schedule and restart behavior. Settings are stored in `~/Library/Application Support/Codex Update Helper/settings.plist` and survive reinstalls. The service reads them each minute; changes take effect on the next check without reinstalling or restarting the service.

Use the native time pickers for start/end times, the searchable timezone dropdown, and the idle/retry menus. The idle menu disables automatically when you choose to restart during active work. **Restore defaults** fills in the default choices; **Save** applies them. **Cancel** leaves saved settings unchanged.

| Setting | Default | Behavior |
| --- | --- | --- |
| `start-time` | `02:00` | Start of the update window, in 24-hour HH:MM format. |
| `end-time` | `03:00` | End of the window, exclusive. Windows may cross midnight; start and end must differ. |
| `timezone` | `America/New_York` | Named timezone, including daylight saving changes. |
| `idle-minutes` | `15` | Keyboard/mouse inactivity required for `idle-only`; `0` disables this extra check. |
| `retry-minutes` | `15` | Time between update attempts within the window. |
| `restart-policy` | `idle-only` | Wait for no active local tasks or worktrees being created. `always` permits interrupting active work and ignores keyboard/mouse inactivity. |
| `reopen` | `true` | Reopen Codex if it was open before the update; `false` leaves it closed. |

The **always** policy still uses a graceful quit and Sparkle's installer. It approves known warnings about active local tasks and worktrees being created, which can interrupt or lose that work. It does not force-kill a hung app, bypass signature checks, or approve unknown warnings. The time window applies to both policies.

Command-line equivalents:

```bash
./bin/codex-update-helper config show
./bin/codex-update-helper config set start-time 01:30 end-time 03:00 timezone America/New_York
./bin/codex-update-helper config set restart-policy always
./bin/codex-update-helper config set restart-policy idle-only idle-minutes 15 reopen true
./bin/codex-update-helper config reset
```

Multiple values are validated and saved together. An invalid setting leaves the existing file unchanged. Missing settings use the defaults above; a malformed settings file blocks automatic updates until it is fixed or reset. Saved settings are data, never executable shell code. Legacy environment overrides for timezone, start/end hours, and idle seconds take precedence when explicitly supplied.

## Check it

```bash
./bin/codex-update-helper status
./bin/codex-update-helper doctor
./bin/codex-update-helper run --dry-run
```

The installed command is also available at `~/Applications/Codex Update Helper.app/Contents/Resources/codex-update-helper`. An older `codex-update-helper` on your PATH may still refer to the Homebrew release.

To install a waiting update immediately, bypassing the time window and keyboard/mouse idle guard:

```bash
./bin/codex-update-helper run --force
```

The configured restart policy, signature checks, bundle identity checks, graceful quitting, and timeouts still apply. `--force` only bypasses the schedule and keyboard/mouse idle guard; it does not change `idle-only` to `always` and never force-kills Codex.

## Exactly what it does

- Runs as your macOS user through a LaunchAgent; it never needs `sudo`.
- Enables Codex's automatic update checks and automatic downloads.
- Reads Codex's installed build from `/Applications/ChatGPT.app`.
- Reads updates already staged in Codex's Sparkle cache.
- Verifies the installed and staged apps have bundle ID `com.openai.codex`, OpenAI team ID `2DC432GLL2`, and valid Apple code signatures.
- Uses Codex's native quit confirmation to protect active local tasks and worktrees being created under the default `idle-only` policy.
- Lets Sparkle perform the installation. The helper never downloads or copies Codex.
- Reopens Codex when it was open before the update and the `reopen` setting is enabled.

It leaves Sparkle's **Skip this version** preference unchanged.

## Uninstall

```bash
launchctl bootout "gui/$(id -u)/dev.exprmntl.codex-update-helper"
rm "$HOME/Library/LaunchAgents/dev.exprmntl.codex-update-helper.plist"
```

Then remove `~/Applications/Codex Update Helper.app` in Finder. This does not remove Codex, its preferences, or an older Homebrew package. Installer backups are in `~/Library/Application Support/Codex Update Helper/backups/`.

## Logs

The local service writes output to:

```text
~/Library/Logs/Codex Update Helper/service.log
~/Library/Logs/Codex Update Helper/service.error.log
```

## Requirements and scope

- macOS
- The Codex desktop app installed at `/Applications/ChatGPT.app`
- Xcode Command Line Tools to build the helper (no build tools needed at runtime)
- One-time Accessibility permission for the dedicated helper app

The implementation depends on Codex's current Sparkle staging layout. If that implementation changes, `doctor` should report the mismatch rather than attempting an unsafe installation.

## Development

```bash
zsh -n bin/codex-update-helper
./tests/test.sh
# Optional: briefly displays test dialogs in a disposable fixture app.
zsh tests/native-ui.sh
```

See [SECURITY.md](SECURITY.md) for the trust model and vulnerability reporting.

## License

MIT
