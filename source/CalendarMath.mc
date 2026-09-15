import Toybox.Math;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Pure calendar helpers. Public time-dependent functions always receive UTC
// epoch seconds; none of this module reads Time.now().
module CalendarMath {
    const SECONDS_PER_MINUTE = 60;
    const SECONDS_PER_HOUR = 3600;
    const SECONDS_PER_DAY = 86400;
    const SEARCH_WINDOW_SECONDS = 4 * SECONDS_PER_HOUR;

    function utc(y as Lang.Number, m as Lang.Number, d as Lang.Number, hh as Lang.Number, mm as Lang.Number, ss as Lang.Number) as Lang.Number {
        return Gregorian.moment({
            :year => y,
            :month => m,
            :day => d,
            :hour => hh,
            :minute => mm,
            :second => ss
        }).value();
    }

    function localFields(utcSeconds as Lang.Number) as Lang.Dictionary {
        var info = Gregorian.info(new Time.Moment(utcSeconds), Time.FORMAT_SHORT);
        return {
            :year => info.year,
            :month => info.month,
            :day => info.day,
            :weekday => info.day_of_week,
            :hour => info.hour,
            :minute => info.min,
            :second => info.sec
        };
    }

    function utcFields(utcSeconds as Lang.Number) as Lang.Dictionary {
        var info = Gregorian.utcInfo(new Time.Moment(utcSeconds), Time.FORMAT_SHORT);
        return {
            :year => info.year,
            :month => info.month,
            :day => info.day,
            :hour => info.hour,
            :minute => info.min,
            :second => info.sec
        };
    }

    function dateShift(fields as Lang.Dictionary, days as Lang.Number) as Lang.Dictionary {
        var noon = Gregorian.moment({
            :year => fields[:year],
            :month => fields[:month],
            :day => fields[:day],
            :hour => 12,
            :minute => 0,
            :second => 0
        }).value();
        var shifted = Gregorian.utcInfo(new Time.Moment(noon + (days * SECONDS_PER_DAY)), Time.FORMAT_SHORT);
        return {
            :year => shifted.year,
            :month => shifted.month,
            :day => shifted.day,
            :hour => fields[:hour],
            :minute => fields[:minute],
            :second => fields[:second]
        };
    }

    function sameWall(info as Gregorian.Info, fields as Lang.Dictionary) as Lang.Boolean {
        return info.year == fields[:year]
            && info.month == fields[:month]
            && info.day == fields[:day]
            && info.hour == fields[:hour]
            && info.min == fields[:minute]
            && info.sec == fields[:second];
    }

    function wallOrder(info as Gregorian.Info, fields as Lang.Dictionary) as Lang.Number {
        var candidateWall = utc(info.year, info.month, info.day, info.hour, info.min, info.sec);
        var requestedWall = utc(fields[:year], fields[:month], fields[:day],
            fields[:hour], fields[:minute], fields[:second]);
        return candidateWall - requestedWall;
    }

    function infoWallValue(info as Gregorian.Info) as Lang.Number {
        return utc(info.year, info.month, info.day, info.hour, info.min, info.sec);
    }

    function hasNumber(values as Lang.Array, value as Lang.Number) as Lang.Boolean {
        for (var i = 0; i < values.size(); i += 1) {
            if (values[i] == value) { return true; }
        }
        return false;
    }

    // Resolve a local wall tuple near a UTC seed. Ambiguous times choose the
    // match closest to seed (earlier wins ties). Nonexistent times advance to
    // the first representable local minute after the requested wall time.
    function resolveLocalWall(fields as Lang.Dictionary, seedUtc as Lang.Number) as Lang.Dictionary? {
        var best = null;
        var bestDistance = SEARCH_WINDOW_SECONDS + 1;
        var firstAfter = null;
        var firstAfterOrder = SEARCH_WINDOW_SECONDS * 2;
        var start = seedUtc - SEARCH_WINDOW_SECONDS;
        var stop = seedUtc + SEARCH_WINDOW_SECONDS;
        var targetWall = utc(fields[:year], fields[:month], fields[:day],
            fields[:hour], fields[:minute], fields[:second]);
        var offsets = [];
        var transitions = [];
        var previousUtc = start;
        var previousOffset = null;

        // Discover every offset present in the bounded window. Exact local
        // candidates are then derived algebraically; only an hour containing
        // an offset transition needs a minute-resolution scan. This preserves
        // the specified behavior without thousands of Gregorian conversions
        // in one foreground callback (which trips the device watchdog).
        for (var sampleUtc = start; sampleUtc <= stop; sampleUtc += SECONDS_PER_HOUR) {
            var sampleInfo = Gregorian.info(new Time.Moment(sampleUtc), Time.FORMAT_SHORT);
            var offset = infoWallValue(sampleInfo) - sampleUtc;
            if (!hasNumber(offsets, offset)) { offsets.add(offset); }
            if (previousOffset != null && offset != previousOffset) {
                transitions.add([previousUtc, sampleUtc]);
            }
            previousUtc = sampleUtc;
            previousOffset = offset;
        }

        for (var i = 0; i < offsets.size(); i += 1) {
            var candidate = targetWall - offsets[i];
            if (candidate < start || candidate > stop) { continue; }
            var info = Gregorian.info(new Time.Moment(candidate), Time.FORMAT_SHORT);
            if (sameWall(info, fields)) {
                var distance = (candidate - seedUtc).abs();
                if (distance < bestDistance || (distance == bestDistance && (best == null || candidate < best))) {
                    best = candidate;
                    bestDistance = distance;
                }
            } else {
                var order = infoWallValue(info) - targetWall;
                if (order > 0 && order < firstAfterOrder) {
                    firstAfter = candidate;
                    firstAfterOrder = order;
                }
            }
        }

        // For a spring gap, locate the first representable wall minute after
        // the skipped tuple. At most one hourly transition band is normally
        // scanned, keeping execution bounded and watchdog-safe.
        for (var t = 0; t < transitions.size(); t += 1) {
            var band = transitions[t] as Lang.Array;
            for (var probe = band[0]; probe <= band[1]; probe += SECONDS_PER_MINUTE) {
                var probeInfo = Gregorian.info(new Time.Moment(probe), Time.FORMAT_SHORT);
                var probeOrder = infoWallValue(probeInfo) - targetWall;
                if (probeOrder > 0 && probeOrder < firstAfterOrder) {
                    firstAfter = probe;
                    firstAfterOrder = probeOrder;
                }
            }
        }

        if (best != null) {
            return { :utc => best, :adjusted => false };
        }
        if (firstAfter != null) {
            return { :utc => firstAfter, :adjusted => true };
        }
        return null;
    }

