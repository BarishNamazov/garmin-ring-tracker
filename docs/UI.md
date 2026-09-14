# UI and interaction specification

Target canvas: 416 × 416 reference design, round AMOLED  
Scaled targets: 390 × 390 and 454 × 454  
Visual direction: quiet, precise, private, premium

## 1. Coordinate and type system

All measurements below are reference pixels on the 416 × 416 epix Pro 47 mm profile. At runtime:

```text
scale = min(displayWidth, displayHeight) / 416.0
x' = round(x * scale)
y' = round(y * scale)
stroke' = max(1, round(stroke * scale))
```

The three scale factors are 0.9375 for 390 px, 1.0 for 416 px, and approximately 1.0913 for 454 px. Calculate geometry from the actual `Graphics.Dc` dimensions rather than assuming the profile.

### Round-screen safe areas

- Screen center: `(208, 208)`; physical radius: `208`.
- Progress-arc center/radius: `(208, 208)`, `184`; stroke: `14`. Its outer edge is at radius 191, leaving 17 px of black bezel clearance.
- Primary-content safe rectangle: `x = 68..348`, `y = 64..352`. Short centered text may extend to `x = 52..364` near vertical center, after measuring.
- List content safe width varies by row. At vertical offset `dy` from center, the physical half-width is `sqrt(208² - dy²)`. Keep at least 20 px inside that boundary.
- Minimum interactive target: 64 × 64 px at reference scale even if the visible icon is smaller.
- Keep critical text above `y = 350`; bottom hints below that are secondary and may narrow with the circle.

Always measure text with `Graphics.getFontHeight()` and `Dc.getTextWidthInPixels()` before drawing. Ellipsize a secondary label; never scale text non-uniformly.

### Fonts

Use built-in system fonts only. Approximate rendered heights in the installed epix profiles are included to make layout reviews concrete:

| Role | Font constant | 42 mm / 390 | 47 mm / 416 | 51 mm / 454 |
|---|---|---:|---:|---:|
| Eyebrow, hint | `Graphics.FONT_SYSTEM_XTINY` | 19 | 19 | 21 |
| Body/list secondary | `Graphics.FONT_SYSTEM_TINY` | 25 | 26 | 28 |
| Body/list primary | `Graphics.FONT_SYSTEM_SMALL` | 27 | 29 | 32 |
| Action heading | `Graphics.FONT_SYSTEM_MEDIUM` | 32 | 34 | 37 |
| Large text | `Graphics.FONT_SYSTEM_LARGE` | 35 | 37 | 40 |
| Countdown digits | `Graphics.FONT_SYSTEM_NUMBER_HOT` | 69 | 73 | 81 |
| Very large single value | `Graphics.FONT_SYSTEM_NUMBER_THAI_HOT` | 80 | 84 | 92 |
| Glance label | `Graphics.FONT_GLANCE` | 21 | 22 | 25 |
| Glance number | `Graphics.FONT_GLANCE_NUMBER` | 28 | 30 | 33 |

`FONT_SYSTEM_NUMBER_*` contains digits rather than arbitrary letters. Compose the countdown as separately measured runs: large digits in `FONT_SYSTEM_NUMBER_HOT`, compact `d`/`h` units in `FONT_SYSTEM_XTINY`, with an 8 px gap between day and hour groups. If composition would exceed 280 px, fall back to one centered string in `FONT_SYSTEM_LARGE`.

### Color and line style

- Background: true black `#000000`.
- Primary text: `#F4F7F8`; secondary text: `#9AA6AD`.
- Track/divider: `#20262C`.
- Ring-in: `#38D6A0`; ring-free: `#9C7CFF`.
- Attention/due: `#FFB020`; serious overdue: `#FF4D5E`.

Use round line caps where available. If `drawArc` produces butt caps, place a stroke-width circle at each segment endpoint. Do not use gradients, translucent layers, shadows, or a glowing full-screen fill. The black negative space is part of the design.

## 2. Global interaction model

The product is fully operable by buttons and fully operable by touch.

| Physical/gesture input | Meaning |
|---|---|
| START/ENTER | Open, select, or confirm the focused non-destructive control |
| BACK/LAP | Cancel/pop; from the root, exit the app |
| UP/DOWN | Move through rows or values; on main, open Schedule detail |
| Long UP/MENU | Open the main `WatchUi.Menu2` |
| LIGHT | System behavior; the app does not consume it |
| Tap | Select the visible target |
| Swipe up/down | Move/scroll, equivalent to DOWN/UP according to Garmin convention verified in simulator |
| Swipe right | Back/cancel |

