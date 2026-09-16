# Ring Tracker v1.1 delta specification

Status: implementation-ready delta to `SPEC.md`, `UI.md`, `REGIMEN.md`, and `IMPLEMENTATION.md`
Target: epix Pro (Gen 2) 42/47/51 mm; 390/416/454 px
Product scope: NuvaRing only

This document is normative where it differs from the v1.0 documents. Unchanged v1.0 storage safety, DST resolution, confirmation, privacy, memory, glance, and background-process constraints still apply. NuvaRing's current prescribing information says that a new ring is inserted one week after the last ring was removed; v1.1 therefore anchors each due date to the actual preceding event, not to an older projection. Source: [DailyMed, section 2.1](https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=19ef66d1-913f-49a8-a0a5-59b4e20322f5).

## Release decisions

- Main is status, not explanation: arc, phase, countdown, action date/time, and at most one warning block.
- NuvaRing is the only named/supported ring. Generic, EluRyng, and Annovera text is removed except one exclusion line in About.
- Reminder 1 is always enabled. Reminder 2 is optional. Both are calendar-day reminders for removal and insertion; the day-before reminder remains one optional reminder at Reminder 1's time.
- Actual insertion anchors `removeDueUtc`; actual removal anchors `insertDueUtc`. A confirmed event moves every downstream projection.
- The 7-day ring-free and 28-day ring-in boundaries are warnings only. They do not replace either event anchor.
- The planned-action override and Schedule detail screen are removed. `Edit dates` corrects only actual insertion/removal timestamps. `Upcoming` replaces Schedule detail.
- Main UP opens future cycles; Main DOWN opens past cycles. UP/DOWN remain scroll controls after entering either list.

## A. Copy contract and complete v1.0 audit

### Copy rules

- Use sentence case except compact phase/action words.
- A main-screen phrase should be about five words or fewer. The three mandatory safety warnings may wrap as one warning block.
- Use `Ring in`, `Ring free`, and `Ring out`; use `early`, `late`, and `On time` for event variance.
- Do not use `recorded`, `scheduled`, `plan`, `deadline`, `FDA-labelled`, `label-directed`, or `product instructions` in ordinary UI.
- The scheduling/medical limitation appears only on first run and in About. Short actionable threshold warnings are allowed where the threshold is active.
- Omit controls that are invalid for the current state. Do not explain disabled actions with sublabels.
- Delete `MENU • START`, `press START`, picker `START/BACK`, and `BACK` footers. START/tap already performs the visible/native action; hardware labels repeat a platform convention and consume the most valuable round-screen area.
- About must contain exactly one exclusion line: `Not for generics or Annovera.` No other shipped string may mention either generics, EluRyng, or Annovera.
- First run and About use the same three safety lines:
  1. `Schedule aid, not medical advice.`
  2. `Cannot determine contraceptive effectiveness.`
  3. `Follow NuvaRing instructions. Ask a clinician or pharmacist if a ring is late, out too long, or pregnancy is possible.`

The audit below contains all 283 current `<string>` elements. `DELETE` means remove the resource and all call sites. Placeholder tokens remain positional. A line break in a resource is shown as `<br>`.

### Settings, setup, and actions

| ID | Current string | v1.1 string |
| --- | --- | --- |
| `AppName` | `Ring Tracker` | `Ring Tracker` |
| `SetInsertionDateTimeTitle` | `Insertion date and time` | `Insertion date & time` |
| `SetInsertionDateTimePrompt` | `YYYY-MM-DDTHH:mm, local time` | `YYYY-MM-DDTHH:mm, local time` |
| `InsertionDateTimeError` | `Enter a valid local date and time: YYYY-MM-DDTHH:mm` | `Use YYYY-MM-DDTHH:mm local time.` |
| `SettingValueError` | `Enter a value within the documented range.` | `Choose a valid value.` |
| `DstAdjustmentTitle` | `Schedule adjusted` | `Time adjusted` |
| `DstAdjustmentBody` | `A selected local time did not exist because of a daylight-saving change. The deadline was moved to the first valid local minute.` | `That local time did not exist. Moved to the next valid minute.` |
| `ReminderHourTitle` | `Reminder hour` | `Reminder 1 hour` |
| `ReminderMinuteTitle` | `Reminder minute` | `Reminder 1 minute` |
| `DaysInTitle` | `Days ring in` | `Days ring in` |
| `DaysInPrompt` | `Use only if this matches your product instructions or clinician's plan.` | `Use only with your clinician's advice.` |
| `DaysOutTitle` | `Days ring-free` | `Days ring-free` |
| `DaysOutPrompt` | `Zero means replace immediately. Use only if this matches your plan.` | `0 means replace immediately.` |
| `OverdueRepeatTitle` | `Repeat overdue` | `Overdue repeat` |
| `Repeat1Hour` | `1 hour` | `1 hour` |
| `Repeat3Hours` | `3 hours` | `3 hours` |
| `Repeat6Hours` | `6 hours` | `6 hours` |
| `Repeat12Hours` | `12 hours` | `12 hours` |
| `Repeat24Hours` | `24 hours` | `24 hours` |
| `VibrationTitle` | `Vibration` | `Vibration` |
| `SoundTitle` | `Sound` | `Sound` |
| `ForegroundAttentionPrompt` | `When an alert opens; notification behavior is controlled by the watch.` | `When the app opens.` |
| `ClockFormatTitle` | `Clock` | `Clock` |
| `ClockSystem` | `System` | `System` |
| `Clock12Hour` | `12-hour` | `12-hour` |
| `Clock24Hour` | `24-hour` | `24-hour` |
| `Am` | `AM` | `AM` |
| `Pm` | `PM` | `PM` |
| `Loading` | `Loading` | DELETE |
| `MenuTitle` | `Menu` | `Menu` |
| `ScheduleAidTitle` | `Schedule aid` | `Ring Tracker` |
| `DisclaimerLine1` | `This app is a scheduling aid, not medical advice.` | `Schedule aid, not medical advice.` |
| `DisclaimerLine2` | `It cannot determine whether contraception is effective.` | `Cannot determine contraceptive effectiveness.` |
| `DisclaimerLine3` | `Follow the instructions supplied with your ring and contact a qualified clinician or pharmacist if a ring is late, has been out too long, or pregnancy is possible.` | `Follow NuvaRing instructions. Ask a clinician or pharmacist if a ring is late, out too long, or pregnancy is possible.` |
| `ReviewDetails` | `Review details` | DELETE |
| `StartContinue` | `START  Continue` | `Continue` |
| `ContinueQuestion` | `Continue to regimen setup?` | `Continue to setup?` |
| `RegimenTitle` | `Regimen` | `Schedule` |
| `ProductLine1` | `NuvaRing / equivalent` | `NuvaRing` |
| `ProductLine2` | `etonogestrel + EE ring` | DELETE |
| `InRing` | `In ring` | `Ring in` |
| `RingFree` | `Ring-free` | `Ring free` |
| `DaysTemplate` | `$1$ days` | `$1$ days` |
| `OneDayTemplate` | `$1$ day` | `$1$ day` |
| `AnnoveraUnsupported` | `Annovera is not supported` | `Not for generics or Annovera.` |
| `StartConfirm` | `START  Confirm` | `Confirm` |
| `ConfirmRegimenQuestion` | `Use this recorded regimen?` | `Use this schedule?` |
| `InitialInsertionTitle` | `Initial insertion` | `First ring` |
| `InsertedNow` | `Inserted now` | `Insert now` |
| `ChooseDateTime` | `Choose date & time` | `Choose date & time` |
| `RecordInsertionQuestion` | `Insert · $1$`<br>`$2$ · New cycle` | `Insert ring?`<br>`$1$ · $2$ · $3$` |
| `ReplaceRingQuestion` | `Replace · $1$`<br>`$2$ · New cycle` | `Replace ring?`<br>`$1$ · $2$ · $3$` |
| `RemoveRingQuestion` | `Remove · $1$`<br>`$2$ · Ring-free starts` | `Remove ring?`<br>`$1$ · $2$ · $3$` |
| `TempOutQuestion` | `Temp out · $1$`<br>`$2$ · Timer starts` | `Ring out?`<br>`$1$ · $2$` |
| `BackInQuestion` | `Back in · $1$`<br>`$2$ · Interval closes` | `Ring back in?`<br>`$1$ · $2$` |
| `SaveChangeQuestion` | `Save this change?` | `Save changes?` |
| `ClearHistoryQuestion` | `Clear all recorded history?` | `Clear all history?` |
| `ResetQuestion` | `Reset the schedule and settings?` | `Reset dates and settings?` |
| `RingInsertedNow` | `Ring inserted now` | `Insert ring` |
| `RingReplacedNow` | `Ring replaced now` | `Insert ring` |
| `RingRemovedNow` | `Ring removed now` | `Remove ring` |
| `RingOutTemporarily` | `Ring out temporarily` | `Ring out` |
| `RingBackIn` | `Ring back in` | `Ring back in` |
| `AdjustDates` | `Adjust dates` | `Edit dates` |
| `Settings` | `Settings` | `Settings` |
| `History` | `History` | `History` |
| `AboutDisclaimer` | `About / Disclaimer` | `About` |
| `NoCycleReason` | `Record insertion first` | DELETE |
| `AlreadyRemovedReason` | `Ring is recorded removed` | DELETE |

