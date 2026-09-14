# Garmin Ring Tracker: product and technical specification

Status: implementation-ready specification  
Target: epix Pro (Gen 2) 42 mm, 47 mm, and 51 mm  
Connect IQ application type: `watch-app`  
Minimum API: 5.1.0

## 1. Product contract

Garmin Ring Tracker is a private, watch-first schedule aid for NuvaRing and equivalent etonogestrel/ethinyl estradiol generics. It answers four questions quickly:

- Is the ring recorded in, temporarily out, ring-free, or overdue?
- What is the next recorded action?
- When is that action due?
- Has a recorded temporary removal crossed the 3-hour boundary?

The app does not assess contraceptive effectiveness, diagnose pregnancy, recommend a regimen, or support Annovera. The medically sourced behavior and mandatory disclaimer are in [REGIMEN.md](REGIMEN.md).

### Success criteria

- The primary status is legible within one glance at the watch.
- Every state-changing action is deliberate, confirmed, timestamped, and reversible through date adjustment.
- Schedule calculations remain deterministic through restart, DST changes, and phone/watch time-zone changes.
- Reminders are useful but never presented as guaranteed delivery.
- No health data leaves the watch in this version, except user-entered configuration values synchronized through Garmin App Settings.

### Non-goals

- Annovera or other products with different handling rules.
- Cycle, fertility, bleeding, symptoms, sexual activity, or pregnancy tracking.
- Phone dashboards, direct phone push notifications, cloud sync, accounts, analytics, or advertising.
- Medical advice or an effectiveness score.

## 2. Platform and device contract

The supported product IDs and screens are:

| Product ID | Native display | Shape/input | Connect IQ | Watch-app memory | Background memory | Glance memory |
|---|---:|---|---:|---:|---:|---:|
| `epix2pro42mm` | 390 × 390 | round, touch + 5 buttons | 5.2 | 768 KiB | 64 KiB | 64 KiB |
| `epix2pro47mm` | 416 × 416 | round, touch + 5 buttons | 5.2 | 768 KiB | 64 KiB | 64 KiB |
| `epix2pro51mm` | 454 × 454 | round, touch + 5 buttons | 5.2 | 768 KiB | 64 KiB | 64 KiB |

