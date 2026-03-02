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

## Conventions

- UI text and comments are in Chinese
- Animation: spring for status changes, easeInOut for toggles, asymmetric transitions for list updates
- Entitlements are per-target: `macOS/GroTask.entitlements`, `iOS/GroTaskiOS.entitlements`
