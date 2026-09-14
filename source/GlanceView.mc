import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class RingGlanceView extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var compact = RingStore.loadGlance();
        var active = compact[:active] as Lang.Dictionary?;
        var text = gs(Rez.Strings.GlanceSetup);
        var dayText = "";
        var color = 0x9AA6AD;
        var fraction = 0.0;

        if (active != null) {
            var regimen = compact[:regimen] as Lang.Dictionary;
            var nowUtc = currentUtc();
            var status = ScheduleModel.deriveStatus(nowUtc, active, regimen);
            var duration = active[:scheduledInsertionUtc] - active[:insertionUtc];
            fraction = duration <= 0 ? 1.0 : (nowUtc - active[:insertionUtc]).toFloat() / duration;
            if (fraction < 0.0) { fraction = 0.0; }
            if (fraction > 1.0) { fraction = 1.0; }
            var count = status[:temporaryOutOpen]
                ? elapsedText(status[:tempElapsed])
                : compactCountdown(status[:secondsRemaining]);
            if (status[:temporaryOutOpen]) {
                text = gf(Rez.Strings.GlanceOut, [count]);
                color = status[:tempElapsed] > ScheduleModel.TEMP_LIMIT_SECONDS ? 0xFF4D5E : 0xFFB020;
            } else if (status[:phase] == :overdue) {
                text = gf(Rez.Strings.GlanceOverdue, [count]);
                color = status[:ringFreeLimitExceeded] ? 0xFF4D5E : 0xFFB020;
                fraction = 1.0;
            } else {
                var id = status[:nextAction] == :remove ? Rez.Strings.GlanceRemove
                    : (status[:nextAction] == :replace ? Rez.Strings.GlanceReplace : Rez.Strings.GlanceInsert);
                text = gf(id, [count]);
                color = status[:phase] == :ringFree ? 0x9C7CFF : 0x38D6A0;
            }
            dayText = gf(Rez.Strings.GlanceDayCount,
                [status[:dayOfCycle], regimen[:daysIn] + regimen[:daysOut]]);
        }

        var width = dc.getWidth();
        var height = dc.getHeight();
        var pad = 8;
        var textY = (height / 2) - 6;
        var rightWidth = dc.getTextWidthInPixels(dayText, Graphics.FONT_GLANCE_NUMBER);
        var leftMax = width - (pad * 2);
        var showDay = dayText.length() > 0
            && dc.getTextWidthInPixels(text, Graphics.FONT_GLANCE) + rightWidth + 12 <= leftMax;
        if (showDay) { leftMax -= rightWidth + 12; }
        text = ellipsis(dc, text, Graphics.FONT_GLANCE, leftMax);
        dc.setColor(0xF4F7F8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(pad, textY, Graphics.FONT_GLANCE, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (showDay) {
            dc.setColor(0x9AA6AD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width - pad, textY, Graphics.FONT_GLANCE_NUMBER, dayText,
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        var barY = height - 8;
        dc.setPenWidth(4);
        dc.setColor(0x20262C, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(pad, barY, width - pad, barY);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(pad, barY, pad + ((width - (pad * 2)) * fraction).toNumber(), barY);
    }

    private function gs(id as Lang.ResourceId) as Lang.String {
        return Application.loadResource(id) as Lang.String;
    }

    private function gf(id as Lang.ResourceId, values as Lang.Array) as Lang.String {
        return Lang.format(gs(id), values);
    }

    private function compactCountdown(delta as Lang.Number) as Lang.String {
        var value = CalendarMath.glanceCountdown(delta);
        if (value[:unit] == :now) { return gs(Rez.Strings.GlanceNow); }
        if (value[:unit] == :days) { return gf(Rez.Strings.GlanceDayUnit, [value[:value]]); }
        if (value[:unit] == :hours) { return gf(Rez.Strings.GlanceHourUnit, [value[:value]]); }
        return gf(Rez.Strings.GlanceMinuteUnit, [value[:value]]);
    }

    private function elapsedText(seconds as Lang.Number) as Lang.String {
        var hours = seconds / CalendarMath.SECONDS_PER_HOUR;
        var minutes = (seconds % CalendarMath.SECONDS_PER_HOUR) / 60;
        if (hours > 0 && minutes > 0) { return gf(Rez.Strings.GlanceHourMinute, [hours, minutes]); }
        if (hours > 0) { return gf(Rez.Strings.GlanceHourUnit, [hours]); }
        return gf(Rez.Strings.GlanceMinuteUnit, [(seconds + 59) / 60]);
    }

    private function ellipsis(dc as Graphics.Dc, value as Lang.String, font, maxWidth as Lang.Number) as Lang.String {
        if (dc.getTextWidthInPixels(value, font) <= maxWidth) { return value; }
        var end = value.length();
        while (end > 0) {
            var shortened = value.substring(0, end) + gs(Rez.Strings.GlanceEllipsis);
            if (dc.getTextWidthInPixels(shortened, font) <= maxWidth) { return shortened; }
            end -= 1;
        }
        return gs(Rez.Strings.GlanceEllipsis);
    }
}
