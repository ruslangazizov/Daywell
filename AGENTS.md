# Daywell iOS — working context

Verified against the working tree on 2026-10-30. Paths below are relative to this directory. Update this file when something in it becomes outdated.

## Project and status

- Native habit/task planner: SwiftUI, TCA, Swift Concurrency; iOS 26 minimum, Swift tools 6.4.
- This directory is its own Git repository. Check its status and preserve unrelated changes.
- Current tabs: **Today, Statistics, Settings**. Today supports **Timeline, Agenda, Zones**; Timeline is the default.
- Tasks/occurrences currently come from `Clients/ClientPreviewData.swift`; completion changes are in memory. Task editing, durable task storage, reminder scheduling, badge updates and iCloud integration are unfinished. Statistics is a placeholder.
- `../Architecture.md` describes a target architecture and contains outdated names, tabs and toolchain details. Prefer current source/manifests for implemented behavior; README screenshots are not proof of implemented features.

## Code map and conventions

- `Daywell/DaywellApp.swift`: app entry point; creates one root store via `AppBootstrap`.
- `DaywellFeatures/Sources/AppRootFeature`: bootstrap, root reducer, tab composition. Feature targets: `TasksFeature`, `StatisticsFeature`, `SettingsFeature`; keep them independent of one another.
- `DaywellCore/Sources/Domain`: validated value models and scheduling rules (`DWTask`, `TaskSchedule`, `LocalDate`, `TimeWindow`, `OccurrenceRecord`). No SwiftUI, TCA or SwiftData business-model dependencies.
- `DaywellCore/Sources/Clients`: injectable async dependencies; live task/occurrence clients still return demo data. Override dependencies in tests.
- `DaywellCore/Sources/Persistence`: currently preferences and settings options, not a SwiftData store. SwiftData/CloudKit is planned.
- `DaywellCore/Sources/DesignSystem`: shared SwiftUI components, `DWColor`, appearance and layout constants. Reuse these and native iOS controls.
- Follow existing TCA patterns: `Reducer`, `@ObservableState`, `@CasePathable`, scoped stores, dependency-backed effects. Views send actions; reducers own mutations. Existing Today view models are derived display projections, not separate mutable stores.
- Packages enable Approachable Concurrency; UI targets and Domain default to MainActor. Domain value models and client contracts explicitly use `nonisolated`/`Sendable`; preserve isolation boundaries.
- Preferences use `@Shared` for writes and `@SharedReader` for reads with `Persistence.Preferences`; mutate shared values through `withLock`. Keys are computed properties so they respect the current `defaultAppStorage` dependency. Keep stored keys stable.

## Domain rules

- A habit is a repeating `DWTask`. Occurrence identity is `(taskID, LocalDate)`; moving a time window does not change it. Missing outcome records mean no recorded outcome, not automatically overdue.
- Use calendar-day arithmetic, not 86,400-second offsets. Recurrence produces at most one occurrence per day; weekly intervals are Monday-anchored regardless of UI preferences; nonexistent monthly dates are skipped.
- Time windows include their start and exclude their end; overnight windows explicitly use `endDay: .nextDay`. Preserve validation during both construction and decoding.

### Daily zones

Tasks own their optional time window. Today computes zone membership from any positive-duration overlap with the current zone settings; touching an endpoint does not count. A task can appear in several zones, while tasks without a matching zone or without a time window appear in **No zone**.

All cards for an occurrence share one completion record. Timeline, Agenda and daily totals count that occurrence once. Editing, deleting or restoring zones regroups tasks without changing their times or completion records, including when viewing a past date. Overnight tasks remain on their scheduled start date.

Task storage is not implemented yet. Demo tasks that previously inherited a zone now contain explicit time windows. Any future import of the old task format must resolve inherited windows from the old zones before decoding into the current model.

Zone collections allow gaps and an empty list, but reject overlapping windows and duplicate IDs. Default zones have stable IDs.

## Build and verification

- Local project: `Daywell.xcodeproj/project.xcproj` (JSON format). Installed stable toolchain: `/Applications/Xcode-27.2.app`; use `DEVELOPER_DIR` per command rather than changing global Xcode selection.
- `.gitignore` currently excludes the Xcode project and nested package lockfiles; check tracking explicitly when changing project configuration.
- From this directory, build with:

  ```sh
  DEVELOPER_DIR=/Applications/Xcode-27.2.app/Contents/Developer xcodebuild -project Daywell.xcodeproj -scheme Daywell -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/daywell-derived build CODE_SIGNING_ALLOWED=NO
  ```

- Unit tests: Swift Testing + TCA `TestStore` in `DaywellCore/Tests/DomainTests` and `DaywellFeatures/Tests/{TasksFeatureTests,SettingsFeatureTests}`. Use iOS Simulator destinations for UIKit-dependent targets; inspect available package schemes before running package tests.
- UI tests: XCTest in `DaywellUITests`, scheme `DaywellUITests`. Discover an available simulator, then use `xcodebuild test` with its destination. The app scheme currently lists UI tests only; it does not establish package-test coverage.
- `BaseUITestCase` sets `IS_UI_TESTING=true`; the app then uses a fresh UserDefaults suite. Inject dates, calendars, clocks, UUIDs and clients for deterministic reducer tests. Keep accessibility IDs in each feature's `Accessibility.swift` consistent with UI tests.

## Design references

- Follow iOS Human Interface Guidelines and favor standard SwiftUI components. Reuse the existing design system; support light/dark appearance and system accessibility settings.
- Figma work must use **Figma-bridge only**. If unavailable or unable to perform an action, stop that work and tell the user; never use a browser or Computer Use for Figma.
- All Figma content/comments must be English. New-feature brainstorming gets a separate page unless instructed otherwise. Create new reusable components in **Daywell / Components**, then use instances in mockups.
