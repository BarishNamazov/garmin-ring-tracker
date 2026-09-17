# Main screen — ring-free (42/47/51 mm)

## P1
1. **"5d 0h" reads as "50" at a glance**; zero hours is false precision. Fix: one unit at a time — ≥1 day: `5` + caption `days` (or `5d`); <24 h: `17h`; <1 h: `40m`. Never two units side by side in hero type.
2. **Hierarchy inverted by colour**: purple hero is dimmer than the bold white date line. Fix: countdown white; header keeps purple; date light grey (~70%), time darker grey.
3. **Purple doesn't say "ring-free".** Fix (preferred): ring-free segment as a dim/outlined track (solid green = in, hollow = out); or dim purple to ~50% for elapsed portion.

## P2
4. **Today marker under-sized, doesn't scale** (~8 px everywhere, narrower than stroke). Fix: diameter 1.3–1.4× stroke, 2 px black halo, scale with radius; arc stroke ~3% of diameter.
5. **Arc shows schedule, not progress.** Fix: elapsed portion ~45% opacity, remaining 100%; dot sits at the seam.
6. **"Insert · Sat 19 Sep" reads as two list items.** Fix: `Insert Sat 19 Sep` (no interpunct); or relative within 6 days ("Insert Saturday").
7. **Time line smallest/lowest contrast** yet clinically relevant. Fix: same size as date at ~55% grey; drop leading zero; watch clock format.

## P3
8. Segment seam at 12 o'clock is a hard butt joint → 2–3 px gap or round caps.
9. Header "RING FREE" too loud → one step smaller / 60% accent / letterspaced medium.
10. Vertical rhythm: header→number gap (~50 px) > number→date (~35 px); tighten header by ~10 px.

**Verdict:** solid bones; fix single unit, white hero, hollow ring-free arc and it becomes genuinely glanceable.
