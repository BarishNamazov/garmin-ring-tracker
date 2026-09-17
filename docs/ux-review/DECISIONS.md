# UX review — coordinator decisions for v1.3.0

Fifteen independent per-screen reviews (files in this folder) were consolidated into four workstreams. Decisions below resolve conflicts between reviewers and the owner's product preferences (terse NuvaRing-only copy, no useless words, disclaimer only on first run/About).

## Global rules (all workstreams)
- One hero per screen. Phase colour lives on the header word and the arc/bar; the hero number is white. Secondary lines grey (~70%); tertiary (~55%).
- Countdown precision is tiered and single-unit: ≥48 h → `17d`; 24–48 h → `1d 12h`; <24 h → `14h`; <1 h → `45m`. Never render a zero component. Units ≈40% of digit cap-height, same weight family as digits, 6–8 px gap; centre the composite on measured ink bounds.
- Arc: elapsed portion at ~40–45% luminance, remaining full; marker 1.4–1.5× stroke with 2 px black halo, scaled with radius; stroke ≈3.5% of width; outer radius 0.485 × width on all sizes; 2 px gap at segment seams. Purple lifted to ≈#A690FF.
- Date/time line: verb as grey prefix, date white, time on the same line when it fits (51/47) else beneath; width budget 70% of the chord; degrade: drop weekday → drop prefix → step font down. Never within 24 px of the arc at 390 px.
- Safety copy stays short and hedged: `Backup advised · 7 days`. No trailing periods on display lines. Disclaimer wording appears only on first run and About.
- Vocabulary (menus, confirmations, notifications): `Remove ring`, `Insert ring`, `Replace ring`, `Ring out briefly`, `Put ring back`. Past-tense for records: `Inserted`, `Removed`.
- Every visible string fits unclipped on 390/416/454 with the longest real value; stress fixtures must genuinely exercise wrap/overflow.
- Version 1.3.0.

## Workstream A — Main screen (MainView.mc, UiUtils arc helpers, strings)
Reviews: main-ring-in, main-ring-free, main-overdue, temporary-out, main-warnings, main-long-values.
- Ring in / ring free: apply global rules; header (`RING IN` / `RING FREE`) in phase colour, medium weight, +1 px tracking, one step smaller; hero white; ring-free segment rendered as a dim track (hollow look) with purple only where the ring-free week is current/future.
- Overdue: header verb in amber (`REMOVE NOW` / `INSERT NOW`), ~20% larger, directly above the white magnitude (`29h late` up to 48 h, then `2d late`); one grey due line `Was due Sun 13 Sep · 5:26 PM`; arc becomes a lateness meter: dim full track + amber sweep from 12 o'clock scaled to the grace window (7 days for insert, 7 days for remove); never >95% in non-overdue states. Content block optically centred.
- Temporary out: fixed positions in both states; hero elapsed in white; inner 3 h progress ring in amber turning red at 3:00; second line `10m left` / `10m over`; over-limit body: `Reinsert now` bold white + `Backup advised · 7 days`; cycle arc dimmed to ~25% with marker hidden; `Out since 12:30` small grey.
- Serious states: ring-free >7 d and ring-in >28 d own the frame in red (full red arc, red header `INSERT NOW` / `REPLACE NOW`, white hero of the exceeded value e.g. `29d in`, grey `Was due …` line, single warning line `Backup advised · 7 days`). No countdown in these states.
- Vertical rhythm: equal inter-block gaps, block centre ~4 px above centre; padding scales with radius.

## Workstream B — Lists (UpcomingView.mc, HistoryView.mc, cycle detail in StaticViews.mc, strings)
Reviews: upcoming, history.
- Upcoming: title; one small-caps header row `IN  OUT`; rows = eyebrow (`NOW`, `NEXT`, then none) + In date bold white + Out date grey, right-aligned to two fixed column x; no per-row bars; one bar with today tick on the current row only; overdue state on row 1 in amber (`3d overdue`); a single `— if removed today —` divider when projections assume the overdue action happens now; native scroll indicator on all sizes; row 4 peeks above the bottom chord. Year cue on the first January date.
- History: primary = date range white (`8 Sep → 29 Sep`, current shows planned removal in grey); secondary = `Cycle 25 · Current` grey/green; variance one line scoped to the row's own events (`Out 15d early · In 6d late`), amber ≤3 d, red >7 d; remove the left tick and the decorative bar (or make it a real to-scale bar with a planned-removal tick); one left edge; symmetric row padding.
- Cycle detail: label-left/value-right, one left and one right edge; never a bare `—` (show `due Tue 29 Sep` / omit); variance and planned dates shown; `First recorded` caption under the title (not as a value); `Removals` lifetime stat moved out of the per-cycle table or labelled `Removals (all)`.

