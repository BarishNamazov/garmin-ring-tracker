import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Math;
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
        var selectedKind = null;
        var notificationShown = false;
        var ledgerSaved = false;
        var caught = false;
        try {
            var state = BackgroundRuntime.load();
            if (state != null) {
                var active = state[2] as Lang.Array?;
                var nowUtc = currentUtc();
                var selected = BackgroundRuntime.evaluate(nowUtc, state);
                if (selected != null) {
                    selectedKind = selected[0];
                    var reminders = state[5] as Lang.Array;
                    var referenceUtc = active[9] as Lang.Number;
                    if (selected[0] == 0) { referenceUtc = active[6] as Lang.Number; }
                    else if (selected[0] == 1) { referenceUtc = active[7] as Lang.Number; }
                    else if (selected[0] == 2) { referenceUtc = active[5] as Lang.Number; }
                    var reminderSlot = selected.size() > 3 ? selected[3] : 0;
                    var copy = notificationIds(selected[0], selected[1], referenceUtc,
                        reminders[9], nowUtc, reminderSlot);
                    var options = {
                        :icon => Rez.Drawables.NotificationIcon,
                        :data => [active[0], selected[0]],
                        :dismissPrevious => true
                    };
                    if (copy[2] != null) { options[:body] = copy[2]; }
                    showOptionalNotification(copy[0], copy[1], options);
                    notificationShown = true;
                    BackgroundRuntime.markSent(state, selected);
                    BackgroundRuntime.save(state);
                    ledgerSaved = true;
                }
            }
        } catch (ignored) {
            // A later hourly evaluation retries. Do not mark unsent work done.
            caught = true;
        }
        try { reportOptionalServiceResult(selectedKind, notificationShown, ledgerSaved, caught); }
        catch (ignoredResult) { }
        try { reportOptionalServiceMemory(); }
        catch (ignoredMemory) { }
        Background.exit(null);
    }

    function notificationIds(kind as Lang.Number, action as Lang.Number,
                             referenceUtc as Lang.Number, clockFormat as Lang.Number,
                             nowUtc as Lang.Number, reminderSlot as Lang.Number) as Lang.Array {
        var title = null;
        var subtitle = null;
        var body = null;
        if (kind == 5) {
            title = actionText(action, Rez.Strings.NotifyRemoveTomorrow,
                Rez.Strings.NotifyInsertTomorrow, Rez.Strings.NotifyReplaceTomorrow);
            subtitle = dateTimeFor(referenceUtc, clockFormat);
        } else if (kind == 4 && reminderSlot == 2) {
            title = actionText(action, Rez.Strings.NotifyStillInRemove,
                Rez.Strings.NotifyStillOutInsert, Rez.Strings.NotifyStillInReplace);
            subtitle = format(Rez.Strings.NotifyDueTimeToday,
                [timeFor(referenceUtc, clockFormat)]);
            body = actionText(action, Rez.Strings.NotifyLogOnceOut,
                Rez.Strings.NotifyLogOnceIn, Rez.Strings.NotifyLogReplacement);
        } else if (kind == 4) {
            title = actionText(action, Rez.Strings.NotifyRemoveRing,
                Rez.Strings.NotifyInsertRing, Rez.Strings.NotifyReplaceRing);
            subtitle = format(Rez.Strings.NotifyDueToday,
                [timeFor(referenceUtc, clockFormat)]);
        } else if (kind == 3) {
            title = actionText(action, Rez.Strings.NotifyRemoveNow,
                Rez.Strings.NotifyInsertNow, Rez.Strings.NotifyReplaceRing);
            subtitle = format(Rez.Strings.NotifyLateDue,
                [elapsed(nowUtc - referenceUtc), dateFor(referenceUtc)]);
        } else if (kind == 1) {
            title = text(Rez.Strings.NotifyPutRingBack);
            subtitle = format(Rez.Strings.NotifyOutFor,
                [elapsed(nowUtc - referenceUtc)]);
            body = text(Rez.Strings.NotifyBackupDetail);
        } else if (kind == 0) {
            title = text(Rez.Strings.NotifyInsertRing);
            subtitle = format(Rez.Strings.NotifyBreakLate,
                [daysOver(nowUtc - referenceUtc)]);
            body = text(Rez.Strings.NotifyBackup);
        } else if (kind == 2) {
            title = text(Rez.Strings.NotifyReplaceRing);
            subtitle = format(Rez.Strings.NotifyFourWeeksOver,
                [daysOver(nowUtc - referenceUtc)]);
            body = text(Rez.Strings.NotifyBackup);
        }
        return [title, subtitle, body];
    }

    private function actionText(action as Lang.Number, removeId as Lang.ResourceId,
                                insertId as Lang.ResourceId,
                                replaceId as Lang.ResourceId) as Lang.String {
        return text(action == 0 ? removeId : (action == 2 ? replaceId : insertId));
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
            return info.hour.format("%02d") + ":" + info.min.format("%02d");
        }
        var hour = info.hour % 12;
        if (hour == 0) { hour = 12; }
        return hour.toString() + ":" + info.min.format("%02d") + " "
            + (info.hour < 12 ? "AM" : "PM");
    }

    private function dateTimeFor(utc as Lang.Number, clockFormat as Lang.Number) as Lang.String {
        return format(Rez.Strings.NotifyDateTime,
            [dateFor(utc), timeFor(utc, clockFormat)]);
    }

    private function dateFor(utc as Lang.Number) as Lang.String {
        var info = Gregorian.info(new Time.Moment(utc), Time.FORMAT_SHORT);
        var weekdays = [Rez.Strings.NotifySun, Rez.Strings.NotifyMon,
            Rez.Strings.NotifyTue, Rez.Strings.NotifyWed, Rez.Strings.NotifyThu,
            Rez.Strings.NotifyFri, Rez.Strings.NotifySat];
        var months = [Rez.Strings.NotifyJan, Rez.Strings.NotifyFeb,
            Rez.Strings.NotifyMar, Rez.Strings.NotifyApr, Rez.Strings.NotifyMay,
            Rez.Strings.NotifyJun, Rez.Strings.NotifyJul, Rez.Strings.NotifyAug,
            Rez.Strings.NotifySep, Rez.Strings.NotifyOct, Rez.Strings.NotifyNov,
            Rez.Strings.NotifyDec];
        return format(Rez.Strings.NotifyDate,
            [text(weekdays[info.day_of_week - 1]), info.day.toString(),
                text(months[info.month - 1])]);
    }

    private function daysOver(seconds as Lang.Number) as Lang.String {
        var days = (seconds.abs() + 86399) / 86400;
        if (days < 1) { days = 1; }
        return days.toString() + "d";
    }

    private function elapsed(seconds as Lang.Number) as Lang.String {
        var absolute = seconds.abs();
        var days = Math.floor(absolute / 86400);
        var hours = Math.floor((absolute % 86400) / 3600);
        var minutes = Math.floor((absolute % 3600) / 60);
        if (days > 0) {
            var dayText = days.toString() + "d";
            return hours > 0 ? dayText + " " + hours.toString() + "h" : dayText;
        }
        if (hours > 0) {
            var hourText = hours.toString() + "h";
            return minutes > 0 ? hourText + " " + minutes.toString() + "m" : hourText;
        }
        return minutes.toString() + "m";
    }
}
