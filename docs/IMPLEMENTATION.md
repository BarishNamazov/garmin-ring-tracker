# Ring Tracker implementation

This document describes the current Ring Tracker 1.3.0 implementation. The
shipping targets are the epix Pro (Gen 2) 42, 47, and 51 mm device IDs. The app
is a Connect IQ watch app with a glance and an hourly background service.

## Runtime design

The foreground owns the complete schedule document. A cycle records the actual
insertion, actual removal when known, derived action dates, temporary-out
intervals, and the schedule that produced those dates. Confirmed actual events
move downstream dates; projections never replace actual events.

`RingStore` persists schema version 3. The canonical document and two parity
history slots use a revisioned commit. History and constrained mirrors are
written before the canonical revision, so a partial write is rejected rather
than combined with another revision. A preflight keeps each stored value below
the Connect IQ object-store limit, and compaction removes the oldest complete
history before it would split a cycle.

The glance and background service read separate positional mirrors. They do not
load the foreground controller, full history, or view graph. Both mirrors carry
the canonical revision and are accepted only when their shape, types, ranges,
and matching canonical revision validate.

The background service evaluates one reminder candidate per temporal event,
shows at most one native notification, updates the reminder ledger only after a
successful notification, and reaches one final `Background.exit()`. A failed
notification therefore remains eligible for a later hourly check.

The legacy `clockFormat` property remains in schema-v3 documents only for safe
migration. `SettingsBridge` resets it to system mode and removes it from watch
and phone settings. Production display and picker formatting follow
`System.getDeviceSettings().is24Hour`; debug picker fixtures can force either
format so both layouts remain visually testable.

## File map

| Area | Files | Responsibility |
| --- | --- | --- |
| Calendar and schedule | `source/CalendarMath.mc`, `source/ScheduleModel.mc`, `source/ReminderPolicy.mc` | Local-calendar arithmetic, DST resolution, event transitions, projections, warnings, and reminder selection |
| Persistence | `source/RingStore.mc` | Schema migration, validation, revisioned canonical/history writes, constrained mirrors, preflight, and compaction |
| Settings | `source/SettingsBridge.mc`, `resources/settings/`, `resources/settings/properties.xml` | Watch and phone settings, native date and 15-minute phone controls, migration, validation, and watch-wins repair |
| Application shell | `source/RingTrackerApp.mc` | Startup, notification launch, navigation, confirmations, deferred writes, and settings orchestration |
| Main and common UI | `source/MainView.mc`, `source/UiUtils.mc` | Main states, cycle/lateness arcs, measured countdown typography, date/time degradation, and warnings |
| Lists | `source/UpcomingView.mc`, `source/HistoryView.mc`, `source/ListUi.mc` | Six-cycle projection, history, cycle detail helpers, scrolling, dates, variance, and round-screen geometry |
| Menus and supporting views | `source/Menus.mc`, `source/StaticViews.mc`, `source/Pickers.mc` | State menus, settings, confirmations, Correct dates, setup/About/migration screens, and date/time/number pickers |
| Constrained personalities | `source/GlanceView.mc`, `source/BackgroundRuntime.mc`, `source/ServiceDelegate.mc` | Glance rendering, compact background decoding, notifications, ledger updates, and single-exit handling |
| Build variants | `source/OptionalFeatures.mc`, `source/DemoScenarios.mc`, `source/Clock.mc`, `resources-debug/` | Production seams and debug-only fixtures, notification previews, fixed clock, diagnostics, and memory reporting |
| Resources | `resources/strings/strings.xml`, `resources/drawables/` | Visible copy, launcher artwork, and the background-scoped notification icon |
| Tests and checks | `source/tests/`, `scripts/build.sh`, `scripts/check-background-scope.sh`, `scripts/ci/` | Simulator tests, three-device builds, constrained-scope checks, version checks, and release freshness |

## Foreground flow and controls

First run shows the safety acknowledgement, the NuvaRing 21-days-in/7-days-out
regimen summary, and insertion date/time entry. Later launches go to Main unless
a valid notification launch requests Alert detail or migration/settings review
must be completed first.

Main displays ring-in, ring-free, overdue, serious-duration, clock-review, and
temporary-out states. START/tap opens the state menu; while temporarily out it
opens the Put ring back confirmation. Holding MENU always opens the state menu.
UP opens Upcoming, DOWN opens History, and BACK exits. In lists, UP/DOWN scroll,
START opens detail where available, and BACK returns.

