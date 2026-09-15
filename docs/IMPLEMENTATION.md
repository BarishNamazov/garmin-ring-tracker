# Ring Tracker implementation and verification

Ring Tracker is a Garmin Connect IQ watch app for the epix Pro (Gen 2) 42 mm,
47 mm, and 51 mm family. It records a ring-in/ring-free schedule, temporary-out
intervals, archived cycles, app settings, and reminder delivery state. The
manifest application UUID is `99f92e0c-a120-4641-b832-6da4d958585b`; the
minimum API is 5.1.0.

This document is the build, QA, and maintenance handoff. Medical behavior and
copy remain governed by `REGIMEN.md`; product behavior and layout remain
governed by `SPEC.md` and `UI.md`.

## File map

| Area | Files | Responsibility |
| --- | --- | --- |
| Package | `manifest.xml`, `monkey.jungle` | Release manifest, three products, permissions, and release annotation filtering |
| QA builds | `monkey.debug.jungle`, `monkey.tests.jungle` | Debug clock/demo resources and Toybox.Test build |
| Domain | `source/CalendarMath.mc`, `source/ScheduleModel.mc`, `source/ReminderPolicy.mc` | DST-safe calendar operations, state transitions/status, and reminder selection/deduplication |
| Time seam | `source/Clock.mc` | Release clock and compile-time-separated debug storage override |
| Persistence | `source/RingStore.mc` | Schema-v2 positional codecs, revisioned mirror-first commits, split history values, 24 KiB preflight/compaction, recovery, and ledger merge |
| Settings | `source/SettingsBridge.mc`, `resources/settings/` | App Settings validation, diff/reconciliation, and watch-to-property mirroring |
| App shell | `source/RingTrackerApp.mc` | Lifecycle, routing, confirmations, background registration, notification launch validation, and settings review |
| Foreground UI | `source/MainView.mc`, `source/StaticViews.mc`, `source/HistoryView.mc`, `source/Menus.mc`, `source/Pickers.mc`, `source/UiUtils.mc` | Scaled drawing, screens, native menus/confirmations, and custom pickers |
| Constrained personalities | `source/GlanceView.mc`, `source/BackgroundRuntime.mc`, `source/ServiceDelegate.mc` | Independent validated read-only codecs, reduced glance rendering, and hourly notification service |
| Build variants | `source/OptionalFeatures.mc`, `source/DemoScenarios.mc`, `resources-debug/` | Release no-op seams and debug-only demo/time/memory helpers |
| Resources | `resources/strings/strings.xml`, `resources/drawables/` | All visible copy, launcher assets, and background-scoped notification icon |
| Tests | `source/tests/DomainTests.mc`, `source/tests/ReviewTests.mc`, `source/tests/ReviewResolutionTests.mc` | 68 deterministic domain, review-regression, DST, settings, codec, storage, and constrained-runtime tests |
| Visual evidence | `docs/screenshots/` | Native-resolution simulator captures |

The canonical state excludes archived history. History is split between two
revisioned values in alternating parity slots; glance and background have
separate compact mirrors containing only the fields they consume. Mirrors and
history are written before the canonical revision commit. A background ledger
write updates only its small mirror and the next foreground load merges it when
the revision matches. Every value is preflighted against the 24 KiB design
budget, with eligible closed short intervals summarized before a write is
refused. This keeps 24 archived cycles and active interval detail out of the
64 KiB constrained heaps without discarding threshold-crossing records.

## Build configurations

Source the installed SDK environment first:

```bash
cd /home/agent/Dev/garmin-bc
source scripts/env.sh
```

The checked-in driver builds every target, exports the store package, prints
SHA-256 hashes, and treats warnings as build failures:

```bash
./scripts/build.sh release
```

Debug/QA excludes `:production` and test declarations, adds debug resources,
uses `Storage["debugNowUtc"]` when present, exposes **Demo scenarios**, and
prints the service memory sample:

```bash
./scripts/build.sh debug
```

Release outputs are the three device PRGs and `bin/release/RingTracker.iq`.
Debug outputs are the three device PRGs under `bin/debug/`. The final
verification on 2026-09-15 was:

| Configuration | 42 mm | 47 mm | 51 mm |
| --- | --- | --- | --- |
| Release (`monkey.jungle`) | success, no warnings | success, no warnings | success, no warnings |
| Debug (`monkey.debug.jungle`) | success, no warnings | success, no warnings | success, no warnings |

Artifact inspection also confirmed that release contains no `DemoScenarios`,
`debugNowUtc`, memory diagnostic, or test symbols, and that debug contains no
unit-test source.

