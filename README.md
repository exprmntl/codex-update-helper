# Codex Update Helper

Keep the Codex desktop app current on macOS, even when it stays open for days.

Codex already downloads and verifies its own updates with Sparkle. This small helper notices when a signed update is waiting, asks Codex to quit gracefully, waits for Sparkle to install it, and reopens Codex only if it was open before.

> Unofficial community utility. Not affiliated with or endorsed by OpenAI.

## Install

```bash
brew install exprmntl/tap/codex-update-helper
brew services start codex-update-helper
```

That is all. The service checks once an hour and only quits an open Codex app after the Mac has been idle for at least 15 minutes.

## Check it

```bash
codex-update-helper status
codex-update-helper doctor
codex-update-helper run --dry-run
```

To install a waiting update immediately, bypassing only the idle-time guard:

```bash
codex-update-helper run --force
```

Signature checks, bundle-identity checks, graceful quitting, and timeouts still apply.

## Exactly what it does

- Runs as your macOS user through `brew services`; it never needs `sudo`.
- Enables Codex's automatic update checks and automatic downloads.
- Reads Codex's installed build from `/Applications/ChatGPT.app`.
- Reads updates already staged in Codex's Sparkle cache.
- Verifies the installed and staged apps have bundle ID `com.openai.codex`, OpenAI team ID `2DC432GLL2`, and valid Apple code signatures.
- Gracefully asks Codex to quit. It never force-kills the app.
- Lets Sparkle perform the installation. The helper never downloads or copies Codex.
- Reopens Codex only when it was open before the update.

It respects a user's **Skip this version** choice.

## Uninstall

```bash
brew services stop codex-update-helper
brew uninstall codex-update-helper
brew untap exprmntl/tap
```

Uninstalling does not remove Codex or its preferences.

## Logs

Homebrew writes service output to:

```text
$(brew --prefix)/var/log/codex-update-helper.log
$(brew --prefix)/var/log/codex-update-helper.error.log
```

## Requirements and scope

- macOS
- The Codex desktop app installed at `/Applications/ChatGPT.app`
- Homebrew

The implementation depends on Codex's current Sparkle staging layout. If that implementation changes, `doctor` should report the mismatch rather than attempting an unsafe installation.

## Development

```bash
zsh -n bin/codex-update-helper
./tests/test.sh
```

See [SECURITY.md](SECURITY.md) for the trust model and vulnerability reporting.

## License

MIT
