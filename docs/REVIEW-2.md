# Independent verification review — round 2

Reviewed detached commit `14356f33e7fcdc0fd3268e120cae7f5da332da07` in `/tmp/review2-wt`, created with `git worktree add --detach /tmp/review2-wt HEAD`. The concurrent main-tree source/documentation edits were not read or tested. Review date: 2026-09-15. Toolchain: Connect IQ SDK 9.2.0, epix Pro (Gen 2), with calendar-sensitive tests and simulator work run in `America/New_York`.

## Verdict

**DO NOT SHIP.** Thirteen of the 18 round-1 findings are verified, but five are only partial. In particular, corrupted persisted state can still pass validation with an impossible early final deadline, exact-seven-day notifications state that the interval is already “over,” and invalid/rejected App Settings values are not repaired through the production mirror path. The About screen has no medical-copy review date and the repository contains no evidence of the clinician/pharmacist review required by `REGIMEN.md`; `SPEC.md` also gates release on all boundary/storage/reminder tests passing. The new adversarial suite intentionally exposes eight contract failures.

The builds are clean and the constrained runtimes are much smaller than in round 1. Those improvements do not override the failed correctness and medical-copy release gates.

## Round-1 finding verification

`VERIFIED` means the original failure is fixed in code and a regression test passed. `PARTIAL` means the primary change exists but a material part of the finding or claimed resolution remains false. Garmin reports failed `Test.assert` calls as `ERROR`.

