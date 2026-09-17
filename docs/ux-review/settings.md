# Settings (native menu)

## P1
1. **Toggles and sub-menus indistinguishable** ("Off/On" as text). Fix: every binary → native ToggleMenuItem (Day before, Vibration, Sound, Reminder 2 enable); label+value rows only for pickers/sub-menus.
2. **Reminder 2 sub-menu one level too deep, says "Reminder 2" three times.** Fix: flatten — `Reminder 2` toggle row; `Reminder 2 time / 8:00 PM` directly beneath, shown only while on.
3. **`Clock` row redundant with jargon options.** Preferred: delete; use the watch's 12/24 h setting. If kept: `Time format` — `Same as watch`, `12-hour (9:00 PM)`, `24-hour (21:00)`, last in list.

## P2
4. Pickers don't show current selection → setFocus to current on open + sublabel `Selected`.
5. "Overdue repeat" → `Repeat if missed`; options `Every hour`, `Every 3 hours`, `Every 6 hours`, `Off`.
6. `Day-before reminder` too long (bezel on 416, truncates on 390) → `Day before`; labels <~14 chars.
7. `Days ring in/out` → two rows `Ring in / 21 days`, `Ring out / 7 days`.

## P3
8. Proposed order: Reminder 1 · Reminder 2 (toggle) · Reminder 2 time (when on) · Day before · Repeat if missed · Ring in · Ring out · Vibration · Sound.
9. Sub-menu/picker titles restate the value (`Reminder 2 time`).
10. Keep: `9:00 AM` formatting; Reminder 2 collapsing to `Off`.

**Verdict:** 80% there; flatten Reminder 2, native toggles, cut Clock, rename Overdue repeat.
