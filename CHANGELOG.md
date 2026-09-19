# Changelog

All notable changes to Ring Tracker are documented in this file.

## [1.3.1] - 2026-09-19

### Fixed

- Prevented History selection backgrounds from clipping the title or nearby
  rows, and improved Upcoming heading spacing and round-screen date visibility.
- Corrected UP/DOWN directions in time, date, and number pickers; made arrow
  taps change values without advancing or saving the selection.
- Fixed touch routing for history rows, picker columns, and confirmation
  buttons, with scaled targets that ignore taps on headings and empty space.
- Kept paragraphs clear of scrollbars and round-screen edges, added the missing
  migration scroll indicator, and hardened text wrapping for narrow layouts.
- Preserved the edited setting's position after saving or leaving repeat
  settings, and corrected custom-schedule labels and immediate-replacement
  menu actions.
- Corrected sub-hour confirmation wording, glance minute-to-hour rounding,
  exact due-time display, and progress bars for long-overdue cycles.
- Refreshed the main countdown every minute while the app is open so day and
  due-time boundaries do not leave stale values visible.

### Verification

- Added 13 regression tests; all 180 tests pass on each of the three supported
  watch sizes.
- Checked layouts and button/touch behavior in the 42, 47, and 51 mm simulators.

## [1.3.0] - 2026-09-18

### Added

- See the next action at a glance with a clearer main-screen hierarchy,
  tiered countdowns, late/overdue states, and a three-hour ring-out timer.
- Review six upcoming cycles in fixed date columns and browse a cleaner History
  with per-cycle timing details.
- Correct recorded insertion and removal dates with alarm-style time pickers and
  a day/month/year date picker.
- Set insertion date and time from the phone, with existing watch values kept
  safe during migration from earlier versions.

### Changed

- Redesigned Upcoming, History, glance, menus, confirmations, and notifications
  for faster scanning and shorter wording.
- Flattened on-watch Settings with direct toggles for Reminder 2, Day before,
  Vibration, and Sound; time display now always follows the watch setting.
- Made confirmation wording clearer and renamed date editing to **Correct
  dates**.
- Improved phone App Settings with grouped controls, native insertion-date
  input, and 15-minute time lists while retaining exact watch minutes.

### Fixed

- Kept the action time visible on ring-free screens, separated wrapped clock
  warnings, and prevented orphaned separators in warning lines.
- Standardized lateness across Main, Upcoming, glance, alerts, and reminders:
  hours below 48 hours, then whole days.
- Centered every picker column on all three watch sizes and made pending
  removal dates read-only with a clear explanation.
- Improved round-screen list spacing, year-rollover cues, current-cycle marks,
  and the temporary-out reinsertion deadline.
- Restored normal debug startup after screenshot capture and repaired the
  extended-wear notification preview.

### Removed

- Removed the separate Clock option from watch and phone settings.

## [1.1.0] - 2026-09-15

### Added

- Reminder 1, optional Reminder 2, and an optional day-before reminder with
  independent delivery ledger entries.
- A read-only Upcoming screen with six projected cycles and colour-coded
  ring-in/ring-free bars.
- Early/late event variance in confirmations and History, plus one-time
  migration review for existing dates.
- Regression coverage for second-round review findings, v1/v2 migration,
  actual-event anchors, reminder slots, and reduced constrained codecs.
- Review 3 regression coverage for real v1.0 fixtures, DST transition matrices,
  interval-specific temporary-out reminders, and overdue projections.

### Changed

- Anchored every removal deadline to the actual insertion and every insertion
  deadline to the actual removal.
- Simplified Main and mapped UP to Upcoming, DOWN to History, and START/tap or
  long MENU to context actions.
- Reworked all visible copy for terse NuvaRing-only wording; the product-scope
  limitation appears only on About.
- Expanded phone and on-watch settings for both reminder times and day-before
  control, including durable watch-wins repair after rejected remote changes.
- Hardened persisted-state validation for derived deadlines, IDs, and close
  reasons, and moved foreground orchestration out of constrained annotations.
- Scoped every background notification resource, added live temporal-event
  diagnostics, and guarded the service's single-exit contract.
- Made temporary-out reminder slots specific to each open interval, resolved
  nonexistent spring-forward times to the exact first valid minute, and kept
  overdue Upcoming projections non-past with an `if done today` note.
- Added reproducible SHA-256 reporting for every executable PRG embedded in the
  Store `.iq` archive.

### Removed

- Schedule detail, the planned-action override picker, and planned timestamps
  from Edit dates.
- Obsolete v1.0 screenshots and generic day-to-day product wording.

## [1.0.0] - 2026-09-15

### Added

- Ring-in, ring-free, overdue, and temporary-out tracking for the default 21-days-in/7-days-out schedule.
- Confirmed insertion, removal, replacement, and temporary-out events; editable dates; and history for up to 24 cycles.
- Main status, schedule detail, glance, alert detail, on-watch settings, and button/touch navigation for all three epix Pro (Gen 2) sizes.
- Hourly background evaluation with native notifications for upcoming, due, overdue, temporary-out, seven-day ring-free, and extended-duration conditions.
- Clinician-directed configuration for 21–35 days in and 0–7 days out, with acknowledgement and FDA-labelled-duration notices.
- Store-backed App Settings bridge, debug-only clock and demo scenarios, signed release builds, and automated simulator tests.
