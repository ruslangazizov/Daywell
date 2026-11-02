# Daywell iOS — working context

Verified against the working tree on 2026-11-01. Paths below are relative to this directory. Update this file when something in it becomes outdated.

## Project and status

- Native habit/task planner: SwiftUI, TCA, Swift Concurrency; iOS 26 minimum, Swift tools 6.4.
- This directory is its own Git repository. Check its status and preserve unrelated changes.
- Current tabs: **Today, Statistics, Settings**. Today supports **Timeline, Agenda, Zones**; Timeline is the default.
- Tasks/occurrences are stored locally with SwiftData through `TasksClient` and `OccurrencesClient` (fetch, save/update, delete). Completion changes persist; failed writes restore the previous UI outcome. Today presents `TaskEditorFeature` to create a task or repeating habit, using the selected date and preferred default duration. Drafts support optional/overnight windows, recurrence, notes and colors; failed saves keep the editor open, and successful saves update Today. Today cards open task/habit details in a native navigation stack in all three layouts; completion buttons remain separate. Details retain the selected occurrence day, share Today’s task/outcome data, show recorded seven-day habit history and open the same editor for existing tasks. Editing preserves identity, creation date and recorded outcomes; schedule changes apply to the whole task/habit. Reminder scheduling, badge updates and iCloud integration are unfinished. Statistics reads the same clients and shows complete-day totals, period charts, eligible hour/weekday patterns, and active-habit completion counts. Historical consistency/reset rates remain unavailable because schedule snapshots are not stored. `ClientPreviewData.swift` seeds tasks and occurrence history into the Debug simulator database once; production databases start empty. Sample dates remain anchored to the initial import day.
- `../Architecture.md` describes a target architecture and contains outdated names, tabs and toolchain details. Prefer current source/manifests for implemented behavior; README screenshots are not proof of implemented features.

## Code map and conventions

- `Daywell/DaywellApp.swift`: app entry point; creates one root store via `AppBootstrap`.
- `DaywellFeatures/Sources/AppRootFeature`: bootstrap, root reducer, tab composition. Feature targets: `TasksFeature`, `StatisticsFeature`, `SettingsFeature`; keep them independent of one another.
- `DaywellFeatures/Sources/TasksFeature/TaskDetailsFeature`: live detail projection and SwiftUI views. Navigation stores only the occurrence ID; read observable state inside the destination view so completion and edits refresh immediately. History reports recorded outcomes, not inferred misses or streaks.
- `TasksNavigationView` wraps the app's `TabView` and owns task-detail navigation and the task-editor sheet. Details push over the entire tab screen, so the tab bar moves with Today during forward/back transitions instead of toggling visibility. `TasksTodayView` is the root content without its own navigation stack; Settings and Statistics retain their independent navigation containers.
- `DaywellCore/Sources/Domain`: validated value models and scheduling rules (`DWTask`, `TaskSchedule`, `LocalDate`, `TimeWindow`, `OccurrenceRecord`). No SwiftUI, TCA or SwiftData business-model dependencies.
- `DaywellCore/Sources/Clients`: injectable async dependencies; both live task/occurrence clients share a lazy `TaskStore`. Debug simulator builds use a separate persistent store at `Application Support/Daywell-Simulator/Daywell.store`, seeded once from `ClientPreviewData` (tasks and occurrences only; zone preferences are unchanged). A `preview-data-seeded` marker beside the database prevents reseeding after edits or deletions. Device and Release builds use the normal store. Preview and UI-test stores are in memory and empty; UI-test mode takes precedence over the simulator store. Override dependencies in tests.
- `DaywellCore/Sources/Persistence`: preferences, settings options and `TaskStore`. The MainActor-isolated SwiftData context saves explicitly and rolls back failures; CloudKit is explicitly disabled. Unique identity keys accompany validated Codable domain payloads. Permanent task deletion also deletes its outcomes; outcomes require an existing task.
- `DaywellCore/Sources/DesignSystem`: shared SwiftUI components, `DWColor`, appearance and layout constants. Reuse these and native iOS controls.
- Follow existing TCA patterns: `Reducer`, `@ObservableState`, `@CasePathable`, scoped stores, dependency-backed effects. Views send actions; reducers own mutations. Existing Today view models are derived display projections, not separate mutable stores.
- Packages enable Approachable Concurrency; UI targets and Domain default to MainActor. Domain value models and client contracts explicitly use `nonisolated`/`Sendable`; preserve isolation boundaries.
- Preferences use `@Shared` for writes and `@SharedReader` for reads with `Persistence.Preferences`; mutate shared values through `withLock`. Keys are computed properties so they respect the current `defaultAppStorage` dependency. Keep stored keys stable.

## Domain rules