Use `WatchUi.BehaviorDelegate` for semantic navigation. Do not make swipe the only path. No gesture immediately changes schedule data.

Focus is visible as a 2 px accent outline or a 10 px-wide accent rail; it is not conveyed only by color. START/tap opens a confirmation before any timestamp is committed.

## 3. Main status: ring in

```text
                       12 o'clock
                 .-----------------.
             .-'   ● teal arc         '-.
           .'    /                 \      '.
          /    /    RING IN          \       \
         /    |      Day 16            |      \
        ;     |                         |       ;
        |     |      REMOVE IN          |       |
        |     |                         |       |
        |     |       5 d  3 h          |       |
        |     |                         |       |
        ;     |   Tue 22 Sep · 09:00    |       ;
         \    |                         |      /
          \    \    MENU  •  START     /     /
           '.    \                 /       .'
             '-.   violet segment   .-'
                 '-----------------'
```

Reference geometry:

- Draw inactive track first: radius 184, 14 px, full circle.
- Garmin arc angles place 90° at 12 o’clock. Start the cycle at 90° and draw clockwise.
- Segment sweep: `360 * daysIn / (daysIn + daysOut)` and the remainder for ring-free. Leave a 2° black gap at insertion and removal boundaries. For `daysOut == 0`, draw only ring-in and one replacement boundary notch.
- Current-time marker: 8 px white disc centered on radius 184, with a 3 px black inner disc. Position by clamped exact progress from insertion UTC to anchored next-insertion UTC. It is a schedule marker, not an efficacy indicator.
- Phase label baseline near `y = 80`, `FONT_SYSTEM_XTINY`, ring-in accent, centered.
- Day label baseline near `y = 108`, `FONT_SYSTEM_XTINY`, secondary.
- Action heading baseline near `y = 148`, `FONT_SYSTEM_MEDIUM`, primary.
- Countdown vertical center near `y = 212`; combined run no wider than 280 px.
- Next date baseline near `y = 282`, `FONT_SYSTEM_SMALL`, primary. If necessary split date and time across baselines 274/304.
- Bottom hint baseline near `y = 340`, `FONT_SYSTEM_XTINY`, secondary. It is optional when screen-reader/focus UI occupies the region.

Update the countdown when the app resumes, on a minute tick below 24 hours, and on an hour tick otherwise. The marker may move at the same cadence. Do not animate seconds.

Tap anywhere inside the central 240 px-diameter region or press START to open Menu2. Long UP does the same. UP/DOWN opens Schedule detail.

## 4. Main status: ring-free

The layout is identical, which prevents phase changes from feeling like navigation. Color and copy change:

```text
                 .-----------------.
             .-'  teal       ● violet '-.
           .'                           '.
          /          RING-FREE             \
         /             Day 24               \
        ;                                     ;
        |            INSERT IN                |
        |                                     |
        |              4 d                    |
        |                                     |
        ;       Sat 26 Sep · 09:00             ;
         \                                   /
          \          MENU  •  START         /
           '.                               .'
             '-.                         .-'
                 '---------------------'
```

- Phase label and active arc use ring-free violet.
- If fewer than 24 hours remain, action/countdown use amber while the segment stays violet.
- A small secondary line under the date reads `7-day limit: Sat 26 Sep` only when actual removal or an adjusted plan makes that medically relevant. Do not crowd the default 21/7 screen with a duplicate date.

For a configured 29–35-day ring-in phase, keep the configured countdown but replace the bottom hint strictly after day 28 with an amber `Beyond FDA-labelled 4 weeks` badge. Tapping it opens Alert detail with the extended-plan explanation; it does not change the configured action automatically.

## 5. Main status: overdue

```text
                 .-----------------.
             .-'  red warning ring   '-.
           .'                           '.
          /            OVERDUE             \
         /                                  \
        ;           INSERT RING              ;
        |                                    |
        |           8 h  OVERDUE              |
        |                                    |
        |        Ring-free limit passed       |
        ;       Tap for label information     ;
         \                                  /
          \           MENU  •  START       /
           '.                              .'
             '-.                        .-'
                 '--------------------'
```

