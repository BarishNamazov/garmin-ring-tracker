import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Notifications;
import Toybox.System;
import Toybox.Timer;

import Toybox.WatchUi;

(:debug)
function openOptionalMenu(id) as Lang.Boolean {
    if (id != :demo) { return false; }
    WatchUi.switchToView(Menus.demoMenu(), new DemoMenuDelegate(), WatchUi.SLIDE_LEFT);
    return true;
}

(:debug)
function optionalActionMessage(action as Lang.Symbol, fallback as Lang.String) as Lang.String {
    return action == :demo ? Ui.s(Rez.Strings.DemoSeedQuestion) : fallback;
}

(:debug)
function optionalSeedState(action as Lang.Symbol, data, nowUtc as Lang.Number) as Lang.Dictionary? {
    return action == :demo ? demoState(data as Lang.Symbol, nowUtc) : null;
}

(:debug)
function isFreshOptionalSeed(action as Lang.Symbol, data) as Lang.Boolean {
    return action == :demo && data == :fresh;
}

(:debug)
function isTransientOptionalSeed(action as Lang.Symbol, data) as Lang.Boolean {
    return action == :demo && data == :maximumState;
}

(:debug)
function pickerUses24Hour(reminders as Lang.Dictionary) as Lang.Boolean {
    if (reminders[:clockFormat] == 12) { return false; }
    if (reminders[:clockFormat] == 24) { return true; }
    return Toybox.System.getDeviceSettings().is24Hour;
}

(:debug)
function previewOptionalNotification(data, state as Lang.Dictionary, nowUtc as Lang.Number) as Void {
    var scenario = data as Lang.Symbol;
    if (scenario == :alertDetail) {
        getApp().showAlert();
        return;
    }
    var kind = null;
    var reminderSlot = 0;
    if (scenario == :notificationDayBefore) {
        kind = 5;
    } else if (scenario == :notificationReminder1) {
        kind = 4;
        reminderSlot = 1;
    } else if (scenario == :notificationReminder2) {
        kind = 4;
        reminderSlot = 2;
    } else if (scenario == :notificationOverdue) {
        kind = 3;
    } else if (scenario == :notificationTemp) {
        kind = 1;
    } else if (scenario == :notificationFree) {
        kind = 0;
    } else if (scenario == :notificationFourWeeks) {
        kind = 2;
    }
    if (kind == null) { return; }
    var active = state[:active] as Lang.Dictionary;
    var referenceUtc = active[:removeDueUtc] as Lang.Number;
    if (kind == 0) { referenceUtc = active[:insertDueUtc] as Lang.Number; }
    else if (kind == 1) {
        referenceUtc = (ScheduleModel.tempOpen(active) as Lang.Dictionary)[:outUtc] as Lang.Number;
    } else if (kind == 2) {
        referenceUtc = active[:labelFourWeekUtc] as Lang.Number;
    }
    var copy = (new RingServiceDelegate()).notificationIds(kind as Lang.Number, 0,
        referenceUtc, (state[:reminders] as Lang.Dictionary)[:clockFormat], nowUtc,
        reminderSlot);
    WatchUi.switchToView(new NotificationPreviewView(copy), new MainDelegate(),
        WatchUi.SLIDE_IMMEDIATE);
    var options = { :data => [((state[:active] as Lang.Dictionary)[:cycleId]), 0],
        :dismissPrevious => true };
    if (copy[2] != null) { options[:body] = copy[2]; }
    Notifications.showNotification(copy[0] as Lang.String, copy[1] as Lang.String, options);
}

(:debug)
class NotificationPreviewView extends WatchUi.View {
    private var _copy as Lang.Array;

    function initialize(copy as Lang.Array) {
        View.initialize();
        _copy = copy;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var centerX = dc.getWidth() / 2;
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(Ui.px(dc, 3));
        dc.drawCircle(centerX, Ui.px(dc, 30), Ui.px(dc, 8));
        dc.fillCircle(centerX + Ui.px(dc, 8), Ui.px(dc, 22), Ui.px(dc, 3));
        Ui.centered(dc, Ui.px(dc, 80), _copy[0] as Lang.String,
            Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 340));
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(Ui.px(dc, 10), Ui.px(dc, 148),
            dc.getWidth() - Ui.px(dc, 10), Ui.px(dc, 148));
        var subtitle = _copy[1] as Lang.String;
        var separator = " · ";
        var split = subtitle.find(separator);
        var bodyY = Ui.px(dc, 260);
        if (split == null) {
            Ui.centered(dc, Ui.px(dc, 190), subtitle,
                Graphics.FONT_SYSTEM_SMALL,
                subtitle.find("late") == null ? Ui.PRIMARY : Ui.AMBER,
                Ui.px(dc, 330));
        } else {
            var firstLine = subtitle.substring(0, split);
            var secondLine = subtitle.substring(split + separator.length(), subtitle.length());
            Ui.centered(dc, Ui.px(dc, 178), firstLine,
                Graphics.FONT_SYSTEM_SMALL,
                firstLine.find("late") == null ? Ui.PRIMARY : Ui.AMBER,
                Ui.px(dc, 330));
            Ui.centered(dc, Ui.px(dc, 222),
                secondLine, Graphics.FONT_SYSTEM_SMALL,
                secondLine.find("late") == null ? Ui.PRIMARY : Ui.AMBER,
                Ui.px(dc, 330));
            bodyY = Ui.px(dc, 286);
        }
        if (_copy[2] != null) {
            Ui.centered(dc, bodyY, _copy[2] as Lang.String,
                Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 310));
        }
    }
}

