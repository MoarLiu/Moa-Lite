# Changelog

## 1.0.0

- Created Moa-Lite from the Moa codebase as an independent macOS menu bar app.
- Kept Codex, Claude Desktop, Provider Bridge, local usage insights, data package import/export, diagnostics, and iCloud data-root switching.
- Removed Companion, desktop pet, AI quick actions, reminders, journal, Pomodoro, MCP helper, workflow runner, asset upload, updater, dashboard, skins, and sounds.
- Restored trimmed English and Simplified Chinese localization bundles for the Moa-Lite menu and dialogs.
- Isolated app identity and data from Moa: `Moa-Lite.app`, `com.moarliu.moa-lite`, `~/.moa-lite`, `iCloud Drive/Moa-Lite`, `moa-lite-*` Codex provider IDs, and Provider Bridge port `19361`.
- Replaced legacy Moa integration tests with Moa-Lite focused core tests.
