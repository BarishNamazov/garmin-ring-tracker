# Ring Tracker v1.1.0 — final independent verification

Reviewed detached commit `916b41b74fd06163aea301a0ddee678be52c1144` in `/tmp/review3-wt`, created from `HEAD` with `git worktree add --detach /tmp/review3-wt HEAD`. The concurrent main worktree was not used for source, builds, or tests. Review date: 2026-09-15. Toolchain: Connect IQ SDK 9.2.0; functional, DST, memory, glance, and background checks used the epix Pro (Gen 2) 47 mm simulator in `America/New_York`.

No product source was changed. `source/tests/Review3Tests.mc` exists only in the detached review worktree and is not part of the release personality.

## Verdict

**DO NOT SHIP.** A real temporal background wake crashes before displaying any selected reminder because the background resource table does not contain `TimeSeparator`. The same path exits by runtime error rather than the required single `Background.exit`. Independently, a second temporary-out interval in the same cycle does not receive its first strict-`>3h` warning because the ledger slot from the previous interval is reused. Both defects can directly deprive the owner of a reminder on the watch.

The anchoring model, strict threshold calculations, two configured day-of slots at the policy layer, real v1.0 migration, settings reconciliation, copy audit, release PRGs, and memory limits are otherwise in good shape. Those passes do not compensate for a nonfunctional background notification path.

## Findings, ranked

| Rank | Severity | File:line | Failing scenario | Required fix |
|---:|---|---|---|---|
| 1 | **Critical** | `source/ServiceDelegate.mc:18-42,45-90`; `resources/strings/strings.xml:35-36,103-105,130,231-250` | On a real simulator temporal event with an eligible reminder, `notificationIds()` initializes its subtitle through `timeFor()` before branching on notification kind. The background process raises `Symbol Not Found Error: TimeSeparator` at line 89. Generated `BackgroundRez.Strings` contains the notification-specific strings but not `TimeSeparator`, `Am`, `Pm`, `DayUnit`, `HourUnit`, or `MinuteUnit`. Because line 49 is unconditional, every selected reminder kind reaches `timeFor`; the process crashes before `Notifications.showNotification`, ledger persistence, or line 42's `Background.exit`. The no-op path does exit normally. | Add background-scoped formatting resources (prefer separate `BackgroundTimeSeparator`, AM/PM, and unit IDs) or remove those resource lookups from the constrained process. Do not compute a due-time subtitle for warning kinds that replace it. Then run actual temporal events for all seven notification kinds, a no-op, nil/corrupt storage, and an injected notification exception, asserting one notification/ledger update where applicable and exactly one `Background.exit` on every path. |
| 2 | **High** | `source/ReminderPolicy.mc:31-47`; `source/BackgroundRuntime.mc:103-118`; `source/ScheduleModel.mc:226-237` | In one cycle, let temporary-out interval A cross 3h00m01s and mark slot 0 sent, close A, then start interval B. At B +3h00m01s, the candidate is also slot 0 and is suppressed by A's `lastTempOutSlot`. With the default six-hour repeat, B gets no warning until just after nine hours out. `review3SecondTemporaryOutGetsItsOwnFirstWarning` errors at the missing second candidate. The compact background evaluator has the same defect. | Make the temporary ledger interval-specific, for example by persisting the current open interval's `outUtc`/identity beside `lastTempOutSlot` and resetting the slot when that identity changes. Apply the identical rule in foreground and compact background codecs, migration, validation, and merge logic. Add close/reopen, reboot, and multiple-interval parity tests. |
| 3 | **Medium / contract conflict** | `source/ScheduleModel.mc:425-444`; `source/UpcomingView.mc:26-31`; `docs/SPEC-1.1.md:602-632` | With insertion at 2026-06-01 09:00 and no recorded removal, open Upcoming on 2026-07-20. Row 2 begins on 2026-06-29 and later rows can also be in the past while labeled `Upcoming`. `review3UpcomingFutureRowsAreNotPast` errors. The implementation follows SPEC-1.1 line 632's instruction to continue the current overdue anchor and the exact-six-row rule, but that is incompatible with this review's explicit requirement that an upcoming list never show a past date. | Resolve the contract conflict explicitly. The safer UI is to retain the actual current row, suppress non-actual rows whose insertion is already past, and tell the owner to record the current event before future dates can be projected. Do not silently fabricate missed insertions merely to move six rows into the future. Update the six-row requirement and tests with the chosen behavior. |
| 4 | **Low** | `source/CalendarMath.mc:101-171` | In New York on 2027-03-14, direct resolution of nonexistent 02:30, a 21-day removal recurrence landing there, and a 28-day label recurrence landing there all resolve to **03:01**, not the required first valid minute 03:00. Existing 01:30 cases and the fall fold pass. This makes the edge-case due instant one minute late. | Locate the transition boundary independently of the hourly sample phase and validate the returned wall minute against the first representable minute. Keep an exact `03:00` regression for direct wall conversion and 21/28-day recurrence paths on this transition. Verify the result on the target firmware as well as SDK 9.2.0. |
| 5 | **Low / release gate** | `scripts/build.sh:23-34`; `release/RingTracker.iq` | Fresh worktree PRGs match `release/` byte-for-byte, but fresh `bin/release/RingTracker.iq` does not: SHA-256 `ad46267872d21c3500af5f733bdfd365dbad3d554e1fa34e781a56453badffeb` versus checked-in `8e23e963aad6d0f31104d1ae6102f6d4dbb6afb3a2b5fd9b1db3600fed9782f0`. Extraction shows that only the five `debug.xml` files differ; they embed the worktree source path and a random `/tmp/export...` directory. All five internal PRGs and every other extracted file are identical. This is not a runtime payload difference, but it fails the requested byte-for-byte release check. | Make Store export reproducible by normalizing/stripping debug-map paths and deterministic archive metadata if supported, or define and enforce a canonical post-export normalization step. Regenerate `release/RingTracker.iq` and `SHA256SUMS` from that reproducible output. |

