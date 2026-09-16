# Changelog

All notable changes to Ring Tracker are documented in this file.

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