| # | Status | Code evidence | Test evidence and result |
|---:|---|---|---|
| 1 | **VERIFIED** | `ScheduleModel.mc:158-195` preserves `underlyingAction`/deadline while applying the temporary-out overlay; `ReminderPolicy.mc` and `BackgroundRuntime.mc:108-137` evaluate strict `>3h` separately from scheduled reminders. | `temporaryAndScheduleRemindersStayIndependent`, both imported round-1 temporary-reminder tests, and compact-background priority tests: PASS. |
| 2 | **PARTIAL** | `ScheduleModel.mc:426-565` now validates all major document shapes and constrained loaders fail inert. However, `validState` checks `finalInsertionUtc` only as upper bounds (`:443-449`), allows `nextCycleId == active.cycleId` (`:429-450`), and accepts any bounded history `closeReason` (`:536-545`). | Original malformed-reminder/missing-document/chronology tests: PASS. New `adversarialValidationRejectsImpossibleFinalDeadline`, `...DuplicateNextCycleId`, and `...UnknownHistoryReason`: ERROR because all three invalid states were accepted. |
| 3 | **VERIFIED** | `RingTrackerApp.mc:328-345,389-390` captures the just-closed interval; `AlertView` consumes that context; `ScheduleModel.mc:410-423` routes week 1/2, week 3, outside-standard, unknown, and crossed-week cases independently. | `crossedWeekTemporaryGuidanceIncludesEverySection` and the imported outside-standard test: PASS. The close path was also inspected end to end. |
| 4 | **VERIFIED** | `SettingsBridge.mc:12-35` rejects actual insertion after `now + 60s`; `RingTrackerApp.mc:186-205,289-296` rechecks at confirmation/mutation. Pickers perform the same guard. | Imported future-setting test and `insertionEditRejectsFutureChronology`: PASS. New nonexistent-DST ISO test: PASS. |
| 5 | **VERIFIED** | `ScheduleModel.mc:109-117` takes the minimum of scheduled, actual-removal, seven-day ceiling, and override deadlines and persists the result. | Imported override test and `plannedOverrideParticipatesInMinimum`: PASS. |
| 6 | **VERIFIED** | `ScheduleModel.mc:351-400` validates insertion, removal, replacement, and all retained temporary intervals; app/picker entry points recheck before mutation. | Imported chronology test and `insertionEditRejectsFutureChronology`: PASS. |
| 7 | **VERIFIED** | Reminder windows are bounded and `ReminderPolicy.mc:88-90` plus `BackgroundRuntime.mc:146-147` consume day-before when day-of is sent. | Imported no-catch-up test and `dayOfConsumesDayBeforeLedger`: PASS. |
| 8 | **VERIFIED** | Active-cycle compaction folds the oldest eligible closed under-3-hour interval; an uncompactable action displays the storage error. | Imported 33rd-event test and `thirtyThirdTemporaryOutCompactsOldestShort`: PASS. |
| 9 | **PARTIAL** | `ScheduleModel.mc:187-188` distinguishes equality from strict exceedance; `MainView.mc:137-158` has the exact-boundary heading/hint. But `BackgroundRuntime.mc:108-110` emits kind 0 at equality, and `ServiceDelegate.mc:57-60` renders it using `NotificationFree`, “Ring-free interval over 7 days.” After equality, the main screen uses the abbreviated “Ring-free limit passed,” not the required strict-exceedance wording. | `exactSevenDayLimitReachedIsDistinct`: PASS. New exact-notification and strict-exceedance-copy tests: ERROR. |
| 10 | **VERIFIED** | `RingStore.mc:64-99` assigns one revision, stages parity-selected history and constrained mirrors, and writes canonical state last; load repairs revision mismatches. | `revisionedRecordsShareCanonicalCommit`, new interrupted-mirror sequence, and missing-history-chunk recovery tests: PASS. |
| 11 | **VERIFIED** | `RingStore.mc:16,58-87,121-203` enforces a 24 KiB per-value preflight, splits history into two revisioned values, and compacts eligible short intervals before rejection. | Imported maximum-state test, `splitHistoryValuesRemainUnderBudgetAndRoundTrip`, distinct `StorageFullException`, and new 32,000-byte storage/preflight tests: PASS. Note: the preflight is the encoded positional value's `toString().length()`, not an SDK binary-byte measurement, but current encoded data is ASCII-only and the near-limit storage test succeeded. |
| 12 | **PARTIAL** | The new `BackgroundRuntime.mc` and direct `GlanceView.mc` codec remove `ScheduleModel`, `CalendarMath`, `RingStore`, history decoding, and foreground-view construction from their implementation paths. There are no `disableBackgroundCheck` calls; the build checker passes and reported 47 mm data use is 1,946 bytes background / 2,600 bytes glance. However, `RingTrackerApp.mc:9` still scopes the entire foreground-heavy `AppBase` class as `(:background, :glance)`. The release symbol map marks `showSchedule`, `showAbout`, `showMain`, `performConfirmed`, `resolvePendingSettings`, `recomputeDeadlines`, and the other foreground members in both constrained scopes. The requested foreground-orchestration split therefore was not completed, although no concrete foreground view class itself is scope-annotated. | All release targets pass the SDK checker; compact runtime tests pass. Generated-map inspection makes the “move foreground orchestration out of scoped AppBase” part of the claimed resolution false. |
| 13 | **PARTIAL** | `SettingsBridge.mc:152-181` adds a durable pending configuration record, and `RingTrackerApp.mc:92-108` checks both saves. On rejection of an active-cycle duration change, however, `stageMirrors` sees canonical state equal to the old snapshot and stages no repair even though Properties contains the rejected value. The next observation prompts again. | `settingsConfigurationMirrorIsDurablyPending`: PASS for an accepted watch edit/interruption. New `adversarialRejectedDurationChangeStagesCanonicalMirror`: ERROR at the absent pending repair marker. |
| 14 | **VERIFIED** | `Menus.settingsMenu` adds `OutsideLabelBadge` whenever `daysIn > 28`. | Resource/caller inspection and existing settings-menu build coverage: PASS. |
| 15 | **VERIFIED** | `resources/strings/strings.xml:118` exactly says “3-hour limit reached; reinsert now and follow product instructions.” `MainView` uses wrapped rendering for the boundary. | `copyAndFormattingContractsMatchRegimen`: PASS. |
| 16 | **PARTIAL** | `SettingsBridge.mc:101-118` now makes empty insertion invalid with an active cycle and sets `pendingSettingsError`. But acknowledgement through `resolvePendingSettings(false)` clears the error, and `stageMirrors` compares canonical ISO only to `lastSeenInsertionIso` (`:182-186`), which still equals canonical. No `pendingMirrorIso` is staged, so the invalid phone value remains and is observed again. The committed test repairs it only by calling the test/setup helper `mirrorAll`, not the production path. | Marker test: PASS. New `adversarialInvalidInsertionAcknowledgementStagesRepair`: ERROR because Properties stayed invalid and no repair marker was staged. |
| 17 | **VERIFIED** | `ScheduleModel.mc:403-407` requires two numeric values, current cycle ID, and a known kind 0–5. | `notificationLaunchRequiresKnownTypedKind`, stale-cycle, and fractional-kind tests: PASS. |
| 18 | **VERIFIED** | `ServiceDelegate.mc:45-50` explicitly selects replacement-tomorrow/today resources. | `replacementReminderUsesReplacementCopy`: PASS. |

