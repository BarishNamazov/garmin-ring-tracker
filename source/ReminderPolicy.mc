import Toybox.Math;
import Toybox.Lang;

// Reminder evaluation is pure. The service posts at most the one returned
// candidate, then calls markSent only after posting succeeds.
module ReminderPolicy {
    function actionKey(status as Lang.Dictionary) as Lang.String {
        return status[:underlyingAction].toString() + ":" + status[:underlyingActionUtc].toString();
    }

    function candidate(kind as Lang.Symbol, priority as Lang.Number, slot as Lang.Number?,
                       reminderSlot as Lang.Number?) as Lang.Dictionary {
        return { :kind => kind, :priority => priority, :slot => slot,
            :reminderSlot => reminderSlot, :consume1 => false, :consume2 => false };
    }

    function reminderAt(actionUtc as Lang.Number, dayOffset as Lang.Number, hour as Lang.Number, minute as Lang.Number) as Lang.Number? {
        var actionFields = CalendarMath.localFields(actionUtc);
        var shifted = CalendarMath.dateShift(actionFields, dayOffset);
        shifted[:hour] = hour;
        shifted[:minute] = minute;
        shifted[:second] = 0;
        var resolved = CalendarMath.wallToUtcUsingDevice(shifted);
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
            ledger[:dayOf1Sent] = false;
            ledger[:dayOf2Sent] = false;
            ledger[:lastOverdueSlot] = null;
        }

        if (status[:ringFreeOverSevenDays] && !ledger[:ringFreeExceededSent]) {
            return candidate(:ringFreeExceeded, 1, null, null);
        }
        if (status[:temporaryOutOpen] && status[:tempElapsed] > ScheduleModel.TEMP_LIMIT_SECONDS) {
            var open = ScheduleModel.tempOpen(active);
            var identity = (open as Lang.Dictionary)[:outUtc];
            if (ledger[:tempOutIdentity] == null || ledger[:tempOutIdentity] != identity) {
                ledger[:tempOutIdentity] = identity;
                ledger[:lastTempOutSlot] = null;
            }
            var repeatSeconds = reminders[:overdueRepeatHours] * CalendarMath.SECONDS_PER_HOUR;
            var tempSlot = Math.floor((status[:tempElapsed] - ScheduleModel.TEMP_LIMIT_SECONDS - 1) / repeatSeconds);
            if (ledger[:lastTempOutSlot] == null || tempSlot > ledger[:lastTempOutSlot]) {
                var selected = candidate(:tempOver3h, 2, tempSlot, null);
                selected[:tempOutIdentity] = identity;
                return selected;
            }
        }
        if (status[:ringInOverFourWeeks] && !ledger[:labelFourWeekSent]) {
            return candidate(:beyondFourWeeks, 3, null, null);
        }

        var deadline = status[:underlyingActionUtc];
        var sameDate = CalendarMath.dateOrdinal(nowUtc) == CalendarMath.dateOrdinal(deadline);
        if (sameDate) {
            var first = reminderAt(deadline, 0, reminders[:reminder1Hour], reminders[:reminder1Minute]);
            var second = reminders[:reminder2Enabled]
                ? reminderAt(deadline, 0, reminders[:reminder2Hour], reminders[:reminder2Minute]) : null;
            var firstEligible = first != null && nowUtc >= first && !ledger[:dayOf1Sent];
            var secondEligible = second != null && nowUtc >= second && !ledger[:dayOf2Sent];
            if (firstEligible || secondEligible) {
                var useSecond = secondEligible && (!firstEligible || second >= first);
                var selected = candidate(:dayOf, 4, null, useSecond ? 2 : 1);
                selected[:consume1] = firstEligible && first <= (useSecond ? second : first);
                selected[:consume2] = secondEligible && second <= (useSecond ? second : first);
                return selected;
            }
        }

        if (status[:underlyingSecondsRemaining] <= 0) {
            var overdueSlot = Math.floor((-status[:underlyingSecondsRemaining]) / (reminders[:overdueRepeatHours] * CalendarMath.SECONDS_PER_HOUR));
            if (ledger[:lastOverdueSlot] == null || overdueSlot > ledger[:lastOverdueSlot]) {
                return candidate(:overdue, 5, overdueSlot, null);
            }
            return null;
        }

        var dayBefore = reminderAt(deadline, -1, reminders[:reminder1Hour], reminders[:reminder1Minute]);
        var priorDate = CalendarMath.dateOrdinal(nowUtc) == CalendarMath.dateOrdinal(deadline) - 1;
        if (reminders[:dayBeforeEnabled] && priorDate && dayBefore != null
            && nowUtc >= dayBefore && !ledger[:dayBeforeSent]) {
            return candidate(:dayBefore, 6, null, null);
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
                ledger[:tempOutIdentity] = selected[:tempOutIdentity];
                ledger[:lastTempOutSlot] = selected[:slot];
                break;
            case :beyondFourWeeks:
                ledger[:labelFourWeekSent] = true;
                break;
            case :overdue:
                ledger[:lastOverdueSlot] = selected[:slot];
                break;
            case :dayOf:
                if (selected[:consume1]) { ledger[:dayOf1Sent] = true; }
                if (selected[:consume2]) { ledger[:dayOf2Sent] = true; }
                break;
            case :dayBefore:
                ledger[:dayBeforeSent] = true;
                break;
        }
    }
}
