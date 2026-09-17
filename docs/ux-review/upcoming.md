# Upcoming list (rows 1–3 / 4–6), 42/47/51 mm

## P1
1. **Hierarchy inverted**: "Cycle N" biggest, dates smallest/greyest. Fix: In date primary (bold white, title size), Out date secondary; demote/delete cycle label.
2. **Bar carries zero information** (identical 75/25 on every row; reads as divider). Fix: remove from projected rows; keep one bar on the current row with a today tick (purple lit if in ring-free/overdue).
3. **"if done today" ×5 is noise and hides the real state.** Fix: one caption divider between row 1 and 2 (`— if removed today —`) and show state on row 1 ("Out 13 Sep · **3 d overdue**" in alert colour).

## P2
4. **Sentence "In 23 Aug · Out 13 Sep" defeats column scanning**; "In 23 Aug" reads as "in August". Fix: two right-aligned columns with one small-caps header row `IN  OUT`; no per-row words.
5. **"Cycle N" is noise.** Fix: eyebrow `NOW`, `NEXT` on first two rows only (or month small caps).
6. **Three left edges, uneven rhythm.** Fix: one left edge; row = 2 lines tight; inter-row gap ≥2× internal; no separators.
7. **Scroll affordance inconsistent** (47 mm shows none) and page ends with dead space. Fix: native scrollbar on all sizes; let row 4 peek above the bottom chord.

## P3
8. Green means three things (tag, bar, scroll arc) → tag white-on-dim or replaced by NOW.
9. 42 mm tag crowding (moot after 5 and 3).
10. Year boundary cue (`'27` on first January date or month eyebrow).

## Proposed layout (416)
```
              Upcoming
                    IN          OUT
NOW          23 Aug      13 Sep   ← 3 d overdue (alert colour)
             ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬|▬  ← only bar, with today tick
           — if removed today —
NEXT         21 Sep      12 Oct
             19 Oct       9 Nov
             16 Nov       7 Dec
             14 D…                ← peek
```
Row ~56 px; In bold white ~28 px, Out grey same size; eyebrow 16 px small caps; fixed right-aligned column x positions.

**Verdict:** right idea, wrong emphasis. Date-first columns, one status bar on current row, drop repeated tags.
