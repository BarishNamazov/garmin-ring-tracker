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
            if (raw instanceof Lang.Array && raw.size() >= 4 && raw[0] == 2) {
                active = raw[1];
                daysIn = raw[2];
                daysOut = raw[3];
            }
        } catch (ignored) {
            active = null;
        }

        var text = gs(Rez.Strings.GlanceSetup);
        var marker = 0.0;
        var overdue = false;
        if (active instanceof Lang.Array && active.size() >= 7) {
            var a = active as Lang.Array;
            var nowUtc = currentUtc();
            var deadline = a[2] as Lang.Number;
            var delta = deadline - nowUtc;
            var count = compactDuration(delta);
            if (a[6] != null) {
                text = gs(Rez.Strings.GlanceOutPrefix) + elapsed(nowUtc - a[6]);
            } else if (delta <= 0) {
                overdue = true;
                text = gs(Rez.Strings.GlanceOverduePrefix)
                    + (delta == 0 ? gs(Rez.Strings.GlanceNow) : compactDuration(-delta));
            } else if (a[1] != null) {
                text = gs(Rez.Strings.GlanceInsertPrefix) + count;
            } else if (daysOut == 0) {
                text = gs(Rez.Strings.GlanceReplacePrefix) + count;
            } else {
                text = gs(Rez.Strings.GlanceRemovePrefix) + count;
            }
            var duration = a[3] - a[0];
            marker = duration <= 0 ? 1.0 : (nowUtc - a[0]).toFloat() / duration;
            if (marker < 0.0) { marker = 0.0; }
            if (marker > 1.0) { marker = 1.0; }
        }

        var width = dc.getWidth();
        var height = dc.getHeight();
        var pad = 8;
        var font = Graphics.FONT_SYSTEM_XTINY;
        text = ellipsis(dc, text, font, width - (pad * 2));
        dc.setColor(0xF4F7F8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(pad, (height / 2) - 7, font, text,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var left = pad;
        var right = width - pad;
        var barY = height - 6;
        var barWidth = right - left;
        var totalDays = daysIn + daysOut;
        var split = totalDays <= 0 ? right : left + ((barWidth * daysIn) / totalDays);
        dc.setPenWidth(5);
        dc.setColor(0x20262C, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(left, barY, right, barY);
        if (overdue) {
            dc.setColor(0xFFB020, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(left, barY, right, barY);
        } else {
            dc.setColor(0x38D6A0, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(left, barY, split, barY);
            if (daysOut > 0) {
                dc.setColor(0x9C7CFF, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(split, barY, right, barY);
            }
        }
        var markerX = left + (barWidth * marker).toNumber();
        dc.setColor(0xF4F7F8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(markerX, barY, 4);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(markerX, barY, 2);
    }

    private function gs(id as Lang.ResourceId) as Lang.String {
        return Application.loadResource(id) as Lang.String;
    }

    private function compactDuration(seconds as Lang.Number) as Lang.String {
        if (seconds <= 0) { return gs(Rez.Strings.GlanceNow); }
        if (seconds > 86400) {
            var days = (seconds + 86399) / 86400;
            return days.toString() + gs(days == 1 ? Rez.Strings.GlanceOneDaySuffix : Rez.Strings.GlanceDaysSuffix);
        }
        if (seconds >= 3600) {
            var hours = (seconds + 3599) / 3600;
            return hours.toString() + gs(hours == 1 ? Rez.Strings.GlanceOneHourSuffix : Rez.Strings.GlanceHoursSuffix);
        }
        var minutes = (seconds + 59) / 60;
        return minutes.toString() + gs(minutes == 1 ? Rez.Strings.GlanceOneMinuteSuffix : Rez.Strings.GlanceMinutesSuffix);
    }

    private function elapsed(seconds as Lang.Number) as Lang.String {
        if (seconds < 0) { seconds = 0; }
        var hours = seconds / 3600;
        var minutes = (seconds % 3600) / 60;
        if (hours > 0) {
            return hours.toString() + gs(Rez.Strings.GlanceShortHourSuffix)
                + minutes.toString() + gs(Rez.Strings.GlanceShortMinuteSuffix);
        }
        return ((seconds + 59) / 60).toString() + gs(Rez.Strings.GlanceShortMinuteSuffix);
    }

    private function ellipsis(dc as Graphics.Dc, value as Lang.String, font, maxWidth as Lang.Number) as Lang.String {
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