Summary: **13 VERIFIED, 5 PARTIAL, 0 NOT FIXED**. “0 NOT FIXED” does not imply readiness: the partial items include correctness and release-gate failures.

## New and remaining findings, ranked

| Rank | Severity | File:line | Failing scenario | Required fix |
|---:|---|---|---|---|
| 1 | High | `source/ScheduleModel.mc:426-450`, `source/ScheduleModel.mc:536-545` | A persisted removed cycle whose `finalInsertionUtc` is forged one second before removal passes `validState`; background/foreground can then report a false overdue state. Duplicate next IDs and unknown history reasons also pass. | Recompute every derived deadline from canonical event/regimen inputs and require equality (including the actual-removal plan), require `nextCycleId` to exceed every active/history ID, require unique cycle IDs, and whitelist close reasons. Recover on any mismatch. |
| 2 | High / release gate | `source/StaticViews.mc:129-132`, `resources/strings/strings.xml:182-191`; `docs/REGIMEN.md:133-142`, `docs/SPEC.md:738-743` | About contains source families but no last medical-copy review date. No completion record for review against current product labels by a clinician/pharmacist was found. | Complete and record the required qualified review, recheck current label URLs/wording, and display the actual review date in About. Do not invent a date from the software build date. |
| 3 | Medium | `source/SettingsBridge.mc:175-191`, `source/RingTrackerApp.mc:174-229` | Reject or acknowledge an invalid/empty insertion, or cancel an active-cycle duration change. The canonical watch value remains unchanged, but the rejected phone property is not mirrored back and the same review repeats on next observation. | On every rejection/cancel, stage the canonical insertion/config as a durable pending mirror based on the actual Properties divergence, persist it, write Properties, then persist marker clearance. Add interruption tests for this direction too. |
| 4 | Medium | `source/BackgroundRuntime.mc:108-110`, `source/ServiceDelegate.mc:57-60`, `resources/strings/strings.xml:274` | At exactly seven calendar days ring-free, the first notification says “Ring-free interval over 7 days,” contradicting the strict threshold and the required “7-day limit reached.” | Add a distinct equality kind/copy or make service rendering distinguish equality from strict exceedance; retain the strict “over/exceeded” copy only after the boundary. |
| 5 | Medium | `source/RingTrackerApp.mc:160-171,256-274`, `resources/strings/strings.xml:166`; `docs/UI.md:413-422` | Changing `daysIn`/`daysOut` during an active cycle shows a generic acknowledgement. Neither watch nor phone confirmation shows the old and new next-action timestamps, so the user cannot review the schedule consequence required by the UI contract. | Compute the proposed state without mutating canonical state and format both old/new next-action date-times in the confirmation. Apply/mirror only on acceptance. |
| 6 | Medium | `source/MainView.mc:154-158`, `resources/strings/strings.xml:121`; `docs/REGIMEN.md:100-110` | One second after the seven-day ceiling, the main screen says only “Ring-free limit passed,” not the required red “Ring-free interval exceeded 7 days” warning. | Use the reviewed strict-exceedance sentence (wrapped if needed) while retaining overdue elapsed time and access to label caution. |
| 7 | Low / structural | `source/RingTrackerApp.mc:9-410`, release `RingTracker-epix2pro47mm.prg.debug.xml` annotation table | The release checker succeeds, but every foreground orchestration member on `RingTrackerApp` is still tagged for both constrained personalities, so the requested absence of foreground reachability cannot be established structurally. | Keep only minimal personality factories in the scoped AppBase or delegate them to a tiny scoped bridge; move foreground state, UI construction, settings workflow, and mutations to an unscoped controller. Re-inspect generated annotations and memory afterward. |

