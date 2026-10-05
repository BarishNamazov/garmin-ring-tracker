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

## Reminder reliability (v1.5.0)

The application class and its install/update callbacks carry `(:background)`.
Both callbacks and foreground startup use `BackgroundRegistration.ensureHourly()`.
The helper checks `Background.getTemporalEventRegisteredTime()` and registers a
3,600-second Duration only when registration is absent, is a Moment, or has a
different Duration. A correct hourly registration survives repeated opens.
Registration exceptions still use the foreground `ReminderRegistrationError`
screen and retry on the next open.

Garmin's [Background API reference](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html#registerForTemporalEvent-instance_function)
specifies recurring Duration events and says another registration overwrites
the existing event. It does not specify whether registering the same Duration
resets a countdown. In the [Garmin forum discussion about changing intervals](https://forums.garmin.com/developer/connect-iq/f/discussion/6895/restarting-background-temporal-process-after-settings-change/46272),
re-registering a Duration is described as scheduling relative to the last
trigger, including an immediate trigger when that interval has elapsed. That
supports preserving the existing registration; it does **not** establish that
repeated opens starved this watch's reminders. The [AppBase reference](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#onAppInstall-instance_function)
confirms that install/update callbacks run in the background and require the
Background permission and application class annotation.

`ringTrackerBackgroundStatus` is an optional Storage value independent of
canonical state, history, both mirrors, and schema version 3:

```text
[1, checkUtc, outcome, stage, kind, alertUtc, alertKind]
```

| Field | Values |
| --- | --- |
| `checkUtc` | UTC seconds of the last check; null before any check |
| `outcome` | 0 not checked; 1 no active cycle; 2 invalid mirror; 3 canonical mismatch; 4 nothing due; 5 alert shown; 6 failed |
| `stage` | 0 none; failures use 1 load, 2 evaluate, 3 notify, or 4 save |
| `kind`, `alertKind` | 0 ring-free limit; 1 temporary out; 2 four weeks; 3 overdue; 4 Reminder 1; 5 day before; 6 Reminder 2; 7 test; null when absent |
| `alertUtc` | UTC seconds of the last notification whose API call returned; retained across later checks |

The status decoder validates shape, types, ranges, timestamp/kind pairs, and
failure stages. Missing or corrupt values default to not checked. Notification
success records the alert before saving the ledger, so a ledger write failure
can show both the last alert and a save problem. Status writes are best effort:
a persistent Storage failure can prevent recording the failure itself. A
returned notification call does not prove the watch displayed or sounded it.

The service tracks load, evaluate, notify, and save separately. If notification
with the custom icon throws, the service retries once with the same text and
options minus the icon. Only a returned notification call allows the normal
reminder ledger to be marked and saved. Foreground load/repair preserves both
the status and legacy `ringTrackerMirrorError`. A newer recorded background
check replaces the status; a check without a mirror/load problem clears the
legacy mirror error. Reminder timing, selection, priority, and revisions are
unchanged.

Settings adds `Reminder check`, with `Not checked yet`, `Checked <time>`, or
`No check for <hours> h` after two hours. The detail view shows `Last check`,
`Last alert`, local `Today`/`Yesterday` or a date, and the watch's 12/24-hour time.
A problem line appears for stale checks, mirror problems, or the failed stage.
`Send test alert` stores `ringTrackerTestAlert = true` and confirms
`Test queued`. While pending, the view shows `Next hourly check` without hiding
a recorded problem. Every check loads and evaluates the reminder state first.
A selected real reminder owns the notification slot and retains the test flag,
even if its notification or ledger save fails. When no real reminder is selected,
the service deletes the flag before attempting `Test alert` / `Reminder check
complete`. Tests use `dismissPrevious = false` and never save the reminder ledger.
A failed test is consumed too. The hourly Duration is retained throughout.

A queued test is also attempted after an invalid mirror, canonical mismatch, or
load/evaluate failure, to exercise the temporal-event-to-notification chain.
The original problem remains in `outcome`/`stage`; `kind = 7` identifies the test
attempt, and `alertUtc`/`alertKind = 7` update only when its notification call
returns. A test failure on a problem check also retains the original problem.
The seven-field version-1 format and `BackgroundStatus.valid` rules are unchanged;
the detail view can therefore show both the problem and the last test alert.

## File map

| Area | Files | Responsibility |
| --- | --- | --- |
| Calendar and schedule | `source/CalendarMath.mc`, `source/ScheduleModel.mc`, `source/ReminderPolicy.mc` | Local-calendar arithmetic, DST resolution, event transitions, projections, warnings, and reminder selection |
| Persistence | `source/RingStore.mc` | Schema migration, validation, revisioned canonical/history writes, constrained mirrors, preflight, and compaction |
| Settings | `source/SettingsBridge.mc`, `resources/settings/`, `resources/settings/properties.xml` | Watch and phone settings, native date and 15-minute phone controls, migration, validation, and watch-wins repair |
| Application shell | `source/RingTrackerApp.mc` | Startup, notification launch, navigation, confirmations, deferred writes, and settings orchestration |
| Main and common UI | `source/MainView.mc`, `source/UiUtils.mc`, `source/ScreenInput.mc`, `source/Lateness.mc` | Main states, cycle/lateness arcs, measured countdown typography, date/time degradation, coordinate-aware touch/key dispatch, and warnings |
| Lists | `source/UpcomingView.mc`, `source/HistoryView.mc`, `source/ListUi.mc` | Six-cycle projection, history, cycle detail helpers, scrolling, dates, variance, and round-screen geometry |
| Menus and supporting views | `source/Menus.mc`, `source/StaticViews.mc`, `source/Pickers.mc`, `source/ReminderCheckView.mc` | State menus, settings, confirmations, Correct dates, setup/About/migration screens, and date/time/number pickers |
| Constrained personalities | `source/GlanceView.mc`, `source/BackgroundRuntime.mc`, `source/BackgroundRegistration.mc`, `source/BackgroundStatus.mc`, `source/ServiceDelegate.mc` | Glance rendering, compact background decoding, notifications, ledger updates, and single-exit handling |
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
copy, and all notification kinds.

The final v1.5.0 gate passes all 210 tests on epix Pro 47 mm and Forerunner
255S, exports all 68 part-number variants for the 55 manifest devices, and
builds all 55 debug targets. Warnings remain the existing launcher scaling
warnings: the IQ export has the same 47 warning lines as v1.4.0 and no new
warning identities. Version consistency and background scope checks pass.

The 28 v1.5.0 reliability tests cover registration decisions and callbacks,
status decoding and outcomes, stage failures, icon fallback, single-use test
requests, real-reminder priority, preservation of problems during tests, ledger
isolation, evidence retention, and Settings copy/navigation.
The 13 UI-polish regressions cover input
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

The v1.5.0 temporal-event run on 2026-10-05 uses the pinned SDK 9.2.0 and
47 mm simulator in America/New_York. The temporary foreground harness selects
and saves each fixture, synchronizes properties, then injects the fault after
foreground settings writes. Property-change callbacks are held during fixture
injection so they cannot repair a fault before the background service reads it.
Background code is unchanged. The ordinary debug menu and Reminder check action
also exercise native test notifications and repeat checks. The priority follow-up
adds 45 checks across 18 fixtures with a queued test; both intermediate real
alerts and the eventual test are recorded. Unit tests additionally assert the
notification's dismissal policy and version-1 status validity.

| Fixture | Kind | Notification | Ledger saved | Caught | Exit | Status/result |
| --- | ---: | --- | --- | --- | ---: | --- |
| Day before | 5 | yes | yes | no | 1 | alert shown; day-before slot marked |
| Reminder 1 | 4 | yes | yes | no | 1 | alert shown; first day-of slot marked |
| Reminder 2 | 4 | yes | yes | no | 1 | alert shown; status kind 6; second day-of slot marked |
| Overdue | 3 | yes | yes | no | 1 | alert shown; overdue slot marked |
| Temporary out over 3 h | 1 | yes | yes | no | 1 | alert shown; interval-specific slot marked |
| Ring free over 7 d | 0 | yes | yes | no | 1 | alert shown; duration warning marked |
| Ring in over 4 weeks | 2 | yes | yes | no | 1 | alert shown; duration warning marked |
| Valid no-op | — | no | no | no | 1 | nothing due; ledger unchanged |
| Nil mirror | — | no | no | no | 1 | mirror invalid; ledger unchanged |
| Corrupt mirror | — | no | no | no | 1 | mirror invalid; ledger unchanged |
| Injected notification exception | 4 | no | no | yes | 1 | failed: notify; both attempts failed; eligible for retry |
| No active cycle | — | no | no | no | 1 | no active cycle |
| Canonical mismatch | — | no | no | no | 1 | canonical mismatch; ledger unchanged |
| Injected load exception | — | no | no | yes | 1 | failed: load; ledger unchanged |
| Injected evaluate exception | — | no | no | yes | 1 | failed: evaluate; ledger unchanged |
| Injected save exception | 4 | yes | no | yes | 1 | failed: save; last alert retained; ledger unchanged |
| Icon exception | 4 | yes | yes | no | 1 | alert shown without custom icon; first day-of slot marked |
| Test alert, nothing due | 7 | yes | no | no | 1 | normal evaluation first; alert shown; flag consumed; ledger unchanged |
| Test alert, second check | — | no | no | no | 1 | nothing due; last test alert retained |
| Test notification exception | 7 | no | no | yes | 1 | failed: notify; test flag consumed; ledger unchanged |
| Failed test, second check | — | no | no | no | 1 | nothing due; no second test attempt |
| Test icon exception | 7 | yes | no | no | 1 | alert shown without custom icon; flag consumed; ledger unchanged |
| Test icon exception, second check | — | no | no | no | 1 | nothing due; no second test attempt |
| Queued test with day before | 5 | yes | yes | no | 1 | real alert first; test flag retained |
| Queued test with Reminder 1 | 4 | yes | yes | no | 1 | real alert first; test flag retained |
| Queued test with Reminder 2 | 4 | yes | yes | no | 1 | real alert first; status kind 6; test flag retained |
| Queued test with overdue | 3 | yes | yes | no | 1 | real alert first; test flag retained |
| Queued test with temporary-out warning | 1 | yes | yes | no | 1 | real alert first; test flag retained |
| Queued test with ring-free warning | 0 | yes | yes | no | 1 | real alert first; test flag retained |
| Queued test with four-week warning | 2 | yes | yes | no | 1 | real alert first; test flag retained |
| Another real reminder remains due | 3 or 5 | yes | yes | no | 1 | real alert first again; test flag retained |
| Deferred test, first check with nothing due | 7 | yes | no | no | 1 | test consumed; marked reminder ledger unchanged |
| Deferred test, following check | — | no | no | no | 1 | nothing due; no duplicate test |
| Queued test with no active cycle | 7 | yes | no | no | 1 | alert shown; test consumed; ledger unchanged |
| Queued test with nil mirror | 7 | yes | no | no | 1 | mirror invalid retained; last alert is test; flag consumed |
| Queued test with corrupt mirror | 7 | yes | no | no | 1 | mirror invalid retained; last alert is test; flag consumed |
| Queued test with canonical mismatch | 7 | yes | no | no | 1 | canonical mismatch retained; last alert is test; flag consumed |
| Queued test with load exception | 7 | yes | no | yes | 1 | failed: load retained; last alert is test; flag consumed |
| Queued test with evaluate exception | 7 | yes | no | yes | 1 | failed: evaluate retained; last alert is test; flag consumed |
| Problem check after test consumed | — | no | no | varies | 1 | original mirror/load/evaluate problem retained; no duplicate test |
| Queued test with real notify exception | 4 | no | no | yes | 1 | failed: notify; test remains queued |
| Queued test with real save exception | 4 | yes | no | yes | 1 | failed: save; test remains queued |

`Caught` reports a failed stage after any icon fallback; a successful fallback
reports false. Each successful reminder shows one notification and saves its
ledger. Queued tests never preempt a selected real reminder, including failed
real notification/save attempts. All test calls pass `dismissPrevious = false`,
including the icon fallback. Test checks never save the ledger. Later no-op/failure checks preserve
the last returned alert's time and kind. The scope check enforces one final
`Background.exit()` call.

Unit tests query the simulator's actual registration after install/update
callbacks and foreground registration. Forced **Background Events** do not
prove that the device scheduler will invoke the service automatically. Store
install/update callbacks, automatic hourly delivery, and notification visibility
or sound still require an epix Pro device check.

## Memory verification

Foreground and glance figures below retain the v1.3.0 fixture measurements.
Background was re-measured on 2026-10-05 with SDK 9.2.0 on the 47 mm simulator,
using the eleven v1.4.0 paths, all twenty v1.5.0 fixtures and repeat checks, and
ordinary debug-menu checks. Measurements include diagnostic overhead and sample
`System.getSystemStats()` after each service result. The temporary fault harness
holds foreground settings callbacks; ordinary debug checks retain those callbacks.

| Personality/state | Used | Free | Total | Limit result |
| --- | ---: | ---: | ---: | --- |
| Foreground, v1.3.0 maximum 24-cycle history with Upcoming open | 172,152 B (168.1 KiB) | 609,736 B (595.4 KiB) | 781,888 B | within foreground budget |
| Glance, v1.3.0 peak across five states | 22,624 B (22.1 KiB) | 38,632 B (37.7 KiB) | 61,256 B | used memory below 45 KiB |
| Background before, v1.4.0 peak | 19,360 B (18.9 KiB) | 41,896 B (40.9 KiB) | 61,256 B | used memory below 45 KiB |
| Background before priority correction, v1.5.0 peak | 21,264 B (20.8 KiB) | 39,992 B (39.1 KiB) | 61,256 B | used memory below 45 KiB |
| Background after priority correction, v1.5.0 peak | 21,608 B (21.1 KiB) | 39,648 B (38.7 KiB) | 61,256 B | used memory below 45 KiB |

The priority correction adds 344 B to the previous ordinary-debug sample
(21,264 B → 21,608 B). The follow-up harness sampled 45 native checks across
18 fixtures, including every real reminder kind with a queued test, subsequent
checks until the test runs, mirror/load/evaluate problems with a test, and
real/test notification failures. Its peak was 21,584 B, compared with 21,224 B
in the previous harness. An ordinary-debug overdue check used 21,608 B. These
are sampled path peaks, not an allocation trace inside the notification API.

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

Version 1.5.0 adds two 47 mm captures from the ordinary debug UI:
`epix2pro47mm-settings-reminder-check.png` and
`epix2pro47mm-reminder-check.png`. Both use the existing 416×416 crop at
`+122+263`; the screenshot inventory now contains 121 PNGs. The Settings row,
last-check/last-alert text, problem slot, and test action were inspected for
round-edge clearance and clipping.

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
