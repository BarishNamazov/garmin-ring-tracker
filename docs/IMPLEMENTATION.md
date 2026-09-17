# Ring Tracker implementation and verification

Ring Tracker v1.2 is a Garmin Connect IQ device app for the epix Pro (Gen 2)
42 mm, 47 mm, and 51 mm family. It tracks NuvaRing insertion, removal, and
temporary-out events; derives each next deadline from the event that actually
happened; projects upcoming cycles; keeps 24 archived cycles; and evaluates
local reminder slots. The manifest application UUID is
`99f92e0c-a120-4641-b832-6da4d958585b`; the minimum API is 5.1.0.

`SPEC-1.1.md` remains the reminder and settings-conflict contract. `SPEC.md`
and `UI.md` remain the v1.0 base where later requirements do not override them,
and `REGIMEN.md` remains the medical-model source record.

## UX round: lists

Upcoming is a date-first six-cycle projection with fixed right-aligned `IN`
and `OUT` columns. Only the current row carries a real schedule bar and today
tick; overdue removal appears in amber on that row, and one `if removed today`
divider explains the re-anchored future projection. The first January date
carries a two-digit year cue, the fourth row peeks into view, and the neutral
scroll indicator is present on every supported size.

History now leads with the recorded insertion/removal range. An open current
cycle uses its planned removal as a grey range endpoint. `Cycle N · Current`
is secondary, and each row has one variance line using only that cycle's own
removal and insertion events. Variance over seven days is red; smaller nonzero
variance is amber. Three rows fit with symmetric padding, a full-row focus
shape, and no decorative regimen bars or bezel tick.

Cycle detail aligns all labels and values to one pair of edges. Actual events
show a weekday timestamp with their variance and compact planned date; pending
events say `due ...` and unavailable rows are omitted. `First recorded` is a
caption under the title, brief-outs remain cycle-scoped, and the lifetime
scheduled-removal count is explicitly labelled `Removals (all)` in the footer.

Debug list fixtures cover `Wed 30 Sep`, a December-to-January projection, a
three-day-overdue current cycle, 15-day early/late variance, and the 24-cycle
history limit. Six focused tests cover date ranges, planned current endpoints,
cycle-scoped variance text/severity, and the single January year cue.

## v1.2 changes

### Native-style watch pickers

The installed SDK 9.2.0 `Picker` sample and Garmin's `WatchUi.Picker` contract
establish the native progressive model used here: `:pattern` contains one
factory or fixed drawable per column, `:defaults` selects each initial index,
and the device supplies the next, previous, and confirm controls unless the app
overrides `:nextArrow`, `:previousArrow`, or `:confirm`. START advances from
one selectable column to the next; BACK returns to the preceding column and
then cancels. The stock control supplies button, touch, wrap, and device repeat
behavior.

The time picker follows the epix alarm arrangement within that model:

- 12-hour mode uses hour `1–12`, minute `00–59`, and AM/PM factories;
- 24-hour mode uses hour `00–23` and minute `00–59` factories;
- the minute factory is independent from the hour factory, so scrolling a
  minute never traverses an hour boundary;
- the colon is kept in the live title instead of consuming a picker pattern
  slot, leaving hour, minute, and AM/PM visible together at minute focus;
- the native title slot redraws the assembled time after each selection; and
- Reminder 1, Reminder 2, and the time half of every date edit use the same
  picker.

`PickerDelegate` exposes accept, cancel, and action-menu callbacks, but no raw
key-pressed/key-released callbacks. `InputDelegate` exposes those raw callbacks,
but it is not the delegate contract for the stock Picker. Ring Tracker therefore
does not add an app-level hold timer; it retains the stock control's native
wrap and key-repeat behavior.

The date picker uses day, short-month, and year factories. Its year range is
the current local year ±2, its live title is `Wed 16 Sep 2026`-style copy, and
the selected day is clamped for the chosen month and year before the time picker
opens. Leap-year and month-length helpers are shared with the tests. Native
390×390, 416×416, and 454×454 captures verify the longest visible year/date
forms without clipping.

### Phone App Settings schema and migration

The visible settings page now has three groups and this order:

| Group | Controls |
| --- | --- |
| Schedule | Insertion date, Insertion time, Days ring in, Days ring out |
| Reminders | Reminder 1, Reminder 2 On/Off, Reminder 2 time, Day-before reminder, Overdue repeat |
| Display | Clock format, Vibration, Sound |