### Main, dates, and history

| ID | Current string | v1.1 string |
| --- | --- | --- |
| `ScheduleTitle` | `Schedule` | `Upcoming` |
| `InsertedLabel` | `Inserted` | `Inserted` |
| `RemoveLabel` | `Remove` | `Remove` |
| `InsertLabel` | `Insert` | `Insert` |
| `CycleDayLabel` | `Cycle day` | DELETE |
| `PlanLabel` | `Plan` | DELETE |
| `PlanTemplate` | `$1$ in / $2$ out` | `$1$ in / $2$ out` |
| `HistoryPlanTemplate` | `$1$ / $2$` | DELETE |
| `HistoryPlanSummaryTemplate` | `$1$ / $2$ · + summarized` | DELETE |
| `TimesCurrentLocal` | `Current local time` | DELETE |
| `BackHint` | `BACK` | DELETE |
| `PhaseRingIn` | `RING IN` | `RING IN` |
| `PhaseRingFree` | `RING-FREE` | `RING FREE` |
| `PhaseOverdue` | `OVERDUE` | DELETE |
| `RingIsOut` | `RING IS OUT` | `RING OUT` |
| `DayTemplate` | `Day $1$` | DELETE |
| `RemoveIn` | `REMOVE IN` | DELETE |
| `InsertIn` | `INSERT IN` | DELETE |
| `ReplaceIn` | `REPLACE IN` | DELETE |
| `RemoveRing` | `REMOVE RING` | `REMOVE NOW` |
| `InsertRing` | `INSERT RING` | `INSERT NOW` |
| `ReplaceRing` | `REPLACE RING` | `REPLACE NOW` |
| `Elapsed` | `ELAPSED` | DELETE |
| `MenuStartHint` | `MENU  •  START` | DELETE |
| `PressStart` | `press START` | DELETE |
| `DueNow` | `Due now` | `Now` |
| `OverdueBy` | `OVERDUE BY` | DELETE |
| `HourUnit` | `h` | `h` |
| `DayUnit` | `d` | `d` |
| `MinuteUnit` | `m` | `m` |
| `HoursShortTemplate` | `$1$h` | `$1$h` |
| `HourTemplate` | `$1$ hour` | `$1$ hour` |
| `HoursTemplate` | `$1$ hours` | `$1$ hours` |
| `Jan` | `Jan` | `Jan` |
| `Feb` | `Feb` | `Feb` |
| `Mar` | `Mar` | `Mar` |
| `Apr` | `Apr` | `Apr` |
| `May` | `May` | `May` |
| `Jun` | `Jun` | `Jun` |
| `Jul` | `Jul` | `Jul` |
| `Aug` | `Aug` | `Aug` |
| `Sep` | `Sep` | `Sep` |
| `Oct` | `Oct` | `Oct` |
| `Nov` | `Nov` | `Nov` |
| `Dec` | `Dec` | `Dec` |
| `Sun` | `Sun` | `Sun` |
| `Mon` | `Mon` | `Mon` |
| `Tue` | `Tue` | `Tue` |
| `Wed` | `Wed` | `Wed` |
| `Thu` | `Thu` | `Thu` |
| `Fri` | `Fri` | `Fri` |
| `Sat` | `Sat` | `Sat` |
| `ThreeHourInTemplate` | `3-hour boundary in $1$m` | `Put it back in` |
| `ThreeHourReached` | `3-hour limit reached; reinsert now and follow product instructions.` | `3h reached. Put it back in.` |
| `RecordedOutOver3h` | `Recorded out over 3 hours` | `Out over 3h. Reinsert now. Use backup 7 days.` |
| `ReinsertSoon` | `Reinsert as soon as possible; follow product instructions.` | `Put it back in` |
| `RingFreeLimitPassed` | `Ring-free limit passed` | `Insert now. Use backup 7 days.` |
| `RingFreeLimitReached` | `7-day limit reached` | DELETE |
| `InsertNow` | `INSERT NOW` | `INSERT NOW` |
| `TapLabelInfo` | `Tap for label information` | DELETE |
| `BeyondFourWeeks` | `Beyond FDA-labelled 4 weeks` | `Ring in over 4 weeks. Replace now.` |
| `BeyondFourWeeksLine1` | `Beyond the FDA-labelled` | DELETE |
| `BeyondFourWeeksLine2` | `4-week duration` | DELETE |
| `WatchBeforeInsertion` | `Watch time is before recorded insertion` | `Check insertion date` |
| `AdjustedBadge` | `Adjusted` | DELETE |
| `AdjustTitle` | `Adjust dates` | `Edit dates` |
| `Insertion` | `Insertion` | `Insertion` |
| `Removal` | `Removal` | `Removal` |
| `PlannedNextAction` | `Planned next action` | DELETE |
| `InsertionDate` | `Insertion date` | `Insertion date` |
| `RemovalDate` | `Removal date` | `Removal date` |
| `PlannedDate` | `Planned action date` | DELETE |
| `TimeTitle` | `Time` | `Time` |
| `NextHint` | `START Next · BACK` | DELETE |
| `ReviewHint` | `START Review · BACK` | DELETE |
| `DateSeparator` | `-` | DELETE |
| `TimeSeparator` | `:` | `:` |
| `DateTimeSeparator` | ` · ` | ` · ` |
| `RangeSeparator` | ` — ` | ` — ` |
| `NotRecorded` | `—` | `—` |
| `Ellipsis` | `…` | `…` |
| `InvalidDate` | `That date is not valid.` | `Choose a valid date.` |
| `InvalidEventOrder` | `That time conflicts with recorded event order.` | `That time conflicts with another event.` |
| `FutureEvent` | `Actual events cannot be recorded in the future.` | `Choose now or an earlier time.` |
| `DurationSettings` | `Duration settings` | DELETE |
| `ReminderTime` | `Reminder time` | `Reminder 1` |
| `DaysRingIn` | `Days ring in` | `Days ring in` |
| `DaysRingFree` | `Days ring-free` | `Days ring-free` |
| `RepeatOverdue` | `Repeat overdue` | `Overdue repeat` |
| `Vibration` | `Vibration` | `Vibration` |
| `Sound` | `Sound` | `Sound` |
| `Clock` | `Clock` | `Clock` |
| `On` | `On` | `On` |
| `Off` | `Off` | `Off` |
| `ReplaceImmediately` | `Replace immediately` | `Replace now` |
| `ForegroundOnlyFooter` | `When alert opens; notification behavior is controlled by the watch` | DELETE |
| `ResetApp` | `Reset app` | `Reset app` |
| `ExtendedUseNotice` | `Use only if this matches your product instructions or clinician's plan.` | `Use only with your clinician's advice.` |
| `OutsideLabelNotice` | `Outside FDA-labelled duration. Use only if this matches your clinician's plan.` | `Over 4 weeks. Use only with your clinician's advice.` |
| `OutsideLabelBadge` | `Outside FDA-labelled duration` | `Over 4 weeks` |
| `AcknowledgeDurationQuestion` | `$1$ Save this duration?` | `$1$ Save this length?` |
| `RegimenChangeQuestion` | `Change plan from $1$ to $2$? Future deadlines will be recomputed.` | `Change from $1$ to $2$? Upcoming dates will update.` |
| `RepeatTitle` | `Repeat overdue` | `Overdue repeat` |
| `ClockTitle` | `Clock format` | `Clock` |
| `HistoryEmpty` | `No completed cycles` | `No history yet` |
| `HistoryCountTemplate` | `$1$ recorded` | `$1$ cycles` |
| `HistoryEndTemplate` | `to $1$` | `to $1$` |
| `ClearHistory` | `Clear history` | `Clear history` |
| `CycleDetailTitle` | `Cycle detail` | `Cycle $1$` |
| `RemovedLabel` | `Removed` | `Removed` |
| `NextInsertedLabel` | `Next in` | `Next inserted` |
| `RegimenLabel` | `Regimen` | `Schedule` |
| `TemporaryOutLabel` | `Temp out` | `Ring out` |
| `EventsTemplate` | `$1$ events` | `$1$ times` |
| `EventTemplate` | `$1$ event` | `$1$ time` |
| `SummarizedBadge` | `+ summarized` | `Some short times summarized` |
| `OpenInterval` | `open` | `Still out` |

### About, alerts, errors, glance, and notifications

