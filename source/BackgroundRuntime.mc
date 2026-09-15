import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Compact background record:
// [schema, revision, active, daysIn, daysOut, reminders, ledger]
// active: [cycle, inserted, removed, scheduledRemoval, finalInsertion,
//          fourWeek, freeCeiling, openOut, action, actionDeadline]
// kinds: 0 free-limit, 1 temporary-out, 2 four-week, 3 overdue,
//        4 day-of, 5 day-before; actions: 0 remove, 1 insert, 2 replace.
(:background)
module BackgroundRuntime {
    function load() as Lang.Array? {
        try {
            var raw = Storage.getValue("ringTrackerBackground");
            if (!(raw instanceof Lang.Array) || !valid(raw as Lang.Array)) {
                markMirrorError("invalid background mirror");
                return null;
            }
            var state = Storage.getValue("ringTrackerState");
            if (!(state instanceof Lang.Array) || (state as Lang.Array).size() < 10
                || (state as Lang.Array)[0] != 2 || (state as Lang.Array)[9] != (raw as Lang.Array)[1]) {
                markMirrorError("background revision mismatch");
                return null;
            }
            return raw as Lang.Array;
        } catch (ignored) {
            markMirrorError("background read failed");
            return null;
        }
    }

    function save(state as Lang.Array) as Void {
        if (!valid(state)) { markMirrorError("background write rejected"); return; }
        Storage.setValue("ringTrackerBackground", state);
    }

    function markMirrorError(message as Lang.String) as Void {
        try { Storage.setValue("ringTrackerMirrorError", message); } catch (ignored) { }
    }

    function valid(a as Lang.Array) as Lang.Boolean {
        if (a.size() != 7 || a[0] != 2 || !nonnegative(a[1])
            || !between(a[3], 21, 35) || !between(a[4], 0, 7)
            || !(a[5] instanceof Lang.Array) || !(a[6] instanceof Lang.Array)) { return false; }
        var reminders = a[5] as Lang.Array;
        var ledger = a[6] as Lang.Array;
        if (reminders.size() != 6 || !between(reminders[0], 0, 23)
            || !between(reminders[1], 0, 59)
            || !(reminders[2] == 1 || reminders[2] == 3 || reminders[2] == 6
                || reminders[2] == 12 || reminders[2] == 24)
            || !(reminders[3] instanceof Lang.Boolean) || !(reminders[4] instanceof Lang.Boolean)
            || !(reminders[5] == 0 || reminders[5] == 12 || reminders[5] == 24)) { return false; }
        if (ledger.size() != 8 || !nonnegative(ledger[0]) || !(ledger[1] instanceof Lang.String)
            || (ledger[1] as Lang.String).length() > 64
            || !(ledger[2] instanceof Lang.Boolean) || !(ledger[3] instanceof Lang.Boolean)
            || !nullableNonnegative(ledger[4]) || !nullableNonnegative(ledger[5])
            || !(ledger[6] instanceof Lang.Boolean) || !(ledger[7] instanceof Lang.Boolean)) { return false; }
        if (a[2] == null) { return true; }
        if (!(a[2] instanceof Lang.Array) || (a[2] as Lang.Array).size() != 10) { return false; }
        var active = a[2] as Lang.Array;
        if (!between(active[0], 1, 2147483647) || !(active[1] instanceof Lang.Number)
            || (active[2] != null && (!(active[2] instanceof Lang.Number) || active[2] < active[1]))
            || !(active[3] instanceof Lang.Number) || active[3] < active[1]
            || !(active[4] instanceof Lang.Number) || !(active[5] instanceof Lang.Number)
            || active[5] < active[1] || (active[6] != null && !(active[6] instanceof Lang.Number))
            || (active[7] != null && (!(active[7] instanceof Lang.Number) || active[7] < active[1]))
            || !between(active[8], 0, 2) || !(active[9] instanceof Lang.Number)) { return false; }
        if (active[2] == null) {
            return active[6] == null && active[9] == active[3]
                && active[8] == (a[4] == 0 ? 2 : 0);
        }
        return active[6] instanceof Lang.Number && active[6] > active[2]
            && active[7] == null && active[8] == 1 && active[9] == active[4];
    }

    function between(value, low as Lang.Number, high as Lang.Number) as Lang.Boolean {
        return value instanceof Lang.Number && value >= low && value <= high;
    }

    function nonnegative(value) as Lang.Boolean {
        return value instanceof Lang.Number && value >= 0;
    }

    function nullableNonnegative(value) as Lang.Boolean {
        return value == null || nonnegative(value);
    }

