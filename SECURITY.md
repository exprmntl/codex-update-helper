# Security

## Trust model

Codex Update Helper does not download, extract, copy, or replace application code. It delegates installation to the Sparkle framework bundled with Codex.

Before requesting a quit, it verifies both the installed application and staged update using:

- bundle ID `com.openai.codex`
- Apple Developer team ID `2DC432GLL2`
- `codesign --verify --deep --strict`

The helper never uses `sudo`, never force-kills Codex, and makes no network requests.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for `exprmntl/codex-update-helper`. Do not open a public issue for an unpatched security problem.
