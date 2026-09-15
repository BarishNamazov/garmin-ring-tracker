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
    const RING_FREE = 0x9C7CFF;
    const AMBER = 0xFFB020;
    const RED = 0xFF4D5E;

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
        var labelWidth = (width * 46) / 100;
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
        var labelWidth = (width * 46) / 100;
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
            while (end <= text.length()) {
                var part = text.substring(start, end);
                if (dc.getTextWidthInPixels(part, font) > maxWidth) { break; }
                if (text.substring(end - 1, end).equals(" ")) { lastSpace = end - 1; }
                end += 1;
            }
            if (end > text.length()) {
                lines.add(text.substring(start, text.length()));
                break;
            }
            var cut = lastSpace >= start ? lastSpace : end - 1;
            lines.add(text.substring(start, cut));
            start = cut;
            while (start < text.length() && text.substring(start, start + 1).equals(" ")) { start += 1; }
        }
        return lines;
    }

    function drawParagraphs(dc as Graphics.Dc, paragraphs as Lang.Array<Lang.String>, startY as Lang.Number,
                            bottomY as Lang.Number, scrollLine as Lang.Number) as Lang.Number {
        var font = Graphics.FONT_SYSTEM_XTINY;
        var lineHeight = Graphics.getFontHeight(font) + px(dc, 5);
        var all = [] as Lang.Array<Lang.String>;
        for (var i = 0; i < paragraphs.size(); i += 1) {
            var wrapped = wrap(dc, paragraphs[i], font, dc.getWidth() - px(dc, 124));
            for (var j = 0; j < wrapped.size(); j += 1) { all.add(wrapped[j]); }
            all.add("");
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

    function drawScrollIndicator(dc as Graphics.Dc, startY as Lang.Number, bottomY as Lang.Number,
                                 position as Lang.Number, total as Lang.Number,
                                 visible as Lang.Number, color as Lang.Number) as Void {
        if (total <= visible || visible <= 0) { return; }
        var maxPosition = total - visible;
        if (position < 0) { position = 0; }
        if (position > maxPosition) { position = maxPosition; }
        var trackHeight = bottomY - startY;
        var thumbHeight = (trackHeight * visible) / total;
        if (thumbHeight < px(dc, 18)) { thumbHeight = px(dc, 18); }
        var thumbY = startY;
        if (maxPosition > 0) {
            thumbY += ((trackHeight - thumbHeight) * position) / maxPosition;
        }
        var x = dc.getWidth() - px(dc, 42);
        dc.setColor(TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, startY, px(dc, 2), trackHeight);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - px(dc, 1), thumbY, px(dc, 4), thumbHeight);
    }
}