State menus expose only valid actions:

- No cycle: Insert ring now; Ring already in; Settings; About.
- Ring in: Remove ring; Ring out briefly; Edit insertion time; History;
  Settings; About.
- Ring free: Insert ring; Edit removal time; History; Settings; About.
- Temporarily out: Put ring back; Keep out and start the ring-free week; Undo
  ring out; Settings; About.

Correct dates edits only an actual insertion or removal. A pending removal is
shown as a due date and is not editable. Early/late actions and corrections use
two-line confirmations before any write.

## Build and verification procedures

Load the pinned SDK/runtime environment before direct compiler or simulator
commands:

```bash
source scripts/env.sh
```

The supported entry points are:

```bash
./scripts/build.sh release
./scripts/build.sh debug
./scripts/build.sh test
```

`release` produces three signed PRGs and `RingTracker.iq` in `bin/release/`.
`debug` produces three PRGs with Demo scenarios and diagnostics. `test` builds a
47 mm unit-test PRG, starts a headless simulator when needed, and fails unless
the parsed summary has at least one pass and zero failures/errors.

The release gate is run from a clean environment:

```bash
env -i HOME=$HOME PATH=/usr/bin:/bin bash -lc \
  'cd /path/to/garmin-bc && ./scripts/build.sh release && \
   ./scripts/build.sh debug && ./scripts/build.sh test'
./scripts/check-background-scope.sh
./scripts/ci/check-version.sh v1.3.0
./scripts/ci/check-release.sh bin/release
```

All compiler invocations use warnings-as-errors. The v1.3.0 suite contains 164
tests. It covers schedule boundaries, DST gaps/folds, actual-event anchoring,
temporary-out identity, reminder priority/deduplication, migrations, storage
interruption and compaction, settings repair, phone/watch picker conversion,
copy contracts, navigation helpers, all main countdown tiers, lists, glance
copy, and all notification kinds.

## Background-event verification

This is a simulator temporal-event test, separate from unit tests:

1. Build `debug` and start `TZ=America/New_York ciq_headless_simulator`.
2. Launch the 47 mm debug PRG with `monkeydo`.
3. Load and confirm one `BG · …` Demo scenario. The fixture writes a fresh
   compact mirror and then applies any requested nil/corrupt/exception fault.
4. Choose **Simulation > Background Events**, leave **Temporal Event** and
   **Ring Tracker** selected, and confirm.
5. Record `RING_TRACKER_BACKGROUND_RESULT` and
   `RING_TRACKER_BACKGROUND_MEMORY`, then repeat for every row.

The final 1.3.0 run produced:

| Fixture | Kind | Notification | Ledger saved | Caught | Exit | Result |
| --- | ---: | --- | --- | --- | ---: | --- |
| Day before | 5 | yes | yes | no | 1 | day-before slot marked |
| Reminder 1 | 4 | yes | yes | no | 1 | first day-of slot marked |
| Reminder 2 | 4 | yes | yes | no | 1 | second day-of slot marked |
| Overdue | 3 | yes | yes | no | 1 | overdue slot marked |
| Temporary out over 3 h | 1 | yes | yes | no | 1 | interval-specific slot marked |
| Ring free over 7 d | 0 | yes | yes | no | 1 | duration warning marked |
| Ring in over 4 weeks | 2 | yes | yes | no | 1 | duration warning marked |
| Valid no-op | — | no | no | no | 1 | ledger unchanged |
| Nil mirror | — | no | no | no | 1 | no mirror accepted |
| Corrupt mirror | — | no | no | no | 1 | invalid mirror rejected |
| Injected notification exception | 4 | no | no | yes | 1 | ledger unchanged for retry |

Each success showed one notification and one save. The no-op and invalid-input
paths showed and saved nothing. The injected failure was caught before the
ledger changed.

## Memory verification

Measurements use the 47 mm debug build, so they conservatively include fixture
and diagnostic overhead. Used and free values are derived from
`System.getSystemStats()` at the rendered state.

