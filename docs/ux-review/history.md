# History list + Cycle detail (42/47/51 mm)

## P1
1. **Bar is loudest and encodes nothing** (identical on every row). Fix: real two-segment bar to a common scale with an amber tick at planned removal, or a 1 px hairline; nothing in between.
2. **Row hierarchy inverted** ("Cycle 25" biggest). Fix: primary = date range white (`8 Sep → 29 Sep`; current shows planned removal instead of `—`); secondary = `Cycle 25 · Current` grey/green. Resolve "First cycle" vs "Cycle 25" contradiction (→ `First recorded` or drop).
3. **Current-cycle detail shows two dead dashes.** Fix: `Removed   due Tue 29 Sep`, `Next in   due 6 Oct`; past cycles: `Removed 11 Aug` + `15d early` amber + `planned 26 Aug` grey. Never a bare `—`; omit absent rows.
4. **Variance ambiguous/duplicate** ("Inserted 15d late" — which cycle?). Fix: one line scoped to the row's own events: `Out 15d early · In 6d late`; insertion variance belongs to the cycle it opens. Tier colour: amber ≤3 d, red >7 d.

## P2
5. Mixed alignment (title left, date centred; detail bottom group inset ~8 px) → one left edge, one right edge; deliberate insets ≥16 px or none.
6. "First cycle" styled as a value → grey caption under title or drop.
7. Weekday/time precision inconsistent → none in list, weekday in detail; `Tue 8 Sep · 17:26` on one line.
8. Green left tick in bezel dead zone, redundant with "Current" → remove.
9. Spacing makes the bar read as top border of next row → symmetric padding or bar above title; detail group separator hairline or consistent 36–40 px pitch.
10. "Ring out — 32 times" is a lifetime stat in a per-cycle table → `Removals` on a stats screen, or `Removals (all) 32`.

## P3
11. 51 mm could fit a third row once variance collapses.
12. "Out —" in list → `→ 29 Sep` planned in grey.
13. "Current" hugs right edge on 42 mm (moot after 2).
14. Colour continuity list → detail (green Current, amber variance).

**Verdict:** solid bones; fix the bar, invert hierarchy, replace every dash with a due date.
