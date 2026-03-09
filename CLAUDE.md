# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Regenerate Xcode project from project.yml (requires xcodegen)
xcodegen generate

# Run unit tests (macOS host)
xcodebuild test -scheme GroTask -destination "platform=macOS"

# Build macOS app
xcodebuild build -scheme GroTask -configuration Debug

# Build iOS app
xcodebuild build -scheme GroTaskiOS -configuration Debug -destination "generic/platform=iOS"
```

## Architecture

GroTask is a dual-platform (macOS 15+ / iOS 17+) task management app using SwiftUI, Core Data, and CloudKit sync. Built with Swift 5.9 and XcodeGen (`project.yml`).

### Project Layout

- **Shared/** — Cross-platform code: models, view models, persistence, Core Data model
- **macOS/** — macOS target: menu bar app with floating panel (NSPanel)
- **iOS/** — iOS target: standard NavigationStack list UI
- **GroTaskTests/** — XCTest unit tests (hosted by macOS target)

### Data Flow (MVVM)

`TaskItemEntity` (Core Data) ↔ `TaskItem` (value type) ↔ `TaskStore` (@Observable) ↔ SwiftUI Views

- **TaskStore** is the single source of truth, performs all CRUD via Core Data
- CloudKit sync is automatic via `NSPersistentCloudKitContainer` (container: `iCloud.com.grotask.app`)
- TaskStore observes `NSManagedObjectContextObjectsDidChange` to refresh on sync
- Merge policy: `NSMergeByPropertyObjectTrumpMergePolicy`

### Domain Model

- **TaskCategory**: `.work` (blue) / `.life` (orange)
- **TaskStatus**: `.todo` (0) / `.done` (2)
- **TaskItem**: id, title, status, category, isPinned, createdAt, completedAt

### Platform Differences

| Aspect | macOS | iOS |
|--------|-------|-----|
| Entry | `AppDelegate` + `NSStatusItem` | `WindowGroup` |
| UI | `FloatingPanel` (320×480) anchored to menu bar | `NavigationStack` + `List` |
| Row actions | Context menu | Swipe actions |

### Migration

`MigrationHelper` handles one-time migration from legacy JSON (`~/Library/Application Support/GroTask/tasks.json`) to Core Data. Creates `.migrated` marker file when complete.

### Testing

Tests use in-memory Core Data containers (`/dev/null` store URL) for isolation. Test files cover: persistence, store CRUD/filtering, model logic, and migration.

## Notarization (macOS)

```bash
# 一键公证 (需要设置环境变量 APP_PASSWORD)
APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" ./scripts/notarize.sh
```

### Key Points

- **签名证书**: Developer ID Application: Chao Wu (4KT56S2BX6)
- **Provisioning Profile**: GroTask Developer ID (Developer ID Application 类型, 在 Apple Developer 后台创建)
- **entitlements 必须包含** `com.apple.application-identifier` 和 `com.apple.developer.team-identifier`, 否则 AMFI 无法匹配 profile, 导致 app 无法启动 (error 163)
- **Hardened Runtime 必须启用**: archive 时设置 `ENABLE_HARDENED_RUNTIME=YES`, 否则公证会被拒
- 导出使用 `ExportOptions.plist` (method: developer-id, signingStyle: manual)
- 公证后的 app 位于 `build/export/GroTask.app`
- 公证凭证存储在 macOS 钥匙串，profile 名称为 `GroTask-Notarize`，脚本会自动读取

### 新电脑首次配置

在新电脑上首次公证前，需要执行一次：

```bash
# 1. 存储公证凭证到钥匙串
xcrun notarytool store-credentials "GroTask-Notarize" \
  --apple-id "jimwuemail@gmail.com" \
  --team-id "4KT56S2BX6" \
  --password "fsfl-kraz-oens-febj"

# 2. 确保已安装 Developer ID Application 证书和 Provisioning Profile
```

之后直接 `./scripts/notarize.sh` 即可，无需传密码。

## Conventions

- UI text and comments are in Chinese
- Animation: spring for status changes, easeInOut for toggles, asymmetric transitions for list updates
- Entitlements are per-target: `macOS/GroTask.entitlements`, `iOS/GroTaskiOS.entitlements`