- Replace both schedule colors with an inactive track plus a red 300° warning arc; leave the top 60° gap so the display does not become a bright ring.
- Phase label `OVERDUE` is red. Use amber for due/ordinary overdue removal, red after the 7-day ring-free ceiling or an over-3-hour temporary removal.
- Keep the primary instruction factual: `INSERT RING`, `REMOVE RING`, or `REPLACE RING`. Never display “unprotected.”
- START/tap on the central warning opens Alert detail. Long UP opens the menu.
- Do not auto-advance or create a cycle at a deadline. Only a confirmed user event changes state.

## 6. Main status: temporarily out

An open temporary-out event takes priority over ordinary main content while the underlying cycle arc remains visible at 35% brightness.

```text
                 .-----------------.
             .-'   dim schedule arc  '-.
           .'                           '.
          /          RING IS OUT           \
         /                                  \
        ;             ELAPSED                ;
        |                                    |
        |              2:42                  |
        |                                    |
        |       3-hour boundary in 18m        |
        ;                                    ;
         \        RING BACK IN             /
          \          press START          /
           '.                              .'
             '-.                        .-'
                 '--------------------'
```

- `2:42` means `2h 42m`, not a clock time; draw `2` and `42` with `FONT_SYSTEM_NUMBER_HOT` and small `h`/`m` units when space permits.
- Before 3 hours, use amber only for the final 30 minutes. At exactly 3 hours show amber `3-hour limit reached`. Strictly after 3 hours use red and `Recorded out over 3 hours`.
- The `RING BACK IN` control has a centered 260 × 64 px target at `x = 78..338`, `y = 300..364`, even though its visible label is smaller.
- START/tap opens the “Ring back in now?” confirmation. BACK exits without closing the interval. The live timer survives restart because its start UTC is persisted.

## 7. Setup and first run

Setup is a three-step, resumable flow. Persist acceptance and configuration after each confirmed step, but do not create a cycle until final insertion confirmation.

### 7.1 Safety boundary

```text
                 .-----------------.
             .-'                     '-.
           .'       SCHEDULE AID        '.
          /                               \
         /   This app cannot determine    \
        ;    contraceptive effectiveness.  ;
        |                                  |
        |   Follow the instructions for    |
        |   your ring and your clinician.   |
        ;                                  ;
         \         Review details        /
          \        START  Continue      /
           '.                             .'
             '-.                       .-'
                 '-------------------'
```

- Title at `y = 68`, `FONT_SYSTEM_SMALL`.
- Four or five body lines within `x = 62..354`, `y = 118..272`, `FONT_SYSTEM_XTINY`, 6 px leading.
- `START Continue` at `y = 328`, `FONT_SYSTEM_TINY`.
- DOWN scrolls if translated copy does not fit. BACK exits and setup resumes here.

### 7.2 Product and regimen

Present one supported product family, not misleading brand choices:

```text
                 .-----------------.
             .-'      REGIMEN        '-.
           .'                           '.
          /   NuvaRing / equivalent       \
         /   etonogestrel + EE ring        \
        ;                                   ;
        |   In ring                  21 days |
        |   Ring-free                 7 days |
        |                                   |
        ;   Annovera is not supported       ;
         \                                  /
          \     START  Confirm            /
           '.                              .'
             '-.                        .-'
                 '--------------------'
```

Selecting either duration opens its picker. A non-default duration presents the extended-use explanation and acknowledgement from REGIMEN before it can be saved. `daysIn > 28` gets the stronger “outside FDA-labelled duration” notice. Selecting Annovera information opens About; there is no Annovera schedule option.

### 7.3 Initial insertion

Offer `Inserted now` and `Choose date & time`. Both end in the standard timestamp confirmation. A final success transition subtly draws the arc once from 0 to its current marker over no more than 300 ms; respect reduced-motion conventions if exposed by the platform, and never loop the animation.

## 8. Schedule detail

This read-only screen explains the compact main view without becoming a dense dashboard.

```text
                 .-----------------.
             .-'      SCHEDULE       '-.
           .'                           '.
          /   Inserted       1 Sep 09:00  \
         /   Remove         22 Sep 09:00   \
        ;    Insert         29 Sep 09:00    ;
        |                                   |
        |   Cycle day                  16    |
        |   Plan                  21 in / 7  |
        ;                                   ;
         \   Times shown in current local  /
          \            time              /
           '.          BACK              .'
             '-.                       .-'
                 '-------------------'
```

