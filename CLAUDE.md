# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Regenerate Xcode project from project.yml (requires xcodegen)
xcodegen generate
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

## Distribution

### macOS 公证

```bash
# 一键公证
./scripts/notarize.sh
# 安装到 Applications
cp -R build/export/GroTask.app /Applications/
```

- **签名证书**: Developer ID Application: Chao Wu (4KT56S2BX6)
- **Provisioning Profile**: GroTask Developer ID (Developer ID Application 类型, 在 Apple Developer 后台创建)
- **entitlements 必须包含** `com.apple.application-identifier` 和 `com.apple.developer.team-identifier`, 否则 AMFI 无法匹配 profile, 导致 app 无法启动 (error 163)
- **Hardened Runtime 必须启用**: archive 时设置 `ENABLE_HARDENED_RUNTIME=YES`, 否则公证会被拒
- 导出使用 `ExportOptions.plist` (method: developer-id, signingStyle: manual)
- 公证后的 app 位于 `build/export/GroTask.app`
- 公证凭证存储在 macOS 钥匙串，profile 名称为 `GroTask-Notarize`，脚本会自动读取

### iOS TestFlight

```bash
# 一键上传 TestFlight（自动递增 build number）
./scripts/testflight.sh
```

- **Bundle ID**: `com.grotask.ios`
- **App Store Connect App ID**: 6760607036
- 导出使用 `ExportOptions-iOS.plist` (method: app-store, signingStyle: automatic)
- 需要 fastlane 已登录 (`brew install fastlane`)
- App 专用密码已硬编码在脚本中（与公证相同）
- **App icon 不能有 alpha 通道**，否则上传验证失败

### 新电脑首次配置

```bash
# 1. 存储公证凭证到钥匙串
xcrun notarytool store-credentials "GroTask-Notarize" \
  --apple-id "jimwuemail@gmail.com" \
  --team-id "4KT56S2BX6" \
  --password "fsfl-kraz-oens-febj"

# 2. 确保已安装 Developer ID Application 证书和 Provisioning Profile
# 3. 安装 fastlane: brew install fastlane
# 4. 首次运行 fastlane 需要交互式登录 Apple ID + 2FA
```

## CloudKit Sync

- 容器: `iCloud.com.grotask.app`
- **Development 和 Production 是隔离的数据环境**，数据不互通
- Debug 包（Xcode Run）→ Development 环境；正式包（公证/TestFlight）→ Production 环境
- 修改 Core Data model 后，需要去 CloudKit Dashboard 将 schema 从 Development 部署到 Production
- Debug 包下 CloudKit 静默推送不可靠，实时同步可能不工作，属已知限制
- Production 环境下同步正常，延迟通常几秒到十几秒

## Conventions

- UI text and comments are in Chinese
- Animation: spring for status changes, easeInOut for toggles, asymmetric transitions for list updates
- Entitlements are per-target: `macOS/GroTask-Debug.entitlements` / `macOS/GroTask-Release.entitlements`, `iOS/GroTaskiOS.entitlements`
- macOS Release entitlements 中 `aps-environment: production`，Debug 为 `development`
- iOS 右键菜单：编辑、切换类别、时间视角、删除（无置顶）
- macOS 右键菜单：编辑、切换类别、时间视角（无置顶、无删除，删除用 hover 图标）
