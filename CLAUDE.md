# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test

```bash
# Generate Xcode project (requires: brew install xcodegen)
xcodegen generate

# Build
xcodebuild -scheme Cirrus -configuration Debug -destination 'platform=macOS' build

# Release build + open in Finder
./build-release.sh

# Run all tests (Swift Testing framework: @Test, #expect())
xcodebuild test -scheme CirrusTests -destination 'platform=macOS'
```

No separate linter — Swift 6.0 strict concurrency checking is enforced by the compiler.

## Architecture

Native macOS menu bar app (Swift 6, SwiftUI, macOS 14+). Wraps rclone CLI — assembles commands from profile configs and manages execution lifecycle.

### Two UI Surfaces

- **Tray popup** — NSPanel triggered by NSStatusItem click. SwiftUI content (`TrayPopupView`) with callbacks wired in `AppDelegate`. Refreshes every 1s while visible.
- **Main window** — SwiftUI `Window` with three tabs: Profiles, History, Settings. Closing it keeps the app running in the menu bar (accessory mode).

### State Management

Five `@MainActor @Observable` managers created in `CirrusApp.init()` and injected via `@Environment`:

| Manager | Role |
|---------|------|
| `AppSettings` | rclone path, config directory |
| `ProfileStore` | CRUD for profile JSON files |
| `JobManager` | Spawns rclone `Process`, tracks active jobs, streams output |
| `LogStore` | Log index + raw log files per run |
| `ScheduleManager` | 5-second cron evaluation loop, daily log pruning |

Dependencies use **closure-based injection** (`@escaping () -> URL`) for deferred evaluation — managers are created before config is fully loaded.

### Job Execution

Profile snapshotted (value-type copy) -> filter file written from ignore patterns -> rclone Process spawned with pipes -> output streamed to live buffer + log file (ANSI stripped) -> termination handler finalizes log entry + cleans up filter file.

### Data Persistence

All JSON files in `~/.config/cirrus/` (configurable). Profiles stored as individual `profiles/{uuid}.json` files. Log index at `logs/index.json`, raw output at `logs/runs/`. All writes use `AtomicFileWriter` (temp + rename). Custom `JSONEncoder.cirrus`/`JSONDecoder.cirrus` with ISO8601 dates and sorted keys.

## Key Conventions

- **Swift 6 strict concurrency** — all managers are `@MainActor`. Use `nonisolated(unsafe)` sparingly for values captured in Process termination handlers.
- **Backward-compatible Codable** — `Profile` has custom `init(from:)` that migrates legacy format. New optional fields use `decodeIfPresent` with nil defaults.
- **Bisync auto-resync** — First bisync run for a profile automatically adds `--resync`. Logic in `JobManager.startJob()` checks LogStore for prior successful bisync entries.
- **XcodeGen** — Project generated from `project.yml`. Don't edit `Cirrus.xcodeproj` directly.
- **CI releases** — `.github/workflows/release.yml` manual dispatch with semver version input.