`Insertion date` uses the native `date` control. Garmin stores that control as
a UTC epoch value, so `Gregorian.utcInfo()` supplies its year, month, and day;
the epoch is never treated as the intended local instant. `Insertion time`,
Reminder 1, and Reminder 2 are 96-entry lists from `12:00 AM` through
`11:45 PM`. Garmin's schema has no time-only control. Each list value is
minutes since midnight at a 15-minute interval.

Every visible control has a clear title and applicable short prompt. The
schema's `helpUrl` attribute is deprecated, and `enableIfTrue` applies to an
entire group rather than an individual setting, so neither is appropriate for
this page; Reminder 2's time remains visible and retained while its switch is
Off.

Watch values remain exact to the minute. A watch-to-phone mirror rounds only
the property representation to the nearest quarter-hour; values at minutes
`00–07` round down, `08–14` round up, and a late-night result may wrap to the
next date. The canonical state is not changed. A phone list selection is
already a quarter-hour value and is accepted exactly. Insertion date and time
are observed as one local tuple: changing either field is a settings edit,
future or nonexistent local times are rejected, and a valid changed tuple is
confirmed in the foreground. Pending mirrors and the watch-wins conflict rule
remain in force.

The one-time property-schema migration reads v1.1's numeric reminder hour and
minute fields and ISO insertion string, writes the new lists/native date, and
marks schema version 2. The legacy property IDs remain declared in
`properties.xml` but are absent from `settings.xml`; retaining the declarations
makes synchronized upgrade values readable without exposing obsolete controls.

SDK 9.2.0 validates the grouped schema during every build. The documented
interactive editor is **File > Edit Persistent Storage > Edit
Application.Properties data**. In this headless Linux environment the editor's
WebKit child cannot create an EGL display under Xvfb, even after its packaged
network-process path is made available, and the SDK contains no standalone
settings HTML/preview command. The phone settings page therefore could not be
captured on any of the three simulated targets; the watch picker captures and
the compiled settings schema are the available visual/build evidence.

## v1.1 changes

- Visible product copy is terse and NuvaRing-specific. The only shipped use of
  “generics” or “Annovera” is the required About line, `Not for generics or
  Annovera.`
- Reminder 1 is always enabled, Reminder 2 is optional, and the day-before
  reminder is optional. The day-before reminder uses Reminder 1's time.
- Removal is due `daysIn` local calendar days after the actual insertion.
  Insertion is due `daysOut` local calendar days after the actual removal.
  Confirmations and History preserve early/late event deltas.
- Upcoming projects six cycles from the active actual-event anchor without
  mutating state. If the current action is overdue, row 1 retains the actual
  cycle while projected rows assume the action happens now, remain non-past,
  and show `if done today`.
- Main is a status screen: UP opens Upcoming, DOWN opens History, START/tap
  opens the context menu, and long MENU opens the same menu. While temporarily
  out, START/tap opens the ring-back-in confirmation.
- Edit dates edits only recorded insertion and removal timestamps. The v1.0
  Schedule detail and planned-action override picker were removed.
- State validation recomputes every derived deadline, enforces unique cycle
  IDs, requires `nextCycleId` above every retained ID, and accepts only known
  close reasons.
- Rejected or cancelled phone-setting changes stage a durable watch-wins mirror
  so the canonical values are written back without repeating the prompt.
- A mid-cycle days-in/days-out change shows the old and new next-action time in
  its native confirmation.
- History is a custom three-row scrollable view with date-range primaries,
  cycle-scoped one-line variance, full-row focus, cycle detail, and a final
  Clear-history action. Cycle-detail actual, planned, due, and variance values
  form a right-aligned vertical block. Native confirmations use compact
  two-line copy, and Main warning text breaks at sentence boundaries.
- Foreground orchestration lives in the unscoped `ForegroundController` and
  `ForegroundRuntime`, outside the `:background` and `:glance` personalities.
- Temporary-out reminder deduplication includes the open interval's `outUtc`,
  so closing and reopening within one cycle starts a new reminder sequence.
- Spring-forward gaps resolve to the exact first valid minute. The background
  notification path uses only background-scoped resources and is exercised by
  real simulator temporal events, including failure paths.

## File map