## Unit tests

Build and run the test personality headlessly in a DST-observing timezone:

```bash
source scripts/env.sh
./scripts/build.sh test
```

Final result: **68 passed, 0 failed, 0 errors**, with process status zero. The
driver starts and stops a headless simulator when needed, parses the SDK runner
summary, prints the counts, and exits nonzero for a missing summary, failure,
or error.

Coverage includes leap/month/year boundaries, countdowns, all exact regimen
boundaries, replacement/history behavior, strict `>3h`, reminder priority and
deduplication, invalid/future data, App Settings parsing/ranges/mirroring,
storage round trips, history compaction, spring-forward normalization,
fall-back tie-breaking, revision ordering and mirror repair, durable settings
mirrors, constrained-codec rejection, exact copy/date/clock formatting, and a
storage stress fixture with 24 history cycles and 32 threshold-crossing
intervals per cycle. The stress fixture verifies that both history values stay
below 24 KiB, round-trip all retained records, and leave glance/background with
only reduced active data.

## Debug time and demo scenarios

Release `currentUtc()` always returns `Time.now().value()`. Debug
`currentUtc()` first reads numeric epoch seconds from the object-store key
`debugNowUtc`. Use the simulator's object-store editor to set that key to any
instant, or remove it to resume real time. The debug implementation and key
name are absent from release PRGs.

The debug-only main menu has these confirmed scenario seeds:

- Fresh
- Day 5 ring-in
- Day before removal
- Overdue removal
- Overdue 12d 23h
- Ring-free day 3
- Ring-free ceiling exceeded
- Temporary-out 2h50m
- Temporary-out 3h10m
- 35-day extended plan after day 28
- Maximum stored history (24 cycles and 64 total retained temporary intervals)

Every seed is itself protected by a native Confirmation and replaces storage
only after acceptance.

## Headless simulator and screenshots

Start the simulator in one shell and the app in another:

```bash
# shell 1
source scripts/env.sh
TZ=America/New_York ciq_headless_simulator

# shell 2
source scripts/env.sh
monkeydo bin/debug/RingTracker-epix2pro47mm.prg epix2pro47mm
```

For a simulator running on display `:99`, capture the 47 mm device canvas as
documented by the installed headless setup:

```bash
source scripts/env.sh
export DISPLAY=:99
export XAUTHORITY=/tmp/xvfb-run.XXXXXX/Xauthority
export MAGICK_CONFIGURE_PATH="$CIQ_SIM_RUNTIME/etc/ImageMagick-6"
export MAGICK_CODER_MODULE_PATH="$CIQ_SIM_RUNTIME/usr/lib/x86_64-linux-gnu/ImageMagick-6.9.12/modules-Q16/coders"
xwd -silent -root -out /tmp/ring-tracker.xwd
convert-im6.q16 /tmp/ring-tracker.xwd \
  -crop 416x416+122+263 docs/screenshots/epix2pro47mm-main-ring-in.png
```

The Xauthority directory is generated per simulator start; read it from the
running Xvfb command. The confirmed content crops are 390×390 at `+118+259`,
416×416 at `+122+263`, and 454×454 at `+146+281`.

Screenshot inventory:

- `epix2pro42mm-main.png`
- `epix2pro42mm-main-overdue.png`
- `epix2pro42mm-glance.png`
- `epix2pro51mm-main.png`
- `epix2pro51mm-main-overdue.png`
- `epix2pro51mm-glance.png`
- `epix2pro47mm-first-run-disclaimer.png`
- `epix2pro47mm-regimen.png`
- `epix2pro47mm-initial-insertion-menu.png`
- `epix2pro47mm-date-picker.png`
- `epix2pro47mm-time-picker.png`
- `epix2pro47mm-insertion-confirmation.png`
- `epix2pro47mm-main-ring-in.png`
- `epix2pro47mm-main-ring-free.png`
- `epix2pro47mm-main-overdue.png`
- `epix2pro47mm-main-temporary-out-2h50.png`
- `epix2pro47mm-main-temporary-out-3h10.png`
- `epix2pro47mm-main-extended-35-day.png`
- `epix2pro47mm-main-menu.png`
- `epix2pro47mm-adjust-menu.png`
- `epix2pro47mm-settings-menu.png`
- `epix2pro47mm-repeat-menu.png`
- `epix2pro47mm-clock-menu.png`
- `epix2pro47mm-schedule.png`
- `epix2pro47mm-history.png`
- `epix2pro47mm-cycle-detail.png`
- `epix2pro47mm-about.png`
- `epix2pro47mm-alert-detail.png`
- `epix2pro47mm-confirmation.png`
- `epix2pro47mm-demo-scenarios.png`
- `epix2pro47mm-glance.png`

