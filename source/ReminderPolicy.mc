import Toybox.Math;
import Toybox.Lang;

// Reminder evaluation is pure. The service posts at most the one returned
// candidate, then calls markSent only after posting succeeds.
(:background)
module ReminderPolicy {
    function actionKey(status as Lang.Dictionary) as Lang.String {
        return status[:nextAction].toString() + ":" + status[:nextActionUtc].toString();
    }

    function candidate(kind as Lang.Symbol, priority as Lang.Number, slot as Lang.Number?) as Lang.Dictionary {
        return { :kind => kind, :priority => priority, :slot => slot };
    }

    function reminderAt(actionUtc as Lang.Number, dayOffset as Lang.Number, hour as Lang.Number, minute as Lang.Number) as Lang.Number? {
        var actionFields = CalendarMath.localFields(actionUtc);
        var shifted = CalendarMath.dateShift(actionFields, dayOffset);
        shifted[:hour] = hour;
        shifted[:minute] = minute;
        shifted[:second] = 0;
        var resolved = CalendarMath.resolveLocalWall(shifted, actionUtc + (dayOffset * CalendarMath.SECONDS_PER_DAY));
        return resolved == null ? null : resolved[:utc];
    }

    function evaluate(nowUtc as Lang.Number, active as Lang.Dictionary?, regimen as Lang.Dictionary, reminders as Lang.Dictionary, ledger as Lang.Dictionary) as Lang.Dictionary? {
        if (active == null) { return null; }
        var status = ScheduleModel.deriveStatus(nowUtc, active, regimen);
        var key = actionKey(status);
        if (ledger[:cycleId] != active[:cycleId] || !(ledger[:actionKey] as Lang.String).equals(key)) {
            ledger[:cycleId] = active[:cycleId];
            ledger[:actionKey] = key;
            ledger[:dayBeforeSent] = false;
            ledger[:dayOfSent] = false;
            ledger[:lastOverdueSlot] = null;
            ledger[:lastTempOutSlot] = null;
        }

        if (status[:ringFreeLimitExceeded] && !ledger[:ringFreeExceededSent]) {
            return candidate(:ringFreeExceeded, 1, null);
        }
        if (status[:temporaryOutOpen] && status[:tempElapsed] > ScheduleModel.TEMP_LIMIT_SECONDS) {
            var repeatSeconds = reminders[:overdueRepeatHours] * CalendarMath.SECONDS_PER_HOUR;
            var tempSlot = Math.floor((status[:tempElapsed] - ScheduleModel.TEMP_LIMIT_SECONDS - 1) / repeatSeconds);
            if (ledger[:lastTempOutSlot] == null || tempSlot > ledger[:lastTempOutSlot]) {
                return candidate(:tempOver3h, 2, tempSlot);
            }
        }
        if (status[:beyondLabelFourWeeks] && !ledger[:labelFourWeekSent]) {
            return candidate(:beyondFourWeeks, 3, null);
        }
        if (status[:secondsRemaining] <= 0) {
            var overdueSlot = Math.floor((-status[:secondsRemaining]) / (reminders[:overdueRepeatHours] * CalendarMath.SECONDS_PER_HOUR));
            if (ledger[:lastOverdueSlot] == null || overdueSlot > ledger[:lastOverdueSlot]) {
                return candidate(:overdue, 4, overdueSlot);
            }
            return null;
        }

        var dayOf = reminderAt(status[:nextActionUtc], 0, reminders[:localHour], reminders[:localMinute]);
        if (dayOf != null && dayOf < status[:nextActionUtc] && nowUtc >= dayOf && !ledger[:dayOfSent]) {
            return candidate(:dayOf, 5, null);
        }
        var dayBefore = reminderAt(status[:nextActionUtc], -1, reminders[:localHour], reminders[:localMinute]);
        if (dayBefore != null && dayBefore < status[:nextActionUtc] && nowUtc >= dayBefore && !ledger[:dayBeforeSent]) {
            return candidate(:dayBefore, 6, null);
        }
        return null;
    }

    function markSent(ledger as Lang.Dictionary, selected as Lang.Dictionary?) as Void {
        if (selected == null) { return; }
        switch (selected[:kind]) {
            case :ringFreeExceeded:
                ledger[:ringFreeExceededSent] = true;
                break;
            case :tempOver3h:
                ledger[:lastTempOutSlot] = selected[:slot];
                break;
            case :beyondFourWeeks:
                ledger[:labelFourWeekSent] = true;
                break;
            case :overdue:
                ledger[:lastOverdueSlot] = selected[:slot];
                break;
            case :dayOf:
                ledger[:dayOfSent] = true;
                break;
            case :dayBefore:
                ledger[:dayBeforeSent] = true;
                break;
        }
    }
}