| ID | Current string | v1.1 string |
| --- | --- | --- |
| `AboutTitle` | `About` | `About` |
| `ProductVersion` | `Garmin Ring Tracker v1.0` | `Ring Tracker v1.1` |
| `SchedulingAid` | `Scheduling aid — not medical advice.` | DELETE |
| `SupportedScope` | `NuvaRing and equivalent etonogestrel/EE generics only.` | `NuvaRing only.` |
| `ReminderLimit` | `Reminders may be delayed; do not rely on this app as your only reminder.` | `Reminders can be delayed. Keep another reminder.` |
| `Privacy` | `Schedule data stays on the watch except configuration entered or synced through Garmin App Settings.` | `Data stays on your watch. Garmin App Settings syncs configuration.` |
| `SourcesTitle` | `Sources` | `Sources` |
| `SourcesLine1` | `NuvaRing and EluRyng prescribing information` | `NuvaRing prescribing information` |
| `SourcesLine2` | `FDA NuvaRing label (2019); NHS ring guide` | `DailyMed; NHS NuvaRing guide` |
| `SourcesLine3` | `Planned Parenthood ring guidance; Annovera FDA label (unsupported product)` | DELETE |
| `ActionDueTitle` | `Action due` | `Ring due` |
| `ActionDueBody` | `Open actions to record what actually happened.` | `Choose what happened.` |
| `RingFreeExceededBody` | `The recorded ring-free interval exceeded 7 days. Follow the product label; consider pregnancy and use label-directed backup until the new ring has been used continuously for 7 days.` | `Insert now. Use backup 7 days.` |
| `RingFreeReachedBody` | `The recorded ring-free interval has reached 7 days. Insert now and follow your product instructions.` | DELETE |
| `TempOverBody12` | `Ring recorded out for more than 3 hours. Reinsert as soon as possible and use label-directed backup for 7 continuous days after reinsertion.` | `Out over 3h. Reinsert now. Use backup 7 days.` |
| `TempOverBody3` | `For a week-3 interval over 3 hours, the label describes either inserting a new ring immediately or inserting no later than 7 days after removal when prior continuous use conditions are met. Use label-directed backup; record what actually happened.` | DELETE |
| `TempOverBodyOutside` | `This interval began outside cycle days 1–21. The app does not assign standard week-specific instructions. Follow your product instructions or clinician's plan.` | DELETE |
| `TempOverBodyUnknown` | `The interval's standard schedule week is unknown. Review the recorded dates and follow your product instructions or contact a clinician or pharmacist.` | DELETE |
| `ExtendedBody` | `The ring is recorded in beyond the FDA-labelled 4-week duration. Follow the product label and your clinician's plan.` | `Ring in over 4 weeks. Replace now.` |
| `StartOpenActions` | `START  Open actions` | DELETE |
| `AlertOverdueTitle` | `Action overdue` | `Ring overdue` |
| `AlertRingFreeTitle` | `Ring-free warning` | `Insert now` |
| `AlertTemporaryTitle` | `Temporary-out warning` | `Ring out` |
| `AlertDurationTitle` | `Duration warning` | `Over 4 weeks` |
| `AlertDateReviewTitle` | `Date review needed` | `Check dates` |
| `RingBackInAction` | `RING BACK IN` | `RING BACK IN` |
| `AlertOverdueBy` | `Overdue by $1$` | `$1$ late` |
| `AlertOutFor` | `Out for $1$` | `Out $1$` |
| `AlertDueTodayAt` | `Due today at $1$` | `Today · $1$` |
| `AlertDueIn` | `Due in $1$` | `In $1$` |
| `NextActionLabel` | `NEXT ACTION` | DELETE |
| `AlertRecordHint` | `Record it in Actions` | DELETE |
| `AlertLabelHint` | `DOWN  Label details` | DELETE |
| `AlertReviewDateHint` | `Review insertion date` | `Check insertion date` |
| `LabelInformationTitle` | `Label information` | `Safety` |
| `AboutSourcesHint` | `Source details: About › Sources` | `Sources: About` |
| `AlertActionsHint` | `BACK  •  START Actions` | DELETE |
| `SetupNeeded` | `Setup needed` | `Add insertion date` |
| `StorageError` | `The schedule could not be saved. No change was applied.` | `Couldn't save. Nothing changed.` |
| `SettingsMirrorRetry` | `The schedule was saved, but its Garmin App Settings mirror could not be finalized. The app will retry next time it opens.` | `Saved on watch. Settings sync will retry.` |
| `TemporaryOutStorageError` | `No eligible short interval could be summarized. The temporary-out event was not recorded.` | `Couldn't save ring-out time.` |
| `ReminderRegistrationError` | `Hourly reminder checks could not be registered. Reopen the app to retry.` | `Reminders unavailable. Reopen to retry.` |
| `RecoveredError` | `Stored schedule data was invalid and was reset. A bounded recovery copy was retained.` | `Saved dates were damaged. Schedule reset.` |
| `IncompatibleData` | `This schedule was created by a newer app version and is read-only.` | `Newer app data. Read-only.` |
| `Saved` | `Saved` | DELETE |
| `SettingsReviewTitle` | `Settings change` | `Review settings` |
| `SettingsReviewBody` | `A schedule-affecting change arrived from Garmin App Settings. Review it on the watch before it is applied.` | `Review changes from Garmin App Settings.` |
| `InvalidSettingsBody` | `An invalid Garmin App Settings value was ignored. Confirm to keep the watch schedule.` | `A Garmin App Settings value was invalid.` |
| `StartReview` | `START  Review` | DELETE |
| `SettingsReviewActionsHint` | `BACK  •  START Review` | DELETE |
| `SettingsReviewQuestion` | `Apply the reviewed Garmin App Settings changes?` | `Apply these settings?` |
| `RemoteInsertionQuestion` | `Replace watch insertion $1$ with settings insertion $2$?` | `Change insertion from $1$ to $2$?` |
| `InvalidSettingsQuestion` | `Keep the watch schedule and replace the invalid setting?` | `Keep watch dates?` |
| `GlanceSetup` | `Ring: setup needed` | `Add insertion date` |
| `GlanceRemove` | `Ring: remove in $1$` | `Remove in $1$` |
| `GlanceInsert` | `Ring: insert in $1$` | `Insert in $1$` |
| `GlanceReplace` | `Ring: replace in $1$` | `Replace in $1$` |
| `GlanceOverdue` | `Ring: overdue $1$` | `Overdue $1$` |
| `GlanceOut` | `Ring: out $1$` | `Ring out $1$` |
| `GlanceNow` | `now` | `now` |
| `GlanceDayUnit` | `$1$d` | DELETE |
| `GlanceHourUnit` | `$1$h` | DELETE |
| `GlanceHourMinute` | `$1$h $2$m` | DELETE |
| `GlanceMinuteUnit` | `$1$m` | DELETE |
| `GlanceDayCount` | `$1$ / $2$` | DELETE |
| `GlanceEllipsis` | `…` | `…` |
| `GlanceRemovePrefix` | `Remove in ` | `Remove in ` |
| `GlanceInsertPrefix` | `Insert in ` | `Insert in ` |
| `GlanceReplacePrefix` | `Replace in ` | `Replace in ` |
| `GlanceOverduePrefix` | `Overdue ` | `Overdue ` |
| `GlanceOutPrefix` | `Ring out ` | `Ring out ` |
| `GlanceOneDaySuffix` | ` day` | ` day` |
| `GlanceDaysSuffix` | ` days` | ` days` |
| `GlanceOneHourSuffix` | ` hr` | ` hr` |
| `GlanceHoursSuffix` | ` hrs` | ` hrs` |
| `GlanceOneMinuteSuffix` | ` min` | ` min` |
| `GlanceMinutesSuffix` | ` mins` | ` mins` |
| `GlanceShortHourSuffix` | `h ` | `h ` |
| `GlanceShortMinuteSuffix` | `m` | `m` |
| `NotificationTitle` | `Ring reminder` | DELETE |
| `NotificationOverdueTitle` | `Ring action overdue` | `Ring overdue $1$` |
| `NotificationWarningTitle` | `Ring timing warning` | DELETE |
| `NotificationRemoveTomorrow` | `Remove tomorrow` | `Remove ring tomorrow` |
| `NotificationInsertTomorrow` | `Insert tomorrow` | `Insert ring tomorrow` |
| `NotificationRemoveToday` | `Remove today` | `Remove ring today` |
| `NotificationInsertToday` | `Insert today` | `Insert ring today` |
| `NotificationReplaceTomorrow` | `Replace tomorrow` | `Replace ring tomorrow` |
| `NotificationReplaceToday` | `Replace today` | `Replace ring today` |
| `NotificationRemove` | `Remove ring` | `Remove ring` |
| `NotificationInsert` | `Insert ring` | `Insert ring` |
| `NotificationReplace` | `Replace ring` | `Replace ring` |
| `NotificationTemp` | `Recorded out over 3 hours` | `Out over 3h` |
| `NotificationFree` | `Ring-free interval over 7 days` | `Insert now` |
| `NotificationFourWeeks` | `Beyond labelled 4 weeks` | `Replace now` |
| `NotificationScheduled` | `Open for current schedule` | `Due $1$` |
| `NotificationLabelInfo` | `Open for product-label information` | DELETE |
| `WakeFallback` | `Ring Tracker has a current schedule alert. Open the app?` | DELETE |

