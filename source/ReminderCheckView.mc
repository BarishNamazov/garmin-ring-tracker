import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

module ReminderCheckUi {
    function sublabel(status as Lang.Array, nowUtc as Lang.Number) as Lang.String {
        if (status[1] == null) { return Ui.s(Rez.Strings.CheckNotYet); }
        var age = nowUtc - status[1];
        if (age >= 7200) { return Ui.fmt(Rez.Strings.CheckStale, [age / 3600]); }
        return Ui.fmt(Rez.Strings.CheckRecent, [Ui.timeForUtc(status[1], 0)]);
    }

    function timestamp(utc, nowUtc as Lang.Number) as Lang.String {
        if (utc == null) { return Ui.s(Rez.Strings.CheckNever); }
        var day = CalendarMath.dateOrdinal(utc);
        var today = CalendarMath.dateOrdinal(nowUtc);
        var yesterday = today - 1;
        var label = day == today ? Ui.s(Rez.Strings.CheckToday)
            : (day == yesterday ? Ui.s(Rez.Strings.CheckYesterday) : Ui.shortDate(utc));
        return label + Ui.s(Rez.Strings.DateTimeSeparator) + Ui.timeForUtc(utc, 0);
    }

    function kindLabel(kind) as Lang.String {
        if (kind == null) { return Ui.s(Rez.Strings.CheckNever); }
        var ids = [Rez.Strings.CheckFreeLimit, Rez.Strings.CheckTemporaryOut,
            Rez.Strings.CheckFourWeeks, Rez.Strings.CheckOverdue,
            Rez.Strings.CheckReminder1, Rez.Strings.CheckDayBefore,
            Rez.Strings.CheckReminder2, Rez.Strings.CheckTest];
        return Ui.s(ids[kind]);
    }

    function problem(status as Lang.Array, nowUtc as Lang.Number) as Lang.String? {
        if (status[2] == BackgroundStatus.MIRROR_INVALID) { return Ui.s(Rez.Strings.CheckMirrorError); }
        if (status[2] == BackgroundStatus.CANONICAL_MISMATCH) { return Ui.s(Rez.Strings.CheckMismatch); }
        if (status[2] == BackgroundStatus.FAILED) {
            var ids = [Rez.Strings.CheckLoadFailed, Rez.Strings.CheckEvaluateFailed,
                Rez.Strings.CheckNotifyFailed, Rez.Strings.CheckSaveFailed];
            return Ui.s(ids[status[3] - 1]);
        }
        if (status[1] != null && nowUtc - status[1] >= 7200) { return sublabel(status, nowUtc); }
        // Retain evidence from older versions until the first recorded check.
        if (status[1] == null && Storage.getValue(RingStore.MIRROR_ERROR_KEY) != null) {
            return Ui.s(Rez.Strings.CheckMirrorError);
        }
        return null;
    }
}

class ReminderCheckView extends WatchUi.View {
    function initialize() { View.initialize(); }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var nowUtc = currentUtc();
        var status = BackgroundStatus.load();
        Ui.centered(dc, Ui.px(dc, 62), Ui.s(Rez.Strings.ReminderCheck),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        Ui.centered(dc, Ui.px(dc, 110), Ui.s(Rez.Strings.CheckLastCheck),
            Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 140), ReminderCheckUi.timestamp(status[1], nowUtc),
            Graphics.FONT_SYSTEM_TINY, Ui.PRIMARY, Ui.px(dc, 310));
        Ui.centered(dc, Ui.px(dc, 184), Ui.s(Rez.Strings.CheckLastAlert),
            Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 215), ReminderCheckUi.kindLabel(status[6]),
            Graphics.FONT_SYSTEM_TINY, Ui.PRIMARY, Ui.px(dc, 310));
        if (status[5] != null) {
            Ui.centered(dc, Ui.px(dc, 246), ReminderCheckUi.timestamp(status[5], nowUtc),
                Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 310));
        }
        var problem = ReminderCheckUi.problem(status, nowUtc);
        if (problem != null) {
            Ui.centered(dc, Ui.px(dc, 282), problem, Graphics.FONT_SYSTEM_XTINY,
                Ui.AMBER, Ui.px(dc, 300));
        }
        var pending = Storage.getValue(BackgroundStatus.TEST_KEY) == true;
        Ui.centered(dc, Ui.px(dc, pending ? 316 : 332),
            "[ " + Ui.s(pending ? Rez.Strings.CheckTestQueued : Rez.Strings.CheckSendTest) + " ]",
            Graphics.FONT_SYSTEM_XTINY, Ui.RING_IN, Ui.px(dc, 280));
        if (pending) {
            Ui.centered(dc, Ui.px(dc, 350), Ui.s(Rez.Strings.CheckTestNext),
                Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 280));
        }
    }
}

class ReminderCheckDelegate extends ScreenInputDelegate {
    function initialize() { ScreenInputDelegate.initialize(); }
    function onSelect() as Lang.Boolean {
        try {
            BackgroundStatus.queueTest();
            WatchUi.requestUpdate();
            WatchUi.showToast(Rez.Strings.CheckTestQueued, null);
        } catch (ignored) { WatchUi.showToast(Rez.Strings.CheckQueueFailed, null); }
        return true;
    }
    function onTap(event as WatchUi.ClickEvent) as Lang.Boolean {
        return TouchTargets.action(event.getCoordinates()[1],
            System.getDeviceSettings().screenHeight) ? onSelect() : true;
    }
    function onBack() as Lang.Boolean {
        getApp().showSettingsMenuFor(:reminderCheck);
        return true;
    }
}
