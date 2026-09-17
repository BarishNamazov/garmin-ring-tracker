# Notifications (7 cards, 416 px)

## P1
1. **Title budget ~17 chars; "Remove ring tomorr…" already clips.** Rule: titles ≤15 chars, no numbers in titles.
2. **Large numeral collides with the divider** on temp-over-3h and ring-in-over-28d.
3. **Reminder 1 and 2 pixel-identical.** Second must say "still".
4. **Ring-in-over-28d contradicts itself** (green "6d 0h" + "Remove · Sun 20 Sep" above red "Replace now"). Drop the countdown; show red days-over.
5. **Overdue card has no instruction.**

## P2
6. Body repeats title verbatim on three cards → title = verb, body = fact + secondary instruction.
7. Three vocabularies → verbs: `Remove` (scheduled out), `Insert` (scheduled in), `Replace` (swap), `Put back` (temporary out); date label consistent.
8. "Use backup 7 days." is an unhedged clinical directive and the least discreet text → "Backup advised", details in-app.
9. Grey "5:26 PM" reads as the received-at timestamp → fold into the date line.
10. Orphaned wrap on ring-free.

## P3
11. Icon looks like a spinner → closed single-colour ring with dot marker at ~32 px; not colour-coded per state.
12. Day-before green reads as "success" → neutral white/grey numeral.
13. Discretion: keep "ring"; drop body words that only make sense clinically.

## Replacements (title ≤15 ch)
| Card | Title | Body |
|---|---|---|
| Day-before | **Remove tomorrow** | `Tue 15 Sep · 5:26 PM` |
| Reminder 1 | **Remove ring** | `Due today · 5:26 PM` |
| Reminder 2 | **Still in — remove** | `Due 5:26 PM today. Tap to log once out.` |
| Overdue | **Remove now** | `1d 4h late · due Sun 13 Sep` |
| Temp out >3 h | **Put ring back** | `Out 3h 10m. Backup advised — see detail.` |
| Ring-free >7 d | **Insert ring** | `Break over 7 days · 1d late. Backup advised.` |
| Ring-in >28 d | **Replace ring** | `In over 4 weeks · Xd over. Backup advised.` |
(Insert-side variants of day-before/reminders/overdue follow the same pattern with `Insert`.)

**Verdict:** IA right; execution leaks. Fix the five P1s and adopt the four-verb vocabulary.
