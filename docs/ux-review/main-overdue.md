# Main screen — overdue (remove / insert), 42/47/51 mm

## P1
1. **Arc says "almost done", not "late"**: ~300° static amber sweep, identical for 5h and 1d late; off-axis start cap at 11 o'clock looks like a bug. Fix: lateness meter — dim full track (25% grey), amber sweep from 12 o'clock growing with hours late (full = grace window exhausted). Minimum: start at 12; never show >95% in non-overdue states.
2. **Instruction is not the hero**: "1d late" is largest; "REMOVE NOW" is second-tier in the same amber, ~100 px above. Fix: one amber text element — REMOVE NOW in amber caps, ~20% bigger (~34 px cap at 416), directly above the number (~12 px gap); "1d late" in white (~64 px). Amber = what to do, white = how bad, grey = when.

## P2
3. **Top-heavy, dead bottom third.** Fix: group header + hero + due line, optically centre (~5% above centre).
4. **Due line too heavy, two rows.** Fix: one line, medium weight, ~70% grey: `Was due Sun 13 Sep · 5:26 PM`.
5. **No visible way to act.** Fix: small grey hint in bottom band (`Hold to log removed`), ~20 px, dimmed. (Only if the interaction model supports it.)

## P3
6. Ring, header, hero share the same amber → ring at ~70% luminance or 20% thinner.
7. Edge inset inconsistent (42 mm flush; 47/51 have gutter) → outer radius 0.485 × width everywhere.
8. Lateness precision: hours up to 48 h (`29h late`), then days.
9. No clipping; consider a tiny in/out glyph before the header.

**Verdict:** reads "almost time" with a big number, not "you're late, do this now". Fix ring semantics and swap hero roles (amber verb on top, white magnitude, one grey due line).
