# Round 2 — overdue + serious states — verdict: FIX

## P1
1. 42 mm `main-warning-wrap`: schedule line wraps its time to a smaller second line touching descenders, then a two-line red error stacks under it (four sizes in ~90 px). → never wrap the schedule line into a different size; degrade copy first (`Remove · 8 Oct 1:26 PM` → `Remove · 8 Oct`); when the "watch time before insertion" error fires, REPLACE the schedule line with the error, don't stack both.

## P2
2. Lateness arc quantized to whole days (29 h ≈ 2 d). → fraction = minutes late / (7 × 1440), clamp 1.0.
3. Magnitude metric changes meaning at red (`2d late` → `8d out` / `29d in`; "8d out" reads as "8 days away"). → keep `Nd late` as the magnitude in amber and red; total in the secondary line (`Ring-free 8 d · was due Wed 16 Sep`), or unambiguous units (`29 d worn`).
4. `Backup advised · 7 days` set in the lowest-hierarchy grey → white, directive copy `Use backup 7 days`, no dot separator.
5. Wrap-screen validity error reuses serious red and breaks mid-clause → amber/white, `Check insertion date` / `Watch time is before insertion`.
6. Magnitude row jumps y≈200 (amber) → y≈165 (red); 42 mm red block top-heavy → fixed magnitude y across states; re-centre 42 mm block by ~7 px.
