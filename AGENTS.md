Update this file when something significant in it becomes outdated.

## Project and status

- Tasks/occurrences are stored locally with SwiftData through `TasksClient` and `OccurrencesClient`.
- Reminder scheduling, badge updates and iCloud integration are unfinished.
- Statistics reads the same clients and shows complete-day totals, period charts, eligible hour/weekday patterns, and active-habit completion counts.

## Code map and conventions

- `Daywell/DaywellApp.swift`: app entry point; creates one root store via `AppBootstrap`.
- `DaywellFeatures/Sources/AppRootFeature`: bootstrap, root reducer, tab composition. Feature targets: `TasksFeature`, `StatisticsFeature`, `SettingsFeature`; keep them independent of one another.
- `TasksNavigationView` wraps the app's `TabView` and owns task-detail navigation, the habit-statistics push, and the task-editor sheet. `AppView` supplies `HabitStatisticsView` so Tasks and Statistics stay independent. Details push over the entire tab screen, so the tab bar moves with Today during forward/back transitions instead of toggling visibility. `TasksTodayView` is the root content without its own navigation stack; Settings and Statistics retain their independent navigation containers.
- `DaywellCore/Sources/Domain`: validated value models and scheduling rules (`DWTask`, `TaskSchedule`, `LocalDate`, `TimeWindow`, `OccurrenceRecord`). No SwiftUI, TCA or SwiftData business-model dependencies.
- `DaywellCore/Sources/Clients`: injectable async dependencies `TasksClient` and `OccurrencesClient`.
- `DaywellCore/Sources/Persistence`: preferences, settings options and `TaskStore`.
- `DaywellCore/Sources/DesignSystem`: shared SwiftUI components, `DWColor`, appearance and layout constants. Reuse these and native iOS controls.
- Follow existing TCA patterns: `Reducer`, `@ObservableState`, `@CasePathable`, scoped stores, dependency-backed effects. Views send actions; reducers own mutations and data preparation for Views. Existing Today view models are derived display projections, not separate mutable stores. Business logic should always be in reducers (or its state), not Views. For complicated logic introduce separate stateless ViewModelBuilder converter type.
- Preferences use `@Shared` for writes and `@SharedReader` for reads with `Persistence.Preferences`.

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
- Verify the affected flow after UI changes; a successful build alone is insufficient.
- If MCP is unavailable, use `xcodebuild`, `xcrun simctl` and LLDB as appropriate, explaining any missing UI automation. Request expanded execution permissions when required for CoreSimulator access; do not assume a connection error means Xcode is broken.
- Preserve existing simulator data; do not erase devices, uninstall the app or reset its database unless the task requires and authorizes it.

### Build commands and tests

- Local project: `Daywell.xcodeproj/project.xcproj` (JSON format). Installed stable toolchain: `/Applications/Xcode-27.2.app`; use `DEVELOPER_DIR` per command rather than changing global Xcode selection.
- From this directory, build with:

  ```sh
  DEVELOPER_DIR=/Applications/Xcode-27.2.app/Contents/Developer xcodebuild -project Daywell.xcodeproj -scheme Daywell -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/daywell-derived build CODE_SIGNING_ALLOWED=NO
  ```

- Unit tests: Swift Testing + TCA `TestStore` in `DaywellCore/Tests` and `DaywellFeatures/Tests`.
- UI tests: XCTest in `DaywellUITests`, scheme `DaywellUITests`.
- `BaseUITestCase` sets `IS_UI_TESTING=true`; the app then uses a fresh UserDefaults suite and an empty in-memory SwiftData store. Inject dates, calendars, clocks, UUIDs and clients for deterministic reducer tests. Keep accessibility IDs in each feature's `Accessibility.swift` consistent with UI tests.