All files have their native expected dimensions. The conditional App Settings
review is not pictured because the headless App Settings editor requires an
authenticated Garmin session; its view, confirmation, validation, and
accept/reject reconciliation paths are implemented, compiled, and covered at
the bridge/domain level.

## Memory verification

Measurements use the 47 mm debug build, which is larger than release, and the
reproducible **Maximum stored history** fixture: 24 archived cycles, 32
archived temporary intervals, and 32 active intervals including one open
interval. The storage-specific test separately exercises the larger legal case
of 32 threshold-crossing intervals in every archived cycle.

| Personality | Before review | After review | Available heap | Evidence |
| --- | ---: | ---: | ---: | --- |
| Foreground | 89.7 KiB | 121.1 KiB | 763.6 KiB | Highest active-memory reading after maximum-state save, 24-item History construction, and Cycle detail navigation |
| Glance | 52.9 KiB | 21.6 KiB | 59.8 KiB | Active-memory reading after rendering the maximum-state reduced mirror |
| Background | 48,136 bytes (47.0 KiB) | 19,744 bytes (19.3 KiB) | 61,256 bytes (59.8 KiB) | Debug sample after a manually triggered temporal callback against the maximum-state mirror |

The transient background process exits too quickly for the headless GUI panel
to remain attached. Its recorded value is therefore the post-work live heap
sample immediately before exit, matching the prior measurement method. Glance
and background are both below the requested 45 KiB ceiling and the stricter
40 KiB target in `SPEC.md`. Neither constrained personality loads
`CalendarMath`, `ScheduleModel`, the full store/history codec, or foreground
views. No constrained personality failed in the maximum-state run.

## Installed SDK API verification

Every used platform surface was checked against the SDK 9.2.0 API data and
generated documentation under `$CIQ_SDK_HOME`, including:

- `Notifications.showNotification(title, subtitle, options)` and the `:body`,
  `:icon`, `:data`, and `:dismissPrevious` option keys;
- manifest permission IDs `Background` and `Notifications`;
- `Background.registerForTemporalEvent(Duration)` and `Background.exit(data)`;
- `AppBase.getServiceDelegate()`, `getGlanceView()`, `onSettingsChanged()`, and
  `onValidateProperty(key, value)`;
- notification launch data under `:launchedFromNotification`;
- `Graphics.FONT_GLANCE`, `FONT_GLANCE_NUMBER`, and
  `Dc.drawArc(x, y, radius, direction, startAngle, endAngle)` with
  `Graphics.ARC_CLOCKWISE`;
- `WatchUi.Menu2`, `MenuItem`, `Picker`, `PickerFactory`, `PickerDelegate`,
  `Confirmation`, `ConfirmationDelegate`, and `BehaviorDelegate` callbacks;
- `Attention`, `System.getDeviceSettings()`, and `System.getSystemStats()`.

## Deliberate deviations and platform limitations

1. The specified ±4-hour local-time resolver described checking every minute.
   That implementation triggered the foreground watchdog on an actual insert
   in this device simulator. The working resolver samples the complete window
   hourly to discover every UTC offset, derives exact candidates
   algebraically, and scans transition bands minute-by-minute. It preserves
   the same ambiguous/nonexistent-time results and is covered by both DST tests.
2. Connect IQ's native `Confirmation` accepts one message rather than separate
   title/body/consequence fields. Ring Tracker uses two concise lines with the
   date and time in separate segments; the longest replacement copy was checked
   without ellipsis on all target sizes. All mutations still require
   Confirmation.
3. The device personality requires a 60×60 compiled launcher bitmap. The
   required 40×40 source asset is retained as `launcher-40.svg`; the visually
   identical 60×60 declaration is used as the manifest launcher.
4. The optional first-insertion arc-draw animation is omitted. The app renders
   the final marker immediately, avoiding an unverified reduced-motion
   assumption on this API level.
5. Cycle detail shows the most recent retained temporary-out interval plus the
   retained-event count and a summarized badge. The complete data remains in
   storage, but multiple intervals are not all scroll-rendered on this compact
   detail screen.
6. A background historical-peak window cannot remain open after the required
   immediate `Background.exit(null)` in the headless simulator. The table
   records the post-work live heap sample immediately before exit and calls out
   that evidence distinction explicitly.

