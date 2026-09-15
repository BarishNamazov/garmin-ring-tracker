import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Numeric codes keep the hourly process allocation-light:
// kinds 0 free-limit, 1 temporary-out, 2 four-week, 3 overdue,
//       4 day-of, 5 day-before;
// actions 0 remove, 1 insert, 2 replace, 3 ring-back-in.
(:background)
module BackgroundRuntime {
    function load() as Lang.Array? {
        try {
            var raw = Storage.getValue("ringTrackerBackground");
            if (raw instanceof Lang.Array && raw.size() >= 6 && raw[0] == 1) {
                var active = raw[1];
                if (active == null || (active instanceof Lang.Array && active.size() >= 14)) {
                    return raw as Lang.Array;
                }
            }
        } catch (ignored) {
        }
        return null;
    }

    function save(state as Lang.Array) as Void {
        Storage.setValue("ringTrackerBackground", state);
    }

    function evaluate(nowUtc as Lang.Number, state as Lang.Array) as Lang.Array? {
        var active = state[1] as Lang.Array?;
        if (active == null) { return null; }
        var reminders = state[4] as Lang.Array;
        var ledger = state[5] as Lang.Array;
        var deadline = active[12] as Lang.Number;
        var action = active[13] as Lang.Number;
        var actionName = action == 0 ? "remove" : (action == 1 ? "insert" : (action == 2 ? "replace" : "ringBackIn"));
        var key = actionName + ":" + deadline.toString();
        if (ledger[0] != active[0] || !(ledger[1] as Lang.String).equals(key)) {
            ledger[0] = active[0];
            ledger[1] = key;
            ledger[2] = false;
            ledger[3] = false;
            ledger[4] = null;
            ledger[5] = null;
        }

        if (active[3] != null && active[8] != null && nowUtc > active[8] && !ledger[7]) {
            return [0, action, null];
        }
        var open = active[11] as Lang.Array;
        if (open.size() > 0) {
            var elapsed = nowUtc - (open[0] as Lang.Array)[0];
            if (elapsed > 10800) {
                var tempSlot = Math.floor((elapsed - 10801) / (reminders[2] * 3600));
                if (ledger[5] == null || tempSlot > ledger[5]) { return [1, action, tempSlot]; }
            }
        }
        if (active[3] == null && nowUtc > active[7] && !ledger[6]) {
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
        if (dayBefore != null && dayBefore < deadline && nowUtc >= dayBefore && !ledger[2]) {
            return [5, action, null];
        }
        return null;
    }

    function markSent(state as Lang.Array, selected as Lang.Array) as Void {
        var ledger = state[5] as Lang.Array;
        if (selected[0] == 0) { ledger[7] = true; }
        else if (selected[0] == 1) { ledger[5] = selected[2]; }
        else if (selected[0] == 2) { ledger[6] = true; }
        else if (selected[0] == 3) { ledger[4] = selected[2]; }
        else if (selected[0] == 4) { ledger[3] = true; }
        else if (selected[0] == 5) { ledger[2] = true; }
    }

    function shaped(year as Lang.Number, month as Lang.Number, day as Lang.Number,
                            hour as Lang.Number, minute as Lang.Number) as Lang.Number {
        return Gregorian.moment({ :year => year, :month => month, :day => day,
            :hour => hour, :minute => minute, :second => 0 }).value();
    }

    function wallValue(info as Gregorian.Info) as Lang.Number {
        return shaped(info.year, info.month, info.day, info.hour, info.min);
    }

    // Resolve the reminder in the device's current local calendar. Algebraic
    // offset correction handles ordinary/DST dates; the bounded scan handles
    // the uncommon configured minute that falls inside a spring gap.
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
                firstAfter = probe;
                firstDifference = probeDifference;
            }
        }
        return firstAfter;
    }
}