### New resources

| ID | Exact value | Use |
| --- | --- | --- |
| `Reminder1` | `Reminder 1` | Watch Settings row/title |
| `Reminder2` | `Reminder 2` | Watch Settings row/title |
| `Reminder2EnabledTitle` | `Reminder 2` | Phone toggle title |
| `Reminder2HourTitle` | `Reminder 2 hour` | Phone numeric title |
| `Reminder2MinuteTitle` | `Reminder 2 minute` | Phone numeric title |
| `DayBeforeReminder` | `Day-before reminder` | Watch/phone toggle |
| `Upcoming` | `Upcoming` | Main menu and screen title |
| `CycleTemplate` | `Cycle $1$` | Upcoming/history row |
| `UpcomingInTemplate` | `In $1$` | Upcoming row |
| `UpcomingOutTemplate` | `Out $1$` | Upcoming row |
| `CurrentCycle` | `Current` | Current Upcoming row badge |
| `IfDoneToday` | `if done today` | Projected row after an overdue current action |
| `OnTime` | `On time` | Event delta |
| `FirstCycle` | `First cycle` | Initial insertion confirmation/history fallback |
| `EarlyTemplate` | `$1$ early` | Event delta |
| `LateTemplate` | `$1$ late` | Event delta |
| `MainRemoveDate` | `Remove · $1$ · $2$` | Ring-in main |
| `MainInsertDate` | `Insert · $1$ · $2$` | Ring-free main |
| `MainReplaceDate` | `Replace · $1$ · $2$` | Zero-day main |
| `MigrationTitle` | `Dates updated` | One-time v1.1 migration notice |
| `MigrationBody` | `Dates now follow actual insertions and removals. Check Edit dates.` | One-time v1.1 migration notice |
| `NotificationReinsertNow` | `Reinsert now` | Temporary warning subtitle |
| `NotificationTempBody` | `Use backup 7 days.` | Temporary warning body |
| `NotificationFreeContext` | `Ring out over 7d` | Ring-free warning subtitle |
| `NotificationFreeBody` | `Use backup 7 days.` | Notification body |
| `NotificationFourWeekContext` | `Ring in over 4 weeks` | Four-week warning subtitle |

Do not add a separate `NuvaRing` label to Main; the product scope is established in setup/About and the app name already supplies context.

## B. Two reminders

### Settings behavior

The watch Settings order is:

1. `Reminder 1` — time picker; default 9:00 AM; always enabled; no toggle.
2. `Reminder 2` — opens a two-row submenu: `Reminder 2` On/Off and `Time`; default 8:00 PM and Off. Keep the selected time while Off. The parent row shows `Off` or the formatted time.
3. `Day-before reminder` — On/Off; default On; always uses Reminder 1's current time.
4. `Overdue repeat` — unchanged choices and 6-hour default.
5. `Days ring in`, `Days ring-free`, `Vibration`, `Sound`, `Clock`, `Reset app` — existing behavior except for copy in the audit.

Both enabled day-of slots apply to both action dates: remove/replace day and insert day. Completion of the action cancels remaining slots because the `actionKey` changes. A day-of slot is still eligible later on the same local action date when the action is overdue; this is required so an enabled evening reminder actually fires after a morning due time. On that date, a day-of slot outranks an ordinary overdue repeat. The hard-limit warnings still outrank it.

### Reminder configuration schema

The logical v1.1 reminder schema is version 2:

```text
reminders = {
  reminder1Hour: 0..23,          // default 9
  reminder1Minute: 0..59,        // default 0; always enabled
  reminder2Hour: 0..23,          // default 20
  reminder2Minute: 0..59,        // default 0
  reminder2Enabled: Boolean,     // default false
  dayBeforeEnabled: Boolean,     // default true; uses Reminder 1 time
  overdueRepeatHours: 1|3|6|12|24,
  vibrationEnabled: Boolean,
  soundEnabled: Boolean,
  clockFormat: 0|12|24
}
```

For the product-level schema 1 → 2 migration, map `localHour/localMinute` to Reminder 1 so an existing user's chosen time is preserved. Add Reminder 2 at 20:00 Off and `dayBeforeEnabled = true`. Fresh installs use 09:00/20:00 with the same toggles. The persisted-document version conflict and actual codec migration are specified in section F.

### Ledger and deduplication

Replace `dayOfSent` with per-slot state:

```text
reminderLedger = {
  cycleId,
  actionKey,                     // action + actual-event-derived due UTC
  dayBeforeSent,
  dayOf1Sent,
  dayOf2Sent,
  lastOverdueSlot,
  lastTempOutSlot,
  labelFourWeekSent,
  ringFreeExceededSent
}
```

- A Reminder 1 delivery sets only `dayOf1Sent`; a Reminder 2 delivery sets only `dayOf2Sent`.
- If the first wake occurs after both configured times, deliver the most recent eligible slot and mark every older eligible day-of slot consumed. Do not send a catch-up burst on the next wake.
- If both times are equal, deliver one card and mark both slots sent.
- Disabling Reminder 2 suppresses its candidate but does not clear its time or ledger flag. Re-enabling it cannot repeat a slot already sent for the current `actionKey`.
- A day-before delivery sets only `dayBeforeSent`. It is eligible only on the prior local calendar date, so it cannot arrive as stale day-before copy on the action date.
- When `cycleId` or `actionKey` changes, reset the three date-slot fields and `lastOverdueSlot`. Preserve threshold-warning and temporary-out fields when they still refer to the same cycle/open interval.
- Schema migration maps old `dayOfSent` to both `dayOf1Sent` and `dayOf2Sent`; this prevents an upgrade from repeating a morning reminder. Reminder 2 is Off by default, but the mapping remains correct if it is enabled before the next action.

`ReminderPolicy.candidate` gains `:reminderSlot => 1|2|null`. `ReminderPolicy.markSent` and compact `BackgroundRuntime.markSent` must update the matching slot only, subject to the missed-slot rule above. The foreground and reduced background evaluators must remain behaviorally identical.

### Candidate order

At each hourly wake, form all currently eligible candidates and post at most one:

| Priority | Candidate | Eligibility |
| ---: | --- | --- |
| 1 | Ring free over 7 days | `nowUtc > ringFreeCeilingUtc`; once per cycle |
| 2 | Ring out over 3 hours | Open temporary interval and elapsed `> 10,800s`; repeated by existing overdue interval |
| 3 | Ring in over 28 days | Ring not removed and `nowUtc > labelFourWeekUtc`; once per cycle |
| 4 | Day-of Reminder 1/2 | Enabled unsent slot; current local date equals action date; choose latest due slot |
| 5 | Action overdue | `nowUtc >= actionDueUtc`; repeated by existing overdue interval |
| 6 | Day-before | Toggle On; unsent; prior local date; Reminder 1 time |

At the exact action due instant, format overdue elapsed as `now`; at later instants use the same absolute countdown formatter as Main (`1d 4h`, `5h 10m`). A threshold candidate wins even if a day-of slot or overdue slot is also due. After it is marked, the next wake may deliver the still-current lower-priority candidate.

### Exact native notification copy

`Notifications.showNotification(title, subtitle, options)` uses the following. Omit `options[:body]` where the table says —; do not add `Open app` filler. `$time` is the action due time in the selected 12/24-hour format, not the reminder slot time; `$elapsed` is compact elapsed time.

| Kind | Title | Subtitle | Body |
| --- | --- | --- | --- |
| Remove, day before | `Remove ring tomorrow` | `Due $time` | — |
| Insert, day before | `Insert ring tomorrow` | `Due $time` | — |
| Replace, day before | `Replace ring tomorrow` | `Due $time` | — |
| Remove, Reminder 1 or 2 | `Remove ring today` | `Due $time` | — |
| Insert, Reminder 1 or 2 | `Insert ring today` | `Due $time` | — |
| Replace, Reminder 1 or 2 | `Replace ring today` | `Due $time` | — |
| Remove overdue | `Ring overdue $elapsed` | `Remove ring` | — |
| Insert overdue | `Ring overdue $elapsed` | `Insert ring` | — |
| Replace overdue | `Ring overdue $elapsed` | `Replace ring` | — |
| Temporary out >3h | `Out over 3h` | `Reinsert now` | `Use backup 7 days.` |
| Ring-free >7d | `Insert now` | `Ring out over 7d` | `Use backup 7 days.` |
| Ring-in >28d | `Replace now` | `Ring in over 4 weeks` | — |