(:debug)
function afterOptionalSeed(action as Lang.Symbol, data) as Void {
    if (action != :demo) { return; }
    var scenario = data as Lang.Symbol;
    Storage.setValue("debugBackgroundScenario", scenario.toString());
    Storage.deleteValue("debugBackgroundResult");
    Storage.deleteValue("debugBackgroundThrow");
    if (scenario == :backgroundNil) {
        Storage.deleteValue(RingStore.BACKGROUND_KEY);
    } else if (scenario == :backgroundCorrupt) {
        Storage.setValue(RingStore.BACKGROUND_KEY, ["corrupt"]);
    } else if (scenario == :backgroundThrow) {
        Storage.setValue("debugBackgroundThrow", true);
    }
}

(:debug, :background)
function reportOptionalServiceMemory() as Void {
    var stats = Toybox.System.getSystemStats();
    Toybox.System.println("RING_TRACKER_BACKGROUND_MEMORY=" + stats.usedMemory + "/" + stats.totalMemory);
}

(:debug, :background)
function showOptionalNotification(title as Lang.String, subtitle as Lang.String, options) as Void {
    if (Storage.getValue("debugBackgroundThrow") == true) {
        Storage.deleteValue("debugBackgroundThrow");
        throw new Lang.InvalidValueException("injected notification failure");
    }
    Notifications.showNotification(title, subtitle, options);
}

(:debug, :background)
function reportOptionalServiceResult(kind, notificationShown as Lang.Boolean,
                                     ledgerSaved as Lang.Boolean, caught as Lang.Boolean) as Void {
    try {
        var scenario = Storage.getValue("debugBackgroundScenario");
        var raw = Storage.getValue("ringTrackerBackground");
        var ledger = raw instanceof Lang.Array && (raw as Lang.Array).size() > 6
            ? (raw as Lang.Array)[6].toString() : "null";
        var line = "RING_TRACKER_BACKGROUND_RESULT=" + scenario
            + ",kind=" + kind + ",notification=" + notificationShown
            + ",ledgerSaved=" + ledgerSaved + ",caught=" + caught
            + ",exit=1,ledger=" + ledger;
        Toybox.System.println(line);
        Storage.setValue("debugBackgroundResult", line);
    } catch (ignored) { }
}

(:debug)
function mainDemoReferenceUtc(fallback as Lang.Number) as Lang.Number {
    var wall = {
        :year=>2026, :month=>9, :day=>17,
        :hour=>12, :minute=>26, :second=>0
    };
    var resolved = CalendarMath.wallToUtcUsingDevice(wall);
    return resolved == null ? fallback : resolved[:utc];
}

(:debug)
function mainDemoWallUtc(year as Lang.Number, month as Lang.Number, day as Lang.Number,
                         hour as Lang.Number, minute as Lang.Number,
                         fallback as Lang.Number) as Lang.Number {
    var resolved = CalendarMath.wallToUtcUsingDevice({
        :year=>year, :month=>month, :day=>day,
        :hour=>hour, :minute=>minute, :second=>0
    });
    return resolved == null ? fallback : resolved[:utc];
}

