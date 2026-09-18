# Round 2 — glance + notifications — verdict: FIX

## P1
1. Late duration formatted three ways (`1d 4h late`, `1d late`, `6d over`, glance `1 day`). → one formatter: `Xd Xh late` under 2 days, `Xd late` from 2 days; glance value `1d 4h` with title `Remove overdue`. Never mix "over" and "late".
2. Overdue titles not parallel (`Remove now` / `Insert ring` / `Replace ring`). → `Remove now` / `Insert now` / `Replace now`.
3. Reminder 2 title `Still in — remove` violates verb-first + em dash. → `Remove ring today`, body `Due 12:26 PM` (Insert-side equivalent).
4. Reminder 1 vs 2 body layouts differ. → both: line 1 `Due today`, line 2 `12:26 PM`.

## P2
5. Hint row inconsistent. → advisories always `Backup advised`; action hints always `Tap to log`; drop `Choose what happened` / `see detail` / `once out`.
6. Overdue notification late line plain white → orange like the glance. Glance icon stays green in overdue → tint orange or make icon neutral grey in all states.
7. Temporary-out glance breaks title/value pattern (`Ring out` / `10 min left`). → title `Reinsert in`, value `10 min`.
8. `Break over 7 days` / `In over 4 weeks` → `Ring-free 8 days` / `Ring in 34 days` (actual counts).
9. Bar right margin on 454 px ~3 px from chord → compute width from chord at bar y minus ~10 px inset.
10. Bar: dim segment ahead of the dot (~40%); dot +2 px on 416/454.