Example overdue card: title `Ring overdue 1d 4h`, subtitle `Insert ring`. Keep `:dismissPrevious => true`, compact `[cycleId, kind]` launch data, write-after-post ledger semantics, and the no-burst rule.

## C. Flexible actual-event anchoring

### Due-date construction

There is one rule per phase. Both use `CalendarMath.addLocalCalendarDays`, preserving the actual event's local wall-clock time across DST under the existing resolver contract.

```text
removeDueUtc = addLocalCalendarDays(actualInsertionUtc, daysIn).utc
insertDueUtc = addLocalCalendarDays(actualRemovalUtc, daysOut).utc
```

For `daysOut == 0`, `insertDueUtc == actualRemovalUtc`. The user must still confirm the insertion; removal does not create a new cycle automatically.

Examples for 21/7:

- Due to remove Sep 22, actually removed Sep 20 → `2d early`; insert due Sep 27.
- Due to remove Sep 22, actually removed Sep 24 → `2d late`; insert due Oct 1, not Sep 29.
- Due to insert Oct 1, actually inserted Oct 2 → `1d late`; next removal due Oct 23.

Delete the minimum/"earlier deadline wins" behavior. Neither an insertion-derived projection, the 7-day warning boundary, nor a user override may substitute for `insertDueUtc` after an actual removal.

### Thresholds are warnings, not anchors

Keep two independent instants:

```text
labelFourWeekUtc    = addLocalCalendarDays(actualInsertionUtc, 28).utc
ringFreeCeilingUtc  = addLocalCalendarDays(actualRemovalUtc, 7).utc
```

- `ringInOverFourWeeks = true` only when the ring is still in and `nowUtc > labelFourWeekUtc`. Exact equality is not "over." Warning: `Ring in over 4 weeks. Replace now.`
- `ringFreeOverSevenDays = true` only when the ring is removed and `nowUtc > ringFreeCeilingUtc`. Exact equality is not "over." Warning: `Insert now. Use backup 7 days.`
- These flags do not change `phase`, `actionDueUtc`, projections, or event history. A configured duration may already make the ordinary action overdue; the warning remains independently true/false.
- The temporary-out threshold remains strict `> 10,800s`; at exactly three hours show `3h reached. Put it back in.` without setting the over-three-hour flag.

### Active and history fields

Replace the active scheduling fields as follows.

Drop:

- `scheduledRemovalUtc`
- `scheduledInsertionUtc`
- `plannedOverrideUtc`
- `finalInsertionUtc`

Add:

```text
active = {
  insertionUtc,
  insertionWall,
  insertionPlanUtc: Long | null,       // prior cycle's due action; null on first setup
  insertionDeltaSeconds: Long | null,  // insertionUtc - insertionPlanUtc
  removeDueUtc: Long,
  removalUtc: Long | null,
  removalWall: Wall | null,
  removalDeltaSeconds: Long | null,    // removalUtc - removeDueUtc
  insertDueUtc: Long | null,           // actual removal + daysOut
  labelFourWeekUtc: Long,
  ringFreeCeilingUtc: Long | null,
  ...existing temporary-out fields...
}
```

The history codec adds `insertionPlanUtc`, `insertionDeltaSeconds`, `removeDueUtc`, `removalDeltaSeconds`, `insertDueUtc`, and `nextInsertionDeltaSeconds`. Retain existing `nextInsertionUtc` as the cycle-close instant. On the insertion that closes a cycle:

1. Compare the new insertion with the old cycle's `insertDueUtc` (or `removeDueUtc` for a direct replacement while still in).
2. Store the signed delta as old history's `nextInsertionDeltaSeconds`.
3. Create the new active cycle with the same expected instant in `insertionPlanUtc` and signed delta in `insertionDeltaSeconds`.

The deliberate duplication makes a cycle record self-contained and lets its own insertion show variance even after the preceding cycle is evicted. Validation must require every non-null persisted delta to equal the difference of its two instants.

### `deriveStatus`

`ScheduleModel.deriveStatus(nowUtc, active, regimen)` becomes:

```text
if active == null:
    phase = SETUP; nextAction = SET_UP; actionDueUtc = null
else if removalUtc == null:
    actionDueUtc = removeDueUtc
    nextAction = daysOut == 0 ? REPLACE : REMOVE
    phase = nowUtc < actionDueUtc ? RING_IN : OVERDUE
else:
    actionDueUtc = insertDueUtc
    nextAction = INSERT
    phase = nowUtc < actionDueUtc ? RING_FREE : OVERDUE

ringInOverFourWeeks = removalUtc == null && nowUtc > labelFourWeekUtc
ringFreeOverSevenDays = removalUtc != null && nowUtc > ringFreeCeilingUtc
```

Return `actionDueUtc`, `secondsRemaining`, `nextAction`, `phase`, `overdueKind`, the two warning flags, `clockBeforeInsertion`, and existing temporary-out data. Keep `underlyingAction`, `underlyingActionUtc`, and `underlyingSecondsRemaining` only if the temporary-out overlay still needs them; they must point to the actual-event-derived action. An open temporary interval changes the displayed action to `RING_BACK_IN` but never changes the underlying phase or due instant.

Remove `ringFreeLimitReached`: equality with the seven-day boundary is an ordinary due/overdue instant when `daysOut == 7`, not the strict over-seven warning. Rename `beyondLabelFourWeeks` and `ringFreeLimitExceeded` to the plain semantic flags above throughout foreground, glance mirror, and background mirror code.

### Event deltas and edits

Signed delta is `actualUtc - dueUtc`: negative is early; positive is late. Persist seconds, but format no seconds:

| Absolute delta | Display |
| --- | --- |
| `< 60s` | `On time` |
| `1m..<1h` | whole minutes, e.g. `18m late` |
| `1h..<1d` | hours plus non-zero minutes, e.g. `5h 10m early` |
| `>=1d` | days plus non-zero hours, e.g. `2d early`, `2d 5h late` |

Use at most two units and floor the smallest shown unit. The raw signed seconds remain available to tests and migration.

Every insertion/removal confirmation previews the delta before commit:

```text
Remove ring?
Mon 2 Nov · 2:05 PM · 5h late

Insert ring?
Mon 9 Nov · 8:00 AM · 2d early
```

First setup has no prior due instant; use `First cycle` instead of a fabricated on-time delta. Temporary-out and back-in confirmations show their timestamps but no schedule delta.

`Edit dates` contains `Insertion` and, when present, `Removal` only. Delete `:adjustPlanned`, `ScheduleModel.setPlannedOverride`, `PlannedNextAction`, `PlannedDate`, and all override badges. Corrections behave as follows:

- Editing insertion recalculates `removeDueUtc` and `labelFourWeekUtc`; if removal already exists, recompute `removalDeltaSeconds`. It does not move `insertDueUtc`, which remains anchored to actual removal.
- Editing removal recalculates `removalDeltaSeconds`, `insertDueUtc`, and `ringFreeCeilingUtc`.
- Changing `daysIn` recalculates the active removal due/delta and future projections; changing `daysOut` recalculates the active insertion due only after an actual removal. Archived cycle snapshots and their deltas do not change.
- Keep existing chronology checks against removal, temporary-out intervals, and history. Actual events remain disallowed more than 60 seconds in the future.

History prepends the active cycle as `Cycle n · Current`, so a new insertion/removal delta is visible immediately rather than only after archive. Completed history remains capped at 24; `Clear history` clears completed cycles, never the active row. List secondary text shows available variance, e.g. `Remove 5h late · Insert 2d early`; omit a missing variance rather than showing a dash. Cycle detail places the variance directly below each `Inserted`, `Removed`, and `Next inserted` timestamp. The first retained insertion may show `First cycle` or omit the variance when migration cannot establish its prior due instant.

## D. Upcoming cycles

### Content and projection

`Upcoming` is a read-only custom scroll view containing exactly six rows when an active cycle exists. The active cycle is row 1 even when its removal is overdue or it is currently ring free. Use its `cycleId`; future row labels increment that ID without reserving IDs in storage.

```text
                    UPCOMING

       Cycle 3                         Current
       In Mon 2 Nov        Out Mon 23 Nov
       ━━━━━━━━━━━━━━━━━━━ ━━━━━━

       Cycle 4
       In Mon 30 Nov       Out Mon 21 Dec
       ━━━━━━━━━━━━━━━━━━━ ━━━━━━

       Cycle 5
       In Mon 28 Dec       Out Mon 18 Jan
       ━━━━━━━━━━━━━━━━━━━ ━━━━━━
```