| Area | Files | Responsibility |
| --- | --- | --- |
| Package | `manifest.xml`, `monkey.jungle` | Version, three products, permissions, and release annotation filtering |
| QA builds | `monkey.debug.jungle`, `monkey.tests.jungle` | Debug resources/clock/scenarios and Toybox.Test personality |
| Domain | `source/CalendarMath.mc`, `source/ScheduleModel.mc`, `source/ReminderPolicy.mc` | DST-safe local calendar math, actual-event transitions/validation, status, and reminder selection/deduplication |
| Persistence | `source/RingStore.mc` | Schema-v3 codecs; v1/v2 migration; revisioned canonical/history/mirror writes; 24 KiB preflight and compaction |
| Settings | `source/SettingsBridge.mc`, `resources/settings/` | Grouped native-date/quarter-hour App Settings, legacy property migration, conflict review, and durable canonical mirrors |
| App shell | `source/RingTrackerApp.mc` | Minimal scoped `AppBase` bridge plus unscoped foreground controller, navigation, confirmations, and settings orchestration |
| Foreground UI | `source/MainView.mc`, `source/UpcomingView.mc`, `source/HistoryView.mc`, `source/StaticViews.mc`, `source/Menus.mc`, `source/Pickers.mc`, `source/UiUtils.mc` | Main, six-cycle Upcoming, custom scrollable History/detail, setup/About, menus, confirmations, and native pickers |
| Constrained personalities | `source/GlanceView.mc`, `source/BackgroundRuntime.mc`, `source/ServiceDelegate.mc` | Reduced mirror codecs, glance rendering, and hourly reminder service |
| Build variants | `source/Clock.mc`, `source/OptionalFeatures.mc`, `source/DemoScenarios.mc`, `resources-debug/` | Production seams and debug-only clock, fixtures, notification previews, temporal-event diagnostics, and memory reporting |
| Resources | `resources/strings/strings.xml`, `resources/drawables/` | Audited visible copy, launcher assets, and background notification icon |
| Tests | `source/tests/*.mc` | 135 deterministic domain, picker, migration, settings, storage, reminder, layout-helper, and review-regression tests |
| Build checks | `scripts/build.sh`, `scripts/check-background-scope.sh`, `scripts/IqPrgHashes.java` | Three-target warning-free builds, portable `grep` background resource/exit guard, simulator tests, and Store-package PRG hashes |
| Visual evidence | `docs/screenshots/` | 102 native-resolution captures, including nine v1.2 picker states |

The canonical document excludes archived history. History is split across two
revisioned values in alternating parity slots. Glance and background each use a
compact, independently validated mirror containing only the fields they need.
History and mirrors are written before the canonical revision commit. A
background ledger update touches only its small mirror and is merged by the
next foreground load when revisions match.

Schema v3 is the storage implementation of the product-level v1.1/schema-2
contract. It adds actual-event anchors/deltas, the two-slot reminder ledger,
day-before configuration, and `migrationNoticePending`. v1 and v2 documents are
decoded and migrated in memory, then history/mirrors and finally canonical
state are committed under a new revision. A failed migration does not destroy
the recoverable prior document. Existing reminder time becomes Reminder 1;
Reminder 2 defaults to 20:00 Off; day-before defaults On; old `dayOfSent` maps
to both new day-of ledger flags.

## Build configurations

Source the SDK environment, then use the checked-in driver:

```bash
cd /path/to/garmin-ring-tracker
source scripts/env.sh
./scripts/build.sh release
./scripts/build.sh debug
./scripts/build.sh test
```

The driver first checks that every `Rez.Strings` symbol referenced by
`ServiceDelegate` or `BackgroundRuntime` is declared with
`scope="background"`, and that the service contains exactly one lexical
`Background.exit` call. It then builds every target, treats warnings as
failures, exports the Store package for release, and runs the simulator test
personality for `test`. The shell checks require only Bash, coreutils, `grep`,
`sed`, `awk`, `unzip`, `sha256sum`, the documented simulator runtime, and the
SDK/JDK tools; they do not require `rg`, `pgrep`, or `setsid`. The portability
smoke test is:

```bash
env -i HOME="$HOME" PATH=/usr/bin:/bin bash -lc \
  'cd /path/to/garmin-ring-tracker && source scripts/env.sh && ./scripts/build.sh release'
env -i HOME="$HOME" PATH=/usr/bin:/bin bash -lc \
  'cd /path/to/garmin-ring-tracker && source scripts/env.sh && ./scripts/build.sh debug'
env -i HOME="$HOME" PATH=/usr/bin:/bin bash -lc \
  'cd /path/to/garmin-ring-tracker && source scripts/env.sh && ./scripts/build.sh test'
```