    function addLocalCalendarDays(sourceUtc as Lang.Number, days as Lang.Number) as Lang.Dictionary {
        var target = dateShift(localFields(sourceUtc), days);
        var seed = sourceUtc + (days * SECONDS_PER_DAY);
        return resolveLocalWall(target, seed);
    }

    function wallToUtc(fields as Lang.Dictionary, timeZoneOffsetSeconds as Lang.Number) as Lang.Dictionary? {
        var shaped = utc(fields[:year], fields[:month], fields[:day], fields[:hour], fields[:minute], fields[:second]);
        return resolveLocalWall(fields, shaped - timeZoneOffsetSeconds);
    }

    function wallToUtcUsingDevice(fields as Lang.Dictionary) as Lang.Dictionary? {
        return wallToUtc(fields, System.getClockTime().timeZoneOffset);
    }

    function dateOrdinal(utcSeconds as Lang.Number) as Lang.Number {
        var fields = localFields(utcSeconds);
        var noon = utc(fields[:year], fields[:month], fields[:day], 12, 0, 0);
        return Math.floor(noon / SECONDS_PER_DAY);
    }

    function dayOfCycle(nowUtc as Lang.Number, insertionUtc as Lang.Number) as Lang.Number {
        var value = dateOrdinal(nowUtc) - dateOrdinal(insertionUtc) + 1;
        return value < 1 ? 1 : value;
    }

    function countdown(deltaSeconds as Lang.Number) as Lang.Dictionary {
        var absolute = deltaSeconds.abs();
        return {
            :days => Math.floor(absolute / SECONDS_PER_DAY),
            :hours => Math.floor((absolute % SECONDS_PER_DAY) / SECONDS_PER_HOUR),
            :minutes => Math.floor((absolute % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE),
            :due => deltaSeconds == 0,
            :overdue => deltaSeconds < 0
        };
    }

    function glanceCountdown(deltaSeconds as Lang.Number) as Lang.Dictionary {
        if (deltaSeconds <= 0) { return { :value => 0, :unit => :now }; }
        if (deltaSeconds > SECONDS_PER_DAY) {
            return { :value => Math.ceil(deltaSeconds.toFloat() / SECONDS_PER_DAY).toNumber(), :unit => :days };
        }
        if (deltaSeconds >= SECONDS_PER_HOUR) {
            return { :value => Math.ceil(deltaSeconds.toFloat() / SECONDS_PER_HOUR).toNumber(), :unit => :hours };
        }
        return { :value => Math.ceil(deltaSeconds.toFloat() / SECONDS_PER_MINUTE).toNumber(), :unit => :minutes };
    }

    function isLeapYear(year as Lang.Number) as Lang.Boolean {
        return (year % 400 == 0) || ((year % 4 == 0) && (year % 100 != 0));
    }

    function daysInMonth(year as Lang.Number, month as Lang.Number) as Lang.Number {
        if (month == 2) { return isLeapYear(year) ? 29 : 28; }
        if (month == 4 || month == 6 || month == 9 || month == 11) { return 30; }
        return 31;
    }

    function validWall(fields as Lang.Dictionary) as Lang.Boolean {
        var y = fields[:year];
        var m = fields[:month];
        var d = fields[:day];
        var hh = fields[:hour];
        var mm = fields[:minute];
        var ss = fields[:second];
        return y >= 1970 && y <= 2106
            && m >= 1 && m <= 12
            && d >= 1 && d <= daysInMonth(y, m)
            && hh >= 0 && hh <= 23
            && mm >= 0 && mm <= 59
            && ss >= 0 && ss <= 59;
    }
}
