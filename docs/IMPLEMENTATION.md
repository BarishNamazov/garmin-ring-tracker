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
| Persistence | `source/RingStore.mc` | Versioned positional codec, recovery, full state, reduced glance mirror, and reduced background mirror |
| Settings | `source/SettingsBridge.mc`, `resources/settings/` | App Settings validation, diff/reconciliation, and watch-to-property mirroring |
| App shell | `source/RingTrackerApp.mc` | Lifecycle, routing, confirmations, background registration, notification launch validation, and settings review |
| Foreground UI | `source/MainView.mc`, `source/StaticViews.mc`, `source/HistoryView.mc`, `source/Menus.mc`, `source/Pickers.mc`, `source/UiUtils.mc` | Scaled drawing, screens, native menus/confirmations, and custom pickers |
| Constrained personalities | `source/GlanceView.mc`, `source/ServiceDelegate.mc` | Reduced glance and hourly notification service |
| Build variants | `source/OptionalFeatures.mc`, `source/DemoScenarios.mc`, `resources-debug/` | Release no-op seams and debug-only demo/time/memory helpers |
| Resources | `resources/strings/strings.xml`, `resources/drawables/` | All visible copy, launcher assets, and background-scoped notification icon |
| Tests | `source/tests/DomainTests.mc` | 31 deterministic domain, DST, settings, codec, history, and max-state mirror tests |
| Visual evidence | `docs/screenshots/` | Native-resolution simulator captures |

The full state retains history and every active temporary-out record. Separate
storage mirrors intentionally limit glance and background data to the active
schedule, configuration, ledger, and at most the currently open temporary-out
interval. A background ledger write updates only its small mirror; the next
foreground load merges it into full state. This prevents 24 archived cycles or
32 active intervals from consuming the 64 KiB constrained heaps.

## Build configurations

Source the installed SDK environment first:

```bash
cd /home/agent/Dev/garmin-bc
source scripts/env.sh
```

Release physically excludes `:debug`, `:test`, and `:testhelper` declarations:

```bash
monkeyc -d epix2pro47mm -f monkey.jungle \
  -o bin/RingTracker-epix2pro47mm-release.prg \
  -y ~/.Garmin/developer_key.der -w
```

Debug/QA excludes `:production` and test declarations, adds debug resources,
uses `Storage["debugNowUtc"]` when present, exposes **Demo scenarios**, and
prints the service memory sample:

```bash
monkeyc -d epix2pro47mm -f monkey.debug.jungle \
  -o bin/RingTracker-epix2pro47mm-debug.prg \
  -y ~/.Garmin/developer_key.der -w
```

Replace the device and output name with `epix2pro42mm` or `epix2pro51mm` for
the other family members. The final verification on 2026-09-14 was:

| Configuration | 42 mm | 47 mm | 51 mm |
| --- | --- | --- | --- |
| Release (`monkey.jungle`) | success, no warnings | success, no warnings | success, no warnings |
| Debug (`monkey.debug.jungle`) | success, no warnings | success, no warnings | success, no warnings |

Artifact inspection also confirmed that release contains no `DemoScenarios`,
`debugNowUtc`, memory diagnostic, or test symbols, and that debug contains no
unit-test source.

## Unit tests

Build and run the test personality in a DST-observing timezone:

```bash
source scripts/env.sh
monkeyc -d epix2pro47mm -f monkey.tests.jungle \
  -o bin/RingTracker-tests.prg \
  -y ~/.Garmin/developer_key.der -w --unit-test
TZ=America/New_York monkeydo bin/RingTracker-tests.prg epix2pro47mm -t
```

Final result: **31 passed, 0 failed, 0 errors**. The SDK's `monkeydo` process
returns status 1 after this successful unit-test run; the authoritative runner
output ends with `PASSED (passed=31, failed=0, errors=0)`.

Coverage includes leap/month/year boundaries, countdowns, all exact regimen
boundaries, replacement/history behavior, strict `>3h`, reminder priority and
deduplication, invalid/future data, App Settings parsing/ranges/mirroring,
storage round trips, history compaction, spring-forward normalization,
fall-back tie-breaking, background-ledger history preservation, and a stored
maximum-state fixture with 24 history cycles and 32 active intervals. The last
fixture verifies that glance/background mirrors contain only the open interval.

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
- Ring-free day 3
- Ring-free ceiling exceeded
- Temporary-out 2h50m
- Temporary-out 3h10m
- 35-day extended plan after day 28

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
monkeydo bin/RingTracker-epix2pro47mm-debug.prg epix2pro47mm
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
- `epix2pro51mm-main.png`
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

Measurements used the 47 mm debug build, which is larger than release, and the
maximum-state test fixture (24 archived cycles, 32 active temporary-out
records, one open interval). The simulator's **Active Memory** panel was
refreshed after foreground/glance rendering and nested navigation.

| Personality | Measurement | Available heap | Evidence |
| --- | ---: | ---: | --- |
| Foreground | 89.7 KiB peak | 763.6 KiB | Active Memory panel after max-state load and history/detail navigation |
| Glance | 52.9 KiB peak | 59.8 KiB | Active Memory panel with max-state reduced mirror |
| Background | 48,136 bytes (47.0 KiB) after full callback | 61,256 bytes (59.8 KiB) | Debug `System.getSystemStats()` immediately before `Background.exit(null)` after evaluation/notification |

The transient background process exits too quickly for the headless GUI panel
to remain attached. Its recorded value is therefore the end-of-callback live
usage after all service work, rather than the panel's historical peak field.
An earlier implementation that decoded all active intervals failed this same
max-state run with `Out Of Memory Error`; the reduced mirror above is the
verified fix. No constrained personality failed after that change.

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
   title/body/consequence fields. Ring Tracker composes the timestamp and
   consequence into that message; native firmware may ellipsize long text on a
   round screen. All mutations still require Confirmation.
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

