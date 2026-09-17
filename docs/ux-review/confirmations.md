# Confirmations (remove now / insert now / edit removal), 42/47/51 mm

## P1
1. **Variance line has no referent** ("2d early" — relative to what?) and reads as a verdict. Fix: line 2 = schedule fact: `Remove ring now?` / `Due in 2 days`; `Insert ring now?` / `Due 5 hours ago`. If keeping variance: `2 days before due`.
2. **"Set removal?" ambiguous** (schedule future vs edit past). Fix: `Change removal to` / `11 Sep · 12:26 PM` (no "?").

## P2
3. **Inconsistent "consequence" grammar** across the three. Pick: line 1 = action, line 2 = schedule fact. For edits, ideally the shifted next-insertion date; if timestamp, add weekday (`Thu 11 Sep · 12:26 PM`; 42 mm tighten spaces).
4. **"2d"/"5h" are code; rounding invisible.** Spell out units (`2 days`, `5 hours`); rule: <24 h hours, ≥24 h floor-days, never round up.
5. **"late" on a 5 h insertion is alarming.** Use neutral "Due 5 hours ago"; escalate wording only past the leaflet threshold.

## P3
6. Noun drift: "ring" in two titles, absent in the third → `Change ring removal to`.
7. Timestamp follows device 12/24 h and locale; 42 mm edit dialog is the only overflow risk.
8. Cancel/Confirm mapping is platform-native; don't make Confirm look like the safe default.

**Verdict:** fit fine; wording is the problem. Replace bare variance with "Due in/ago" and the fragment with "Change removal to".