The long segment of each 5 px bar is ring-in green and the short segment is ring-free purple, proportional to `daysIn/daysOut`, with a 2 px black gap. For `daysOut == 0`, draw green only with a purple 5 px boundary tick. Color is reinforced by the `In`/`Out` words.

Projection algorithm:

1. Row 1 `In` is the active actual `insertionUtc`. Row 1 `Out` is actual `removalUtc` when present, otherwise `removeDueUtc`.
2. Let the current action be removal when no actual removal exists, otherwise insertion. If that action is not overdue, row 2 `In` is `insertDueUtc` after actual removal, or `addLocalCalendarDays(removeDueUtc, daysOut)` before removal.
3. If the current action is overdue, keep row 1 unchanged but assume that action happens at `nowUtc` for projection only. For overdue removal, row 2 `In` is `addLocalCalendarDays(nowUtc, daysOut)`; for overdue insertion, row 2 `In` is `nowUtc`. This assumption never records an event or changes state.
4. For rows 2–6, `Out = addLocalCalendarDays(In, daysIn)` and the following `In = addLocalCalendarDays(Out, daysOut)`.
5. Show local dates only as `Mon 2 Nov`; do not show times or explanatory footers. When rule 3 applies, show the subtle small-line note `if done today` on projected rows 2–6.
6. Compute rows on view creation/resume; never persist them. An actual insertion/removal, an edited actual timestamp, a duration change, or advancing `nowUtc` invalidates the view model and regenerates all six rows.

Implement this as pure `ScheduleModel.projectUpcoming(active, regimen, count, nowUtc)` returning rows `{ :cycleId, :inUtc, :outUtc, :inActual, :outActual, :isCurrent, :ifDoneToday }`. Require `count == 6` at the UI call site; keeping the helper parameterized makes boundary tests small without putting date math in the view.

Row 1 always retains actual event dates. Projected rows never show a past action: when the current action is overdue, they use the non-persisted “if done today” assumption above. Once the user records the late event, all downstream rows shift from that actual instant and the assumption note disappears.

### Layout and input

Use `Graphics.FONT_SYSTEM_SMALL` for `Upcoming` and `Cycle n`, `FONT_SYSTEM_TINY` for date pairs, and a measured fallback to `FONT_SYSTEM_XTINY` only if a date pair exceeds the safe width. The reference geometry scales with the existing `Ui.px` rule:

| Element | 390 px | 416 px reference | 454 px |
| --- | ---: | ---: | ---: |
| Header baseline | 45 | 48 | 52 |
| List top | 68 | 72 | 79 |
| Row height | 84 | 90 | 98 |
| Three-row bottom | 321 | 342 | 373 |
| Row horizontal inset | 62 | 66 | 72 |
| Bar width | 259 | 276 | 301 |
| Bar stroke | 5 | 5 | 5–6 |

Show three rows at once. `topIndex` ranges 0–3. UP/DOWN or vertical swipe changes `topIndex` by one and draws the existing non-color-only scroll indicator; there is no focus rail because rows have no action. BACK/swipe right returns to Main. START/tap does nothing rather than implying a detail view.

### Main navigation

Replace the v1.0 both-directions-to-Schedule mapping:

- Main UP / `onPreviousPage()` → `Upcoming`.
- Main DOWN / `onNextPage()` → `History`.
- Main START/tap → context action/menu as specified under Main.
- Long MENU → main menu.

This is cleaner than a three-screen carousel: `Upcoming` and `History` need UP/DOWN for their own scrolling. Future-above and past-below give both destinations one action from Main without overloading list navigation. Add both destinations to Menu2 for discoverability and touch use.

## E. Main screen simplification

### Final information hierarchy

Main may render only:

1. schedule arc;
2. one phase/action phrase;
3. one large countdown or elapsed value;
4. one next-action date/time block;
5. one optional warning block.

Delete cycle day, `REMOVE IN`/`INSERT IN`, overdue eyebrow, footer hints, override badge, `Current local time`, and any explanatory line. Do not show `tracking`, `schedule aid`, product scope, or NuvaRing on Main.

Use the existing radius 184/stroke 14 reference arc. While ring-in, its phase boundary is `removeDueUtc` and projected cycle end is `addLocalCalendarDays(removeDueUtc, daysOut)`. After actual removal, redraw the boundary at `removalUtc` and use `insertDueUtc` as cycle end. For non-zero total duration, boundary/marker fractions are `(boundaryUtc - insertionUtc) / (cycleEndUtc - insertionUtc)` and `(nowUtc - insertionUtc) / (cycleEndUtc - insertionUtc)`, each clamped to `0..1`; `daysOut == 0` draws green only with the existing replacement notch. Overdue marker clamps at the due boundary. Temporary-out dims the underlying arc. An ordinary overdue arc is amber; a currently active >3h, >7d, or >28d warning is red. The arc is time status, never an effectiveness meter.

Reference baselines on 416 px are phase 90, countdown center 194, action date 270, action time 300, and optional warning block 320–354. Scale all positions. When a warning exists, use phase 68, countdown 168, action date/time 238/266, and warning block 294–354. Use `FONT_SYSTEM_SMALL` for phase, the existing composed `FONT_SYSTEM_NUMBER_HOT` countdown, `FONT_SYSTEM_SMALL` for date, `FONT_SYSTEM_XTINY` for time/warning, and measured width limits from `UI.md`.

START/tap opens the context-aware main menu in every schedule state; long MENU opens the same menu. The only direct mutation affordance remains temporary out: START/tap opens the `Ring back in?` confirmation because `Put it back in` is the visible next action. No main-screen tap commits an event.

### Ring in

```text
              .--------------------.
           .-'    green/purple arc   '-.
         .'                            '.
        /            RING IN             \
       ;                                  ;
       |            20d 23h               |
       |                                  |
       |         Remove · Mon 5 Oct       |
       ;               5:26 PM            ;
        \                                /
         '.                            .'
           '-.                      .-'
              '--------------------'
```

Countdown is to `removeDueUtc`. For `daysOut == 0`, the date verb is `Replace`.

### Ring free

```text
              .--------------------.
           .-'    actual phase arc   '-.
         .'                            '.
        /           RING FREE            \
       ;                                  ;
       |             4d 0h                |
       |                                  |
       |         Insert · Fri 18 Sep      |
       ;               5:26 PM            ;
        \                                /
         '.                            .'
           '-.                      .-'
              '--------------------'
```

Countdown is to `insertDueUtc`, derived only from actual removal.

### Overdue remove

```text
              .--------------------.
           .-'       amber arc       '-.
         .'                            '.
        /          REMOVE NOW            \
       ;                                  ;
       |          1d 4h late              |
       |                                  |
       |          Due · Sun 13 Sep        |
       ;               5:26 PM            ;
        \                                /
         '.                            .'
           '-.                      .-'
              '--------------------'
```

If the ring is also in over 28 days, use the warning layout/red arc and add the single warning block `Ring in over 4 weeks. Replace now.` The warning does not replace `removeDueUtc` in the model.

### Overdue insert

```text
              .--------------------.
           .-'       amber arc       '-.
         .'                            '.
        /          INSERT NOW            \
       ;                                  ;
       |           8h late                |
       |                                  |
       |          Due · Mon 9 Nov         |
       ;               9:00 AM            ;
        \                                /
         '.                            .'
           '-.                      .-'
              '--------------------'
```

Strictly after seven days out, use the red arc and add `Insert now. Use backup 7 days.` as the one warning block.

### Ring out temporarily

```text
              .--------------------.
           .-'        dim arc         '-.
         .'                            '.
        /            RING OUT             \
       ;                                  ;
       |            2h 50m                |
       |                                  |
       |          Put it back in          |
       ;                                  ;
        \                                /
         '.                            .'
           '-.                      .-'
              '--------------------'
```

At exactly three hours, the warning block is `3h reached. Put it back in.` Strictly after three hours, show the elapsed value in red and the single warning block, wrapping by sentence if required:

```text
Out over 3h. Reinsert now.
Use backup 7 days.
```

### First run

First run is the sole non-About exception to the Main information limit because acknowledgement requires the safety boundary. It has no arc or decorative footer.

```text
              .--------------------.
           .-'      RING TRACKER      '-.
         .'                            '.
        /  Schedule aid, not medical     \
       ;   advice.                        ;
       |                                  |
       |  Cannot determine contraceptive  |
       |  effectiveness.                  |
       |                                  |
       |  Follow NuvaRing instructions.   |
       |  Ask a clinician or pharmacist   |
       |  if late, out too long, or        |
       ;  pregnancy is possible.           ;
        \             Continue           /
         '.                            .'
           '-.                      .-'
              '--------------------'
```

The body scrolls if necessary. START/tap on `Continue` opens the existing confirmation; BACK exits and preserves the setup step.

### Main menu contract

Use native `Menu2`. Omit invalid actions; do not show disabled rows or reasons. Put state-valid actions first, followed by the same destination order:

| State | Action rows, in order | Destination rows, in order |
| --- | --- | --- |
| No cycle | `Insert ring` | `Upcoming` omitted; `History`, `Settings`, `About` |
| Ring in | `Remove ring`, `Ring out`, `Insert ring` | `Edit dates`, `Upcoming`, `History`, `Settings`, `About` |
| Ring out temporarily | `Ring back in`, `Remove ring`, `Insert ring` | `Edit dates`, `Upcoming`, `History`, `Settings`, `About` |
| Ring free/overdue insert | `Insert ring` | `Edit dates`, `Upcoming`, `History`, `Settings`, `About` |

While a ring is in, `Insert ring` means a direct replacement and its confirmation says `Replace ring?`; the shorter menu verb is the owner's required vocabulary. `Edit dates` is omitted until an active cycle exists. `History` remains visible when empty so the empty state is discoverable.

## F. Persistence, settings, implementation map, and verification

### Persisted schema and migration

There are two version numbers in the existing documents/code and they must not be conflated:

- The v1.0 conceptual model in `SPEC.md` calls itself schema 1; the requested v1.1 logical reminder/model change is therefore schema 1 → 2. Section B gives that mapping and defaults.
- The finished v1.0 source already has `ScheduleModel.SCHEMA_VERSION = 2`, a positional schema-2 codec, split history, revisioned mirrors, and `RingStore.migrateV1`.

The shipping v1.1 source must set `SCHEMA_VERSION = 3`. Reusing 2 would make old bytes decode with the new field positions and can corrupt dates. Load paths are normative:

```text
missing              -> fresh v3 defaults
stored v1            -> existing v1-to-v2 decode -> migrateV2ToV3 -> validate -> save v3
stored v2            -> decodeLegacyV2 -> migrateV2ToV3 -> validate -> save v3
stored v3            -> strict v3 decode and validation
stored version > 3   -> existing read-only incompatibility path; no overwrite
anything invalid     -> existing bounded recovery path
```

`migrateV2ToV3` performs these steps before the first v3 validation:

1. Map reminders: legacy `localHour/localMinute` → Reminder 1; add Reminder 2 20:00 Off and day-before On. Convert the 8-item settings config snapshot to the 12-item order specified below, including pending snapshots.
2. Map active removal due from legacy `scheduledRemovalUtc` to `removeDueUtc`.
3. If no removal exists, set `insertDueUtc`, removal delta, and ring-free ceiling to null. Ignore/drop legacy `scheduledInsertionUtc`, `plannedOverrideUtc`, and `finalInsertionUtc`.
4. If removal exists, compute `removalDeltaSeconds = removalUtc - removeDueUtc`, `insertDueUtc = addLocalCalendarDays(removalUtc, daysOut)`, and `ringFreeCeilingUtc = addLocalCalendarDays(removalUtc, 7)`. This intentionally changes a late-removal schedule from v1.0's anchored/minimum date to the actual-removal date.
5. Recompute `labelFourWeekUtc` from actual insertion. Set active insertion plan/delta null initially.
6. For every retained history cycle, compute its removal due/delta and insertion due using its regimen snapshot. Compute `nextInsertionDeltaSeconds` against `insertDueUtc` after removal or against `removeDueUtc` for a direct replacement with no removal.
7. Stitch each later history/active insertion to the preceding retained cycle only when the preceding `nextInsertionUtc` equals that insertion. Copy the preceding due into `insertionPlanUtc` and compute the insertion delta. Leave it null across an eviction/gap.
8. Map old `dayOfSent` to both new slot flags. Derive the new actual-event `actionKey`. If it equals the old action/deadline key, preserve day/overdue fields; otherwise reset date slots and overdue slot. Preserve already-sent four-week/ring-free warnings and the open interval's temporary slot for the same cycle.
9. Set `migrationNoticePending = true`. On the first foreground open, show `Dates updated` / `Dates now follow actual insertions and removals. Check Edit dates.`, clear the flag, and save. Background/glance must not show the notice.
10. Write history chunks and reduced mirrors first and canonical state last under one new revision, retaining the current 24 KiB preflight and recovery behavior.

Fresh v3 state sets `migrationNoticePending = false`. A failed migration never partially writes v3 and never deletes the recoverable v2 state.

### `properties.xml`

Retain the legacy `reminderHour` and `reminderMinute` property IDs as Reminder 1; this preserves synchronized values without relying on undeclared/orphan property access. Add four Reminder 2/day-before values. The complete v1.1 property order is:

```xml
<properties>
    <property id="insertionIso" type="string"></property>
    <property id="reminderHour" type="number">9</property>
    <property id="reminderMinute" type="number">0</property>
    <property id="reminder2Enabled" type="boolean">false</property>
    <property id="reminder2Hour" type="number">20</property>
    <property id="reminder2Minute" type="number">0</property>
    <property id="dayBeforeEnabled" type="boolean">true</property>
    <property id="daysIn" type="number">21</property>
    <property id="daysOut" type="number">7</property>
    <property id="overdueRepeatHours" type="number">6</property>
    <property id="vibrationEnabled" type="boolean">true</property>
    <property id="soundEnabled" type="boolean">false</property>
    <property id="clockFormat" type="number">0</property>
</properties>
```

`insertionIso` remains the current actual insertion timestamp. Do not add a planned-action property. Existing watch-wins/snapshot-diff conflict handling remains.

### `settings.xml` and `SettingsBridge`

Keep the insertion setting first. Replace the existing reminder titles with `Reminder 1 hour` and `Reminder 1 minute`, then add:

```xml
<setting propertyKey="@Properties.reminder2Enabled" title="@Strings.Reminder2EnabledTitle">
    <settingConfig type="boolean" />
</setting>
<setting propertyKey="@Properties.reminder2Hour" title="@Strings.Reminder2HourTitle">
    <settingConfig type="numeric" min="0" max="23" />
</setting>
<setting propertyKey="@Properties.reminder2Minute" title="@Strings.Reminder2MinuteTitle">
    <settingConfig type="numeric" min="0" max="59" />
</setting>
<setting propertyKey="@Properties.dayBeforeEnabled" title="@Strings.DayBeforeReminder">
    <settingConfig type="boolean" />
</setting>
```

The stock phone settings page cannot conditionally hide Reminder 2 time fields; leave them editable while Off. On-watch Settings uses the nested two-row Reminder 2 menu defined in section B.

Update `SettingsBridge.validate`, `configFromState`, `configFromProperties`, `applyConfig`, `completePendingMirrors`, and `validConfigArray`. The exact v3 config array is:

```text
[r1Hour, r1Minute, r2Hour, r2Minute, r2Enabled, dayBeforeEnabled,
 daysIn, daysOut, overdueRepeatHours, vibrationEnabled, soundEnabled, clockFormat]
```

Watch edits stage/mirror all 12 values through the existing pending snapshot protocol. A partial/invalid phone snapshot does not overwrite the watch configuration.

### File-level implementation map

