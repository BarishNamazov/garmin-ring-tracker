import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;

module Ui {
    const BLACK = 0x000000;
    const PRIMARY = 0xF4F7F8;
    const SECONDARY = 0x9AA6AD;
    const TRACK = 0x20262C;
    const RING_IN = 0x38D6A0;
    const RING_FREE = 0xA690FF;
    const AMBER = 0xFFB020;
    const RED = 0xFF4D5E;
    const RING_IN_DIM = 0x196047;
    const RING_FREE_DIM = 0x4B4173;
    const CYCLE_FREE_DIM = 0x1D1928;
    const MAIN_RING_IN_OTHER = 0x228060;
    const MAIN_RING_FREE_OTHER = 0x645699;

    function s(id as Lang.ResourceId) as Lang.String {
        return Application.loadResource(id) as Lang.String;
    }

    function fmt(id as Lang.ResourceId, values as Lang.Array) as Lang.String {
        return Lang.format(s(id), values);
    }

    function scale(dc as Graphics.Dc) as Lang.Float {
        var size = dc.getWidth() < dc.getHeight() ? dc.getWidth() : dc.getHeight();
        return size.toFloat() / 416.0;
    }

    function px(dc as Graphics.Dc, value as Lang.Number) as Lang.Number {
        return Math.round(value * scale(dc)).toNumber();
    }

    function clear(dc as Graphics.Dc) as Void {
        dc.setColor(BLACK, BLACK);
        dc.clear();
    }