## Workstream C — Menus, confirmations, edit dates, settings, text screens (Menus.mc, StaticViews.mc, controller, Pickers.mc, strings, settings.xml/properties.xml)
Reviews: menus, confirmations, edit-dates, settings, text-screens.
- Menus (state-bearing title, e.g. `Ring in · day 12`): Ring in: Remove ring (sub `Start ring-free week`) · Ring out briefly (sub `Back in within 3 h`) · Edit insertion time · History. Ring free: Insert ring · Edit removal time · History. Temporarily out: Put ring back · Keep out, start ring-free week · Undo ring out. No cycle: Insert ring now · Ring already in… (date/time picker) · Settings. Settings and About reachable from every state (last items). Early insertion in ring-free gets a guard confirmation (`Day 3 of 7 — insert early?`).
- Confirmations: line 1 = action (`Remove ring now?`), line 2 = schedule fact (`Due in 2 days` / `Due 5 hours ago`); edits: `Change removal to` / `Thu 11 Sep · 12:26 PM`. Spelled-out units; <24 h hours, ≥24 h floor-days.
- Edit dates: title `Correct dates`; rows `Inserted` / `Tue 8 Sep · 10:15 PM`, `Removed` / value or `Not yet — due Tue 29 Sep` (non-editable until a removal exists); initial focus on the most recent event; no clipping of the last row.
- Settings: Reminder 1 · Reminder 2 (native toggle) · Reminder 2 time (only when on) · Day before (toggle) · Repeat if missed (`Every hour/3 hours/6 hours/Off`) · Ring in `21 days` · Ring out `7 days` · Vibration (toggle) · Sound (toggle). Delete the Clock/time-format setting on watch and phone; always follow the watch's 12/24 h setting (migrate old property silently). Pickers open focused on the current value with a `Selected` sublabel.
- Text screens: one action slot (bottom, accent colour, regular weight) on all four; first run: **Ring Tracker** / *Reminders for your ring schedule only. Not medical advice, and no measure of contraceptive protection.* / **I understand**; About: title, muted `Ring Tracker 1.3.0`, one-line disclaimer, full text below the fold, `Not for generics or Annovera.`; Regimen: title `Regimen`, subtitle `NuvaRing`, rows `In · 21 days` / `Out · 7 days`, no Confirm; Migration: **Dates updated** / body / **OK**, centred. Body regular weight, bold titles only; rail only on overflow, ≥4 px thumb.

## Workstream D — Glance and notifications (GlanceView.mc, ServiceDelegate.mc, BackgroundRuntime.mc, background-scoped strings, notification icon)
Reviews: glance, notifications.
- Glance: icon (single-colour ring carrying state: green / purple / orange / hollow for ring-out, ~8–9% of width) vertically centred on a two-row text block: title in FONT_GLANCE neutral (`Remove in`, `Insert in`, `Remove overdue`, `Ring out`), value in FONT_GLANCE_NUMBER bold (`17 days`, `2 h 50 min left`, `1 day`); bar 4–5 px rounded, filled 8–9 px white marker with dark outline, spanning the text column, present in every state (dimmed with hollow marker while ring-out); overdue = orange icon/title/value, marker pinned right with an orange overflow tail. Keep glance <45 KiB.
- Notifications: titles ≤15 chars, verb-first, no numbers; body = fact + optional secondary instruction; four verbs; the two day-of reminders differ (`Remove ring` / `Still in — remove`); overdue card has an instruction; ring-in >28 d card shows red days-over, no countdown; `Backup advised`; icon a closed single-colour ring with dot. Use the replacement table in notifications.md (and Insert-side equivalents). Keep background <45 KiB; the background string-scope guard must pass.

## Integration
Workstreams run in separate git worktrees on branches `ux/a-main`, `ux/b-lists`, `ux/c-menus-settings`, `ux/d-glance-notifications`, then are merged into `main` by an integration pass that resolves conflicts (strings.xml is shared), bumps to 1.3.0, reruns all tests, regenerates every screenshot, refreshes release/ and docs, and re-runs the per-screen review loop.