## Tests added and results

The untouched worktree first passed its committed suite with `./scripts/build.sh test`: **105 passed, 0 failed, 0 errors**.

I added eight review-only tests in `/tmp/review3-wt/source/tests/Review3Tests.mc`. The final combined run compiled successfully and ran 113 tests: **110 passed, 0 failed, 3 errors**. All 105 committed tests remained green; five new tests passed and three intentionally exposed the findings above.

| Review test | Result | Coverage |
|---|---|---|
| `review3DstExistingWallMatrixNewYork` | PASS | Spring 2027 01:30 on the transition day and 21/28 days before it; fall 2026 01:30 and 02:30 on the fold day and 21/28 days before it. Existing wall times retain local date/time and fall ambiguity follows the earlier/closest rule. |
| `review3SpringGapUsesFirstValidMinute` | **ERROR** | Direct spring-day 02:30 plus 21/28-day recurrences. Printed `DIRECT=3:1, REMOVE=3:1, LABEL=3:1`; expected 03:00. |
| `review3LeapMidnightAndTravelAuthority` | PASS | A 2028-02-08 00:00 insertion produces 2028-02-29 00:00; status changes at the exact second. Rendering the instant in current-local form does not mutate the persisted authoritative UTC deadline. |
| `review3SecondTemporaryOutGetsItsOwnFirstWarning` | **ERROR** | Two separate temporary-out intervals in one cycle; the second interval's initial strict-`>3h` warning is suppressed. |
| `review3ReminderTimesDoNotRefireAndInsertionGetsBoth` | PASS | Ring-free insertion gets configured Reminder 1 and Reminder 2; changing a sent slot's time mid-day does not re-fire it, and both consumed slots transition to overdue rather than duplicating. |
| `review3RealV10RingInOpenTempAndTwentyFourHistoryMigrates` | PASS | Exact positional v1.0 codec, active ring-in cycle, open temporary-out, 24 split-history cycles, reminder/settings data, and a planned override. Migration preserves all non-obsolete data, maps the old day-of flag to both v1.1 slots, drops the override, and persists the new schema. |
| `review3RealV10LateRemovalDropsMinimumAndOverride` | PASS | Exact v1.0 active ring-free document with late removal and an earlier planned override. Migration recomputes insertion due from actual removal + seven local days, drops the old minimum/override behavior, and preserves the early/late delta. |
| `review3UpcomingFutureRowsAreNotPast` | **ERROR** | Long-overdue current anchor yields a past insertion date in a non-current Upcoming row. |

Garmin's runner reports failed `Test.assert` calls as `ERROR`, hence zero tests are listed as `failed`.

### Anchoring and calendar disposition

- Actual insertion → `removeDueUtc` and actual removal → `insertDueUtc`, early/on-time/late deltas, edit dependency rules, strict `>3h`, strict `>7 local days`, strict `>28 local days`, `daysOut == 0`, and local midnight boundaries all pass the committed tests.
- The new leap-day, exact-midnight, persisted-UTC/travel-authority, existing spring wall-time, and fall-fold matrices pass.
- The exact first-valid-minute spring-gap case fails as finding 4.

### Reminder/ledger and background disposition

At the pure policy and compact-evaluator level, both day-of slots, Reminder 2 disabled, equal configured times, day-before at Reminder 1's time, overdue repetition, stale/missed-slot consumption without a burst, reboot persistence, and foreground/background candidate parity pass. The added mid-day time-change and insertion-day test also passes.