(:debug)
function demoState(scenario as Lang.Symbol, nowUtc as Lang.Number) as Lang.Dictionary {
    if (scenario == :overdueRemoval) {
        nowUtc = demoLocalUtc(2026, 12, 25, 9, 0);
    } else if (scenario == :maximumState) {
        nowUtc = demoLocalUtc(2026, 10, 6, 12, 26);
    } else {
        nowUtc = mainDemoReferenceUtc(nowUtc);
    }
    Storage.setValue("debugNowUtc", nowUtc);
    var state = ScheduleModel.defaultState();
    if (scenario == :fresh) { return state; }
    if (scenario == :noCycle) { state[:setupStep] = 3; return state; }
    if (scenario == :maximumState) { return maximumDemoState(state, nowUtc); }
    state[:setupStep] = 3;
    var regimen = state[:regimen] as Lang.Dictionary;
    var insertion = nowUtc - (4 * CalendarMath.SECONDS_PER_DAY);
    if (scenario == :day5) { insertion = nowUtc - (4 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :beforeRemoval) { insertion = nowUtc - (19 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :overdueRemoval) { insertion = nowUtc - (24 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :overdueLarge) {
        insertion = nowUtc - (33 * CalendarMath.SECONDS_PER_DAY) - (23 * CalendarMath.SECONDS_PER_HOUR);
    }
    else if (scenario == :overdue29h) {
        insertion = nowUtc - (22 * CalendarMath.SECONDS_PER_DAY)
            - (5 * CalendarMath.SECONDS_PER_HOUR);
    }
    else if (scenario == :overdue2d) {
        insertion = nowUtc - (23 * CalendarMath.SECONDS_PER_DAY);
    }
    else if (scenario == :ringFree) { insertion = nowUtc - (23 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :freeDay3) {
        regimen[:daysOut] = 3;
        insertion = nowUtc - (28 * CalendarMath.SECONDS_PER_DAY) - (5 * CalendarMath.SECONDS_PER_HOUR);
    }
    else if (scenario == :freeExceeded || scenario == :ringFree8d
        || scenario == :notificationFree || scenario == :backgroundFree) {
        insertion = nowUtc - (30 * CalendarMath.SECONDS_PER_DAY);
    }
    else if (scenario == :temp250 || scenario == :temp310 || scenario == :notificationTemp
        || scenario == :backgroundTemp || scenario == :reminder2) {
        insertion = nowUtc - (5 * CalendarMath.SECONDS_PER_DAY);
    }
    else if (scenario == :ringIn1d12h) {
        insertion = nowUtc - (19 * CalendarMath.SECONDS_PER_DAY)
            - (12 * CalendarMath.SECONDS_PER_HOUR);
    }
    else if (scenario == :ringIn14h || scenario == :backgroundCorrupt) {
        insertion = nowUtc - (20 * CalendarMath.SECONDS_PER_DAY)
            - (10 * CalendarMath.SECONDS_PER_HOUR);
    }
    else if (scenario == :ringIn45m || scenario == :backgroundNil) {
        insertion = nowUtc - (20 * CalendarMath.SECONDS_PER_DAY)
            - (23 * CalendarMath.SECONDS_PER_HOUR) - (15 * 60);
    }
    else if (scenario == :warningWrapLong || scenario == :backgroundNoOp) {
        insertion = nowUtc + CalendarMath.SECONDS_PER_HOUR;
    }
    else if (scenario == :extended35 || scenario == :notificationFourWeeks
        || scenario == :backgroundFourWeeks || scenario == :largestCountdown
        || scenario == :ringIn29d) {
        regimen[:daysIn] = 35;
        insertion = (scenario == :notificationFourWeeks || scenario == :backgroundFourWeeks)
            ? nowUtc - (34 * CalendarMath.SECONDS_PER_DAY)
            : ((scenario == :extended35 || scenario == :ringIn29d)
                ? nowUtc - (29 * CalendarMath.SECONDS_PER_DAY) : nowUtc);
    }
    else if (scenario == :clock12Long) {
        insertion = mainDemoWallUtc(2026, 9, 9, 12, 26, insertion);
    }
    else if (scenario == :clock24) {
        insertion = nowUtc - (19 * CalendarMath.SECONDS_PER_DAY)
            - CalendarMath.SECONDS_PER_HOUR;
    }
    else if (scenario == :notificationDayBefore || scenario == :backgroundDayBefore) {
        insertion = nowUtc - (20 * CalendarMath.SECONDS_PER_DAY);
    }
    else if (scenario == :notificationReminder1 || scenario == :notificationReminder2
        || scenario == :backgroundReminder1 || scenario == :backgroundReminder2
        || scenario == :backgroundThrow) {
        insertion = nowUtc - (21 * CalendarMath.SECONDS_PER_DAY);
    }
    else if (scenario == :notificationOverdue || scenario == :backgroundOverdue) {
        insertion = nowUtc - (22 * CalendarMath.SECONDS_PER_DAY)
            - (5 * CalendarMath.SECONDS_PER_HOUR);
    }
    else if (scenario == :alertDetail) {
        insertion = nowUtc - (22 * CalendarMath.SECONDS_PER_DAY) - (4 * CalendarMath.SECONDS_PER_HOUR);
    }
    var active = ScheduleModel.insertOrReplace(state, insertion);
    if (scenario == :overdueRemoval) { addListDemoHistory(state, active); }
    if (scenario == :ringFree) { ScheduleModel.recordRemoval(active, nowUtc - (2 * CalendarMath.SECONDS_PER_DAY), regimen); }
    else if (scenario == :freeDay3) { ScheduleModel.recordRemoval(active, nowUtc - (3 * CalendarMath.SECONDS_PER_DAY) - (5 * CalendarMath.SECONDS_PER_HOUR), regimen); }
    else if (scenario == :freeExceeded || scenario == :ringFree8d
        || scenario == :notificationFree || scenario == :backgroundFree) {
        ScheduleModel.recordRemoval(active, nowUtc - (8 * CalendarMath.SECONDS_PER_DAY), regimen);
    }
    else if (scenario == :temp250) { ScheduleModel.startTemporaryOut(active, nowUtc - (2 * 3600) - (50 * 60)); }
    else if (scenario == :temp310 || scenario == :notificationTemp || scenario == :backgroundTemp) { ScheduleModel.startTemporaryOut(active, nowUtc - (3 * 3600) - (10 * 60)); }
    else if (scenario == :reminder2) {
        var demoReminders = state[:reminders] as Lang.Dictionary;
        demoReminders[:reminder2Enabled] = true;
    }
    var scenarioReminders = state[:reminders] as Lang.Dictionary;
    if (scenario == :notificationDayBefore || scenario == :notificationReminder1
        || scenario == :backgroundDayBefore || scenario == :backgroundReminder1
        || scenario == :backgroundThrow) {
        var reminderNow = CalendarMath.localFields(nowUtc);
        scenarioReminders[:reminder1Hour] = reminderNow[:hour];
        scenarioReminders[:reminder1Minute] = reminderNow[:minute];
    }
    if (scenario == :clock12Long) { scenarioReminders[:clockFormat] = 12; }
    else if (scenario == :clock24) { scenarioReminders[:clockFormat] = 24; }
    else if (scenario == :migration) { state[:migrationNoticePending] = true; }
    else if (scenario == :notificationReminder2 || scenario == :backgroundReminder2) {
        var nowFields = CalendarMath.localFields(nowUtc);
        scenarioReminders[:reminder2Enabled] = true;
        scenarioReminders[:reminder2Hour] = nowFields[:hour];
        scenarioReminders[:reminder2Minute] = nowFields[:minute];
        var notificationLedger = state[:reminderLedger] as Lang.Dictionary;
        var notificationStatus = ScheduleModel.deriveStatus(nowUtc, active, regimen);
        notificationLedger[:cycleId] = active[:cycleId];
        notificationLedger[:actionKey] = ReminderPolicy.actionKey(notificationStatus);
        notificationLedger[:dayOf1Sent] = true;
    }
    return state;
}

(:debug)
function addListDemoHistory(state as Lang.Dictionary, active as Lang.Dictionary) as Void {
    var latestInsertion = demoLocalUtc(2026, 9, 30, 9, 0);
    var history = [];
    for (var c = 0; c < ScheduleModel.MAX_HISTORY; c += 1) {
        var inserted = latestInsertion
            - ((ScheduleModel.MAX_HISTORY - c - 1) * 40 * CalendarMath.SECONDS_PER_DAY);
        var amberCycle = c == ScheduleModel.MAX_HISTORY - 2;
        var removed = inserted + ((amberCycle ? 19 : 6) * CalendarMath.SECONDS_PER_DAY);
        var removeDue = CalendarMath.addLocalCalendarDays(inserted, 21)[:utc];
        var insertDue = CalendarMath.addLocalCalendarDays(removed, 7)[:utc];
        var nextInserted = insertDue + ((amberCycle ? 2 : 15) * CalendarMath.SECONDS_PER_DAY);
        var firstRecorded = c == 0;
        var insertionVariance = amberCycle ? 2 : 15;
        var insertionPlan = firstRecorded ? null
            : inserted - (insertionVariance * CalendarMath.SECONDS_PER_DAY);
        history.add({:cycleId=>c + 1, :insertionUtc=>inserted,
            :insertionPlanUtc=>insertionPlan,
            :insertionDeltaSeconds=>firstRecorded ? null
                : insertionVariance * CalendarMath.SECONDS_PER_DAY,
            :removeDueUtc=>removeDue, :removalUtc=>removed,
            :removalDeltaSeconds=>removed - removeDue, :insertDueUtc=>insertDue,
            :nextInsertionUtc=>nextInserted, :nextInsertionDeltaSeconds=>nextInserted - insertDue,
            :closeReason=>"replaced", :regimenDaysIn=>21, :regimenDaysOut=>7,
            :temporaryOut=>[],
            :temporaryOutSummary=>{:shortIntervalCount=>0, :shortIntervalSeconds=>0}});
    }
    state[:history] = history;
    active[:cycleId] = ScheduleModel.MAX_HISTORY + 1;
    state[:nextCycleId] = ScheduleModel.MAX_HISTORY + 2;
    var ledger = state[:reminderLedger] as Lang.Dictionary;
    ledger[:cycleId] = active[:cycleId];
}

(:debug)
function demoLocalUtc(year as Lang.Number, month as Lang.Number, day as Lang.Number,
                      hour as Lang.Number, minute as Lang.Number) as Lang.Number {
    var fields = {:year=>year, :month=>month, :day=>day,
        :hour=>hour, :minute=>minute, :second=>0};
    var resolved = CalendarMath.wallToUtcUsingDevice(fields);
    return resolved == null ? CalendarMath.utc(year, month, day, hour, minute, 0)
        : (resolved as Lang.Dictionary)[:utc] as Lang.Number;
}

(:debug)
function maximumDemoState(state as Lang.Dictionary, nowUtc as Lang.Number) as Lang.Dictionary {
    state[:setupStep] = 3;
    var reminders = state[:reminders] as Lang.Dictionary;
    reminders[:clockFormat] = 12;
    var history = [];
    for (var c = 0; c < ScheduleModel.MAX_HISTORY; c += 1) {
        var inserted = nowUtc - ((ScheduleModel.MAX_HISTORY - c) * 40 * CalendarMath.SECONDS_PER_DAY);
        var intervals = [];
        // Thirty-two archived intervals plus thirty-two active intervals meet
        // the SPEC memory fixture while retaining the maximum 24 cycles.
        var intervalCount = c < 8 ? 2 : 1;
        for (var i = 0; i < intervalCount; i += 1) {
            var out = inserted + 100 + (i * 11000);
            intervals.add({:outUtc=>out, :backInUtc=>out + 10801,
                :phaseWeekAtStart=>1, :phaseWeekAtEnd=>1, :thresholdCode=>"over3h"});
        }
        var removed = inserted + (6 * CalendarMath.SECONDS_PER_DAY);
        var removeDue = CalendarMath.addLocalCalendarDays(inserted, 21)[:utc];
        var insertDue = CalendarMath.addLocalCalendarDays(removed, 7)[:utc];
        var nextInserted = inserted + (28 * CalendarMath.SECONDS_PER_DAY);
        var firstRecorded = c == 0;
        var insertionPlan = firstRecorded ? null
            : inserted - (15 * CalendarMath.SECONDS_PER_DAY);
        history.add({:cycleId=>c + 1, :insertionUtc=>inserted,
            :insertionPlanUtc=>insertionPlan,
            :insertionDeltaSeconds=>firstRecorded ? null : 15 * CalendarMath.SECONDS_PER_DAY,
            :removeDueUtc=>removeDue, :removalUtc=>removed,
            :removalDeltaSeconds=>removed - removeDue, :insertDueUtc=>insertDue,
            :nextInsertionUtc=>nextInserted, :nextInsertionDeltaSeconds=>nextInserted - insertDue,
            :closeReason=>"replaced", :regimenDaysIn=>21, :regimenDaysOut=>7,
            :temporaryOut=>intervals,
            :temporaryOutSummary=>{:shortIntervalCount=>0, :shortIntervalSeconds=>0}});
    }
    state[:history] = history;
    state[:nextCycleId] = ScheduleModel.MAX_HISTORY + 1;
    var active = ScheduleModel.insertOrReplace(state, nowUtc - (6 * CalendarMath.SECONDS_PER_DAY));
    var activeIntervals = active[:temporaryOut] as Lang.Array;
    for (var j = 0; j < ScheduleModel.MAX_TEMP_INTERVALS - 1; j += 1) {
        var activeOut = active[:insertionUtc] + 100 + (j * 11000);
        activeIntervals.add({:outUtc=>activeOut, :backInUtc=>activeOut + 10801,
            :phaseWeekAtStart=>1, :phaseWeekAtEnd=>1, :thresholdCode=>"over3h"});
    }
    activeIntervals.add({:outUtc=>active[:insertionUtc] + 100
        + ((ScheduleModel.MAX_TEMP_INTERVALS - 1) * 11000), :backInUtc=>null,
        :phaseWeekAtStart=>1, :phaseWeekAtEnd=>null, :thresholdCode=>null});
    return state;
}