Final verification on 2026-09-16:

| Configuration | 42 mm | 47 mm | 51 mm |
| --- | --- | --- | --- |
| Release | success, zero warnings | success, zero warnings | success, zero warnings |
| Debug | success, zero warnings | success, zero warnings | success, zero warnings |
| Unit-test personality | — | success, zero warnings; 129/0/0 | — |

The generated 47 mm debug annotation map contains no `background` or `glance`
entry for `ForegroundController`, `ForegroundRuntime`, `ForegroundEntryView`,
or `ForegroundSettingsEntryView`. Only the required `AppBase` bridge methods
and the dedicated constrained implementations are tagged into those scopes.

## Tests

The final simulator result is **135 passed, 0 failed, 0 errors**:

| File | Tests |
| --- | ---: |
| `DomainTests.mc` | 34 |
| `ReviewTests.mc` | 17 |
| `ReviewResolutionTests.mc` | 15 |
| `Review2Tests.mc` | 15 |
| `Review3Tests.mc` | 8 |
| `Review3ResolutionTests.mc` | 3 |
| `V11Tests.mc` | 12 |
| `V11CoverageTests.mc` | 16 |
| `V12Tests.mc` | 9 |
| `ListUiTests.mc` | 6 |

The suite covers exact and crossed regimen boundaries, leap/month/year and DST
calendar behavior, per-minute picker values, quarter-hour phone rounding and
conversion, native-date UTC calendar semantics, legacy property migration,
picker day clamping, actual-event re-anchoring, early/late deltas, six-cycle
projection, compact confirmation timestamps, measured date-pair fallbacks,
sentence-boundary warning splits, History variance/scroll bounds, reminder priority and per-slot deduplication, v1/v2 migration,
pending settings mirrors, schema validation, split-history recovery and
compaction, reduced codecs, interval-specific temporary-out deduplication,
exact spring-gap boundaries, non-past overdue projection, and the maximum
retained-history fixture.

### Review 2 regression disposition

Fifteen applicable cases from `docs/review-tests/Review2Tests.mc` were moved to
`source/tests/Review2Tests.mc` and adapted to schema v3:

1. older-schema migration and persistence;
2. interrupted pending-property mirror recovery;
3. missing history-chunk rejection;
4. 23:59 local insertion across DST;
5. mid-cycle days-in reclassification;
6. temporary-out reboot and strict `>3h` handling;
7. stale-cycle notification rejection;
8. nonexistent DST property-time normalization;
9. near-32-KiB history preflight/compaction;
10. derived-deadline mismatch rejection;
11. duplicate IDs and invalid `nextCycleId` rejection;
12. unknown close-reason rejection;
13. fractional notification-kind rejection;
14. durable repair after rejecting an invalid insertion change; and
15. durable canonical repair after rejecting a duration change.

Four old expectations were dropped or replaced because v1.1 supersedes them:

- the exact-seven-day “does not say over” wording assertion (v1.1 uses the
  normal exact-due state and reserves the hard warning for strictly over seven
  days);
- the requirement for a medical-review date on About (the v1.1 exact copy table
  removes it);
- the old ring-free-exceeded main wording (replaced by the exact v1.1 warning
  `Insert now. Use backup 7 days.`); and
- the impossible/final planned-deadline case (planned overrides and the final
  deadline were removed; actual-event deadline validation replaces it).

### Review 3 resolution

All eight tests in `docs/review-tests/Review3Tests.mc` were adopted into
`source/tests/Review3Tests.mc`; none were dropped. The Upcoming test was adapted
only to pass the explicit `nowUtc` required by the selected overdue-projection
contract. The adopted cases cover:

1. existing spring/fall wall times;
2. exact 03:00 spring-gap resolution for direct, 21-day, and 28-day paths;
3. leap-day, midnight, and persisted-UTC authority;
4. a second temporary-out interval in one cycle;
5. changed reminder times and both insertion-day slots;
6. a real v1.0 ring-in/open-interval/24-history migration;
7. a real v1.0 late-removal migration; and
8. non-past Upcoming rows after a long-overdue current action.

`Review3ResolutionTests.mc` adds three implementation-specific checks: the
temporary interval identity survives a foreground codec round trip, a second
interval stays in foreground/background parity, and an old nine-field schema-3
ledger drops its ambiguous temporary slot while migrating to ten fields.