That policy correctness is not delivered to the owner because the live background process crashes as finding 1. Static inspection finds exactly one lexical `Background.exit(null)` at `ServiceDelegate.mc:42`; live no-op evaluation reaches it, but a selected-reminder resource error does not. The `try/catch` shape would route ordinary caught storage/notification exceptions to the exit, but the observed missing-symbol runtime error bypasses that path. A successful notification path cannot be certified until the resource defect is fixed.

## Migration and settings bridge

The fixture was derived from `git show 87bf813:source/RingStore.mc` and the matching v1.0 model code rather than an invented dictionary. That source calls its persisted format numeric schema `2`; current v1.1 persists numeric schema `3` (the product-level request describes the release migration as schema 1 → 2). Both real legacy documents migrate and validate as described in the test table.

Settings reconciliation passes inspection and simulator tests:

- the property/config order includes `reminder2Enabled`, `reminder2Hour`, `reminder2Minute`, and `dayBeforeEnabled` consistently in `properties.xml`, `settings.xml`, `configFromState`, `configFromProperties`, `applyConfig`, and durable mirror completion;
- malformed, impossible, nonexistent-DST, and future insertion ISO values are rejected;
- an invalid or rejected phone value stages the canonical watch value and mirrors it back durably, including an interrupted two-save sequence;
- accepted watch and phone reminder values survive codec/migration round trips.

No settings-bridge finding remains.

## Upcoming projection

Committed tests pass six-row projection from the current actual anchor, regeneration after insertion/removal/edit/duration changes, local calendar boundaries, scroll limits, and `daysOut == 0`. The new long-overdue case fails the explicit no-past-date acceptance criterion, with the specification conflict noted in finding 3.

## Shipped-copy audit

Production resource values and callers were searched for `recorded`, `scheduled`, `plan`, `deadline`, `FDA-labelled`, `label-directed`, `product instructions`, `tracking`, `schedule aid`, `generics`, `EluRyng`, and `Annovera`.

- No forbidden ordinary-UI value remains. Matches such as `NotificationScheduled`, `NotRecorded`, and internal `deadline` variables are identifiers/source implementation, not shipped copy.
- `Schedule aid, not medical advice.` occurs only in the required shared first-run/About line.
- `Not for generics or Annovera.` is the only shipped generic/EluRyng/Annovera mention and has one About caller.
- Main contains neither `tracking` nor `schedule aid` and does not name a product.

Copy audit: **PASS**.

## Simulator memory

I instrumented the review worktree temporarily, opened Upcoming with 24 retained cycles and the maximum temporary-interval fixture, persisted its reduced constrained mirrors, sampled `System.getSystemStats()`, and removed the instrumentation before the final builds/tests.

| Personality and fixture | Peak/live used | Simulator heap | Contract budget | Result |
|---|---:|---:|---:|---|
| Foreground, 24-cycle history + Upcoming open | 134,784 B (131.6 KiB) | 781,888 B (763.6 KiB) | <500 KiB | PASS |
| Glance, maximum reduced active mirror | 20,288 B (19.8 KiB) | 61,256 B (59.8 KiB) | <40 KiB | PASS |
| Background no-op, maximum reduced active mirror | 14,840 B (14.5 KiB) | 61,256 B (59.8 KiB) | <40 KiB | PASS |

The selected-notification background peak cannot be validly measured because it crashes before the reporting point. The no-op constrained peak is comfortably within budget; rerun the selected path after fixing finding 1.

## Release artifacts

`./scripts/build.sh release` completed successfully for 42, 47, and 51 mm and exported the Store package.

- All three fresh PRGs are 107,516 bytes, are identical to one another, and match their checked-in `release/` counterparts byte-for-byte at SHA-256 `6d2a44d5dd4b4d47c2914a5a5c89ddd11330a05527ce42f78258ef669e69ac6f`.
- `(cd release && sha256sum -c SHA256SUMS)` verifies all four checked-in artifacts.
- `strings` and generated-map scans of every release PRG find no `DemoScenarios`, `debugNowUtc`, maximum-demo fixture, `source/tests`, review-test, or test-wall symbol/copy.
- The Store IQ mismatch is limited to path-bearing `debug.xml` files as described in finding 5. Its executable payload is identical, but the requested whole-file byte comparison fails.

## Ship decision

Do not install this release as the owner's relied-on reminder build. Fix findings 1 and 2, resolve the Upcoming contract conflict, add the exact spring-gap regression, make or explicitly redefine the IQ reproducibility gate, and rerun the real temporal-event matrix plus the full 113-test review suite. Findings 1 and 2 are the minimum blockers for a personal-use ship decision.
