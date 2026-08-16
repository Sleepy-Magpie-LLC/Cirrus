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

No separate linter. Swift 6.0 strict concurrency checking is enforced by the compiler.

## Architecture

Native macOS menu bar app (Swift 6, SwiftUI, macOS 14+). Wraps the rclone CLI, assembling commands from profile configs and managing the execution lifecycle.

### Two UI Surfaces

- **Tray popup:** NSPanel triggered by NSStatusItem click. SwiftUI content (`TrayPopupView`) with callbacks wired in `AppDelegate`. Refreshes every 1s while visible.
- **Main window:** SwiftUI `Window` with three tabs: Profiles, History, Settings. Closing it keeps the app running in the menu bar (accessory mode).

### State Management

Five `@MainActor @Observable` managers created and loaded by `AppEnvironment.shared`, then injected via `@Environment`:

| Manager | Role |
|---------|------|
| `AppSettings` | rclone path, config directory |
| `ProfileStore` | CRUD for profile JSON files |
| `JobManager` | Spawns rclone `Process`, tracks active jobs, streams output |
| `LogStore` | Log index + raw log files per run |
| `ScheduleManager` | 5-second cron evaluation loop, daily log pruning |

Dependencies use closure-based injection (`@escaping () -> URL`) for deferred evaluation, since managers are created before config is fully loaded.

Launch work (store wiring into `AppDelegate`, `ScheduleManager.start()`, window visibility) happens in `applicationDidFinishLaunching`, never in a view's `onAppear`: the app is `LSUIElement`, so a login-item launch may never instantiate the `Window` scene.

### Job Execution

Profile snapshotted (value-type copy), filter file written from ignore patterns, rclone Process spawned with pipes, output streamed to a live buffer plus log file (ANSI stripped), termination handler finalizes the log entry and cleans up the filter file.

### Data Persistence

All JSON files live in `~/.config/cirrus/` (configurable). Profiles stored as individual `profiles/{uuid}.json` files. Log index at `logs/index.json`, raw output at `logs/runs/`. All writes use `AtomicFileWriter` (temp + rename). Custom `JSONEncoder.cirrus`/`JSONDecoder.cirrus` with ISO8601 dates and sorted keys.

## Key Conventions

- **Swift 6 strict concurrency:** all managers are `@MainActor`. Use `nonisolated(unsafe)` sparingly for values captured in Process termination handlers.
- **Backward-compatible Codable:** `Profile` has a custom `init(from:)` that migrates the legacy format. New optional fields use `decodeIfPresent` with nil defaults.
- **Bisync auto-resync:** the first bisync run for a profile automatically adds `--resync`. Logic in `JobManager.startJob()` checks LogStore for prior successful bisync entries.
- **XcodeGen:** project generated from `project.yml`. Don't edit `Cirrus.xcodeproj` directly.
- **CI releases:** `.github/workflows/release.yml` manual dispatch with semver version input.

## Model Selection

- **Claude Fable 5 (`claude-fable-5`):** actor-isolation and strict-concurrency problems, Process lifecycle and output-streaming bugs, Codable migration design, and security-sensitive handling of assembled rclone commands.
- **Claude Opus 4.8 (`claude-opus-4-8`):** default for features spanning managers and UI, such as new profile fields, scheduling changes, or new rclone actions.
- **Claude Sonnet 5 (`claude-sonnet-5`):** routine SwiftUI view tweaks, small bug fixes, and adding or updating Swift Testing tests.
- **Claude Haiku 4.5 (`claude-haiku-4-5`):** quick lookups, README and doc edits, boilerplate, and cheap subagent work.