- Rows occupy `y = 82, 122, 162, 222, 262`; labels align left at `x = 66`, values right at `x = 350`.
- Labels: `FONT_SYSTEM_XTINY`, secondary. Values: `FONT_SYSTEM_TINY`, primary.
- UP/DOWN returns to main only when there is no overflow; BACK always pops.

## 9. Main Menu2

Use native `WatchUi.Menu2` rendering and behavior rather than recreating a custom round list. Required order:

```text
                 .-----------------.
             .-'        MENU         '-.
           .'                           '.
          /     Ring inserted now         \
         /    >Ring removed now            \
        ;      Ring out temporarily         ;
        |      Adjust dates                 |
        |      Settings                     |
        ;      History                       ;
         \     About / Disclaimer          /
          \                               /
           '.                             .'
             '-.                       .-'
                 '-------------------'
```

The visible row count is device-controlled. Supply short labels and optional sublabels; let native scrolling expose all seven actions. While a temporary interval is open, replace the third label with `Ring back in`. For a 0-day ring-free plan, the first item becomes `Ring replaced now` near the deadline.

Actions that conflict with state remain visible only if a useful explanation exists; otherwise omit them. For example, when no cycle exists, show `Ring inserted now` but omit removal/temporary-out items.

## 10. Confirmation dialog

Use native `WatchUi.Confirmation` so button and touch conventions remain familiar.

```text
                 .-----------------.
             .-'                     '-.
           .'       REMOVE RING?        '.
          /                               \
         /       Mon 21 Sep · 09:03        \
        ;                                   ;
        |     Starts the ring-free week.    |
        |                                   |
        ;                                   ;
         \          YES       NO          /
          \       START      BACK        /
           '.                              .'
             '-.                        .-'
                 '--------------------'
```

Dialog copy requirements:

- verb and object in title;
- exact local timestamp;
- one short consequence line;
- for replacement, “Archives current cycle and starts a new one”;
- for back-in after >3 hours, the confirmation commits first, then Alert detail presents label information.

No confirmation defaults visually to Yes after inactivity. BACK is always No.

## 11. Adjust dates

`Adjust dates` first opens a native Menu2 choice: `Insertion`, `Removal` if present, or `Planned next action`. Editing insertion/removal rewrites the actual recorded event and recomputes dependent deadlines. Editing only planned next action records an override with a visible `Adjusted` badge; it does not falsify event history.

Use a two-step `WatchUi.Picker`: date, then time.

### 11.1 Date picker

```text
                 .-----------------.
             .-'      INSERTION      '-.
           .'          DATE             '.
          /                                \
         /            13 Sep                \
        ;          > 14 Sep <                ;
        |            15 Sep                  |
        |                                    |
        ;             2026                   ;
         \                                  /
          \      START Next  ·  BACK       /
           '.                              .'
             '-.                        .-'
                 '--------------------'
```

- Header `y = 56..104`, `FONT_SYSTEM_XTINY`.
- Focused value center `y = 208`, `FONT_SYSTEM_LARGE`, primary.
- Adjacent values at `y = 154/262`, `FONT_SYSTEM_SMALL`, secondary.
- Year/context at `y = 302`, `FONT_SYSTEM_TINY`.
- Native picker arrows/focus may replace the ASCII chevrons.

### 11.2 Time picker

```text
                 .-----------------.
             .-'      INSERTION      '-.
           .'          TIME             '.
          /                                \
         /                                 \
        ;             09 : 00               ;
        |             ^^                     |
        |       current local time           |
        ;                                    ;
         \                                  /
          \    START Review  ·  BACK       /
           '.                              .'
             '-.                        .-'
                 '--------------------'
```

Use 5-minute increments by default but include every minute reachable with continued scrolling; existing event seconds normalize to zero only when edited. Respect 12/24-hour selection, including an AM/PM column for 12-hour mode. Review then opens a confirmation with the assembled full timestamp. Invalid/nonexistent local times display an explanatory adjustment before confirmation.

## 12. Settings

Use native Menu2/list rows. On-watch settings are authoritative immediately after confirmation and mirror into App Settings.

```text
                 .-----------------.
             .-'      SETTINGS       '-.
           .'                           '.
          /   Reminder time        09:00  \
         /    Days ring in            21   \
        ;     Days ring-free           7    ;
        |     Repeat overdue           6h   |
        |     Vibration*               On   |
        ;     Sound*                  Off   ;
         \    Clock                  System/
          \   *when app opens            /
           '.                             .'
             '-.                       .-'
                 '-------------------'
```