## Review findings resolution

The 18 findings in `REVIEW.md` were resolved in rank order. The imported review
suite now lives in `source/tests/ReviewTests.mc`; focused follow-up coverage is
in `source/tests/ReviewResolutionTests.mc`.

1. Temporary-out state no longer replaces the scheduled action or deadline.
   `ScheduleModel.mc`, `ReminderPolicy.mc`, and `BackgroundRuntime.mc` evaluate
   schedule reminders and the strict `>3h` temporary warning independently.
2. `ScheduleModel.mc` now validates every persisted document, bounded field,
   enum, wall tuple, interval, ledger slot, and chronology. `RingStore.mc`,
   `BackgroundRuntime.mc`, and `GlanceView.mc` reject invalid mirrors; the
   constrained paths leave a durable foreground recovery marker.
3. `RingTrackerApp.mc` passes the just-closed interval to `AlertView`; the
   context is cleared for later live alerts. `ScheduleModel.temporaryGuidance`
   explicitly handles weeks 1/2, week 3, outside-standard, unknown, and
   crossed-week intervals and shows every applicable section.
4. `SettingsBridge.mc`, picker delegates, settings confirmation, and mutation
   entry points reject actual insertions later than `now + 60s`; only planned
   overrides may be future-dated.
5. `ScheduleModel.mc` persists `finalInsertionUtc` as the minimum of the
   configured plan, actual-removal plan, seven-day ceiling, and override, and
   refreshes it whenever an accepted edit changes those inputs.
6. Insertion, removal, and replacement edits validate their order against all
   retained events before rebuilding or saving. Invalid watch and settings
   edits keep the canonical cycle unchanged.
7. `ReminderPolicy.mc` bounds day-before/day-of eligibility and marks
   day-before consumed when day-of is delivered, preventing catch-up bursts.
8. Active cycles have a short-interval summary. Starting the 33rd event first
   folds the oldest eligible closed short interval; a genuinely uncompactable
   action surfaces a blocking storage message.
9. Status exposes exact `ringFreeLimitReached` separately from strict
   `ringFreeLimitExceeded`; main and alert UI render “Insert now” and the
   seven-day-limit copy at equality.
10. `RingStore.mc` writes revisioned history and constrained mirrors first and
    canonical state last. Load repairs mismatched mirrors, background ledger
    merge requires the canonical revision, and storage-full failures have a
    distinct classification.
11. Every encoded value has a 24 KiB preflight. History is split into two
    revisioned chunks, threshold-crossing records are retained, eligible short
    intervals are compacted in one pass before retry, and the maximum-value and
    `StorageFullException` paths have regression coverage.
12. Final deadlines are persisted at edit time. Glance and background now use
    small direct positional codecs (`GlanceView.mc` and
    `BackgroundRuntime.mc`) and do not construct domain dictionaries, resolve
    wall time, decode history, or construct foreground views. All
    `disableBackgroundCheck` suppressions were removed, and all three target
    builds pass the SDK background checker. Measured usage fell from 52.9 to
    21.6 KiB for glance and from 47.0 to 19.3 KiB for the background callback.
13. Configuration edits use the same durable pending-mirror protocol as
    insertion edits. `SettingsBridge.mc` completes interrupted mirrors
    idempotently, and `RingTrackerApp.saveOrRecover` treats the clearing save as
    a retryable error instead of ignoring it.
14. `Menus.settingsMenu` adds a persistent outside-FDA-labelled row whenever
    `daysIn` is 29–35, in addition to the acknowledgement and main-screen
    boundary notice.
15. The exact-three-hour resource now says “3-hour limit reached; reinsert now
    and follow product instructions.” It remains distinct from the strict
    over-three-hour classification and uses wrapped foreground rendering.
16. An empty settings insertion is accepted only with no active cycle. With an
    active cycle it creates a bounded pending error and the foreground mirror
    repairs the phone property to the canonical insertion.
17. Notification launches require a two-number payload, matching active cycle
    ID, and one of the six known kind codes before Alert opens.
18. Background-scoped replacement-tomorrow and replacement-today resources
    are selected explicitly for zero-day ring-free plans in
    `ServiceDelegate.mc`.

The polish pass also standardized every user-facing date to `Mon 5 Oct`, put
time on its own segment with system/12/24-hour handling, centered one-column
date/time pickers without stray separators, reordered the overdue screen, made
Alert state live and scroll-safe, added the full-width glance phase bar and
today marker, and replaced the About release-gate placeholder with the exact
`REGIMEN.md` disclaimer plus all six source families.
