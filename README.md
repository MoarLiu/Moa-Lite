# Moa-Lite

Moa-Lite is the trimmed macOS menu bar edition of Moa for Codex Desktop, Claude Desktop, and local Provider Bridge workflows.

It intentionally excludes the original Moa Companion surface: no desktop pet, AI quick actions, reminders, journal, Pomodoro, MCP helper, workflow runner, asset upload, updater, dashboard, skins, or sounds.

## Features

- Codex controls: Fast Mode, Remote Connections, official account switching, provider profile import/export, and Codex reopen helpers.
- Provider Bridge: local loopback Responses bridge for Chat Completions upstreams, with DeepSeek and common gateway presets.
- Claude Desktop profiles: write Claude Desktop 3P gateway profiles and copy Claude Code environment snippets.
- Usage insights: local Codex and Claude usage summaries with configurable daily alerts.
- Moa-Lite Data: export/import data packages, export redacted diagnostics, and optionally switch the active data root to iCloud Drive.

## Coexistence With Moa

Moa-Lite is configured so it can be installed beside the original Moa app:

- App bundle: `Moa-Lite.app`
- Bundle identifier: `com.moarliu.moa-lite`
- SwiftPM executable product: `Moa-Lite`
- Local data root: `~/.moa-lite`
- Application Support root: `~/Library/Application Support/Moa-Lite`
- iCloud data root: `iCloud Drive/Moa-Lite`
- Data package root: `MoaLiteDataPackage/.moa-lite`
- Provider Bridge default port: `19361`
- Codex managed provider IDs: `moa-lite-*`
- Claude Desktop 3P config-library profile: `Moa-Lite`

Moa-Lite still edits the real Codex and Claude Desktop configuration files when you ask it to switch profiles. Its own profile databases, bridge tokens, package manifests, iCloud state, and diagnostics are stored separately from Moa.

## Data Files

Moa-Lite stores its local profile and recovery data under:

- `~/.moa-lite/config.toml`
- `~/.moa-lite/auth.json`
- `~/.moa-lite/codex_official_accounts.json`
- `~/.moa-lite/codex-auth/accounts/*.json`
- `~/.moa-lite/profiles.json`
- `~/.moa-lite/provider_bridge_profiles.json`
- `~/.moa-lite/claude_desktop_profiles.json`
- `~/.moa-lite/usage-pricing-overrides.json`
- `~/.moa-lite/backups`

When iCloud storage is enabled, Moa-Lite reads and writes `iCloud Drive/Moa-Lite` directly instead of `~/.moa-lite`.

## Build

```bash
swift build
./scripts/run-tests.sh
CODE_SIGN_IDENTITY=- ./scripts/build-menu-bar-app.sh
```

The app bundle is written to `Moa-Lite.app`.

To create a DMG:

```bash
CODE_SIGN_IDENTITY=- ./scripts/package-dmg.sh
```

The DMG is written to `dist/Moa-Lite-<version>-macos-<arch>.dmg` with a matching SHA-256 file.

## Local Run Button

Codex app run-button support is wired through:

- `script/build_and_run.sh`
- `.codex/environments/environment.toml`

The script builds `Moa-Lite.app`, stops any currently running Moa-Lite process, and launches the fresh bundle.

## Security Notes

- Provider API keys and bridge tokens stay local.
- The Provider Bridge listens on `127.0.0.1` only.
- Diagnostic packages redact auth, key, and token fields.
- Packaging scripts refuse to include `.moa`, `.moa-lite`, `.codex`, auth/config/profile files, environment files, and signing keys.
- Moa-Lite does not bundle `MoaMCP` and does not expose local workflow tools.
