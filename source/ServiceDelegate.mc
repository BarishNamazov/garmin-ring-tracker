import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Notifications;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// This class and every domain/storage dependency it reaches are scoped for the
// 64 KiB background process. It has no reference to a view or UI delegate.
(:background)
class RingServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        try {
            var state = BackgroundRuntime.load();
            if (state != null) {
                var active = state[2] as Lang.Array?;
                var selected = BackgroundRuntime.evaluate(currentUtc(), state);
                if (selected != null) {
                    var reminders = state[5] as Lang.Array;
                    var copy = notificationIds(selected[0], selected[1], active[9], reminders[9], currentUtc());
                    var options = {
                        :icon => Rez.Drawables.NotificationIcon,
                        :data => [active[0], selected[0]],
                        :dismissPrevious => true
                    };
                    if (copy[2] != null) { options[:body] = copy[2]; }
                    Notifications.showNotification(copy[0], copy[1], options);
                    BackgroundRuntime.markSent(state, selected);
                    BackgroundRuntime.save(state);
                }
            }
        } catch (ignored) {
            // A later hourly evaluation retries. Do not mark unsent work done.
        }
        reportOptionalServiceMemory();
        Background.exit(null);
    }

    function notificationIds(kind as Lang.Number, action as Lang.Number, deadline as Lang.Number,
                             clockFormat as Lang.Number, nowUtc as Lang.Number) as Lang.Array {
        var title = text(action == 0 ? Rez.Strings.NotificationRemoveToday
            : (action == 2 ? Rez.Strings.NotificationReplaceToday : Rez.Strings.NotificationInsertToday));
        var subtitle = format(Rez.Strings.NotificationScheduled, [timeFor(deadline, clockFormat)]);
        var body = null;
        if (kind == 5) {
            title = text(action == 0 ? Rez.Strings.NotificationRemoveTomorrow
                : (action == 2 ? Rez.Strings.NotificationReplaceTomorrow : Rez.Strings.NotificationInsertTomorrow));
        } else if (kind == 3) {
            title = format(Rez.Strings.NotificationOverdueTitle, [elapsed(nowUtc - deadline)]);
            subtitle = text(action == 0 ? Rez.Strings.NotificationRemove
                : (action == 2 ? Rez.Strings.NotificationReplace : Rez.Strings.NotificationInsert));
        } else if (kind == 1) {
            title = text(Rez.Strings.NotificationTemp);
            subtitle = text(Rez.Strings.NotificationReinsertNow);
            body = text(Rez.Strings.NotificationTempBody);
        } else if (kind == 0) {
            title = text(Rez.Strings.NotificationFree);
            subtitle = text(Rez.Strings.NotificationFreeContext);
            body = text(Rez.Strings.NotificationFreeBody);
        } else if (kind == 2) {
            title = text(Rez.Strings.NotificationFourWeeks);
            subtitle = text(Rez.Strings.NotificationFourWeekContext);
        }
        return [title, subtitle, body];
    }

    private function text(id as Lang.ResourceId) as Lang.String {
        return Application.loadResource(id) as Lang.String;
    }

    private function format(id as Lang.ResourceId, values as Lang.Array) as Lang.String {
        return Lang.format(text(id), values);
    }

    private function timeFor(utc as Lang.Number, clockFormat as Lang.Number) as Lang.String {
        var info = Gregorian.info(new Time.Moment(utc), Time.FORMAT_SHORT);
        var use24 = clockFormat == 24 || (clockFormat == 0 && System.getDeviceSettings().is24Hour);
        if (use24) {
            return info.hour.format("%02d") + text(Rez.Strings.TimeSeparator) + info.min.format("%02d");
        }
        var hour = info.hour % 12;
        if (hour == 0) { hour = 12; }
        return hour.toString() + text(Rez.Strings.TimeSeparator) + info.min.format("%02d") + " "
            + text(info.hour < 12 ? Rez.Strings.Am : Rez.Strings.Pm);
    }

    private function elapsed(seconds as Lang.Number) as Lang.String {
        if (seconds == 0) { return text(Rez.Strings.NotificationNow); }
        var absolute = seconds.abs();
        var days = Math.floor(absolute / 86400);
        var hours = Math.floor((absolute % 86400) / 3600);
        var minutes = Math.floor((absolute % 3600) / 60);
        if (days > 0) {
            var dayText = days.toString() + text(Rez.Strings.DayUnit);
            return hours > 0 ? dayText + " " + hours.toString() + text(Rez.Strings.HourUnit) : dayText;
        }
        if (hours > 0) {
            var hourText = hours.toString() + text(Rez.Strings.HourUnit);
            return minutes > 0 ? hourText + " " + minutes.toString() + text(Rez.Strings.MinuteUnit) : hourText;
        }
        return minutes.toString() + text(Rez.Strings.MinuteUnit);
    }
}