| Personality/state | Used | Free | Total | Limit result |
| --- | ---: | ---: | ---: | --- |
| Foreground, maximum 24-cycle history with Upcoming open | 170,576 B (166.6 KiB) | 611,312 B (597.0 KiB) | 781,888 B | within foreground budget |
| Glance, overdue state | 22,152 B (21.6 KiB) | 39,104 B (38.2 KiB) | 61,256 B | used memory below 45 KiB |
| Background, peak injected-exception path | 18,320 B (17.9 KiB) | 42,936 B (41.9 KiB) | 61,256 B | used memory below 45 KiB |

## Debug fixtures and screenshots

Demo scenarios contain the union needed by the main, list, menu/settings,
glance, notification, migration, storage, and background verification work.
They include countdown boundaries (`1d 12h`, `14h`, `45m`), both overdue
directions and magnitudes, temporary-out limits, serious duration warnings,
long date/warning stress cases, both watch clock formats for picker evidence,
maximum history, all seven notification kinds, all background faults, and Alert
detail.

Native screenshot crops are 390×390 at `+118+260`, 416×416 at `+122+263`, and
454×454 at `+146+281`. The checked-in inventory contains 119 PNGs:

| Family | Sizes | Count |
| --- | --- | ---: |
| Main states: normal, countdown boundaries, overdue, temporary-out, warnings, longest values, and both clock formats | 42/47/51 mm | 48 |
| Upcoming pages, History, and cycle detail | 42/47/51 mm | 12 |
| Glance: ring in, ring free, overdue, temporary out | 42/47/51 mm | 12 |
| Time/date pickers | 42/47/51 mm | 9 |
| Confirmations | 42/47/51 mm | 9 |
| Correct dates, including pending removal | 42/47/51 mm | 6 |
| Four state menus | 47 mm | 4 |
| Settings and Reminder 2 picker | 47 mm | 7 |
| First run, regimen, About, migration | 47 mm | 4 |
| Native notifications | 47 mm | 7 |
| Alert detail | 47 mm | 1 |
| **Total** |  | **119** |

Every image was regenerated from the integrated debug source and inspected for
round-edge clearance, clipping, overlap, scroll position, and state accuracy.
The seven native-notification captures use a debug-only body surface below the
simulator's native header because the Linux simulator otherwise overlays that
header on the current app view. Production still passes the same title,
subtitle, body, icon, launch data, and dismiss policy directly to Garmin's
Notifications API. The large-number/divider collision is absent.

`docs/store/generate-assets.sh` converts eight selected 47 mm captures to RGB
sRGB PNGs. All are 416×416 and below the Store's 150 KiB limit. It also renders
the centered 500×500 launcher with 118 px minimum artwork padding.

## UX round (v1.3.0)

Version 1.3.0 combines the unreleased picker/phone-settings work with the four
review workstreams. Main now uses measured mixed-size countdowns, scaled arcs,
explicit overdue/serious states, and a stable temporary-out layout. Upcoming
and History use fixed columns and event-scoped variance. Menus are state-aware;
confirmations and Correct dates use compact actual-event wording. Settings are
flat and the Clock option is gone. Setup/About screens use one bottom action
slot. Glance has two text rows and a progress bar. Notifications use verb-first
titles, distinct Reminder 1/2 copy, complete facts/instructions, and the closed
ring/dot icon.

Two contract tensions are intentional and documented:

- Garmin supplies the app glyph beside a glance, so it remains the green
  launcher glyph; the drawable cannot recolour it per glance state. Overdue
  state is still carried by the orange title, value, bar, and overflow tail.
- The required Reminder 2 titles `Still in — remove` and
  `Still out — insert` exceed the nominal 15-character title budget. The
  required distinguishing phrases take precedence and fit the target card.

No other item in `docs/ux-review/DECISIONS.md` remains unimplemented. Native
menus may reveal a deliberately partial adjacent row at the round bezel while
scrolling; the selected row and every custom-rendered value remain unclipped.

The round-2 list pass keeps Upcoming on fixed 78 px row pitches with shared
column anchors, a proportional elapsed/overdue track, chord-safe rails, and the
rollover year in the column header. History uses full-width selection bands and
`NOW`; cycle detail compacts its populated rows, dates, and brief-out count.

## Release bundle

After the clean build, copy the three PRGs and `RingTracker.iq` from
`bin/release/` into `release/`, regenerate `release/SHA256SUMS`, and run
`scripts/ci/check-release.sh bin/release`. `RingTracker.iq` is the Store package;
users sideload only the PRG matching their device ID.
