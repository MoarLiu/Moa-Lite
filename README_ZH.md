# Moa-Lite

Moa-Lite 是从 Moa 中拆出的轻量 macOS 菜单栏版本，只保留 Codex Desktop、Claude Desktop 和本地 Provider Bridge 相关能力。

它不包含原 Moa 的 Companion 相关功能：没有桌面宠物、AI 快捷动作、提醒事项、日记、番茄钟、MCP helper、Workflow Runner、资产上传、自动更新、Dashboard、皮肤和声音资源包。

## 功能范围

- Codex 控制：Fast Mode、Remote Connections、官方账号切换、provider profile 导入导出、重启 Codex。
- Provider Bridge：本地 loopback Responses bridge，用于把 Codex 请求转发到 Chat Completions 上游，内置 DeepSeek 和常见网关 preset。
- Claude Desktop profile：写入 Claude Desktop 3P gateway profile，并复制 Claude Code 环境变量片段。
- 用量统计：基于本地 Codex / Claude session 日志估算用量，并支持每日提醒阈值。
- Moa-Lite 数据：导出/导入完整数据包、导出脱敏诊断包，并可把数据根切换到 iCloud Drive。

## 与 Moa 共存

Moa-Lite 已经和原 Moa 做了隔离，可以同时安装：

- App bundle：`Moa-Lite.app`
- Bundle ID：`com.moarliu.moa-lite`
- SwiftPM executable product：`Moa-Lite`
- 本地数据根：`~/.moa-lite`
- Application Support：`~/Library/Application Support/Moa-Lite`
- iCloud 数据根：`iCloud Drive/Moa-Lite`
- 数据包根目录：`MoaLiteDataPackage/.moa-lite`
- Provider Bridge 默认端口：`19361`
- Codex 托管 provider ID：`moa-lite-*`
- Claude Desktop 3P config-library profile：`Moa-Lite`

Moa-Lite 在你执行切换动作时仍会写入真实的 Codex 和 Claude Desktop 配置文件；但它自己的 profile 数据库、bridge token、数据包 manifest、iCloud 状态和诊断包都与 Moa 分开存放。

## 数据文件

Moa-Lite 的本地数据存放在：

- `~/.moa-lite/config.toml`
- `~/.moa-lite/auth.json`
- `~/.moa-lite/codex_official_accounts.json`
- `~/.moa-lite/codex-auth/accounts/*.json`
- `~/.moa-lite/profiles.json`
- `~/.moa-lite/provider_bridge_profiles.json`
- `~/.moa-lite/claude_desktop_profiles.json`
- `~/.moa-lite/usage-pricing-overrides.json`
- `~/.moa-lite/backups`

开启 iCloud 存储后，Moa-Lite 会直接读写 `iCloud Drive/Moa-Lite`，不再读写 `~/.moa-lite`。

## 构建

```bash
swift build
./scripts/run-tests.sh
CODE_SIGN_IDENTITY=- ./scripts/build-menu-bar-app.sh
```

构建结果会输出到 `Moa-Lite.app`。

生成 DMG：

```bash
CODE_SIGN_IDENTITY=- ./scripts/package-dmg.sh
```

DMG 会输出到 `dist/Moa-Lite-<version>-macos-<arch>.dmg`，并生成匹配的 SHA-256 文件。

## Codex 本地运行按钮

Codex app 的 Run 按钮通过以下文件接入：

- `script/build_and_run.sh`
- `.codex/environments/environment.toml`

脚本会构建 `Moa-Lite.app`，停止正在运行的 Moa-Lite 进程，然后启动新 bundle。

## 安全说明

- Provider API key 和 bridge token 只保存在本地。
- Provider Bridge 只监听 `127.0.0.1`。
- 诊断包会脱敏 auth、key、token 字段。
- 打包脚本会拒绝把 `.moa`、`.moa-lite`、`.codex`、auth/config/profile 文件、环境变量文件和签名密钥打进发布包。
- Moa-Lite 不打包 `MoaMCP`，也不暴露本地 workflow tools。