| File/symbol | Required delta |
| --- | --- |
| `resources/strings/strings.xml` | Apply the complete audit, remove dead IDs/call sites, add the new resources, and keep notification resources background-scoped. |
| `resources/settings/properties.xml`, `settings.xml` | Retain Reminder 1 IDs; add Reminder 2/day-before properties and controls with the defaults/ranges above. |
| `ScheduleModel.defaultReminders`, `defaultLedger`, `newCycle` | Add two-slot defaults/ledger; create actual-event fields and due dates. |
| `ScheduleModel.computeFinalInsertionUtc`, `refreshFinalInsertionUtc`, `setPlannedOverride` | Delete. All insertion due computation occurs when actual removal is recorded/edited. |
| `ScheduleModel.recordRemoval`, `insertOrReplace`, `rebuildForInsertion`, `deriveStatus` | Apply the exact anchors, deltas, warning-only boundaries, and edit cascades in section C. |
| `ScheduleModel.projectUpcoming` (new) | Return six non-persisted rows from the active/actual anchor as specified in section D. |
| `ScheduleModel.validState`, `validActive`, `validHistory`, `validReminders`, `validLedger`, `validConfigArray` | Validate v3 shape, delta equations, strict chronology, and new ranges/array lengths. |
| `RingStore.load`, `migrateV1`, new `decodeLegacyV2`/`migrateV2ToV3` | Preserve the v1 path, add v2 → v3 migration, then save only after complete validation. |
| `RingStore` canonical/history codecs | Remove three legacy schedule fields; add actual due/delta fields and migration notice. Update every positional length check. |
| `RingStore.encodeGlance`, `encodeBackground`, `decodeReducedActive` | Carry `removeDueUtc`/`insertDueUtc` as the one active due; retain independent warning instants. Bump mirror schema and validators. Do not add projections/history. |
| `SettingsBridge` | Use the 12-item configuration contract and legacy Reminder 1 property IDs. |
| `ReminderPolicy.evaluate`, `markSent` | Add Reminder 1/2 candidate slots, day-before toggle, priority, most-recent missed-slot selection, and per-slot dedup. |
| `BackgroundRuntime` | Mirror `ReminderPolicy` with the new compact array positions/kind codes. Replace hard-coded schema 2 with 3. Keep the constrained path independent of `ScheduleModel`/foreground UI. |
| `RingServiceDelegate.notificationIds` | Return/build the exact title/subtitle/body table, including dynamic due time and elapsed overdue text. Keep launch payload kind validation in sync. |
| `MainView.drawArc`, `drawStatus`, `drawTemporary`, `MainDelegate` | Implement section E; remove day/action/footer lines; use actual phase boundary; map UP/DOWN to future/past. |
| `Menus.mainMenuWithFocus`, `adjustMenu`, `settingsMenu` and delegates | Apply the short conditional menu, remove planned override, add Upcoming and two-reminder settings flows. |
| `StaticViews.DisclaimerView`, `RegimenView`, `AboutView` | Use the shared short safety lines; remove the second product line and setup exclusion row; show the sole generic/Annovera exclusion only in About. |
| `StaticViews.AlertView` | Use the three exact threshold warnings; remove label/product-instruction pages and redundant input footers. |
| `StaticViews.ScheduleView` | Replace with `UpcomingView` or move a new implementation to `UpcomingView.mc`; do not keep two screens for the same destination. |
| `RingTrackerApp.showSchedule`, action handling, `recomputeDeadlines` | Rename route to `showUpcoming`; add `showHistory`; remove `:adjustPlanned`; add reminder toggles/time actions; regenerate actual-derived due fields. |
| `HistoryView.CycleDetailView`, `Menus.historyMenu` | Prepend the active cycle, show signed event deltas without `recorded`/`plan` jargon, and keep Clear history scoped to completed cycles. |
| `Pickers` | Retain native arrows/OK behavior and remove `START Next`, `START Review`, `BACK`, and unused separator resources from custom rendering. |
| `GlanceView` | Read the actual-derived due instant and new warning flags; remove optional day count. Keep one short action line and progress bar. |
| `DemoScenarios` and debug strings | Replace planned/minimum fixtures with early/late actual-event, Reminder 2, Upcoming, >7d, and >28d fixtures. |

### Unit tests to delete or rewrite

Delete these obsolete assertions rather than weakening them:

- `reviewPlannedOverrideCannotPostponeEarlierDeadline`
- `plannedOverrideParticipatesInMinimum`

Rewrite:

- `earlyRemovalUsesEarlierDeadline` → `earlyRemovalAnchorsInsertionToActualRemoval`; assert the old insertion-derived date is irrelevant.
- `lateRemovalIsImmediatelyOverdue` → `lateRemovalShiftsInsertionDue`; immediately after removal the state is `RING_FREE` for positive `daysOut`, with insertion due `actualRemoval + daysOut`.
- `exactSevenDayLimitReachedIsDistinct` and `ringFreeCeilingBoundary` → strict warning false at equality and true at `+1s`; action due remains independent.
- `scheduleExtendedLabelBoundary` → strict >28-day warning false at equality, true at `+1s`, without changing the configured action due.
- `dayOfConsumesDayBeforeLedger`, `reviewDayOfSuppressesStaleDayBeforeCatchup`, and all reminder codec tests → two day-of slot flags plus independently controlled day-before behavior.
- `storageCodecRoundTrip`, `revisionedRecordsShareCanonicalCommit`, `constrainedMirrorValidationFailsInertAndMarksError`, `backgroundMirrorStaysReducedAtLimits`, and storage-size fixtures → schema 3 lengths/fields while retaining revision and budget assertions.
- `replacementReminderUsesReplacementCopy` → exact title/subtitle/body for all remove/insert/replace day-before, day-of, and overdue variants.
- `copyAndFormattingContractsMatchRegimen` → exact first-run/About lines, three threshold warnings, short menus, notification copy, and absence of banned terms from all non-About/non-first-run resources.

### Unit tests to add

Schedule and events:

- early/on-time/late actual removal anchors insertion from removal for `daysOut` 0, 3, and 7;
- early/on-time/late insertion creates a new removal due from that insertion;
- a late removal can move insertion later than v1.0's `scheduledInsertionUtc` without immediate overdue;
- editing insertion updates removal due/delta but not an existing removal-anchored insertion due;
- editing removal updates insertion due, removal delta, seven-day warning boundary, and projections;
- event delta signs, `<60s` on-time display, minute/hour/day formatting, and DST-crossing elapsed deltas;
- History prepends active data, shows its insertion/removal deltas, and clearing completed history preserves it;
- direct replacement while ring-in compares against `removeDueUtc` and archives exactly one cycle;
- equality/+1-second tests for 3h, 7d, and 28d boundaries;
- warning flags never alter action due or phase;
- active/history delta equation validation rejects mismatches.

Upcoming:

- exactly six rows, current cycle first, monotonically incremented display IDs;
- current actual insertion/removal wins over projection;
- ring-in projection, ring-free projection, and zero-day replacement projection;
- all downstream rows update after actual removal, actual insertion, either date edit, and either duration edit;
- leap day, month/year, spring gap, and fall fold use existing local-day resolution;
- read-only scroll bounds `0..3`; START/tap causes no mutation.

Reminders/settings:

- fresh defaults 09:00 always-on, 20:00 Off, day-before On;
- Reminder 2 Off suppresses only slot 2; On sends on both remove and insert dates;
- changing Reminder 1 also changes day-before time; changing Reminder 2 does not;
- each slot deduplicates independently; equal times post once and mark both;
- when both slots were missed, only the latest posts and the older is consumed;
- day-of slots remain eligible after due on the same local date and outrank ordinary overdue;
- threshold warning → day-of → overdue progression posts one candidate per wake;
- disabling/re-enabling Reminder 2 does not repeat a sent slot;
- logical reminder schema 1 → 2 preserves old configured time and adds exact defaults;
- persisted v1 → v2 → v3 and v2 → v3 migrations produce identical valid v3 state;
- legacy active late-removal data discards old minimum/override and uses actual removal;
- migration stitches only contiguous retained cycles and leaves unknown insertion deltas null;
- old `dayOfSent` maps to both new flags; a changed action key safely resets action-specific slots;
- 12-item watch/property snapshots survive interrupted mirror writes and reject partial/invalid input;
- reduced background candidate/output matches foreground `ReminderPolicy` for every kind.

### Screenshot checklist

Capture native pixels; do not scale source images. Replace obsolete v1.0 Schedule/override/jargon images rather than presenting them as v1.1 evidence.

All three sizes (390/416/454):

- Ring in, ring free, overdue remove, overdue insert, temporary out 2h50, temporary out 3h10;
- ring free >7d warning and ring in >28d warning;
- Upcoming with an overdue current action at rows 1–3 and scrolled to rows
  4–6; verify the actual row, future `if done today` rows, date pairs, and bars
  clear the round edge;
- long 12-hour date/time, 24-hour time, largest countdown, and warning wrapping;
- glance ring-in, ring-free, overdue, and temporary-out.

47 mm interaction set:

- first-run safety screen and NuvaRing schedule screen with no generic/Annovera copy;
- main menu in no-cycle, ring-in, temporary-out, and ring-free states;
- Edit dates showing only Insertion/Removal;
- Reminder Settings with Reminder 2 Off, Reminder 2 submenu On, and its time picker;
- day-before toggle, overdue repeat, and clock menus;
- early removal confirmation (`2d early`) and late insertion confirmation (`5h late`);
- History list and Cycle detail with insertion/removal variance;
- About, including the only `Not for generics or Annovera.` line;
- one-time migration notice;
- native day-before, Reminder 1, Reminder 2, overdue (`Ring overdue 1d 4h`), >3h, >7d, and >28d cards;
- button-only and touch-only navigation: Main UP → Upcoming, BACK, Main DOWN → History.

Release review fails if any main screenshot contains `Day n`, `REMOVE IN`, `INSERT IN`, `OVERDUE BY`, `MENU • START`, `recorded`, `tracking`, or a product disclaimer; if a non-About screen mentions a generic, EluRyng, or Annovera; or if any 390 px warning collides with the arc.

### Release gates

- All changed safety copy receives clinician/pharmacist review against the current NuvaRing prescribing information.
- Full string audit has no undeclared user-visible literal and no banned day-to-day term.
- Schema migration is tested from real v1 and v2 positional fixtures before any v3 write.
- Foreground, glance, and background remain within the existing budgets; background is remeasured after the two-slot ledger/copy change.
- A physical target verifies two same-day notifications, overdue interleaving, OS delay behavior, and notification launch context.
- Every state-changing action still requires native confirmation; projections and list navigation never mutate state.
