import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The glance reads a positional mirror directly. Keeping dictionaries,
// CalendarMath, ScheduleModel, RingStore, and Lang.format out of this process
// leaves enough heap headroom for device-specific firmware overhead.
(:glance)
class RingGlanceView extends WatchUi.GlanceView {
    private const GREEN = 0x38D6A0;
    private const PURPLE = 0xA690FF;
    private const ORANGE = 0xFFB020;
    private const WHITE = 0xF4F7F8;
    private const NEUTRAL = 0xB2BAC1;
    private const TRACK = 0x252B31;
    private const DIM_GREEN = 0x1E6B52;
    private const DIM_PURPLE = 0x56487D;

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var active = null;
        var daysIn = 21;
        var daysOut = 7;
        try {
            var raw = Storage.getValue("ringTrackerGlance");
            var state = Storage.getValue("ringTrackerState");
            if (raw instanceof Lang.Array && raw.size() == 5 && raw[0] == 3
                && raw[1] instanceof Lang.Number && raw[3] instanceof Lang.Number
                && raw[4] instanceof Lang.Number && raw[3] >= 21 && raw[3] <= 35
                && raw[4] >= 0 && raw[4] <= 7
                && state instanceof Lang.Array && state.size() >= 10
                && state[0] == 3 && state[9] == raw[1]
                && validActive(raw[2])) {
                active = raw[2];
                daysIn = raw[3];
                daysOut = raw[4];
            } else {
                markMirrorError();
            }
        } catch (ignored) {
            active = null;
            markMirrorError();
        }

        var title = gs(Rez.Strings.GlanceSetupTitle);
        var value = gs(Rez.Strings.GlanceSetupValue);
        var marker = 0.0;
        var overdue = false;
        var ringOut = false;
        var ringOutOver = false;
        if (active instanceof Lang.Array && active.size() >= 7) {
            var a = active as Lang.Array;
            var nowUtc = currentUtc();
            var deadline = a[2] as Lang.Number;
            var delta = deadline - nowUtc;
            var removed = a[1] != null;
            if (a[6] != null) {
                ringOut = true;
                var remaining = 10800 - (nowUtc - (a[6] as Lang.Number));
                ringOutOver = remaining < 0;
                title = gs(Rez.Strings.GlanceOutTitle);
                value = temporaryText(remaining);
            } else if (delta <= 0) {
                overdue = true;
                if (removed) {
                    title = gs(Rez.Strings.GlanceInsertOverdueTitle);
                } else if (daysOut == 0) {
                    title = gs(Rez.Strings.GlanceReplaceOverdueTitle);
                } else {
                    title = gs(Rez.Strings.GlanceRemoveOverdueTitle);
                }
                value = durationText(-delta);
            } else {
                if (removed) {
                    title = gs(Rez.Strings.GlanceInsertTitle);
                } else if (daysOut == 0) {
                    title = gs(Rez.Strings.GlanceReplaceTitle);
                } else {
                    title = gs(Rez.Strings.GlanceRemoveTitle);
                }
                value = durationText(delta);
            }
            var duration = a[3] - a[0];
            marker = duration <= 0 ? 1.0 : (nowUtc - a[0]).toFloat() / duration;
            if (marker < 0.0) { marker = 0.0; }
            if (marker > 1.0) { marker = 1.0; }
        }

        var width = dc.getWidth();
        var height = dc.getHeight();
        var pad = (width * 3) / 100;
        if (pad < 8) { pad = 8; }
        var left = pad;
        var right = width - pad;
        var maxWidth = right - left;
        var titleFont = Graphics.FONT_GLANCE;
        var valueFont = Graphics.FONT_GLANCE_NUMBER;
        var titleHeight = dc.getFontHeight(titleFont);
        var valueHeight = dc.getFontHeight(valueFont);
        var rowGap = -2;
        var barGap = 7;
        var barWidth = right - left;
        var blockHeight = titleHeight + rowGap + valueHeight + barGap + 5;
        var top = (height - blockHeight) / 2;
        if (top < 1) { top = 1; }
        var valueY = top + titleHeight + rowGap;
        var barY = valueY + valueHeight + barGap;