The five review findings were resolved as follows:

- Background subtitle formatting no longer looks up `TimeSeparator`, `Am`,
  `Pm`, `DayUnit`, `HourUnit`, or `MinuteUnit`; its compact formatter uses
  background-safe literals. The build-time scope guard prevents recurrence.
- The ledger stores `tempOutIdentity` beside `lastTempOutSlot`; an identity
  change resets the slot in both foreground and compact background codecs.
- Overdue projections keep the actual current row, project later rows from an
  as-if-done-now anchor, and mark those rows `if done today`.
- The spring-gap resolver binary-searches the UTC offset transition, returning
  the first valid instant rather than retaining the input minute phase.
- SDK 9.2 release mode strips executable debug information, but the Store
  archive still embeds path-bearing `debug.xml` entries. The executable PRGs
  inside the archive are therefore hashed separately as described below.

### Live background temporal-event verification

The verification uses the actual `System.ServiceDelegate` entry point, not a
direct unit-test call:

1. `source scripts/env.sh`, build `debug`, start
   `TZ=America/New_York ciq_headless_simulator`, and attach
   `monkeydo bin/debug/RingTracker-epix2pro47mm.prg epix2pro47mm`.
2. In the app's **Demo scenarios** menu, load one `BG · …` fixture and confirm
   it. Each fixture records its scenario and creates a fresh compact mirror;
   the nil/corrupt/throw fixtures then apply their named fault.
3. In the simulator choose **Simulation → Background Events**, leave
   **Temporal Event** and the current app target selected, then press Return.
4. Read `RING_TRACKER_BACKGROUND_RESULT=…` and
   `RING_TRACKER_BACKGROUND_MEMORY=…` from the attached `monkeydo` process.
   The result records selected kind, post/save/catch flags, the resulting
   ledger, and `exit=1` immediately before the sole `Background.exit(null)`.

Observed 47 mm results:

| Fixture | Kind | Notification | Ledger save | Caught | Exit | Ledger effect |
| --- | ---: | --- | --- | --- | ---: | --- |
| Day-before | 5 | yes | yes | no | 1 | `dayBeforeSent=true` |
| Reminder 1 | 4 | yes | yes | no | 1 | `dayOf1Sent=true` |
| Reminder 2 | 4 | yes | yes | no | 1 | `dayOf1Sent=true`, `dayOf2Sent=true` |
| Overdue | 3 | yes | yes | no | 1 | `lastOverdueSlot=4` |
| Temporary out >3h | 1 | yes | yes | no | 1 | slot 0 plus interval `outUtc` identity |
| Ring free >7d | 0 | yes | yes | no | 1 | `ringFreeExceededSent=true` |
| Ring in >4 weeks | 2 | yes | yes | no | 1 | `labelFourWeekSent=true` |
| Valid no-op | — | no | no | no | 1 | unchanged |
| Nil mirror | — | no | no | no | 1 | no mirror |
| Corrupt mirror | — | no | no | no | 1 | rejected as inert |
| Injected `showNotification` exception | 4 | no | no | yes | 1 | unchanged for retry |

Each successful reminder produced one native notification and one ledger
write. No-op and invalid-storage paths produced neither. The injected exception
was caught before marking or saving. Diagnostic and memory hooks are separately
guarded so they cannot bypass the one final exit.

## Debug fixtures and visual QA

Debug uses numeric object-store key `debugNowUtc` as a clock override. Remove
the key to return to `Time.now()`. Its demo menu seeds fresh/setup, ring-in,
day-before, overdue, ring-free, temporary-out, extended-duration, early/late
event, Reminder 2, Upcoming, migration, notification-preview, and
maximum-history states. The maximum-history UI fixture is transient so opening
it cannot exceed the foreground watchdog; storage stress remains persistent in
the automated suite.

The native screenshot crops are 390×390 at `+118+259`, 416×416 at `+122+263`,
and 454×454 at `+146+281`. The repository contains 102 native-size images.
The nine v1.2 captures cover 12-hour time, 24-hour time, and date pickers on all
three sizes; each was checked for title updates, clipping, overlap, and
round-edge clearance. Button navigation, BACK-to-previous-column behavior, and
touch selection were also exercised in the simulator.