## Adversarial tests added and run

The repository was kept read-only. I copied the worktree to `/tmp/review2-adversarial`, added `source/tests/Round2AdversarialTests.mc` there, and added one test-only wrapper for private deadline recomputation. No test source was copied into the repository.

| Test | Result | Scenario |
|---|---|---|
| `adversarialOlderSchemaMigratesAndPersists` | PASS | Loads schema v1, migrates active/temp data, and persists schema v2. |
| `adversarialInterruptedMirrorSequenceKeepsCanonical` | PASS | Simulates newer staged mirrors without canonical commit; canonical revision remains authoritative and mirrors repair. |
| `adversarialMissingHistoryChunkRecoversInsteadOfMixingRevisions` | PASS | A nil history chunk during load causes bounded recovery/reset rather than revision mixing. |
| `adversarialInsertion2359AcrossDstKeepsWallIntent` | PASS | 23:59 local insertion retains 23:59 after the spring DST shift in the same cycle week. |
| `adversarialDaysInChangeReclassifiesDay25BothWays` | PASS | Day 25 moves overdue → ring-in when 21 becomes 35, and back to overdue when restored. |
| `adversarialTemporaryOutSurvivesRebootAndClosesOver3h` | PASS | An open interval survives store/load and closes after 3h00m01s as over-three-hours. |
| `adversarialNotificationStaleCycleIsRejected` | PASS | Current kind with stale cycle ID is rejected. |
| `adversarialSettingsIsoRejectsDstNonexistentTime` | PASS | `2026-03-08T02:30` in New York is rejected, not normalized. |
| `adversarialStorageValueNear32KiBAndPreflight` | PASS | Simulator round-trips a 32,000-character Storage value; RingStore's 24 KiB preflight rejects it. |
| `adversarialFractionalNotificationKindIsRejected` | PASS | Kind `2.5` is rejected. |
| `adversarialValidationRejectsImpossibleFinalDeadline` | **ERROR** | Validator accepted a final deadline before removal. |
| `adversarialValidationRejectsDuplicateNextCycleId` | **ERROR** | Validator accepted the next ID equal to the active ID. |
| `adversarialValidationRejectsUnknownHistoryReason` | **ERROR** | Validator accepted an unknown close-reason enum. |
| `adversarialInvalidInsertionAcknowledgementStagesRepair` | **ERROR** | Production staging did not repair the invalid insertion property. |
| `adversarialRejectedDurationChangeStagesCanonicalMirror` | **ERROR** | Cancel/rejection did not stage canonical duration values back to Properties. |
| `adversarialExactRingFreeNotificationDoesNotSayOver` | **ERROR** | Equality notification selected the strict-over copy. |
| `adversarialAboutIncludesMedicalCopyReviewDate` | **ERROR** | About source text contains no review date. |
| `adversarialExceededRingFreeMainCopyMatchesContract` | **ERROR** | Strict-exceedance main copy did not match `REGIMEN.md`. |

The combined adversarial run contained 86 tests: **78 passed, 0 failed, 8 errors**. One failing test initially lacked the active-cycle precondition needed to enter duration review; after correcting that test fixture, I reran it alone and it still errored at the intended missing-repair assertion. This correction did not change the pass/error classification.

The committed, unmodified suite was run first from `/tmp/review2-wt` with `./scripts/build.sh test`: **68 passed, 0 failed, 0 errors**.

