# Round 2 — settings, Correct dates, pickers — verdict: FIX

## P1
1. Picker columns overflow off-screen: only the focused column (centre) and the next (x≈345) are visible; AM/PM (12 h) / year (date) are off the right edge with the left half empty; no affordance. → size factory drawables so the whole group fits: ≈0.28·W each for 3 columns (0.35·W for the 2-column 24 h picker) and let Picker centre the group; verify hour ≈0.25 W, minute ≈0.5 W, AM/PM ≈0.75 W on 390/416/454. If a carousel is intentional, peek the neighbour column at the edge.

## P2
2. Picker stack shifted down; bottom arrow apex clipped (value row at y≈270 vs centre 208). → value row at H/2, arrows symmetric, title drawable ~40 px tall, arrows ≤0.12·H.
3. No hour:minute separator → static dimmed ":" between hour and minute columns (grey as unfocused).
4. "Ring in / 21 days", "Ring out / 7 days" read as countdowns → `Days worn` / `Days out` (or `Wear period` / `Break period`).
5. Focus indicator inconsistent: Correct dates custom purple bar vs Menu2 white bar. → rebuild Correct dates as Menu2 with sublabel values (pending Removed row grey/disabled, select no-op or feedback), or match Menu2's bar.

Not a defect: native Menu2 left-bezel clipping of unfocused rows.