The list UX round regenerated `history` and `cycle-detail` on all three sizes.
History captures exercise the 24-cycle fixture and its longest scoped variance,
`Out 15d early · In 15d late`, in one line. They also verify the date-range
hierarchy, grey planned endpoint for the current cycle, symmetric focus shape,
neutral scroll rail, and round-edge clearance. The detail captures verify the
single label/value edges, weekday timestamps, variance plus planned-date
context, omitted unavailable rows, `First recorded` caption, and the relocated
`Removals (all)` lifetime statistic.

Both Upcoming pages were regenerated on all three sizes from the overdue
December fixture. The captures verify fixed right-aligned `IN`/`OUT` columns,
the single current-row schedule bar and today tick, amber overdue treatment,
one `if removed today` divider, the first-January year cue, a fourth-row peek,
and the neutral scroll rail. The same list fixture includes the `Wed 30 Sep`
history edge case; every capture was checked for clipping and round-edge
clearance at 390, 416, and 454 px.

For every size, 26 captures cover the three v1.2 pickers plus ring-in, ring-free, overdue removal,
overdue insertion, temporary out at 2h50 and 3h10, >7d and >28d warnings,
Upcoming rows 1–3 and 4–6, long 12-hour and 24-hour formatting, maximum
countdown, warning wrapping, all four glance states, custom History and cycle
detail, and early-removal, late-insertion, and edit-removal confirmations. The
six Upcoming captures now use the overdue-removal fixture: row 1 retains its
actual past dates, rows 2–6 are re-anchored after the single explanatory
divider, and the January transition carries one year cue without clipping on
390, 416, or 454 px. The
47 mm interaction set adds 24 captures covering first run, regimen, four context menus, Edit
dates, Reminder 2 Off/On/submenus/picker, day-before, overdue repeat, clock,
About, migration notice, and all seven native notification kinds. Obsolete Schedule, planned-override, and
v1.0-jargon screenshots were removed.

## Memory verification

Measurements use the 47 mm debug personality so they include the QA overhead.
The foreground reading is the maximum transient history fixture; glance and
background use reduced active mirrors.

| Personality | Peak/live use | Available heap | Result |
| --- | ---: | ---: | --- |
| Foreground | 138.7 KiB | 763.6 KiB | within foreground budget |
| Glance | 17.5 KiB | 59.8 KiB | below 45 KiB |
| Background | 16,184 bytes (15.8 KiB) | 61,256 bytes (59.8 KiB) | below 45 KiB |

The foreground reading is the maximum transient 25-row History view. Glance
was launched with **Settings → Glance Launch Mode → Launch in Glance Mode**.
The background peak is the injected notification-exception case, sampled after
temporal evaluation immediately before the short-lived process exits. Neither
constrained personality loads the full history, foreground controller, or
foreground view graph.

The 47 mm v1.2 visual run reported 123.0 KiB on the 12-hour picker and
122.1 KiB on the date picker, both below the retained maximum-history foreground
peak above. The background idle diagnostic after the v1.2 settings changes was
15,816/61,256 bytes; the existing injected-exception peak remains the larger
background measurement reported in the table.

## Deliberate deviation

No functional requirement in SPEC-1.1 is omitted. There is one narrow copy
presentation override:

- The About version is `Ring Tracker v1.2.0`, following the release instruction
  to put the full semantic version in both the manifest and About; the earlier
  copy table abbreviated that line to a major/minor version.

## Release contents

`bin/release/` is generated. The checked-in `release/` bundle contains:

- `RingTracker-epix2pro42mm.prg`
- `RingTracker-epix2pro47mm.prg`
- `RingTracker-epix2pro51mm.prg`
- `RingTracker.iq`
- `SHA256SUMS`

The three standalone release PRGs are byte-reproducible. The SDK 9.2.0
`monkeyc -e -r` export has no option to omit the path-bearing `debug.xml`
members inside the 7z-format `.iq`, so whole-file `.iq` bytes can vary with the
build path even when executable content is identical. After every release
export, `build.sh` uses `IqPrgHashes.java` and the SDK-bundled Apache Commons
Compress library to print SHA-256 for every internal PRG as `IQ:<entry>`. Those
internal hashes are the reproducible executable-payload verification; the
outer `.iq` hash in `SHA256SUMS` verifies the exact distributed archive.

Copy those files only after all three build targets, the string audit, native
image-dimension check, and release-symbol inspection pass.

The engineering checks do not constitute the clinician/pharmacist review
required by the medical-copy release gate. No review date or approval was
invented; the coordinator must retain qualified sign-off before distribution.
