# Ring Tracker implementation and verification

Ring Tracker v1.1 is a Garmin Connect IQ device app for the epix Pro (Gen 2)
42 mm, 47 mm, and 51 mm family. It tracks NuvaRing insertion, removal, and
temporary-out events; derives each next deadline from the event that actually
happened; projects upcoming cycles; keeps 24 archived cycles; and evaluates
local reminder slots. The manifest application UUID is
`99f92e0c-a120-4641-b832-6da4d958585b`; the minimum API is 5.1.0.

`SPEC-1.1.md` is the v1.1 delta contract. `SPEC.md` and `UI.md` remain the v1.0
base where the delta does not override them, and `REGIMEN.md` remains the
medical-model source record.

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
  mutating state.
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
- History is a custom two-row scrollable view with full-width dates, event
  variance, regimen bars, row focus, cycle detail, and a final Clear-history
  action. Native confirmations use compact two-line copy, and Main warning
  text breaks at sentence boundaries.
- Foreground orchestration lives in the unscoped `ForegroundController` and
  `ForegroundRuntime`, outside the `:background` and `:glance` personalities.

## File map

| Area | Files | Responsibility |
| --- | --- | --- |
| Package | `manifest.xml`, `monkey.jungle` | Version, three products, permissions, and release annotation filtering |
| QA builds | `monkey.debug.jungle`, `monkey.tests.jungle` | Debug resources/clock/scenarios and Toybox.Test personality |
| Domain | `source/CalendarMath.mc`, `source/ScheduleModel.mc`, `source/ReminderPolicy.mc` | DST-safe local calendar math, actual-event transitions/validation, status, and reminder selection/deduplication |
| Persistence | `source/RingStore.mc` | Schema-v3 codecs; v1/v2 migration; revisioned canonical/history/mirror writes; 24 KiB preflight and compaction |
| Settings | `source/SettingsBridge.mc`, `resources/settings/` | 12-item configuration contract, App Settings validation, conflict review, and durable canonical mirrors |
| App shell | `source/RingTrackerApp.mc` | Minimal scoped `AppBase` bridge plus unscoped foreground controller, navigation, confirmations, and settings orchestration |
| Foreground UI | `source/MainView.mc`, `source/UpcomingView.mc`, `source/HistoryView.mc`, `source/StaticViews.mc`, `source/Menus.mc`, `source/Pickers.mc`, `source/UiUtils.mc` | Main, six-cycle Upcoming, custom scrollable History/detail, setup/About, menus, confirmations, and native pickers |
| Constrained personalities | `source/GlanceView.mc`, `source/BackgroundRuntime.mc`, `source/ServiceDelegate.mc` | Reduced mirror codecs, glance rendering, and hourly reminder service |
| Build variants | `source/Clock.mc`, `source/OptionalFeatures.mc`, `source/DemoScenarios.mc`, `resources-debug/` | Production no-op seams and debug-only clock, fixtures, notification previews, and memory reporting |
| Resources | `resources/strings/strings.xml`, `resources/drawables/` | Audited visible copy, launcher assets, and background notification icon |
| Tests | `source/tests/*.mc` | 108 deterministic domain, migration, settings, storage, reminder, layout-helper, and review-regression tests |
| Visual evidence | `docs/screenshots/` | 93 native-resolution v1.1 captures |

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
cd /home/agent/Dev/garmin-bc
source scripts/env.sh
./scripts/build.sh release
./scripts/build.sh debug
./scripts/build.sh test
```

The driver builds every target, treats warnings as failures, exports the Store
package for release, and runs the simulator test personality for `test`.

Final verification on 2026-09-15:

| Configuration | 42 mm | 47 mm | 51 mm |
| --- | --- | --- | --- |
| Release | success, zero warnings | success, zero warnings | success, zero warnings |
| Debug | success, zero warnings | success, zero warnings | success, zero warnings |
| Test compile | success, zero warnings | success, zero warnings | success, zero warnings |

The generated 47 mm debug annotation map contains no `background` or `glance`
entry for `ForegroundController`, `ForegroundRuntime`, `ForegroundEntryView`,
or `ForegroundSettingsEntryView`. Only the required `AppBase` bridge methods
and the dedicated constrained implementations are tagged into those scopes.

## Tests

The final simulator result is **108 passed, 0 failed, 0 errors**:

| File | Tests |
| --- | ---: |
| `DomainTests.mc` | 34 |
| `ReviewTests.mc` | 17 |
| `ReviewResolutionTests.mc` | 15 |
| `Review2Tests.mc` | 15 |
| `V11Tests.mc` | 12 |
| `V11CoverageTests.mc` | 15 |

The suite covers exact and crossed regimen boundaries, leap/month/year and DST
calendar behavior, actual-event re-anchoring, early/late deltas, six-cycle
projection, compact confirmation timestamps, sentence-boundary warning splits,
History variance/scroll bounds, reminder priority and per-slot deduplication, v1/v2 migration,
pending settings mirrors, schema validation, split-history recovery and
compaction, reduced codecs, and the maximum retained-history fixture.

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

## Debug fixtures and visual QA

Debug uses numeric object-store key `debugNowUtc` as a clock override. Remove
the key to return to `Time.now()`. Its demo menu seeds fresh/setup, ring-in,
day-before, overdue, ring-free, temporary-out, extended-duration, early/late
event, Reminder 2, Upcoming, migration, notification-preview, and
maximum-history states. The maximum-history UI fixture is transient so opening
it cannot exceed the foreground watchdog; storage stress remains persistent in
the automated suite.

The native screenshot crops are 390×390 at `+118+259`, 416×416 at `+122+263`,
and 454×454 at `+146+281`. All 93 images in `docs/screenshots/` were regenerated
and visually checked at native size for clipping, overlap, round-edge clearance,
warning wrapping, and correct local date/time content.

For every size, 23 captures cover ring-in, ring-free, overdue removal,
overdue insertion, temporary out at 2h50 and 3h10, >7d and >28d warnings,
Upcoming rows 1–3 and 4–6, long 12-hour and 24-hour formatting, maximum
countdown, warning wrapping, all four glance states, custom History and cycle
detail, and early-removal, late-insertion, and edit-removal confirmations. The
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
| Foreground | 136.0 KiB | 763.6 KiB | within foreground budget |
| Glance | 16.8 KiB | 59.8 KiB | below 45 KiB |
| Background | 15,040 bytes (14.7 KiB) | 61,256 bytes (59.8 KiB) | below 45 KiB |

The background number is sampled after temporal evaluation immediately before
the short-lived process exits. Neither constrained personality loads the full
history, foreground controller, or foreground view graph.

## Deliberate deviation

No functional requirement in SPEC-1.1 is omitted. There is one narrow copy
presentation override:

- The About version is `Ring Tracker v1.1.0`, following the release instruction
  to put the full semantic version in both the manifest and About; section A's
  table abbreviates that line to `v1.1`.

## Release contents

`bin/release/` is generated. The checked-in `release/` bundle contains:

- `RingTracker-epix2pro42mm.prg`
- `RingTracker-epix2pro47mm.prg`
- `RingTracker-epix2pro51mm.prg`
- `RingTracker.iq`
- `SHA256SUMS`

Copy those files only after all three build targets, the string audit, native
image-dimension check, and release-symbol inspection pass.

The engineering checks do not constitute the clinician/pharmacist review
required by the medical-copy release gate. No review date or approval was
invented; the coordinator must retain qualified sign-off before distribution.
