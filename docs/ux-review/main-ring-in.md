# Main screen — ring in (42/47/51 mm)

## P1
1. **"17d 0h" gives zero hours full hero weight.** Fix: tiered precision — ≥48 h: `17` + `d`; 24–48 h: `1d 12h`; <24 h: `14 h`; <1 h: `45 min`. Never render a zero component.
2. **Unit glyphs illegible and mismatched** (~22–25% of digit height, baseline subscripts, bolder than digits; uneven gaps). Fix: units ~40% of digit cap-height (~32 px at 47 mm), same/lighter weight, 6–8 px digit→unit gap, 18–20 px between groups.
3. **Arc is a static map, not progress**; marker smaller than the stroke. Fix: elapsed portion (12 o'clock → marker) at ~40% brightness, full ahead; marker 1.5× stroke (~21 px at 47 mm) with 2 px black outline. Keep purple week full colour.
4. **Hero not optically centred** (+7/+12/+13 px right). Fix: centre on ink bounds of digits; hang units outside the centring box.

## P2
5. **"RING IN" competes with hero** (same green, bold caps). Fix: title 80% white, medium weight, +1 px tracking; phase colour reserved for number and arc.
6. **Arc flush with bezel** (2–4 px). Fix: inset outer radius ~1.5% of width (6 px at 416); stroke ~3.5% of width (14/15/16 px).
7. **Purple weakest colour** (~4.5:1). Fix: lift to ~#A690FF (≥6:1).
8. **Removal time under-served** (60% size, mid grey). Fix: 85% white, same size as date; or one line `Remove · Thu 1 Oct · 5:26 PM` at 51 mm.
9. **Uneven vertical rhythm** (40 px vs 25 px; stack 12 px high). Fix: equal gaps ~28–30 px; centre minus ~4 px.

## P3
10. Hero digit weight light → one step up.
11. Action line flat → "Remove" 70% white, date 100% white.
12. Hard butt seams → 1–2 px black gap at 9 and 12 o'clock.
13. "RING IN" tracking +1–2 px.

**Verdict:** bones right; precision noise ("0h", subscript units) and a decorative arc hold it back from premium.
