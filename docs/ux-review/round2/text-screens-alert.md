# Round 2 — text screens + alert detail — verdict: FIX

## P1
1. Alert detail has no action slot; "Choose what happened" is plain body text. → standard bracketed action `[ What happened? ]` at the slot.
2. About: orphan blank line + phantom green rail thumb when content fits. → remove blank; rail only on overflow (grey). Copy: `Ring Tracker 1.3.0` / `Reminders only · Not medical advice` / `NuvaRing only. Not generics or Annovera.`
3. Dismiss labels inconsistent (Done / Continue / OK). → "OK" for one-shot notices (migration), "Done" for About and Regimen; "I understand" on first run.

## P2
4. Migration copy → `Your schedule now follows the dates you actually inserted and removed the ring. Review them under Correct dates.`
5. First-run body → `Reminders for your ring schedule only. Not medical advice. Does not confirm contraceptive protection.`
6. Alert detail: "1d  4h late" double space → single; add `Due` prefix to the date block.
7. Alert detail: three competing headline sizes → only "REMOVE NOW" largest; date same size as elapsed line (~28 px).
8. Regimen rows "In"/"Out" → `Ring in` / `Ring out`, one step larger, grey.
9. Body weight = title weight → body one size step down (FONT_TINY) + ~4 px leading if no regular cut.