The dimensions and API support are listed in Garmin’s [compatible devices table](https://developer.garmin.com/connect-iq/compatible-devices/); the [epix Pro (Gen 2) 47 mm device reference](https://developer.garmin.com/connect-iq/device-reference/epix2pro47mm/) supplies the representative memory and input limits. The installed SDK 9.2.0 device definitions give the same memory limits for all three targets. Treat each process limit independently: the background service cannot rely on the foreground app’s 768 KiB budget.

Use the 416 × 416 layout as the design coordinate space and scale every coordinate by `min(width, height) / 416.0`. See [UI.md](UI.md) for exact geometry.

## 3. Architecture

Use one Connect IQ device application with three execution surfaces:

1. **Foreground app:** main status, menus, pickers, history, settings, and alert explanation.
2. **Glance:** a read-only single-row summary and mini progress bar.
3. **Background service:** a small temporal-event handler that evaluates reminder policy and posts a native app notification.

Keep date math in a pure, allocation-light domain module that can be called by all three surfaces and by tests. Keep UI objects, history rendering, and custom picker factories out of background annotations.

Suggested source boundaries for the implementing agent—not required filenames—are:

- `ScheduleModel`: storage records, migration, validation, and derived status;
- `CalendarMath`: local calendar-day conversion and countdown formatting;
- `ReminderPolicy`: candidates, priority, deduplication, and repeat slots;
- foreground `App`, `View`, `Delegate`, menus, pickers, and dialogs;
- `GlanceView` with a reduced read model;
- `ServiceDelegate` with only `(:background)`-reachable dependencies.

## 4. Persistent data model

Use [`Application.Storage`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html) (API 2.4.0), not deprecated `Application.Properties`, for schedule and event data. Storage supports persisted primitive values, arrays, and dictionaries; an individual value is limited to 32 KiB. Store the document under one key such as `state`, with small mirrors under separate keys only where the background/glance path materially benefits.

The following is a conceptual schema, not Monkey C source:

```text
state = {
  schemaVersion: 1,
  nextCycleId: Long,

  active: {
    cycleId: Long,
    insertionUtc: Long,             // Unix epoch seconds; null before setup
    insertionWall: { y, m, d, hh, mm },
    removalUtc: Long | null,
    removalWall: { y, m, d, hh, mm } | null,
    scheduledRemovalUtc: Long,
    scheduledInsertionUtc: Long,
    labelFourWeekUtc: Long,
    ringFreeCeilingUtc: Long | null,
    dstAdjustment: String | null,
    temporaryOut: [
      {
        outUtc: Long,
        backInUtc: Long | null,
        phaseWeekAtStart: 1 | 2 | 3 | null,
        phaseWeekAtEnd: 1 | 2 | 3 | null,
        thresholdCode: String | null
      }
    ]
  } | null,

  regimen: {
    daysIn: Number,                 // default 21; allowed 21..35
    daysOut: Number                 // default 7; allowed 0..7
  },

  reminders: {
    localHour: Number,              // 0..23; default 09
    localMinute: Number,            // 0..59; default 00
    overdueRepeatHours: Number,     // one of 1, 3, 6, 12, 24; default 6
    vibrationEnabled: Boolean,      // foreground alert only
    soundEnabled: Boolean,          // foreground alert only
    clockFormat: Number             // 0 system, 12, or 24
  },

  reminderLedger: {
    cycleId: Long,
    actionKey: String,
    dayBeforeSent: Boolean,
    dayOfSent: Boolean,
    lastOverdueSlot: Number | null,
    lastTempOutSlot: Number | null,
    labelFourWeekSent: Boolean,
    ringFreeExceededSent: Boolean
  },

  history: [
    {
      cycleId: Long,
      insertionUtc: Long,
      removalUtc: Long | null,
      nextInsertionUtc: Long | null,
      closeReason: String,
      regimenDaysIn: Number,
      regimenDaysOut: Number,
      temporaryOut: [ ...retained closed intervals... ],
      temporaryOutSummary: { shortIntervalCount, shortIntervalSeconds }
    }
  ],

  settingsSync: {
    lastSeenInsertionIso: String,
    lastAcceptedInsertionIso: String,
    lastWatchScheduleEditUtc: Long,
    lastSettingsObservationUtc: Long,
    pendingMirrorIso: String | null,
    pendingSettingsError: String | null
  }
}
```

### Storage rules

- Unix epoch seconds are the canonical instants. Construct `Time.Moment` values only at computation boundaries.
- Persist the wall-clock fields that the user selected as an audit trail and to regenerate calendar recurrences. A time-zone identifier is not reliably available, so do not pretend to store one.
- Persist computed action deadlines when an insertion/removal/edit occurs. Background checks read them rather than rebuilding a calendar recurrence every hour.
- Snapshot `daysIn` and `daysOut` into each closed cycle so changing settings does not rewrite history.
- Cap history at 24 completed cycles. Drop the oldest whole cycle only after successfully storing the new state.
- Cap detailed temporary-out intervals at 32 in the active cycle. When closing a cycle, retain every threshold-crossing interval plus the eight most recent short intervals; consolidate older short intervals into a count and elapsed-seconds summary. If the state approaches 24 KiB, consolidate additional short intervals before removing any threshold-crossing record. Show “Some short intervals were summarized.” Never discard an open interval.
- Store no names, notes, symptoms, sexual activity, or location.
- Validate all loaded fields. On corruption, preserve the raw value under a bounded `recovery` key if it fits, reset to setup, and show an error; do not guess dates.
- Write a fully validated replacement document. Update the foreground model only after `Storage.setValue()` succeeds.

### Migration

On load:

1. Missing data becomes a schema-1 default.
2. The current version passes strict range and shape validation.
3. Older known versions migrate one version at a time and are written back.
4. A newer unknown `schemaVersion` opens a read-only incompatibility screen and must not overwrite the record.

## 5. Schedule computation

The pure calculation has this input:

```text
deriveStatus(nowUtc, activeCycle, regimen) -> Status
```

`Status` contains at least:

```text
phase: SETUP | RING_IN | RING_FREE | OVERDUE
overdueKind: null | REMOVE | REPLACE | INSERT
temporaryOutOpen: Boolean
dayOfCycle: Number | null
nextAction: INSERT | REMOVE | REPLACE | RING_BACK_IN | SET_UP
nextActionUtc: Long | null
secondsRemaining: Long | null       // negative when overdue
displayDays: Number
displayHours: Number
ringFreeLimitExceeded: Boolean
beyondLabelFourWeeks: Boolean
```

### Deadline construction

At insertion:

- `scheduledRemovalUtc = addLocalCalendarDays(insertion, daysIn)`.
- `scheduledInsertionUtc = addLocalCalendarDays(insertion, daysIn + daysOut)`.
- `labelFourWeekUtc = addLocalCalendarDays(insertion, 28)` independently of configuration.
- For `daysOut == 0`, both actions form one `REPLACE` deadline at `daysIn`; there is no planned ring-free phase.

At actual removal:

- `ringFreeCeilingUtc = addLocalCalendarDays(actualRemoval, 7)`.
- Planned insertion remains anchored to the original cycle. Do not let a late removal silently postpone the original insertion.
- `nextActionUtc = min(scheduledInsertionUtc, addLocalCalendarDays(actualRemoval, daysOut), ringFreeCeilingUtc)` for `daysOut > 0`.
- If a user records removal under a `daysOut == 0` plan, `nextActionUtc = actualRemovalUtc`: insertion is immediately due. The app does not manufacture a ring-free interval.
- If this produces an insertion deadline at or before the actual removal—late or off-plan removal—the phase is immediately overdue and the UI says that the recorded schedule needs attention.

That “earlier deadline wins” rule is intentionally conservative and deterministic. It preserves the normal same-weekday schedule, prevents an early removal from creating a longer interval, and never moves the medical 7-day ceiling later. The app reports the discrepancy; it does not give a medical recommendation.

### Phase rules and exact boundaries

- No active insertion: `SETUP`.
- Ring not recorded removed and `nowUtc < scheduledRemovalUtc`: `RING_IN`; action `REMOVE`, or `REPLACE` when `daysOut == 0`.
- Ring not recorded removed and `nowUtc >= scheduledRemovalUtc`: `OVERDUE`; kind `REMOVE` or `REPLACE`.
- Ring recorded removed and `nowUtc < nextActionUtc`: `RING_FREE`; action `INSERT`.
- Ring recorded removed and `nowUtc >= nextActionUtc`: `OVERDUE`; kind `INSERT`.
- An open temporary-out interval overrides the primary action shown with `RING_BACK_IN`, but does not erase the underlying phase or advance its deadlines.
- At exactly 3 hours temporarily out, show “3-hour limit reached.” The `>3h` warning flag becomes true only after 10,800 seconds have elapsed.
- At exactly the 7-day ring-free ceiling, the deadline is reached and insertion is overdue. After it, set `ringFreeLimitExceeded = true` and use the escalated copy from REGIMEN.
- While a ring remains recorded in, set `beyondLabelFourWeeks = true` only when `nowUtc > labelFourWeekUtc`. Under a 29–35-day configured plan this does not change `RING_IN` to `OVERDUE` before its configured action, but it adds the persistent FDA-label-boundary warning. Under a shorter plan, ordinary overdue state already applies and the warning escalates its detail.

All comparisons use seconds and explicitly use `<` before a deadline and `>=` at/after a deadline. Tests must lock these boundary semantics.

### Event and edit edge cases

- Reject an actual insertion, removal, or back-in timestamp materially in the future. A future intention belongs in a planned-action override, not in event history.
- If a backward clock change places `now` before the recorded insertion, show `Watch time is before recorded insertion` and require date review. Do not render a negative cycle day or mutate the record.
- A removal before insertion and a back-in before its out time are invalid. Keep the picker open with an error.
- `Ring inserted now` while a ring is already recorded in means replacement. Label it `Ring replaced now`; confirmation archives the old cycle and starts exactly one new cycle.
- `Ring removed now` while a temporary-out interval is open closes that interval and records removal at the same timestamp, in one confirmation.
- A second temporary-out start is disabled while one is open. `Ring back in` is disabled when no interval is open.
- Standard labelled weeks are local cycle days 1–7, 8–14, and 15–21. A temporary-out interval on day 22 or later of an extended plan gets `phaseWeekAtStart = null` and an “outside the standard three-week schedule” message; the app must not invent a week-3 instruction. If an interval crosses a week boundary, record that fact and present every potentially relevant label section without choosing a medical option.
- Changes to `daysIn/daysOut` do not retroactively alter archived cycles or temporary-out classifications.
- An adjusted planned-action override may be future-dated; every actual event remains immutable except through a separately confirmed correction.

### Day of cycle

`dayOfCycle` is a user-facing local-calendar ordinal, not elapsed 24-hour blocks:

- insertion date is day 1;
- each change of local calendar date increments the number;
- a time-zone change can therefore change the displayed day while leaving the actual deadlines unchanged;
- clamp to at least 1 and allow values above configured cycle length when overdue.

Calculate local date ordinals by converting `Time.Gregorian.info(moment, Time.FORMAT_SHORT)` fields into a timezone-neutral serial date. One safe implementation is to feed local `year/month/day` at UTC noon to `Time.Gregorian.moment()` and divide the difference by 86,400. Do not subtract local midnight epoch guesses.

### Countdown

Let `delta = nextActionUtc - nowUtc`.

- If `delta > 0`, days are `floor(delta / 86400)` and hours are `floor((delta % 86400) / 3600)`. Below one hour, display minutes.
- If `delta == 0`, display “Due now.”
- If `delta < 0`, apply the same decomposition to `abs(delta)` and display “Overdue by …”.
- The compact glance rounds **up** to the next whole day above 24 hours, uses hours below 24 hours, and uses “now” at zero/overdue; it must never say “1d” when the action is already overdue.
- Recompute on every draw/resume and when minute boundaries matter; do not run a continuous animation timer.

## 6. Time and calendar rules

Use [`Time.now()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Time.html), `Time.Moment`, [`Time.Gregorian.info()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Time/Gregorian.html), and `Time.Gregorian.moment()` (all API 1.0.0). `Gregorian.info(moment, Time.FORMAT_SHORT)` returns the current device-local calendar fields; `Gregorian.utcInfo()` returns UTC fields. `Gregorian.moment(options)` interprets its fields as UTC, so it is **not** directly a local-date constructor.

### Creating a future local-calendar deadline

`addLocalCalendarDays()` must preserve the insertion/removal wall-clock intent across DST:

1. Extract the source local fields with `Gregorian.info`.
2. Add `N` to the calendar date in a timezone-neutral representation, retaining hour/minute.
3. Start with `sourceUtc + N * 86400` as a candidate.
4. Search a bounded window around it—at least ±4 hours, at minute resolution—using `Gregorian.info(candidate)` until its local fields equal the target tuple.
5. If two instants match an ambiguous fall-back time, choose the one closest to `sourceUtc + N * 86400`; if tied, choose the earlier instant. Persist the chosen UTC deadline, so later recomputation cannot flip it.
6. If no instant matches a spring-forward nonexistent time, choose the first valid local minute after the requested wall time and persist `dstAdjustment = "advancedToValidLocalTime"`. Show a one-time informational message.

This bounded search is inexpensive because it runs only on event/edit, never on every draw. Write unit tests in a simulator time zone that observes DST.

For a standalone settings/picker wall tuple that has no source instant, create a UTC-shaped value with `Gregorian.moment(targetFields)`, subtract the current `System.getClockTime().timeZoneOffset` in seconds to seed the candidate, and apply the same ±4-hour round-trip search. `timeZoneOffset` is already documented as the current offset from UTC; do not add the separate `dst` field. The offset is only a seed—acceptance still depends on `Gregorian.info(candidate)` exactly matching the selected local tuple.

### Time-zone changes

Once a deadline is created, its UTC epoch is authoritative. Travel or a phone time-zone update changes how that instant is displayed locally; it does not silently shift the action to the same clock reading in the new zone. This prevents an offline watch from rewriting the plan. The status screen may show “Times shown in current local time.” A user who wants to preserve the wall-clock time after travel uses Adjust dates.

When editing a date/time, show the local value, convert the selected wall tuple with the same round-trip search, validate it, and persist both the selected tuple and chosen UTC instant.

### Clock changes and invalid time

- A manual backward clock change may make a previously sent reminder appear in the future. The reminder ledger prevents a duplicate for the same cycle/action/kind.
- A large forward jump evaluates all missed candidates but posts only the highest-priority current notification; do not emit a burst.
- Leap days and month/year boundaries are ordinary calendar arithmetic cases.
- Seconds are normalized to zero for picker and settings edits. “Now” actions preserve current seconds.

## 7. Foreground watch application

The primary view and every secondary screen are specified in [UI.md](UI.md).

### Main view

The main view displays:

- a full-cycle progress arc: ring-in accent for `daysIn`, ring-free accent for `daysOut`, and a marker for today/current progress;
- phase label `RING IN`, `RING-FREE`, or `OVERDUE`;
- action and large countdown, such as “Remove in / 5d 3h” or “Insert in / 2d”;
- local date and time of the next action;
- a temporary-out timer and priority warning when applicable.

The progress arc is a schedule visualization, not a medical-effectiveness meter. If overdue, stop the marker at the end and render an amber/red halo rather than looping into a new cycle automatically.

### Menu2

Use [`WatchUi.Menu2`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Menu2.html) (API 3.0.0). Items, in order:

1. `Ring inserted now`
2. `Ring removed now`
3. `Ring out temporarily` or, while open, `Ring back in`
4. `Adjust dates`
5. `Settings`
6. `History`
7. `About / Disclaimer`

Disable actions that make no state sense and include a short reason in the item sublabel where supported. Examples: no “removed now” before insertion; no second temporary-out start while one is open.

### Confirmations and edits

Use [`WatchUi.Confirmation`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Confirmation.html) (API 1.0.0) before all state changes:

- insertion/replacement;
- removal;
- temporary out/back in;
- accepting an adjusted timestamp;
- deleting or clearing history;
- resetting settings.

The confirmation includes the exact local date/time and the consequence (“Starts a new cycle and archives the current one”). Confirmation result `CONFIRM_YES` commits; `CONFIRM_NO` or Back does nothing.

Use a custom [`WatchUi.Picker`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/Picker.html) and `PickerFactory` (API 1.2.0) for date and time. Validate the assembled tuple only after all columns are selected. Dates may not predate the previous archived cycle unless the user also confirms replacing overlapping history.

### Button and touch map

Implement common navigation through [`WatchUi.BehaviorDelegate`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/BehaviorDelegate.html) (API 1.0.0), adding `InputDelegate` only for gestures not represented by behaviors.

| Input | Main view | Menu/list | Picker/dialog |
|---|---|---|---|
| START/ENTER | Open Menu2; select tapped primary alert when visible | Select item | Accept focused value/Yes |
| BACK/LAP | Exit app from root | Pop/cancel without saving | Cancel/no change |
| UP | Open compact schedule detail | Previous item | Increment/previous value |
| DOWN | Open compact schedule detail | Next item | Decrement/next value |
| Long UP/MENU | Open Menu2 | Open context menu if defined | No destructive shortcut |
| LIGHT | Leave to system backlight behavior | Same | Same |
| Tap | Open Menu2 or activate a clearly drawn control | Select item | Select/confirm target |
| Swipe up/down | Detail/menu navigation | Scroll | Change focused value |
| Swipe right | Back | Back | Cancel |

Do not intercept LIGHT. Never require touch; every operation must be possible with the five buttons. Avoid mapping state changes to long press or double tap.

## 8. Glance

Implement [`AppBase.getGlanceView()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#getGlanceView-instance_function) and [`WatchUi.GlanceView`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/GlanceView.html) (API 3.1.0). API 4.0+ device apps need a glance to appear in the glance loop.

Content is one semantic line plus a mini progress bar:

- `Ring: remove in 5d`
- `Ring: insert in 8h`
- `Ring: overdue 2h`
- `Ring: out 1h 42m`
- `Ring: setup needed`

Use `Graphics.FONT_GLANCE` where available (API 3.1.8), with a built-in fallback selected at compile time for targets that lack it; all current targets have it. The glance is read-only. Selecting it launches the foreground app through normal platform behavior; `onStart(state)` may include `:launchedFromGlance`.

Glance constraints are deliberate: one `GlanceView`, no page controls or view layers, no animations, no history loading, and no notifications. Read only the small active/config record and derive once in `onUpdate`.

## 9. Background service and reminders

### What Connect IQ actually supports

On these CIQ 5.2 watches, the app can post a native Connect IQ app notification from background with [`Notifications.showNotification()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Notifications.html#showNotification-instance_function), introduced in API 5.1.0. Garmin’s [Notifications core topic](https://developer.garmin.com/connect-iq/core-topics/notifications/) and SDK Notifications sample call it from `System.ServiceDelegate.onTemporalEvent`. The device controls the native presentation and notification center behavior.

[`Background.requestApplicationWake()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html#requestApplicationWake-instance_function) (API 2.3.0) is different: after the service exits, it displays a system confirmation asking whether to launch the app. It is not a silent app launch and should not be the routine reminder mechanism.

`System.exit()` ends the foreground application. It is not part of the service lifecycle and must not be called from background. A background invocation must terminate with [`Background.exit(data)`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html#exit-instance_function) (API 2.3.0), including after posting a notification or requesting a wake.

### Registration

From the foreground app, register one repeating temporal event:

```text
Background.registerForTemporalEvent(new Time.Duration(60 * 60))
```

[`Background.registerForTemporalEvent()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html#registerForTemporalEvent-instance_function) is API 2.3.0, permits only one temporal event per app, and enforces a 5-minute minimum. An hourly duration balances reminder latency and battery cost. Registration is idempotent and is refreshed after reminder settings change. Catch `Background.InvalidBackgroundTimeException` and show a nonfatal settings warning.

A temporal event is approximate: the OS can defer it, terminate a service that exceeds 30 seconds, or suppress work under resource pressure. Product copy must say “Reminders may be delayed; do not rely on the app as the only reminder.”

### Reminder policy

For the current `nextActionUtc`, calculate local reminder instants using the configured local hour/minute:

| Candidate | Due rule | Priority |
|---|---|---:|
| Ring-free interval exceeded | Actual removal + 7 calendar days has passed | 1, highest |
| Temporary out >3h | Open interval elapsed is strictly >3h | 2 |
| Beyond labelled 4 weeks | Ring remains recorded in strictly after the 28-day boundary; once per cycle | 3 |
| Action overdue | `now >= nextActionUtc`, repeated by slot | 4 |
| Day-of | Reminder time on the local calendar date of action | 5 |
| Day-before | Reminder time on the prior local calendar date | 6 |

An overdue slot is `floor((nowUtc - nextActionUtc) / (repeatHours * 3600))`. Send once per new slot, beginning with slot 0, using the persisted ledger. The escalating ring-free warning is emitted once at the 7-day ceiling, then replaces ordinary overdue text on later repeat slots. Temporary-out warnings may repeat at the configured interval while still open, but do not state that the ring is ineffective.

Suppress a day-before/day-of candidate if its configured local time is at or after an action deadline that has already passed; the current due/overdue candidate is the truth at that point. This means a reminder time later than the scheduled action time may go directly from day-before to due/overdue copy.

On every hourly wake:

1. Load and validate only the active cycle, reminder configuration, and ledger.
2. Derive status from `Time.now()`.
3. Build all candidates currently due but not recorded sent.
4. Choose the single highest-priority candidate. Never post a catch-up burst.
5. Call `Notifications.showNotification(title, subtitle, options)` with localized strings, a small monochrome icon, `:body`, compact `:data`, and `:dismissPrevious => true` so an updated reminder replaces this app’s stale one. With no custom action list, the documented default launch/dismiss actions are sufficient; the default launch returns `:data` in `onStart` as `:launchedFromNotification`.
6. Persist the ledger only after the notification call succeeds. If persistence fails, accept a possible later duplicate rather than recording a notification that was never posted.
7. Call `Background.exit(null)` exactly once from a finally-equivalent path for a notification-only run. The native notification’s launch data already travels through `:launchedFromNotification`, so passing the same payload as background data would make a later ordinary app launch look like a selected reminder.

The native notification’s `:data` identifies only a cycle and alert kind; it contains no medical detail. If `Notifications.showNotification()` throws or is unavailable despite the supported-device contract, optionally call `Background.requestApplicationWake()` with a message below 255 bytes, then call `Background.exit({ :kind => ..., :cycleId => ..., :at => ..., :expiresUtc => ... })`. Keep that data far below its approximately 8 KiB limit and expire it after 10 minutes. This fallback displays a confirmation, not a notification equivalent. Do not repeatedly request application wake.

### Vibration and tone limits

`Notifications.showNotification()` exposes title, subtitle, body, icon, data, actions, and dismissal behavior; it does not expose per-notification sound or vibration controls. The Garmin OS and user device settings govern native-notification attention. Therefore the in-app “Vibration” and “Sound” settings apply only to the foreground alert shown after launch. The UI must explain this limitation instead of claiming that these switches mute or enable the background notification.

[`Attention.vibrate()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention.html#vibrate-instance_function) and [`Attention.playTone()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention.html#playTone-instance_function) are API 1.0.0 foreground facilities. Do not reference them from `(:background)` code. Before use, respect both the app toggle and relevant device settings/capability checks. Use one short vibration pattern and at most one tone; no repeating alarm loop.

### Launching from a reminder

For a native notification, `AppBase.onStart(state)` receives launch context including `state[:launchedFromNotification]` and the notification action data. For request-wake fallback, service data is delivered to [`AppBase.onBackgroundData()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#onBackgroundData-instance_function) (API 2.3.0), immediately if the app is running or cached for next start.

The app must:

1. validate the cycle ID, alert kind, and optional expiry against current storage;
2. install/return the normal root view first;
3. then use [`WatchUi.pushView()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi.html#pushView-instance_function) (API 1.0.0) to show an alert-detail view, or make that detail the initial view if lifecycle ordering requires it;
4. call foreground Attention APIs only after the view is active and only if enabled;
5. show the live derived state, not stale notification text.

Register `Notifications.registerForNotificationMessages()` in the foreground only if local selection/dismissal feedback is useful. Reminder-posting deduplication must not depend on that callback, and no feedback is transmitted.

## 10. Garmin Connect / Connect IQ mobile-side settings

Connect IQ App Settings are declarative properties edited in the Connect IQ Store app, Garmin Connect, or Garmin Express and synchronized to the watch. They are not a custom companion UI. This version has no channel for pushing live ring status or watch events to the phone. Doing that would require a deliberately designed companion/mobile integration and additional permissions/infrastructure, which are out of scope.

Within Garmin’s stock apps, the only limited status surface would be one or more declared, read-only App Settings properties written on the watch. They can be shown when the phone opens the app’s Settings while connected/synchronized, but they are not a proactive phone push, a phone notification, or a reliably current dashboard. Version 1 deliberately exposes only editable configuration and the insertion mirror listed below, not a status summary.

The current App Settings schema supports `list`, `boolean`, `numeric`, `alphaNumeric`, `phone`, `email`, `url`, `date`, and `password`. There **is** a native `date` control backed by a numeric property, but there is no native **time** or combined **date-time** control. Garmin also cautions that a native date property is stored in UTC and should be interpreted with `Gregorian.utcInfo()`.

For one atomic insertion date-time value, use an `alphaNumeric` ISO-like local string `YYYY-MM-DDTHH:mm` and validate it in the app. This is less friendly than a date picker but avoids syncing date and time fields in separate partial updates. The watch’s Adjust dates picker is the preferred entry path.

### `properties.xml`

This is the complete settings-property contract. String resource IDs are illustrative but required.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<resources xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">
    <properties>
        <property id="insertionIso" type="string"></property>
        <property id="reminderHour" type="number">9</property>
        <property id="reminderMinute" type="number">0</property>
        <property id="daysIn" type="number">21</property>
        <property id="daysOut" type="number">7</property>
        <property id="overdueRepeatHours" type="number">6</property>
        <property id="vibrationEnabled" type="boolean">true</property>
        <property id="soundEnabled" type="boolean">false</property>
        <property id="clockFormat" type="number">0</property>
    </properties>
</resources>
```

### `settings.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<resources xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
           xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">
    <settings>
        <setting propertyKey="@Properties.insertionIso"
                 title="@Strings.SetInsertionDateTimeTitle"
                 prompt="@Strings.SetInsertionDateTimePrompt">
            <settingConfig type="alphaNumeric"
                           maxLength="16"
                           errorMessage="@Strings.InsertionDateTimeError" />
        </setting>

        <setting propertyKey="@Properties.reminderHour"
                 title="@Strings.ReminderHourTitle">
            <settingConfig type="numeric" min="0" max="23" />
        </setting>

        <setting propertyKey="@Properties.reminderMinute"
                 title="@Strings.ReminderMinuteTitle">
            <settingConfig type="numeric" min="0" max="59" />
        </setting>

        <setting propertyKey="@Properties.daysIn"
                 title="@Strings.DaysInTitle"
                 prompt="@Strings.DaysInPrompt">
            <settingConfig type="numeric" min="21" max="35" />
        </setting>

        <setting propertyKey="@Properties.daysOut"
                 title="@Strings.DaysOutTitle"
                 prompt="@Strings.DaysOutPrompt">
            <settingConfig type="numeric" min="0" max="7" />
        </setting>

        <setting propertyKey="@Properties.overdueRepeatHours"
                 title="@Strings.OverdueRepeatTitle">
            <settingConfig type="list">
                <listEntry value="1">@Strings.Repeat1Hour</listEntry>
                <listEntry value="3">@Strings.Repeat3Hours</listEntry>
                <listEntry value="6">@Strings.Repeat6Hours</listEntry>
                <listEntry value="12">@Strings.Repeat12Hours</listEntry>
                <listEntry value="24">@Strings.Repeat24Hours</listEntry>
            </settingConfig>
        </setting>

        <setting propertyKey="@Properties.vibrationEnabled"
                 title="@Strings.VibrationTitle"
                 prompt="@Strings.ForegroundAttentionPrompt">
            <settingConfig type="boolean" />
        </setting>

        <setting propertyKey="@Properties.soundEnabled"
                 title="@Strings.SoundTitle"
                 prompt="@Strings.ForegroundAttentionPrompt">
            <settingConfig type="boolean" />
        </setting>

        <setting propertyKey="@Properties.clockFormat"
                 title="@Strings.ClockFormatTitle">
            <settingConfig type="list">
                <listEntry value="0">@Strings.ClockSystem</listEntry>
                <listEntry value="12">@Strings.Clock12Hour</listEntry>
                <listEntry value="24">@Strings.Clock24Hour</listEntry>
            </settingConfig>
        </setting>
    </settings>
</resources>
```

The insertion prompt must say `YYYY-MM-DDTHH:mm, local time`. XML constrains only length, not the pattern or real calendar validity. Implement [`AppBase.onValidateProperty()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#onValidateProperty-instance_function) (API 4.1.0) to return a localized error string for malformed/impossible insertion values, and still validate defensively when reading properties. Reject DST-invalid times or years outside a documented range such as current year ±2. Never silently normalize `2026-02-31`.

### Settings flow and reconciliation

Use [`AppBase.onSettingsChanged()`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#onSettingsChanged-instance_function) (API 1.2.0) when settings arrive while the app runs, and read properties at startup for changes delivered while it was closed. Access values through [`Application.Properties.getValue/setValue`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Properties.html) (API 2.4.0).

Storage is the canonical schedule. The conflict rule is “watch wins unless a genuinely changed settings value is observed after the latest watch edit”:

1. Persist `lastSeenInsertionIso`, `lastWatchScheduleEditUtc`, and `lastSettingsObservationUtc` in Storage.
2. A watch insertion or Adjust dates edit first writes canonical Storage, `lastWatchScheduleEditUtc`, and `pendingMirrorIso`. It then writes the formatted ISO value to `Application.Properties`, and finally writes `lastSeenInsertionIso` and clears the pending mirror. Storage and Properties have no shared transaction; if startup sees `pendingMirrorIso`, it completes that mirror before performing snapshot comparison.
3. At startup or `onSettingsChanged`, if `insertionIso == lastSeenInsertionIso`, it is merely the mirror or an unchanged/stale sync; do not overwrite Storage.
4. If it differs and parses/round-trips successfully, treat that detection time as a settings edit. Because it was observed after the last local edit, ask for confirmation if the foreground app is open, then accept it, recompute deadlines, set both observation and accepted values, and update `lastSeenInsertionIso`.
5. If invalid, retain the watch schedule, store a bounded pending error for the next foreground opening, and mirror the last accepted ISO back only after showing the error. Never clear an active cycle because the field arrived empty accidentally; an explicit Reset on watch is required.

There is no source timestamp or revision supplied with an App Settings property. A long-delayed stale phone sync can therefore look new. This cannot be solved perfectly with declarative settings; show both timestamps in the confirmation whenever a remote value would replace an active watch schedule.

Other configuration properties use the same snapshot-diff method, but valid changed values may be accepted without a medical-state confirmation. A watch Settings edit mirrors to Properties and refreshes its snapshot so it is not mistaken for a phone edit. Changing `daysIn/daysOut` during a cycle must show a confirmation and recompute only future deadlines; archived history keeps its snapshot.

## 11. Localization and copy

English is the only shipped language (`eng`) for version 1. All user-visible text must nevertheless live in `resources/strings/strings.xml`, including:

- menu, dialog, phase, unit, settings, error, disclaimer, and accessibility text;
- notification title/subtitle/body strings;
- labels embedded in list settings.

Mark strings and drawable resources needed by the service with the appropriate `scope="background"`, following Garmin’s resource-scope rules, so the background compiler includes only what it needs. Do not concatenate English grammar from fragments where word order would block future localization; use format templates for complete phrases.

Dates use the user’s configured ordering where a platform formatter is available; otherwise use an unambiguous localized short form plus weekday. Respect device 12/24-hour format when `clockFormat == 0`.

## 12. Visual system and AMOLED behavior

Palette on true black `#000000`:

| Role | Color |
|---|---|
| Primary text | `#F4F7F8` |
| Secondary text | `#9AA6AD` |
| Inactive track/dividers | `#20262C` |
| Ring-in accent | `#38D6A0` |
| Ring-free accent | `#9C7CFF` |
| Due/attention amber | `#FFB020` |
| Serious overdue red | `#FF4D5E` |

Use Garmin system fonts and vector primitives, not custom font assets or full-screen bitmaps. Garmin’s [AMOLED guidance](https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/) explains that non-black pixels consume power and that true black is useful. Its always-on burn-in shift rules are specifically for watch faces; this product is a foreground device app, not an always-on watch face. Still avoid unnecessary seconds animation, large white fills, and redraws when content has not changed.

## 13. Memory and performance budget

Targets, stricter than the platform maximum:

- foreground steady-state under 500 KiB, leaving headroom for menus/pickers;
- glance under 40 KiB;
- background under 40 KiB;
- persisted `state` under 24 KiB to remain comfortably below the 32 KiB per-value limit.

Tactics:

- draw the arc and icons with `Graphics.Dc`; no background image;
- use built-in `Graphics.FONT_*` resources;
- load only the visible history row/page and build labels lazily;
- store compact numeric codes instead of duplicate display strings;
- keep service code/resource annotations isolated;
- avoid `Lang.format()` and large temporary arrays in the background hot path where direct formatting suffices;
- profile all three products because font metrics and native sizes differ.

## 14. Manifest

Only `Background` and `Notifications` permissions are required. Storage, Attention, UI, and App Settings do not require permissions. Do not request Communications, Positioning, Sensor, UserProfile, or Health History.

```xml
<?xml version="1.0"?>
<iq:manifest version="3" xmlns:iq="http://www.garmin.com/xml/connectiq">
    <iq:application id="REPLACE_WITH_PROJECT_UUID"
                    type="watch-app"
                    name="@Strings.AppName"
                    entry="RingTrackerApp"
                    launcherIcon="@Drawables.LauncherIcon"
                    minApiLevel="5.1.0">
        <iq:products>
            <iq:product id="epix2pro42mm" />
            <iq:product id="epix2pro47mm" />
            <iq:product id="epix2pro51mm" />
        </iq:products>
        <iq:permissions>
            <iq:uses-permission id="Background" />
            <iq:uses-permission id="Notifications" />
        </iq:permissions>
        <iq:languages>
            <iq:language>eng</iq:language>
        </iq:languages>
        <iq:barrels />
    </iq:application>
</iq:manifest>
```

API 5.1.0 is selected because native `Toybox.Notifications` first appears there. All three target products support API 5.2.

## 15. API compatibility matrix

Every API relied upon here exists in the current official documentation:

| API | Minimum API | Use |
|---|---:|---|
| [`Application.Storage.getValue/setValue`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Storage.html) | 2.4.0 | Canonical persistent state |
| [`Application.Properties.getValue/setValue`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/Properties.html) | 2.4.0 | App Settings bridge |
| [`Application.AppBase.onSettingsChanged`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#onSettingsChanged-instance_function) | 1.2.0 | Live settings update |
| [`Application.AppBase.onValidateProperty`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#onValidateProperty-instance_function) | 4.1.0 | Reject malformed mobile setting values |
| [`Application.AppBase.getServiceDelegate`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html#getServiceDelegate-instance_function) | 2.3.0 | Supply the background delegate |
| `Application.AppBase.onBackgroundData` | 2.3.0 | Request-wake/service launch payload |
| `Application.AppBase.getGlanceView` | 3.1.0 | Device-app glance |
| [`Background.registerForTemporalEvent`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html#registerForTemporalEvent-instance_function) | 2.3.0 | Hourly wake |
| `Background.requestApplicationWake` | 2.3.0 | Confirmation-to-launch fallback only |
| `Background.exit` | 2.3.0 | End service and pass compact data |
| [`System.ServiceDelegate.onTemporalEvent`](https://developer.garmin.com/connect-iq/api-docs/Toybox/System/ServiceDelegate.html#onTemporalEvent-instance_function) | 2.3.0 | Temporal callback |
| [`Notifications.showNotification`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Notifications.html#showNotification-instance_function) | 5.1.0 | Native app notification |
| `Notifications.registerForNotificationMessages` | 5.1.0 | Foreground action/dismiss callback |
| `Attention.vibrate/playTone` | 1.0.0 | Foreground attention only |
| `Time.now`, `Time.Moment` | 1.0.0 | UTC instant arithmetic |
| `Time.Gregorian.info/moment/utcInfo` | 1.0.0 | Local and UTC calendar fields |
| [`System.getClockTime`](https://developer.garmin.com/connect-iq/api-docs/Toybox/System.html#getClockTime-instance_function) | 1.0.0 | Seed local-wall-time conversion |
| `WatchUi.View`, `pushView/popView` | 1.0.0 | Foreground view stack |
| `WatchUi.BehaviorDelegate` | 1.0.0 | Button/touch-independent navigation |
| `WatchUi.Menu2` | 3.0.0 | Main menu |
| `WatchUi.Confirmation` | 1.0.0 | State-change confirmation |
| `WatchUi.Picker/PickerFactory` | 1.2.0 | Date/time adjustment |
| `WatchUi.GlanceView` | 3.1.0 | Glance renderer |
| [`Graphics.Dc.drawArc`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html#drawArc-instance_function) | 1.2.0 | Progress arc |
| [`Graphics.getFontHeight`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics.html#getFontHeight-instance_function) / [`Graphics.Dc.getTextWidthInPixels`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics/Dc.html#getTextWidthInPixels-instance_function) | 1.2.0 / 1.0.0 | Measured adaptive typography |
| `Graphics.FONT_GLANCE` | 3.1.8 | Glance text |
| [`Toybox.Test`](https://developer.garmin.com/connect-iq/api-docs/Toybox/Test.html) | 2.1.0 | Simulator unit tests |

## 16. Test plan

### Unit tests

Use Connect IQ’s `Toybox.Test` module. Test methods carry `(:test)`, accept a `Test.Logger`, use `Test.assert`/`Test.assertEqual`, and return `true`. Run a unit-test build in the simulator/Run No Evil environment.

Date-math cases:

- standard insertion at 09:00 produces removal on the same weekday/time after 21 local days and insertion after 28;
- `daysIn = 28`, `daysOut = 0`, and `daysIn = 35` produce correct distinct actions/badges;
- a 35-day configured plan stays in its configured phase after day 28 but gains the once-per-cycle FDA-label-boundary warning;
- leap day, end of month, end of year, and leap-year boundaries;
- spring-forward nonexistent selected time and fall-back ambiguous time follow the documented rule;
- current device time-zone display changes without changing persisted UTC deadlines;
- local day-of-cycle at 23:59, midnight, and after east/west travel;
- phase one second before, exactly at, and one second after every deadline;
- temporary-out at 2:59:59, 3:00:00, and 3:00:01;
- ring-free interval at 6d 23:59:59, exactly 7d, and 7d plus one second;
- early removal, late removal, and a removal after the anchored insertion deadline;
- countdown rounding at 25h, 24h, 1h, 59m, zero, and negative values.

State/storage cases:

- first run and default values;
- each valid state transition and cancel path;
- replacing immediately closes exactly one history record;
- open temporary interval survives restart;
- history evicts the oldest whole record at 25 entries;
- corrupt record recovery, unknown newer schema, and `StorageFullException` behavior;
- watch edit/mirror does not return as a false settings edit;
- valid changed ISO setting wins only after detection/confirmation, and an interrupted pending mirror resumes without becoming a false phone edit;
- invalid, empty, stale, and DST-invalid ISO strings do not overwrite the watch schedule.

Reminder-policy cases:

- day-before and day-of candidate construction at configured local time;
- overdue slot deduplication for every allowed repeat interval;
- highest-priority-only behavior when multiple reminders were missed;
- no burst after reboot or a multi-day forward clock jump;
- replacement notification data contains no sensitive status detail;
- ledger updates only after successful notification posting;
- background exit is reached on success, no-op, storage error, and notification error paths.

### Manual simulator matrix

Run each of these on the 42, 47, and 51 mm simulator profiles:

1. First-run disclaimer, setup, and default 21/7 main screen.
2. Every menu action by buttons only, then by touch only.
3. Confirmation cancel/accept and picker cancel/accept.
4. Long labels, largest countdowns, 12/24-hour formats, and all warning colors on every resolution.
5. Glance loop display and launch from glance.
6. Use simulator date/time and time-zone settings to travel to the day-before, day-of, exact deadline, several overdue repeat slots, DST spring-forward, and DST fall-back.
7. Trigger a temporal background event from the simulator’s Simulation menu. Verify a native notification is posted, only one recent notification remains, selecting it opens the live alert detail, and dismissal does not mutate cycle state.
8. Force a request-wake fallback and verify it shows a confirmation rather than masquerading as a native notification.
9. Disable phone/Bluetooth, restart the watch app, and verify stored schedule/history and local reminders still work.
10. Change App Settings while the foreground app is open and closed; test sync delays and conflict confirmation.
11. Profile foreground, background, and glance memory individually, including 24 history records and 64 temporary intervals.
12. Leave the app open across minute/day boundaries; confirm restrained redraw behavior and no seconds animation.

### Release gates

- No medical copy ships without review against the current product label.
- No state-changing path bypasses confirmation.
- All boundary, DST, storage-failure, and reminder-dedup tests pass.
- Peak process memory remains at least 20% below each platform limit.
- A physical epix Pro verifies notification presentation, launch context, tone/vibration behavior, App Settings sync, and temporal-event delay; simulator behavior alone is insufficient.

## 17. Known risks

| Risk | Consequence | Mitigation/product wording |
|---|---|---|
| Temporal wakes and notification delivery are not guaranteed or exact | A reminder can be delayed or absent | Hourly evaluation, persisted dedup ledger, day-before reminder, explicit “do not rely on this as your only reminder” copy |
| Native notification sound/vibration is OS-controlled | In-app toggles cannot guarantee notification attention | Label toggles “when app opens”; respect device settings; test physical watch |
| App Settings has no combined date-time control | ISO entry is error-prone | Prefer watch Picker; validate and round-trip; never silently normalize |
| Settings properties have no source revision/timestamp | Delayed stale phone value may look new | Storage canonical; snapshot-diff; watch mirrors atomically; foreground confirmation on schedule replacement |
| No reliable stored time-zone identifier | Travel semantics can surprise | Persist UTC deadline and original wall tuple; show current-local rendering; Adjust dates explicitly |
| 35-day advice differs from FDA-labelled duration | App could imply unsupported efficacy | Clearly badge 29–35 days as outside FDA label; require acknowledgement; never claim protection |
| Annovera uses a different temporary-out rule | Applying 3-hour logic would be unsafe | Explicitly unsupported in setup/About; no Annovera product choice |

## 18. Official Connect IQ references

- [Connect IQ Programmer’s Guide / Core Topics](https://developer.garmin.com/connect-iq/core-topics/)
- [Backgrounding core topic](https://developer.garmin.com/connect-iq/core-topics/backgrounding/)
- [Notifications core topic](https://developer.garmin.com/connect-iq/core-topics/notifications/)
- [Properties and App Settings core topic](https://developer.garmin.com/connect-iq/core-topics/properties-and-app-settings/)
- [Glances core topic](https://developer.garmin.com/connect-iq/core-topics/glances/)
- [Connect IQ API documentation](https://developer.garmin.com/connect-iq/api-docs/)
