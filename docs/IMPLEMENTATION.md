# Ring Tracker implementation

This document describes the Ring Tracker implementation. See the
[latest GitHub release](https://github.com/BarishNamazov/garmin-ring-tracker/releases/latest)
for the published version and [`supported-devices.txt`](../supported-devices.txt)
for the current source's device IDs. The app is a Connect IQ watch app with a
glance and an hourly background service.

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
the canonical revision. The background service also compares every scheduling
field in its mirror to canonical storage before evaluating a reminder. The
foreground repairs a drifting background mirror while retaining legitimate
background reminder-ledger updates.

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
| Main and common UI | `source/MainView.mc`, `source/UiUtils.mc`, `source/ScreenInput.mc`, `source/Lateness.mc` | Main states, cycle/lateness arcs, measured countdown typography, date/time degradation, coordinate-aware touch/key dispatch, and warnings |
| Lists | `source/UpcomingView.mc`, `source/HistoryView.mc`, `source/ListUi.mc` | Six-cycle projection, history, cycle detail helpers, scrolling, dates, variance, and round-screen geometry |
| Menus and supporting views | `source/Menus.mc`, `source/StaticViews.mc`, `source/Pickers.mc` | State menus, settings, confirmations, Correct dates, setup/About/migration screens, and date/time/number pickers |
| Constrained personalities | `source/GlanceView.mc`, `source/BackgroundRuntime.mc`, `source/ServiceDelegate.mc` | Glance rendering, compact background decoding, notifications, ledger updates, and single-exit handling |
| Build variants | `source/OptionalFeatures.mc`, `source/DemoScenarios.mc`, `source/Clock.mc`, `resources-debug/` | Production seams and debug-only fixtures, notification previews, fixed clock, diagnostics, and memory reporting |
| Resources | `resources/strings/strings.xml`, `resources/drawables/` | Visible copy, launcher artwork, and the background-scoped notification icon |
| Tests and checks | `source/tests/`, `scripts/build.sh`, `scripts/check-background-scope.sh`, `scripts/ci/` | Simulator tests, device builds, constrained-scope checks, version checks, and release freshness |

## Foreground flow and controls

First run shows the safety acknowledgement, the NuvaRing 21-days-in/7-days-out
regimen summary, and insertion date/time entry. Later launches go to Main unless
a valid notification launch requests Alert detail or migration/settings review
must be completed first.

Main displays ring-in, ring-free, overdue, serious-duration, clock-review, and
temporary-out states. START/tap opens the state menu; while temporarily out it
opens the Put ring back confirmation. Holding MENU always opens the state menu.
UP opens Upcoming, DOWN opens History, and BACK exits. In lists, UP/DOWN scroll,
START opens detail where available, and BACK returns. Custom touch-sensitive
screens use `ScreenInputDelegate`: Garmin's `BehaviorDelegate` otherwise consumes
mapped taps before coordinate handlers run. In pickers, UP/the upper arrow/swipe
up increases the value; DOWN/the lower arrow/swipe down decreases it.

State menus expose only valid actions:

- No ring logged: Insert ring now; Log earlier insertion; Settings; About.
- Ring in: Remove ring (Replace ring when days out is zero); Take out briefly;
  Edit insertion time; History; Settings; About.
- Ring free: Insert ring; Edit removal time; History; Settings; About.
- Temporarily out: Put ring back; Start ring-free week (ring-free time for a
  non-seven-day schedule); Undo ring out; Settings; About. The title reports
  time left before three hours, or time over the limit.

Correct dates edits only an actual insertion or removal. A pending removal is
shown as a dimmed due-date sublabel in native Menu2; selecting it shows a brief
`Not removed yet` toast. Early/late actions and corrections use two-line
confirmations before any write.

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

`release` produces a signed PRG for each supported device and `RingTracker.iq`
in `bin/release/`. `debug` produces a PRG for each device with Demo scenarios
and diagnostics. `test` builds a 47 mm unit-test PRG, starts a headless
simulator when needed, and fails unless
the parsed summary has at least one pass and zero failures/errors.

The release gate is run from a clean environment:

```bash
env -i HOME=$HOME PATH=/usr/bin:/bin bash -lc \
  'cd /path/to/garmin-bc && ./scripts/build.sh release && \
   ./scripts/build.sh debug && ./scripts/build.sh test'
./scripts/check-background-scope.sh
./scripts/ci/check-version.sh
(cd bin/release && sha256sum RingTracker-*.prg RingTracker.iq >SHA256SUMS && sha256sum --check SHA256SUMS)
```

All compiler invocations enable warnings (`-w`). The simulator suite covers
schedule boundaries, DST gaps/folds, actual-event anchoring,
temporary-out identity, reminder priority/deduplication, migrations, storage
interruption and compaction, settings repair, phone/watch picker conversion,
copy contracts, navigation helpers, all main countdown tiers, lists, glance
copy, and all notification kinds. The 13 UI-polish regressions cover input
routing, picker directions and touch targets, History heading clearance,
paragraph/scrollbar spacing, wrapping, custom-schedule menus, long-overdue
progress, and time formatting.

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

The final 1.3.0 temporal-event run on 2026-09-18 produced:

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

The v1.3.0 measurements use the final 47 mm source in debug fixture harnesses,
so they include fixture navigation and diagnostic overhead. Used and free
values are derived from `System.getSystemStats()` at the rendered state.

| Personality/state | Used | Free | Total | Limit result |
| --- | ---: | ---: | ---: | --- |
| Foreground, maximum 24-cycle history with Upcoming open | 172,152 B (168.1 KiB) | 609,736 B (595.4 KiB) | 781,888 B | within foreground budget |
| Glance, peak across five states | 22,624 B (22.1 KiB) | 38,632 B (37.7 KiB) | 61,256 B | used memory below 45 KiB |
| Background, peak across eleven paths | 18,696 B (18.3 KiB) | 42,560 B (41.6 KiB) | 61,256 B | used memory below 45 KiB |

## Debug fixtures and screenshots

Demo scenarios contain the union needed by the main, list, menu/settings,
glance, notification, migration, storage, and background verification work.
They include countdown boundaries (`1d 12h`, `14h`, `45m`), both overdue
directions and magnitudes, temporary-out limits, serious duration warnings,
long date/warning stress cases, both watch clock formats for picker evidence,
maximum history, all seven notification kinds, all background faults, and Alert
detail.

Native screenshot crops are 390×390 at `+118+260`, 416×416 at `+122+263`, and
454×454 at `+146+281`. The v1.3.0 checked-in inventory contains 119 PNGs:

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
| Notification evidence | 47 mm | 7 |
| Alert detail | 47 mm | 1 |
| **Total** |  | **119** |

Every image was regenerated from the final v1.3.0 integrated source using
temporary fixture/navigation harnesses and inspected for round-edge clearance,
clipping, overlap, scroll position, and state accuracy.
The seven notification captures use a debug-only evidence surface that mirrors
the production title, subtitle, body, and icon because the Linux simulator's
native popup obscures the app surface during deterministic capture. Production
passes the same title, subtitle, body, icon, launch data, and dismiss policy
directly to Garmin's Notifications API. The large-number/divider collision is
absent. Capture automation stays outside the app: ordinary debug startup loads
saved state and Demo scenarios are selected explicitly from the menu.

`docs/store/generate-assets.sh` converts eight selected 47 mm captures to RGB
sRGB PNGs. All are 416×416 and below the Store's 150 KiB limit. It also renders
the centered 500×500 launcher with 118 px minimum artwork padding.

## UX rounds (v1.3.0)

Version 1.3.0 combines the unreleased picker/phone-settings work with the four
review workstreams. Main now uses measured mixed-size countdowns, scaled arcs,
explicit overdue/serious states, and a stable temporary-out layout. Upcoming
and History use fixed columns and event-scoped variance. Menus are state-aware;
confirmations and Correct dates use compact actual-event wording. Settings are
flat and the Clock option is gone. Setup/About screens use one bottom action
slot. Glance has two text rows and a progress bar. Notifications use verb-first
titles, distinct Reminder 1/2 copy, complete facts/instructions, and the closed
ring/dot icon.

The round-2 menu pass centres every date/time picker column as one visible
group on all three target sizes, keeps the value row and arrows symmetric, and
adds the dimmed time separator. Correct dates now uses Menu2, duration settings
read `Days worn` / `Days out`, and the setup, About, regimen, migration, and
Alert detail screens share the revised copy hierarchy and action-slot pattern.

The completed pass regenerated all 40 menu, confirmation, Correct dates,
Settings, picker, and text/detail captures. The pending Removed item uses
Menu2's native unfocused treatment and shows `Not removed yet` when selected;
Menu2 does not expose a per-item text-colour override.

Two contract tensions are intentional and documented:

- Garmin supplies the app glyph beside a glance, so it cannot be recoloured by
  state. Round 2 makes that shared launcher glyph neutral grey; the title,
  value, and bar carry state colour. In the 51 mm simulator's full-screen
  glance preview, the circular mask clips part of that native glyph at the
  upper-left edge; app-drawn text and bars fit. Placement in the real watch's
  glance list remains a hardware verification item.
- Garmin's native notification API controls text colour. The debug evidence
  surface renders late lines orange, while production supplies the same late
  copy to the native card without an unsupported colour option. The mandated
  `Remove ring today` / `Insert ring today` titles exceed 15 characters but
  fit the target card; all titles whose wording is flexible remain at most 15.

Main, Upcoming, glance, background notifications, and Alert detail share
`Lateness.mc`: hours below 48 hours, whole days thereafter. The module has no
foreground UI or calendar dependency, so constrained personalities can reuse
it. The final integration preserves time in the ring-free action line and
removes the separator when a serious-state secondary line wraps. The clock
validity warning uses separate title/body spacing even when the body wraps on
the 390 px display.

Native menus may reveal a partial adjacent row at the round bezel while
scrolling; selected rows and custom-rendered values were visually checked.

The round-2 list pass keeps Upcoming on fixed 78 px row pitches with shared
column anchors, a proportional elapsed/overdue track, chord-safe rails, and the
rollover year in the column header. History uses full-width selection bands and
`NOW`; cycle detail compacts its populated rows, dates, and brief-out count.

## Release bundle

After a release build, the signed PRGs and `RingTracker.iq` are in
`bin/release/`. Generate `SHA256SUMS` there to verify downloads. CI publishes
these files as build artifacts, and tagged releases attach them to GitHub
Releases. `RingTracker.iq` is the Store package; users sideload only the PRG
matching their device ID.