    function evaluate(nowUtc as Lang.Number, state as Lang.Array) as Lang.Array? {
        var active = state[2] as Lang.Array?;
        if (active == null) { return null; }
        var reminders = state[5] as Lang.Array;
        var ledger = state[6] as Lang.Array;
        var deadline = active[9] as Lang.Number;
        var action = active[8] as Lang.Number;
        var actionName = action == 0 ? "remove" : (action == 1 ? "insert" : "replace");
        var key = actionName + ":" + deadline.toString();
        if (ledger[0] != active[0] || !(ledger[1] as Lang.String).equals(key)) {
            ledger[0] = active[0]; ledger[1] = key;
            ledger[2] = false; ledger[3] = false;
            ledger[4] = null; ledger[5] = null;
            ledger[6] = false; ledger[7] = false;
        }

        if (active[2] != null && active[6] != null && nowUtc >= active[6] && !ledger[7]) {
            return [0, action, null];
        }
        if (active[7] != null) {
            var elapsed = nowUtc - active[7];
            if (elapsed > 10800) {
                var tempSlot = Math.floor((elapsed - 10801) / (reminders[2] * 3600));
                if (ledger[5] == null || tempSlot > ledger[5]) { return [1, action, tempSlot]; }
            }
        }
        if (active[2] == null && nowUtc > active[5] && !ledger[6]) {
            return [2, action, null];
        }
        var delta = deadline - nowUtc;
        if (delta <= 0) {
            var overdueSlot = Math.floor((-delta) / (reminders[2] * 3600));
            if (ledger[4] == null || overdueSlot > ledger[4]) { return [3, action, overdueSlot]; }
            return null;
        }

        var dayOf = reminderAt(deadline, 0, reminders[0], reminders[1]);
        if (dayOf != null && dayOf < deadline && nowUtc >= dayOf && !ledger[3]) {
            return [4, action, null];
        }
        var dayBefore = reminderAt(deadline, -1, reminders[0], reminders[1]);
        if (dayBefore != null && dayBefore < deadline && nowUtc >= dayBefore
            && (dayOf == null || nowUtc < dayOf) && !ledger[2]) {
            return [5, action, null];
        }
        return null;
    }

    function markSent(state as Lang.Array, selected as Lang.Array) as Void {
        var ledger = state[6] as Lang.Array;
        if (selected[0] == 0) { ledger[7] = true; }
        else if (selected[0] == 1) { ledger[5] = selected[2]; }
        else if (selected[0] == 2) { ledger[6] = true; }
        else if (selected[0] == 3) { ledger[4] = selected[2]; }
        else if (selected[0] == 4) { ledger[3] = true; ledger[2] = true; }
        else if (selected[0] == 5) { ledger[2] = true; }
    }

    function shaped(year as Lang.Number, month as Lang.Number, day as Lang.Number,
                    hour as Lang.Number, minute as Lang.Number) as Lang.Number {
        return Gregorian.moment({:year=>year, :month=>month, :day=>day,
            :hour=>hour, :minute=>minute, :second=>0}).value();
    }

    function wallValue(info as Gregorian.Info) as Lang.Number {
        return shaped(info.year, info.month, info.day, info.hour, info.min);
    }

    function reminderAt(actionUtc as Lang.Number, dayOffset as Lang.Number,
                        hour as Lang.Number, minute as Lang.Number) as Lang.Number? {
        var action = Gregorian.info(new Time.Moment(actionUtc), Time.FORMAT_SHORT);
        var noon = shaped(action.year, action.month, action.day, 12, 0) + (dayOffset * 86400);
        var date = Gregorian.utcInfo(new Time.Moment(noon), Time.FORMAT_SHORT);
        var target = shaped(date.year, date.month, date.day, hour, minute);
        var seed = target - System.getClockTime().timeZoneOffset;
        for (var attempt = 0; attempt < 3; attempt += 1) {
            var info = Gregorian.info(new Time.Moment(seed), Time.FORMAT_SHORT);
            var difference = wallValue(info) - target;
            if (difference == 0) { return seed; }
            seed -= difference;
        }
        var firstAfter = null;
        var firstDifference = 10801;
        for (var probe = seed - 7200; probe <= seed + 7200; probe += 60) {
            var probeInfo = Gregorian.info(new Time.Moment(probe), Time.FORMAT_SHORT);
            var probeDifference = wallValue(probeInfo) - target;
            if (probeDifference == 0) { return probe; }
            if (probeDifference > 0 && probeDifference < firstDifference) {
                firstAfter = probe; firstDifference = probeDifference;
            }
        }
        return firstAfter;
    }
}
