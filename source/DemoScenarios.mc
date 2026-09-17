import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Notifications;

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
function previewOptionalNotification(data, state as Lang.Dictionary, nowUtc as Lang.Number) as Void {
    var scenario = data as Lang.Symbol;
    var title = null;
    var subtitle = null;
    var body = null;
    if (scenario == :notificationDayBefore) {
        title = "Remove ring tomorrow";
        subtitle = "Due " + Ui.timeForUtc(((state[:active] as Lang.Dictionary)[:removeDueUtc]),
            (state[:reminders] as Lang.Dictionary)[:clockFormat]);
    } else if (scenario == :notificationReminder1 || scenario == :notificationReminder2) {
        title = "Remove ring today";
        subtitle = "Due " + Ui.timeForUtc(((state[:active] as Lang.Dictionary)[:removeDueUtc]),
            (state[:reminders] as Lang.Dictionary)[:clockFormat]);
    } else if (scenario == :notificationOverdue) {
        title = "Ring overdue 1d 4h";
        subtitle = "Remove ring";
    } else if (scenario == :notificationTemp) {
        title = "Out over 3h";
        subtitle = "Reinsert now";
        body = "Use backup 7 days.";
    } else if (scenario == :notificationFree) {
        title = "Insert now";
        subtitle = "Ring out over 7d";
        body = "Use backup 7 days.";
    } else if (scenario == :notificationFourWeeks) {
        title = "Replace now";
        subtitle = "Ring in over 4 weeks";
    }
    if (title == null) { return; }
    var options = { :data => [((state[:active] as Lang.Dictionary)[:cycleId]), 0],
        :dismissPrevious => true };
    if (body != null) { options[:body] = body; }
    Notifications.showNotification(title as Lang.String, subtitle as Lang.String, options);
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
function demoState(scenario as Lang.Symbol, nowUtc as Lang.Number) as Lang.Dictionary {
    if (scenario == :overdueRemoval) {
        nowUtc = demoLocalUtc(2026, 12, 25, 9, 0);
    } else if (scenario == :maximumState) {
        nowUtc = demoLocalUtc(2026, 10, 6, 9, 0);
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
    else if (scenario == :ringFree) { insertion = nowUtc - (23 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :freeDay3) {
        regimen[:daysOut] = 3;
        insertion = nowUtc - (28 * CalendarMath.SECONDS_PER_DAY) - (5 * CalendarMath.SECONDS_PER_HOUR);
    }
    else if (scenario == :freeExceeded || scenario == :notificationFree || scenario == :backgroundFree) { insertion = nowUtc - (30 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :temp250 || scenario == :temp310 || scenario == :notificationTemp
        || scenario == :backgroundTemp || scenario == :reminder2) { insertion = nowUtc - (5 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :extended35 || scenario == :notificationFourWeeks
        || scenario == :backgroundFourWeeks || scenario == :largestCountdown) {
        regimen[:daysIn] = 35;
        insertion = (scenario == :extended35 || scenario == :notificationFourWeeks
            || scenario == :backgroundFourWeeks)
            ? nowUtc - (29 * CalendarMath.SECONDS_PER_DAY) : nowUtc;
    }
    else if (scenario == :clock12Long || scenario == :clock24) {
        var targetWall = CalendarMath.localFields(nowUtc - (4 * CalendarMath.SECONDS_PER_DAY));
        targetWall[:hour] = 23;
        targetWall[:minute] = 59;
        targetWall[:second] = 0;
        var target = CalendarMath.wallToUtcUsingDevice(targetWall);
        if (target != null) { insertion = target[:utc]; }
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
        insertion = nowUtc - (22 * CalendarMath.SECONDS_PER_DAY) - (4 * CalendarMath.SECONDS_PER_HOUR);
    }
    var active = ScheduleModel.insertOrReplace(state, insertion);
    if (scenario == :ringFree) { ScheduleModel.recordRemoval(active, nowUtc - (2 * CalendarMath.SECONDS_PER_DAY), regimen); }
    else if (scenario == :freeDay3) { ScheduleModel.recordRemoval(active, nowUtc - (3 * CalendarMath.SECONDS_PER_DAY) - (5 * CalendarMath.SECONDS_PER_HOUR), regimen); }
    else if (scenario == :freeExceeded || scenario == :notificationFree || scenario == :backgroundFree) { ScheduleModel.recordRemoval(active, nowUtc - (8 * CalendarMath.SECONDS_PER_DAY), regimen); }
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