For UI/scoping items that cannot be introspected reliably through Monkey C's unit runner, four fail-before static/artifact assertions were also run and passed: the just-closed interval is passed to `showTemporaryAlert`; Settings references `OutsideLabelBadge`; the exact-three-hour resource contains the complete required action; and the final release map/PRG contains no demo, test, or debug-clock source/string signature. These supplement, rather than replace, the runtime tests above.

## Regression and release-artifact review

- `./scripts/build.sh release` completed without warnings for `epix2pro42mm`, `epix2pro47mm`, and `epix2pro51mm`, and produced the IQ package. The three PRGs were byte-identical at 98,156 bytes.
- The 47 mm release build reported data use of 10,658 bytes foreground, 1,946 background, and 2,600 glance; code use was 59,880, 9,868, and 11,925 bytes respectively. This is comfortably below the specified constrained-process targets at build time, though a physical-device peak test is still required.
- `monkey.jungle:6` excludes `debug;test;testhelper`. Compiler intermediate `.mir` files retain all parsed annotated sources, so they are not proof of shipped contents. The final release PRG debug map contains no `DemoScenarios.mc`, `source/tests`, or debug clock override source mapping, and `strings` over the final PRG finds no demo/test/debug clock names or copy. `Clock.mc` maps only the production `currentUtc` implementation. No demo/test/clock-override code was found in the shipped PRG.
- The same final map does expose the whole-class `RingTrackerApp` annotation problem described in finding 12. Concrete foreground view classes have zero background/glance annotation entries, but foreground controller members do not.
- Revision/parity recovery, nil/mismatched history handling, compact mirror validation, bounded storage values, temporary reminder independence, day-of ledger consumption, earlier-deadline-wins, DST insertion rejection, and the 21↔35-day status transition were inspected and exercised.

## User-visible copy check

All production and debug resource strings and their changed callers were checked against `REGIMEN.md`, including About.

| Copy family | Result |
|---|---|
| Mandatory disclaimer | PASS — the three About/setup fragments concatenate exactly to the required disclaimer. |
| Supported scope / Annovera | PASS — NuvaRing/equivalent etonogestrel/EE generic scope and explicit Annovera exclusion are present. |
| Non-default and 29–35-day plans | PASS — clinician/product-plan acknowledgement and persistent outside-FDA-label Settings badge are present. |
| Beyond four weeks | PASS — strict post-boundary main/alert copy identifies the FDA-labelled four-week duration. |
| Temporary-out under, exactly, and over three hours | PASS — equality has the required urgent sentence; week 1/2, week 3, outside-standard, and unknown/crossed-week guidance avoid efficacy claims and do not choose an option. |
| Ring-free equality and strict exceedance | **FAIL** — foreground equality is correct, but its background notification says “over”; strict-exceedance main copy is abbreviated and does not use the required warning sentence. Alert detail copy is correct. |
| Reminder delivery limitation / privacy | PASS — both are present in About and align with the contract. |
| Prohibited efficacy claims | PASS — no user-visible “safe,” “protected,” or “not protected” claim was found. |
| About sources and review metadata | **FAIL** — all six source families are represented, but the last medical-copy review date is absent and qualified review completion is undocumented. |
| Active-cycle regimen confirmation | **FAIL** — required old/new next-action timestamps are absent. |

## Simulator smoke

`./scripts/build.sh debug` built all three targets successfully; the committed 47 mm debug PRG launched in the headless epix Pro 47 mm simulator without an exception and rendered the initial-insertion and main states. Native key/click automation opened the main menu and Settings/time-picker paths without a crash. `monkeydo --help` exposes app loading and test selection only; it has no key-input or scenario-selection interface. GUI-coordinate automation is possible but was not reliable enough to certify every nested native `Menu2` action: selection events could propagate into the newly pushed view. A complete deterministic pass through all Demo seeds and every main-menu mutation was therefore not achieved in this review. This is a test limitation, not a pass; the pre-existing demo screenshots and unit tests are not substitutes for the physical-watch release gate.

Before release, rerun every Demo scenario and every mutation on the physical 47 mm target, including confirmation cancellation, background wake/notification selection, settings round-trip, reboot while temporary-out is open, and maximum-history state.