- Statistics attributes totals, daily/weekday charts and habit counts to `OccurrenceRecord.day`, including marks made later. Today and future task days are excluded until complete. Hour patterns use only marks recorded on the task's day in the current time zone; retrospective marks do not count toward the 20-check-in hour threshold. Keep `recordedAt` unchanged as the actual check-in timestamp.
- A habit is a repeating `DWTask`. Occurrence identity is `(taskID, LocalDate)`; moving a time window does not change it. Missing outcome records mean no recorded outcome, not automatically overdue.
- Use calendar-day arithmetic, not 86,400-second offsets. Recurrence produces at most one occurrence per day; weekly intervals are Monday-anchored regardless of UI preferences; nonexistent monthly dates are skipped.
- Time windows include their start and exclude their end; overnight windows explicitly use `endDay: .nextDay`. Preserve validation during both construction and decoding.

### Daily zones

Tasks own their optional time window. Today computes zone membership from any positive-duration overlap with the current zone settings; touching an endpoint does not count. A task can appear in several zones, while tasks without a matching zone or without a time window appear in **No zone**.

All cards for an occurrence share one completion record. Timeline, Agenda and daily totals count that occurrence once. Editing, deleting or restoring zones regroups tasks without changing their times or completion records, including when viewing a past date. Overnight tasks remain on their scheduled start date.

Stored tasks contain explicit time windows. Any future import of the old task format must resolve inherited windows from the old zones before decoding into the current model.

Zone collections allow gaps and an empty list, but reject overlapping windows and duplicate IDs. Default zones have stable IDs.

## Build and verification

### Xcode and Simulator tools

- Prefer **XcodeBuildMCP** (Build iOS Apps plugin) for builds, tests, simulator control, UI inspection and debugging. Verify tools are callable; an enabled plugin alone does not prove the server is running.
- Use `list_sims` to discover the current simulator; reuse a booted device rather than hardcoding its UUID. Before building, running or testing, inspect `session_show_defaults` and set the correct project, scheme and simulator with `session_set_defaults`.
- For UI checks, use `snapshot_ui` before interacting, target its element references, and refresh after navigation, scrolling or layout changes. Use screenshots for visual checks. Verify the affected flow after UI changes; a successful build alone is insufficient.
- If MCP is unavailable, use `xcodebuild`, `xcrun simctl` and LLDB as appropriate, explaining any missing UI automation. Request expanded execution permissions when required for CoreSimulator access; do not assume a connection error means Xcode is broken.
- Resolve app storage through `simctl get_app_container <simulator-id> <bundle-id> data`; do not hardcode container paths. Preserve existing simulator data; do not erase devices, uninstall the app or reset its database unless the task requires and authorizes it.
- MCP startup requires Node.js and `npx`. If startup fails, check their availability and Codex/npm logs. Initial package installation can exceed the connection timeout: complete it separately, verify MCP initialization, then reconnect/restart Codex if its tools are still missing. On 2026-11-02, XcodeBuildMCP 2.7.0 successfully listed simulators and read Daywell's UI on iOS 27.2.

### Build commands and tests

- Local project: `Daywell.xcodeproj/project.xcproj` (JSON format). Installed stable toolchain: `/Applications/Xcode-27.2.app`; use `DEVELOPER_DIR` per command rather than changing global Xcode selection.
- `.gitignore` currently excludes the Xcode project and nested package lockfiles; check tracking explicitly when changing project configuration.
- From this directory, build with:

  ```sh
  DEVELOPER_DIR=/Applications/Xcode-27.2.app/Contents/Developer xcodebuild -project Daywell.xcodeproj -scheme Daywell -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/daywell-derived build CODE_SIGNING_ALLOWED=NO
  ```

- Unit tests: Swift Testing + TCA `TestStore` in `DaywellCore/Tests/{DomainTests,ClientsTests}` and `DaywellFeatures/Tests/{TasksFeatureTests,StatisticsFeatureTests,SettingsFeatureTests}`. Use iOS Simulator destinations for UIKit-dependent targets; inspect available package schemes before running package tests.
- UI tests: XCTest in `DaywellUITests`, scheme `DaywellUITests`. Discover an available simulator, then use `xcodebuild test` with its destination. The app scheme currently lists UI tests only; it does not establish package-test coverage.
- `BaseUITestCase` sets `IS_UI_TESTING=true`; the app then uses a fresh UserDefaults suite and an empty in-memory SwiftData store. Inject dates, calendars, clocks, UUIDs and clients for deterministic reducer tests. Keep accessibility IDs in each feature's `Accessibility.swift` consistent with UI tests.

## Design references

- Follow iOS Human Interface Guidelines and favor standard SwiftUI components. Reuse the existing design system; support light/dark appearance and system accessibility settings.
- Figma work must use **Figma-bridge only**. If unavailable or unable to perform an action, stop that work and tell the user; never use a browser or Computer Use for Figma.
- All Figma content/comments must be English. New-feature brainstorming gets a separate page unless instructed otherwise. Create new reusable components in **Daywell / Components**, then use instances in mockups.
