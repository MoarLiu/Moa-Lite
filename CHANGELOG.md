# Changelog

## 1.1.1 - 2026-06-21

- Fixed Codex Official Mode restore so it preserves the selected `model_provider` value for session continuity.
- Removed third-party `base_url` and `experimental_bearer_token` values from the selected provider when restoring Codex Official Mode.
- Added regression coverage for restoring from direct third-party provider profiles such as `model_provider = "one"`.

## 1.1.0 - 2026-06-21

- Added a ZCode menu with usage statistics, launch/relaunch actions, and quick access to `~/.zcode`.
- Added ZCode usage scanning from the local CLI SQLite database with GLM-5.2, GLM-5.1, and GLM-5-Turbo pricing.
- Added cache hit ratio to Codex, Claude Desktop, and ZCode usage summaries and insights.
- Localized new ZCode and cache-hit UI strings in English and Simplified Chinese.

## 1.0.0

- Created Moa-Lite from the Moa codebase as an independent macOS menu bar app.
- Kept Codex, Claude Desktop, Provider Bridge, local usage insights, data package import/export, diagnostics, and iCloud data-root switching.
- Removed Companion, desktop pet, AI quick actions, reminders, journal, Pomodoro, MCP helper, workflow runner, asset upload, updater, dashboard, skins, and sounds.
- Restored trimmed English and Simplified Chinese localization bundles for the Moa-Lite menu and dialogs.
- Isolated app identity and data from Moa: `Moa-Lite.app`, `com.moarliu.moa-lite`, `~/.moa-lite`, `iCloud Drive/Moa-Lite`, `moa-lite-*` Codex provider IDs, and Provider Bridge port `19361`.
- Replaced legacy Moa integration tests with Moa-Lite focused core tests.