    function ellipsize(dc as Graphics.Dc, text as Lang.String, font, maxWidth as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) { return text; }
        var suffix = s(Rez.Strings.Ellipsis);
        if (dc.getTextWidthInPixels(suffix, font) > maxWidth) { return ""; }
        var end = text.length();
        while (end > 0) {
            var shortened = text.substring(0, end) + suffix;
            if (dc.getTextWidthInPixels(shortened, font) <= maxWidth) { return shortened; }
            end -= 1;
        }
        return suffix;
    }

    function centered(dc as Graphics.Dc, y as Lang.Number, text as Lang.String, font, color as Lang.Number, maxWidth as Lang.Number) as Void {
        var shown = ellipsize(dc, text, font, maxWidth);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, y, font, shown, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function trackedCentered(dc as Graphics.Dc, y as Lang.Number, text as Lang.String,
                             font, color as Lang.Number, tracking as Lang.Number) as Void {
        var width = 0;
        for (var i = 0; i < text.length(); i += 1) {
            width += dc.getTextWidthInPixels(text.substring(i, i + 1), font);
            if (i + 1 < text.length()) { width += tracking; }
        }
        var x = (dc.getWidth() - width) / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var j = 0; j < text.length(); j += 1) {
            var glyph = text.substring(j, j + 1);
            dc.drawText(x, y, font, glyph,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += dc.getTextWidthInPixels(glyph, font) + tracking;
        }
    }

    function runsWidth(dc as Graphics.Dc, runs as Lang.Array, font) as Lang.Number {
        var width = 0;
        for (var i = 0; i < runs.size(); i += 1) {
            var run = runs[i] as Lang.Array;
            width += dc.getTextWidthInPixels(run[0] as Lang.String, font);
        }
        return width;
    }

    function centeredRuns(dc as Graphics.Dc, y as Lang.Number, runs as Lang.Array, font) as Void {
        var x = (dc.getWidth() - runsWidth(dc, runs, font)) / 2;
        for (var i = 0; i < runs.size(); i += 1) {
            var run = runs[i] as Lang.Array;
            var text = run[0] as Lang.String;
            dc.setColor(run[1] as Lang.Number, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, y, font, text,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += dc.getTextWidthInPixels(text, font);
        }
    }

    function mainArcStroke(dc as Graphics.Dc) as Lang.Number {
        var size = dc.getWidth() < dc.getHeight() ? dc.getWidth() : dc.getHeight();
        return Math.round(size * 0.035).toNumber();
    }

    function mainArcRadius(dc as Graphics.Dc) as Lang.Number {
        var size = dc.getWidth() < dc.getHeight() ? dc.getWidth() : dc.getHeight();
        var outer = Math.round(size * 0.485).toNumber();
        return outer - (mainArcStroke(dc) / 2);
    }

    function mainChordBudget(dc as Graphics.Dc, y as Lang.Number) as Lang.Number {
        var radius = Math.round((dc.getWidth() < dc.getHeight()
            ? dc.getWidth() : dc.getHeight()) * 0.485).toNumber();
        var dy = (y - (dc.getHeight() / 2)).abs();
        if (dy >= radius) { return dc.getWidth() - px(dc, 96); }
        var halfChord = Math.sqrt((radius * radius) - (dy * dy));
        var chord = Math.floor(halfChord * 2).toNumber();
        var budget = Math.floor(chord * 0.70).toNumber();
        var clearanceBudget = chord - (2 * px(dc, 26));
        return budget < clearanceBudget ? budget : clearanceBudget;
    }

    function mainChordClearanceBudget(dc as Graphics.Dc, y as Lang.Number) as Lang.Number {
        var radius = Math.round((dc.getWidth() < dc.getHeight()
            ? dc.getWidth() : dc.getHeight()) * 0.485).toNumber();
        var dy = (y - (dc.getHeight() / 2)).abs();
        var clearance = px(dc, 26);
        if (dy >= radius) { return dc.getWidth() - (2 * clearance); }
        var halfChord = Math.sqrt((radius * radius) - (dy * dy));
        return Math.floor(halfChord * 2).toNumber() - (2 * clearance);
    }

    function mainInnerChordBudget(dc as Graphics.Dc, y as Lang.Number) as Lang.Number {
        var radius = mainArcRadius(dc) - (mainArcStroke(dc) / 2) - px(dc, 5);
        var dy = (y - (dc.getHeight() / 2)).abs();
        if (dy >= radius) { return dc.getWidth() - px(dc, 96); }
        return Math.floor(Math.sqrt((radius * radius) - (dy * dy)) * 2).toNumber();
    }

    function row(dc as Graphics.Dc, y as Lang.Number, label as Lang.String, value as Lang.String) as Void {
        var xLeft = px(dc, 66);
        var xRight = dc.getWidth() - px(dc, 66);
        var width = xRight - xLeft;
        var labelWidth = (width * 48) / 100;
        dc.setColor(SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY,
                    ellipsize(dc, label, Graphics.FONT_SYSTEM_XTINY, labelWidth),
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, y, Graphics.FONT_SYSTEM_TINY,
                    ellipsize(dc, value, Graphics.FONT_SYSTEM_TINY, width - labelWidth),
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function compactRow(dc as Graphics.Dc, y as Lang.Number, label as Lang.String, value as Lang.String) as Void {
        var xLeft = px(dc, 66);
        var xRight = dc.getWidth() - px(dc, 66);
        var width = xRight - xLeft;
        var labelWidth = (width * 52) / 100;
        dc.setColor(SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY,
                    ellipsize(dc, label, Graphics.FONT_SYSTEM_XTINY, labelWidth),
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY,
                    ellipsize(dc, value, Graphics.FONT_SYSTEM_XTINY, width - labelWidth),
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function dateTimeRow(dc as Graphics.Dc, y as Lang.Number, label as Lang.String,
                         utcSeconds as Lang.Number, clockFormat as Lang.Number) as Void {
        var xLeft = px(dc, 66);
        var xRight = dc.getWidth() - px(dc, 66);
        var width = xRight - xLeft;
        var labelWidth = (width * 52) / 100;
        dc.setColor(SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY,
                    ellipsize(dc, label, Graphics.FONT_SYSTEM_XTINY, labelWidth),
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, y - px(dc, 10), Graphics.FONT_SYSTEM_XTINY,
                    ellipsize(dc, shortDate(utcSeconds), Graphics.FONT_SYSTEM_XTINY, width - labelWidth),
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, y + px(dc, 12), Graphics.FONT_SYSTEM_XTINY,
                    timeForUtc(utcSeconds, clockFormat),
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function twoDigits(value as Lang.Number) as Lang.String {
        return value.format("%02d");
    }

    function timestamp(utcSeconds as Lang.Number, clockFormat as Lang.Number) as Lang.String {
        return shortDate(utcSeconds) + "\n" + timeForUtc(utcSeconds, clockFormat);
    }

    function dateOnly(utcSeconds as Lang.Number) as Lang.String {
        return shortDate(utcSeconds);
    }

    function shortDate(utcSeconds as Lang.Number) as Lang.String {
        var f = CalendarMath.localFields(utcSeconds);
        return weekdayName(f[:weekday]) + " " + f[:day].toString() + " " + monthName(f[:month]);
    }

    function compactDate(utcSeconds as Lang.Number) as Lang.String {
        var f = CalendarMath.localFields(utcSeconds);
        return f[:day].toString() + " " + monthName(f[:month]);
    }

    function datePairParts(inUtc as Lang.Number, outUtc, compact as Lang.Boolean) as Lang.Array<Lang.String> {
        var inDate = compact ? compactDate(inUtc) : shortDate(inUtc);
        var outDate = outUtc == null ? s(Rez.Strings.NotRecorded)
            : (compact ? compactDate(outUtc as Lang.Number) : shortDate(outUtc as Lang.Number));
        return [fmt(Rez.Strings.UpcomingInTemplate, [inDate]),
            fmt(Rez.Strings.UpcomingOutTemplate, [outDate])];
    }

    function datePairText(inUtc as Lang.Number, outUtc, compact as Lang.Boolean) as Lang.String {
        var parts = datePairParts(inUtc, outUtc, compact);
        return parts[0] + s(Rez.Strings.DateTimeSeparator) + parts[1];
    }

    function datePairLayout(dc as Graphics.Dc, inUtc as Lang.Number, outUtc,
                            maxWidth as Lang.Number) as Lang.Number {
        if (dc.getTextWidthInPixels(datePairText(inUtc, outUtc, false),
                Graphics.FONT_SYSTEM_TINY) <= maxWidth) {
            return 0;
        }
        if (dc.getTextWidthInPixels(datePairText(inUtc, outUtc, true),
                Graphics.FONT_SYSTEM_XTINY) <= maxWidth) {
            return 1;
        }
        return 2;
    }

    function drawDatePair(dc as Graphics.Dc, y as Lang.Number, inUtc as Lang.Number,
                          outUtc, maxWidth as Lang.Number, color as Lang.Number) as Lang.Number {
        var layout = datePairLayout(dc, inUtc, outUtc, maxWidth);
        if (layout < 2) {
            centered(dc, y, datePairText(inUtc, outUtc, layout == 1),
                layout == 0 ? Graphics.FONT_SYSTEM_TINY : Graphics.FONT_SYSTEM_XTINY,
                color, maxWidth);
            return 1;
        }

        var parts = datePairParts(inUtc, outUtc, true);
        centered(dc, y - px(dc, 6), parts[0], Graphics.FONT_SYSTEM_XTINY, color, maxWidth);
        centered(dc, y + px(dc, 14), parts[1], Graphics.FONT_SYSTEM_XTINY, color, maxWidth);
        return 2;
    }

    function compactTimestamp(utcSeconds as Lang.Number, clockFormat as Lang.Number) as Lang.String {
        return compactDate(utcSeconds) + s(Rez.Strings.DateTimeSeparator) + timeForUtc(utcSeconds, clockFormat);
    }

    function shortTimestamp(utcSeconds as Lang.Number, clockFormat as Lang.Number) as Lang.String {
        return shortDate(utcSeconds) + s(Rez.Strings.DateTimeSeparator) + timeForUtc(utcSeconds, clockFormat);
    }

    function monthName(month as Lang.Number) as Lang.String {
        var ids = [Rez.Strings.Jan, Rez.Strings.Feb, Rez.Strings.Mar, Rez.Strings.Apr, Rez.Strings.May, Rez.Strings.Jun,
                   Rez.Strings.Jul, Rez.Strings.Aug, Rez.Strings.Sep, Rez.Strings.Oct, Rez.Strings.Nov, Rez.Strings.Dec];
        return s(ids[month - 1]);
    }

    function weekdayName(weekday as Lang.Number) as Lang.String {
        var ids = [Rez.Strings.Sun, Rez.Strings.Mon, Rez.Strings.Tue, Rez.Strings.Wed,
                   Rez.Strings.Thu, Rez.Strings.Fri, Rez.Strings.Sat];
        return s(ids[weekday - 1]);
    }

    function timeOnly(hour as Lang.Number, minute as Lang.Number, clockFormat as Lang.Number) as Lang.String {
        var use24 = clockFormat == 24 || (clockFormat == 0 && System.getDeviceSettings().is24Hour);
        if (use24) { return twoDigits(hour) + s(Rez.Strings.TimeSeparator) + twoDigits(minute); }
        var h = hour % 12;
        if (h == 0) { h = 12; }
        return h.toString() + s(Rez.Strings.TimeSeparator) + twoDigits(minute) + " " + (hour < 12 ? s(Rez.Strings.Am) : s(Rez.Strings.Pm));
    }

    function timeForUtc(utcSeconds as Lang.Number, clockFormat as Lang.Number) as Lang.String {
        var f = CalendarMath.localFields(utcSeconds);
        return timeOnly(f[:hour], f[:minute], clockFormat);
    }

    function countdownText(delta as Lang.Number) as Lang.String {
        var c = CalendarMath.countdown(delta);
        if (c[:due]) { return s(Rez.Strings.DueNow); }
        if (c[:days] > 0) { return c[:days].toString() + s(Rez.Strings.DayUnit) + "  " + c[:hours].toString() + s(Rez.Strings.HourUnit); }
        if (c[:hours] > 0) { return c[:hours].toString() + s(Rez.Strings.HourUnit) + "  " + c[:minutes].toString() + s(Rez.Strings.MinuteUnit); }
        return c[:minutes].toString() + s(Rez.Strings.MinuteUnit);
    }

    function compactElapsed(seconds as Lang.Number) as Lang.String {
        var c = CalendarMath.countdown(seconds.abs());
        if (c[:days] > 0) {
            var dayText = c[:days].toString() + s(Rez.Strings.DayUnit);
            return c[:hours] > 0 ? dayText + " " + c[:hours].toString() + s(Rez.Strings.HourUnit) : dayText;
        }
        if (c[:hours] > 0) {
            var hourText = c[:hours].toString() + s(Rez.Strings.HourUnit);
            return c[:minutes] > 0 ? hourText + " " + c[:minutes].toString() + s(Rez.Strings.MinuteUnit) : hourText;
        }
        return c[:minutes].toString() + s(Rez.Strings.MinuteUnit);
    }

    // Main uses intentionally coarse precision. The smallest displayed unit
    // never becomes zero while time still remains.
    function mainCountdownGroups(delta as Lang.Number) as Lang.Array {
        var value = delta.abs();
        var groups = [];
        if (value >= 2 * CalendarMath.SECONDS_PER_DAY) {
            groups.add([Math.floor(value / CalendarMath.SECONDS_PER_DAY).toString(),
                s(Rez.Strings.DayUnit)]);
        } else if (value >= CalendarMath.SECONDS_PER_DAY) {
            var days = Math.floor(value / CalendarMath.SECONDS_PER_DAY);
            var hours = Math.floor((value % CalendarMath.SECONDS_PER_DAY)
                / CalendarMath.SECONDS_PER_HOUR);
            groups.add([days.toString(), s(Rez.Strings.DayUnit)]);
            if (hours > 0) { groups.add([hours.toString(), s(Rez.Strings.HourUnit)]); }
        } else if (value >= CalendarMath.SECONDS_PER_HOUR) {
            groups.add([Math.floor(value / CalendarMath.SECONDS_PER_HOUR).toString(),
                s(Rez.Strings.HourUnit)]);
        } else {
            var minutes = Math.floor(value / CalendarMath.SECONDS_PER_MINUTE);
            if (minutes < 1) { minutes = 1; }
            groups.add([minutes.toString(), s(Rez.Strings.MinuteUnit)]);
        }
        return groups;
    }

    function mainLatenessGroups(delta as Lang.Number) as Lang.Array {
        return [Lateness.parts(delta)];
    }

    function mainElapsedGroups(elapsed as Lang.Number) as Lang.Array {
        var value = elapsed.abs();
        var groups = [];
        var hours = Math.floor(value / CalendarMath.SECONDS_PER_HOUR);
        var minutes = Math.floor((value % CalendarMath.SECONDS_PER_HOUR)
            / CalendarMath.SECONDS_PER_MINUTE);
        if (hours > 0) { groups.add([hours.toString(), s(Rez.Strings.HourUnit)]); }
        if (minutes > 0 || groups.size() == 0) {
            groups.add([minutes.toString(), s(Rez.Strings.MinuteUnit)]);
        }
        return groups;
    }

    function mainGroupsText(groups as Lang.Array) as Lang.String {
        var text = "";
        for (var i = 0; i < groups.size(); i += 1) {
            if (i > 0) { text += " "; }
            var group = groups[i] as Lang.Array;
            text += (group[0] as Lang.String) + (group[1] as Lang.String);
        }
        return text;
    }

    function mainCountdownText(delta as Lang.Number) as Lang.String {
        if (delta == 0) { return s(Rez.Strings.DueNow); }
        return mainGroupsText(mainCountdownGroups(delta));
    }

    function mainLatenessText(delta as Lang.Number) as Lang.String {
        if (delta == 0) { return s(Rez.Strings.DueNow); }
        return Lateness.format(delta);
    }

    function mainElapsedText(elapsed as Lang.Number) as Lang.String {
        return mainGroupsText(mainElapsedGroups(elapsed));
    }

    function mainLimitDeltaText(elapsed as Lang.Number) as Lang.String {
        var difference = ScheduleModel.TEMP_LIMIT_SECONDS - elapsed;
        if (difference == 0) { return s(Rez.Strings.MainLimitReached); }
        var minutes = Math.ceil(difference.abs().toFloat()
            / CalendarMath.SECONDS_PER_MINUTE).toNumber();
        var value = minutes.toString() + s(Rez.Strings.MinuteUnit);
        return fmt(difference > 0 ? Rez.Strings.MainLeftTemplate
            : Rez.Strings.MainOverTemplate, [value]);
    }

    function drawMainDuration(dc as Graphics.Dc, centerY as Lang.Number,
                              groups as Lang.Array, suffix, color as Lang.Number) as Void {
        var digitFont = dc.getWidth() >= 454
            ? Graphics.FONT_SYSTEM_NUMBER_THAI_HOT
            : Graphics.FONT_SYSTEM_NUMBER_HOT;
        var unitFont = Graphics.FONT_SYSTEM_SMALL;
        var unitGap = px(dc, 6);
        var groupGap = px(dc, 16);
        var suffixGap = px(dc, 8);
        var total = 0;
        for (var i = 0; i < groups.size(); i += 1) {
            if (i > 0) { total += groupGap; }
            var measuredGroup = groups[i] as Lang.Array;
            total += dc.getTextWidthInPixels(measuredGroup[0] as Lang.String, digitFont) + unitGap
                + dc.getTextWidthInPixels(measuredGroup[1] as Lang.String, unitFont);
        }
        if (suffix != null) {
            total += suffixGap + dc.getTextWidthInPixels(suffix as Lang.String, unitFont);
        }
        // Garmin's hot-number font has asymmetric side bearings. Its measured
        // advance box sits optically right of the visible digit/unit group.
        var x = (dc.getWidth() - total) / 2 - px(dc, 8);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var j = 0; j < groups.size(); j += 1) {
            if (j > 0) { x += groupGap; }
            var drawnGroup = groups[j] as Lang.Array;
            var digits = drawnGroup[0] as Lang.String;
            var unit = drawnGroup[1] as Lang.String;
            dc.drawText(x, centerY, digitFont, digits,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += dc.getTextWidthInPixels(digits, digitFont) + unitGap;
            dc.drawText(x, centerY + px(dc, 12), unitFont, unit,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += dc.getTextWidthInPixels(unit, unitFont);
        }
        if (suffix != null) {
            x += suffixGap;
            dc.drawText(x, centerY + px(dc, 12), unitFont, suffix as Lang.String,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function eventDelta(delta, firstCycle as Lang.Boolean) as Lang.String {
        if (delta == null) { return firstCycle ? s(Rez.Strings.FirstCycle) : ""; }
        if ((delta as Lang.Number).abs() < 60) { return s(Rez.Strings.OnTime); }
        var value = compactElapsed(delta as Lang.Number);
        return fmt((delta as Lang.Number) < 0 ? Rez.Strings.EarlyTemplate : Rez.Strings.LateTemplate, [value]);
    }

    function drawCountdown(dc as Graphics.Dc, centerY as Lang.Number, delta as Lang.Number, color as Lang.Number) as Void {
        drawCountdownWithFont(dc, centerY, delta, color, Graphics.FONT_SYSTEM_NUMBER_HOT);
    }

    function drawCompactCountdown(dc as Graphics.Dc, centerY as Lang.Number, delta as Lang.Number, color as Lang.Number) as Void {
        drawCountdownWithFont(dc, centerY, delta, color, Graphics.FONT_SYSTEM_NUMBER_MEDIUM);
    }

    function drawCountdownWithFont(dc as Graphics.Dc, centerY as Lang.Number, delta as Lang.Number,
                                   color as Lang.Number, digitFont) as Void {
        var c = CalendarMath.countdown(delta);
        if (c[:due]) {
            centered(dc, centerY, s(Rez.Strings.DueNow), Graphics.FONT_SYSTEM_LARGE, color, px(dc, 280));
            return;
        }
        var groups = [];
        if (c[:days] > 0) { groups.add([c[:days].toString(), s(Rez.Strings.DayUnit)]); }
        if (c[:hours] > 0 || c[:days] > 0) { groups.add([c[:hours].toString(), s(Rez.Strings.HourUnit)]); }
        if (c[:days] == 0 && c[:hours] > 0 && c[:minutes] > 0) {
            groups.add([c[:minutes].toString(), s(Rez.Strings.MinuteUnit)]);
        }
        if (groups.size() == 0) { groups.add([c[:minutes].toString(), s(Rez.Strings.MinuteUnit)]); }
        var unitFont = Graphics.FONT_SYSTEM_XTINY;
        var gap = px(dc, 8);
        var total = 0;
        for (var i = 0; i < groups.size(); i += 1) {
            total += dc.getTextWidthInPixels(groups[i][0], digitFont) + dc.getTextWidthInPixels(groups[i][1], unitFont);
            if (i > 0) { total += gap; }
        }
        if (total > px(dc, 280)) {
            centered(dc, centerY, countdownText(delta), Graphics.FONT_SYSTEM_LARGE, color, px(dc, 280));
            return;
        }
        var x = (dc.getWidth() - total) / 2;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var j = 0; j < groups.size(); j += 1) {
            if (j > 0) { x += gap; }
            var digits = groups[j][0];
            var unit = groups[j][1];
            dc.drawText(x, centerY, digitFont, digits, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += dc.getTextWidthInPixels(digits, digitFont);
            dc.drawText(x, centerY + px(dc, 15), unitFont, unit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            x += dc.getTextWidthInPixels(unit, unitFont);
        }
    }

    function wrap(dc as Graphics.Dc, text as Lang.String, font, maxWidth as Lang.Number) as Lang.Array<Lang.String> {
        var lines = [] as Lang.Array<Lang.String>;
        var start = 0;
        while (start < text.length()) {
            var end = start + 1;
            var lastSpace = -1;
            var hardBreak = false;
            while (end <= text.length()) {
                var character = text.substring(end - 1, end);
                if (character.equals("\n")) { hardBreak = true; break; }
                var part = text.substring(start, end);
                if (dc.getTextWidthInPixels(part, font) > maxWidth) { break; }
                if (character.equals(" ")) { lastSpace = end - 1; }
                end += 1;
            }
            if (end > text.length()) {
                lines.add(text.substring(start, text.length()));
                break;
            }
            var cut = hardBreak ? end - 1 : (lastSpace >= start ? lastSpace : end - 1);
            // Always consume a character, even when a single glyph is wider
            // than the available space; otherwise wrapping never terminates.
            if (!hardBreak && cut <= start) { cut = start + 1; }
            lines.add(text.substring(start, cut));
            start = hardBreak ? cut + 1 : cut;
            while (start < text.length() && text.substring(start, start + 1).equals(" ")) { start += 1; }
        }
        return lines;
    }

    function sentences(text as Lang.String) as Lang.Array<Lang.String> {
        var result = [] as Lang.Array<Lang.String>;
        var start = 0;
        for (var i = 0; i < text.length(); i += 1) {
            if (text.substring(i, i + 1).equals(".")
                && (i + 1 == text.length() || text.substring(i + 1, i + 2).equals(" "))) {
                result.add(text.substring(start, i + 1));
                start = i + 1;
                while (start < text.length() && text.substring(start, start + 1).equals(" ")) { start += 1; }
                i = start - 1;
            }
        }
        if (start < text.length()) { result.add(text.substring(start, text.length())); }
        return result;
    }

    function warningLines(dc as Graphics.Dc, text as Lang.String, font,
                          maxWidth as Lang.Number) as Lang.Array<Lang.String> {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) { return [text]; }
        var result = [] as Lang.Array<Lang.String>;
        var parts = sentences(text);
        for (var i = 0; i < parts.size(); i += 1) {
            if (dc.getTextWidthInPixels(parts[i], font) <= maxWidth) {
                result.add(parts[i]);
            } else {
                var wrapped = wrap(dc, parts[i], font, maxWidth);
                for (var j = 0; j < wrapped.size(); j += 1) { result.add(wrapped[j]); }
            }
        }
        return result;
    }

    function paragraphWidth(dc as Graphics.Dc, font, lineHeight as Lang.Number,
                            startY as Lang.Number, bottomY as Lang.Number) as Lang.Number {
        var lastY = startY + (((bottomY - startY) / lineHeight) * lineHeight);
        var topEdge = ListUi.textRightEdge(dc, startY, font, px(dc, 8));
        var bottomEdge = ListUi.textRightEdge(dc, lastY, font, px(dc, 8));
        var right = topEdge < bottomEdge ? topEdge : bottomEdge;
        var scrollbarEdge = ListUi.scrollIndicatorX(dc.getWidth(), dc.getHeight(),
            startY, bottomY, px(dc, 2)) - px(dc, 10);
        if (right > scrollbarEdge) { right = scrollbarEdge; }
        return 2 * (right - dc.getWidth() / 2);
    }

    function drawParagraphs(dc as Graphics.Dc, paragraphs as Lang.Array<Lang.String>, startY as Lang.Number,
                            bottomY as Lang.Number, scrollLine as Lang.Number) as Lang.Number {
        var font = Graphics.FONT_SYSTEM_XTINY;
        var lineHeight = Graphics.getFontHeight(font) + px(dc, 5);
        var all = [] as Lang.Array<Lang.String>;
        var width = paragraphWidth(dc, font, lineHeight, startY, bottomY);
        for (var i = 0; i < paragraphs.size(); i += 1) {
            var wrapped = wrap(dc, paragraphs[i], font, width);
            for (var j = 0; j < wrapped.size(); j += 1) { all.add(wrapped[j]); }
            if (i + 1 < paragraphs.size()) { all.add(""); }
        }
        var y = startY;
        dc.setColor(PRIMARY, Graphics.COLOR_TRANSPARENT);
        for (var k = scrollLine; k < all.size() && y <= bottomY; k += 1) {
            dc.drawText(dc.getWidth() / 2, y, font, all[k], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            y += lineHeight;
        }
        return all.size();
    }

    function paragraphVisibleLines(dc as Graphics.Dc, startY as Lang.Number, bottomY as Lang.Number) as Lang.Number {
        var lineHeight = Graphics.getFontHeight(Graphics.FONT_SYSTEM_XTINY) + px(dc, 5);
        return ((bottomY - startY) / lineHeight) + 1;
    }

    function scrollIndicatorMetrics(startY as Lang.Number, bottomY as Lang.Number,
                                    position as Lang.Number, total as Lang.Number,
                                    visible as Lang.Number,
                                    minimumHeight as Lang.Number) as Lang.Array<Lang.Number>? {
        if (total <= visible || visible <= 0 || bottomY <= startY) { return null; }
        var maxPosition = total - visible;
        if (position < 0) { position = 0; }
        if (position > maxPosition) { position = maxPosition; }
        var trackHeight = bottomY - startY;
        var thumbHeight = (trackHeight * visible) / total;
        if (thumbHeight < minimumHeight) { thumbHeight = minimumHeight; }
        if (thumbHeight > trackHeight) { thumbHeight = trackHeight; }
        var thumbY = startY;
        if (maxPosition > 0) {
            thumbY += ((trackHeight - thumbHeight) * position) / maxPosition;
        }
        return [thumbY, thumbHeight];
    }

    function drawScrollIndicator(dc as Graphics.Dc, startY as Lang.Number, bottomY as Lang.Number,
                                 position as Lang.Number, total as Lang.Number,
                                 visible as Lang.Number, color as Lang.Number) as Void {
        var metrics = scrollIndicatorMetrics(startY, bottomY, position, total,
            visible, px(dc, 18));
        if (metrics == null) { return; }
        var trackHeight = bottomY - startY;
        var x = ListUi.scrollIndicatorX(dc.getWidth(), dc.getHeight(),
            startY, bottomY, px(dc, 2));
        dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, startY, px(dc, 2), trackHeight);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - px(dc, 1), metrics[0], px(dc, 4), metrics[1]);
    }
}
