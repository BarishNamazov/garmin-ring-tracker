# Round 2 — Upcoming, History, cycle detail — verdict: FIX

## P1
1. Cycle detail Inserted row collides at 42 mm (label→value gap 13 px; two-digit hours overflow). → drop weekday from the value, or wrap value under the label, or step font down on ≤390.
2. History "Current" highlight card clipped by the round mask at its top corners and butts the scrollbar. → full-bleed band (x0–width), or inset to the chord at the card's top y with ≥12 px radius and ≥8 px clear of the scrollbar.

## P2
3. OUT column left edge wobbles (right-aligned proportional font). → left-align OUT at IN right edge + 16 px, or right-align with tabular figures.
4. Peek row doesn't share the OUT anchor. → same right edges as full rows (or clip instead of shrinking).
5. Today tick collides with the divider's trailing em dash. → tick only through the bar (±3 px); no trailing dash.
6. Status bar column-anchored, not time-proportional; overdue label amber over purple. → one grey proportional track, elapsed fill, overdue excess amber.
7. Overdue hierarchy weak. → tint the NOW row's OUT date amber when overdue.
8. Vertical pitch inconsistent (65/80/78 px). → fixed 78 px pitch @416; NOW row's bar/divider a fixed extra block.
9. Scrollbar not chord-aware (kisses bezel). → clamp track to the circle or inset to x = width − 0.07·width.
10. `1 Jan '27` near the eyebrow at 42 mm. → year in header (`IN · 2027`) on rollover, or reserve ~70 px eyebrow width.
11. Cycle detail dead middle zone; crowded subtitle. → collapse unpopulated rows, centre block; subtitle 12 px top / 20 px bottom.
12. `Brief outs 32` has no unit. → `32×`.
13. Cross-screen: Upcoming "NOW" white vs History "Current" green. → one word, one colour.
14. Divider scopes only NEXT. → `— projected if removed today` once above NEXT, no closing dash.
15. History card padding uneven (5 px top / 25 px bottom). → 10/10.