Rows and rules:

- `Reminder time`: time picker.
- `Days ring in`: numeric picker, 21–35; show medical acknowledgement for non-default ranges.
- `Days ring-free`: numeric picker, 0–7; 0 is displayed as `Replace immediately`.
- `Repeat overdue`: list 1, 3, 6, 12, 24 hours.
- `Vibration` and `Sound`: labelled with an info footer `When alert opens; notification behavior is controlled by the watch`.
- `Clock`: System, 12-hour, 24-hour.

If a regimen duration changes during an active cycle, show old and new next-action times in confirmation. Cancel leaves both watch and mirrored property unchanged.

## 13. History

History is intentionally compact and neutral. It shows recorded facts, not adherence judgments.

```text
                 .-----------------.
             .-'       HISTORY       '-.
           .'                           '.
          /  > 01 Sep — 29 Sep   21 / 7  \
         /     04 Aug — 01 Sep   21 / 7   \
        ;      07 Jul — 04 Aug   21 / 7    ;
        |                                   |
        |                                   |
        ;                                   ;
         \        3 of 12 recorded         /
          \           BACK                /
           '.                              .'
             '-.                        .-'
                 '--------------------'
```

- Use native list behavior with 58–64 px row height.
- Primary row: insertion date to next insertion/close date, `FONT_SYSTEM_SMALL`.
- Secondary: regimen snapshot and a small temporary-out indicator, `FONT_SYSTEM_XTINY`.
- Load labels for only visible rows. Maximum history is 24 cycles. Cycles with consolidated short temporary-out events show a `+ summarized` secondary badge.

Selecting a row opens detail:

```text
                 .-----------------.
             .-'    CYCLE DETAIL     '-.
           .'                           '.
          /   Inserted       01 Sep 09:00 \
         /    Removed        22 Sep 09:04  \
        ;     Next inserted  29 Sep 08:58   ;
        |     Regimen             21 / 7    |
        |                                   |
        ;     Temporary out       1 event   ;
         \    14 Sep 18:02 — 18:47         /
          \            BACK              /
           '.                              .'
             '-.                        .-'
                 '--------------------'
```

Long UP on a history row may expose `Delete cycle`, but deletion still requires Confirmation. There is no export in version 1.

## 14. Alert detail

This screen is used after selecting a native notification, accepting a request-wake prompt, tapping an overdue warning, or closing an over-3-hour interval.

```text
                 .-----------------.
             .-'      ACTION DUE      '-.
           .'                           '.
          /          INSERT RING          \
         /          overdue by 8h          \
        ;                                   ;
        |  The recorded ring-free interval  |
        |  has exceeded 7 days. Follow the   |
        ;  product label; consider pregnancy ;
         \ and use label-directed backup.  /
          \     START Open actions        /
           '.         BACK               .'
             '-.                       .-'
                 '-------------------'
```

- Show live status re-derived after launch; stale notification data supplies navigation only.
- Body may scroll and uses `FONT_SYSTEM_XTINY`, at least 5 px line spacing.
- Cite the product-label basis as `About › Sources`, not a raw URL crammed into the screen.
- START opens Menu2 with the relevant action focused. It does not perform the action.
- Foreground vibration/tone occurs once when this view becomes active if app and device settings permit.

For a week-3 temporary-out warning, present the two label options from REGIMEN on two scroll pages. The user records the action separately. Never preselect one.

## 15. About and disclaimer

Use a scrollable text view with this hierarchy:

```text
                 .-----------------.
             .-'        ABOUT        '-.
           .'                           '.
          /   Garmin Ring Tracker v1.0    \
         /                                 \
        ;   Scheduling aid — not medical    ;
        |   advice. Cannot determine         |
        |   contraceptive effectiveness.     |
        ;                                   ;
         \  NuvaRing/generics only.        /
          \ Annovera is not supported.    /
           '.       Sources  ▾            .'
             '-.                       .-'
                 '-------------------'
```

Content order:

1. product/version;
2. full mandatory disclaimer from REGIMEN;
3. supported-product scope and explicit Annovera exclusion;
4. reminder delivery limitation;
5. privacy statement: schedule stays on watch except configuration entered/synced through Garmin App Settings;
6. short source names and last medical-copy review date;
7. licenses if any.

Show the full disclaimer on first run and keep it permanently reachable. Acceptance means only “continue to setup,” not waiver language.

