# Glance (ring in / ring-free / overdue / temporary out), 42/47/51 mm

## P1
1. **Overdue not visually escalated** (white text, green icon, only a thin orange bar; marker at 77% contradicts "overdue"). Fix: orange icon + title + value; marker pinned to the right end with an orange overflow tail; copy "Remove overdue · 1 day".
2. **No title/value hierarchy** — reads as a sentence. Proposed layout (416, band ≈120–130 px): icon 34 px left, vertically centred on two rows; title (glance font ~20 px, neutral) "Remove in"; value (glance number font bold ~34 px) "17 days"; bar 4 px under the value spanning the text column.
3. **Bar illegible/not learnable** (~3 px, 5 px hollow marker; identical in ring-out). Fix: 4–5 px rounded; filled white 8–9 px marker with 1 px dark outline; keep the two-segment bar in every state; ring-out dims segments to ~50% with hollow marker; lighten purple (~#A78BFA).

## P2
4. Icon static/inconsistent across sizes → single-colour ring carrying state (green/purple/orange/hollow), no sector; ~8–9% of width, inset by safe margin.
5. Copy units inconsistent ("days"/"hrs"/"3h 10m"); ring-out ambiguous → "17 days", "2 h 50 min"; ring-out shows remaining window: title "Ring out", value "2 h 50 min left".
6. Top-heavy rhythm → centre icon on text block; bar 6–8 px under value; centre group in band.

## P3
7. Optional "discreet glance" setting (title "Cycle", value "17 d").
8. Fixed px across sizes → glance fonts + percentage margins.
9. Consider Garmin-like accent/grey palette; orange exclusively for overdue.

**Verdict:** concept right; rebuild as title/value/bar with state colour on icon and value.