        title = ellipsis(dc, title, titleFont, maxWidth);
        value = ellipsis(dc, value, valueFont, maxWidth);
        dc.setColor(overdue ? ORANGE : NEUTRAL, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, top, titleFont, title, Graphics.TEXT_JUSTIFY_LEFT);
        dc.setColor(overdue || ringOutOver ? ORANGE : WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, valueY, valueFont, value, Graphics.TEXT_JUSTIFY_LEFT);

        var totalDays = daysIn + daysOut;
        var split = totalDays <= 0 ? right : left + ((barWidth * daysIn) / totalDays);
        var green = ringOut ? DIM_GREEN : GREEN;
        var purple = ringOut ? DIM_PURPLE : PURPLE;
        dc.setPenWidth(5);
        drawRoundedLine(dc, left, right, barY, TRACK);
        if (overdue) {
            // Leave a short orange tail after the pinned marker so lateness
            // reads as overflow rather than an in-range progress position.
            var pinned = right - 9;
            drawRoundedLine(dc, left, pinned, barY, ORANGE);
            dc.setColor(ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(pinned, barY, right, barY);
            marker = (pinned - left).toFloat() / barWidth;
        } else {
            drawRoundedLine(dc, left, split, barY, green);
            if (daysOut > 0) { drawRoundedLine(dc, split, right, barY, purple); }
        }

        var markerX = left + (barWidth * marker).toNumber();
        if (markerX < left + 5) { markerX = left + 5; }
        if (markerX > right - 5) { markerX = right - 5; }
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(markerX, barY, 5);
        dc.setColor(WHITE, Graphics.COLOR_TRANSPARENT);
        if (ringOut) {
            dc.setPenWidth(2);
            dc.drawCircle(markerX, barY, 4);
        } else {
            dc.fillCircle(markerX, barY, 4);
        }
    }

    function durationText(seconds as Lang.Number) as Lang.String {
        if (seconds < 0) { seconds = -seconds; }
        if (seconds >= 86400) {
            var days = (seconds + 86399) / 86400;
            return days.toString() + gs(days == 1
                ? Rez.Strings.GlanceOneDaySuffix : Rez.Strings.GlanceDaysSuffix);
        }
        var hours = seconds / 3600;
        var minutes = ((seconds % 3600) + 59) / 60;
        if (hours > 0) {
            var result = hours.toString() + gs(Rez.Strings.GlanceHourSuffix);
            return minutes > 0 ? result + minutes.toString()
                + gs(Rez.Strings.GlanceMinuteSuffix) : result;
        }
        if (minutes < 1) { minutes = 1; }
        return minutes.toString() + gs(Rez.Strings.GlanceMinuteSuffix);
    }

    function temporaryText(remaining as Lang.Number) as Lang.String {
        if (remaining < 0) {
            return durationText(-remaining) + gs(Rez.Strings.GlanceOverSuffix);
        }
        return durationText(remaining) + gs(Rez.Strings.GlanceLeftSuffix);
    }

    private function drawRoundedLine(dc as Graphics.Dc, left as Lang.Number,
                                     right as Lang.Number, y as Lang.Number,
                                     color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, y, right, y);
        dc.fillCircle(left, y, 2);
        dc.fillCircle(right, y, 2);
    }

    private function gs(id as Lang.ResourceId) as Lang.String {
        return Application.loadResource(id) as Lang.String;
    }

    private function validActive(value) as Lang.Boolean {
        if (value == null) { return true; }
        if (!(value instanceof Lang.Array) || (value as Lang.Array).size() != 7) { return false; }
        var a = value as Lang.Array;
        return a[0] instanceof Lang.Number && (a[1] == null || a[1] instanceof Lang.Number)
            && a[2] instanceof Lang.Number && a[3] instanceof Lang.Number
            && a[4] instanceof Lang.Number && (a[5] == null || a[5] instanceof Lang.Number)
            && (a[6] == null || a[6] instanceof Lang.Number);
    }

    private function markMirrorError() as Void {
        try { Storage.setValue("ringTrackerMirrorError", "glance mirror invalid"); } catch (ignored) { }
    }

    private function ellipsis(dc as Graphics.Dc, value as Lang.String, font,
                              maxWidth as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(value, font) <= maxWidth) { return value; }
        var suffix = gs(Rez.Strings.GlanceEllipsis);
        var end = value.length();
        while (end > 0) {
            var shortened = value.substring(0, end) + suffix;
            if (dc.getTextWidthInPixels(shortened, font) <= maxWidth) { return shortened; }
            end -= 1;
        }
        return suffix;
    }
}
