# Round 2 decisions (v1.3.0 final polish)

All eight round-2 review files in this folder apply. Where reviewers conflict with each other or with the round-1 DECISIONS.md, these rulings win:

- **Lateness formatter, everywhere** (main, glance, notifications, alert detail, Upcoming): `29h late` under 48 h, `2d late` from 48 h. Never "over"; never mix units across screens. Glance overdue value `29h` / `2d` with title `Remove overdue` / `Insert overdue`.
- **Serious red states** keep `Nd late` as the hero magnitude; the total goes in the secondary line (`Ring-free 8 d · was due Wed 16 Sep`, `Worn 29 d · was due …`). Magnitude row at a fixed y across amber and red.
- **Backup line**: on the main screen and alert detail `Use backup 7 days` in white (directive; no dot). In notifications `Backup advised` (short, discreet).
- **Under 24 h** date line is one line: `Remove · Today 2:26 AM` / `Remove · Tomorrow 12:26 AM`.
- **Validity error** ("watch time before insertion") replaces the schedule line, amber, `Check insertion date` / `Watch time is before insertion`.
- **Arc**: one stroke width for both phases in every state (current phase full, other phase ~60%); marker radius ≤ half stroke + 1 px; hero group (digits + unit) centred as one; hero one font tier up on 454; over-run tail in amber with a 2 px black gap.
- **Temporary out** under-limit fills the fifth row with `Reinsert by 12:36 PM`; over-limit adds 14 px above `Reinsert now`.
- **Pickers**: all columns visible and centred as a group (≈0.28·W per column for three, 0.35·W for two), static dimmed `:` between hour and minute, value row at H/2, arrows symmetric and ≤0.12·H.
- **Correct dates** is rebuilt on native Menu2 (sublabel values; pending Removed row grey with a no-op select that shows a brief "Not removed yet" toast/Confirmation-free message).
- **Settings** duration rows: `Days worn` / `Days out`.
- **Menus**: temporary-out title `Ring out · 10 min left`; items per menus-confirmations.md (Take out briefly / Start ring-free week / Log earlier insertion; title `No ring logged`; declarative sub-labels; no "Logs current time"). Confirmation `Change removal time?`.
- **Text screens**: action slot on Alert detail (`[ What happened? ]`); dismiss labels: OK (migration), Done (About, Regimen), I understand (first run); About three-line copy; migration and first-run copy per text-screens-alert.md; body one size step below title; rail only on overflow.
- **Notifications**: titles `Remove now` / `Insert now` / `Replace now` for overdue/serious; Reminder 2 `Remove ring today` (Insert-side equivalent), bodies `Due today` / `12:26 PM` on both reminders; hints `Tap to log`; late line orange; body `Ring-free 8 days` / `Ring in 34 days` + `Nd late`.
- **Glance**: icon neutral grey in all states (title/value/bar carry colour); temporary-out title `Reinsert in`, value `10 min`; bar width from the chord minus 10 px; future segment at 40%; dot +2 px on 416/454.
- **Upcoming/History**: active-cycle marker is `NOW` in green on both screens (History secondary `Cycle 25 · NOW`); OUT date amber when overdue; divider `— projected if removed today` once, no trailing dash; tick only through the bar; proportional grey track; fixed row pitch; chord-aware scrollbar; year cue in the header on rollover; History highlight full-bleed; cycle detail values without weekday, `32×` for brief outs, collapsed empty rows.