## 16. Native notification appearance

The application supplies concise content; Garmin renders the native card according to device personality.

Recommended payload copy:

| Kind | Title | Subtitle | Body |
|---|---|---|---|
| Day-before removal | `Ring reminder` | `Remove tomorrow` | `Scheduled Tue at 09:00` |
| Day-of insertion | `Ring reminder` | `Insert today` | `Scheduled for 09:00` |
| Overdue | `Ring action overdue` | `Insert ring` | `Open for current schedule` |
| Temporary >3h | `Ring timing warning` | `Recorded out over 3 hours` | `Open for product-label information` |
| Ring-free >7d | `Ring timing warning` | `Ring-free interval over 7 days` | `Open for product-label information` |

Keep medical detail out of lock-screen text where practical. Use one neutral, monochrome ring/calendar icon suitable for the notification slot. `dismissPrevious = true` ensures an updated reminder replaces this app’s prior stale card.

## 17. Glance

The system owns the glance-row container, so the app draws only inside the `GlanceView` DC bounds rather than a 416 px full-screen canvas.

```text
    ┌──────────────────────────────────────┐
    │  Ring: remove in 5d          16 / 28 │
    │  ━━━━━━━━━━━━━━━━━━━───────────────  │
    └──────────────────────────────────────┘
```

- Left summary uses `Graphics.FONT_GLANCE`; optional right day count uses `FONT_GLANCE_NUMBER` only if it fits without truncating the action.
- Progress track is 4 px high, inset 8 px from the DC edges, 6 px below the text baseline. Filled portion uses phase color; overdue uses red and a full bar.
- Reserve at least 8 px horizontal padding and use `Dc.getWidth()/getHeight()`; do not assume system-row dimensions.
- If width is tight, priority is action then time; omit day count first.
- No seconds, animation, buttons, medical advice, or state changes.

## 18. Interaction flows

### Normal cycle

```text
First run
   → disclaimer
   → regimen
   → insertion picker/now
   → confirmation
   → RING IN main
   → removal reminder
   → Menu › Ring removed now
   → confirmation
   → RING-FREE main
   → insertion reminder
   → Menu › Ring inserted now
   → confirmation + archive old cycle
   → RING IN main
```

### Temporary removal

```text
RING IN main
   → Menu › Ring out temporarily
   → confirmation + persist outUtc
   → TEMP OUT overlay/timer
   → Menu/START › Ring back in
   → confirmation + persist backInUtc
   ├─ elapsed ≤ 3h → return to live main
   └─ elapsed > 3h → Alert detail → relevant action menu
```

### Reminder launch

```text
Hourly service
   → native notification
   → user selects notification
   → normal root is installed
   → live state is re-derived
   → Alert detail is pushed
   → optional one-shot foreground vibration/tone
   → START opens Menu2 with relevant action focused
   → confirmation before mutation
```

## 19. Accessibility, privacy, and polish checklist

- Never rely on green/red alone; always pair color with phase/action words and distinct arc treatment.
- Center text according to measured bounds, not character count.
- Preserve at least 4.5:1 contrast for body text; the specified primary/secondary colors meet that design target on black, but verify on hardware.
- Avoid rapid flashes, pulsing warnings, and haptic loops.
- Use plain language: `ring-free`, not jargon such as `hormone-free interval` unless quoting the label.
- Make all sensitive details disappear when the app exits; the native notification uses neutral wording.
- Use one transition at most—brief arc reveal after setup—and no decorative animation elsewhere.
- Do not draw fixed bright status elements continuously. This is not a watch face, but true black and restrained redraws improve AMOLED power use.
- Verify every confirmation, picker, menu, and scroll view with buttons while touch is disabled in the simulator.
- Verify text does not collide with the arc at all three native resolutions and for every documented countdown format.

## 20. Implementation references

- [`Toybox.Graphics`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics.html) for font constants and colors
- [`Graphics.Dc.drawArc`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html#drawArc-instance_function) for the schedule ring
- [`WatchUi.BehaviorDelegate`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/BehaviorDelegate.html) for semantic navigation
- [`WatchUi.Menu2`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Menu2.html) for menus
- [`WatchUi.Confirmation`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Confirmation.html) for guarded state changes
- [`WatchUi.Picker`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Picker.html) and [`PickerFactory`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/PickerFactory.html) for date/time input
- [`WatchUi.GlanceView`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/GlanceView.html) for glance constraints
