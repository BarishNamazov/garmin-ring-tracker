// Independent review regressions originally executed against de9f030.
// Run in TZ=America/New_York with the main domain test personality.

import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

(:test)
function reviewCalendarAddAcrossSpringGap(logger as Test.Logger) as Boolean {
    var source = testWall(2026, 2, 15, 2, 30);
    var result = CalendarMath.addLocalCalendarDays(source, 21);
    var target = {:year=>2026, :month=>3, :day=>8, :hour=>2, :minute=>30, :second=>0};
    var selected = Toybox.Time.Gregorian.info(new Toybox.Time.Moment(result[:utc]), Toybox.Time.FORMAT_SHORT);
    var previous = Toybox.Time.Gregorian.info(new Toybox.Time.Moment(result[:utc] - 60), Toybox.Time.FORMAT_SHORT);
    Test.assert(result[:adjusted]);
    Test.assert(CalendarMath.wallOrder(selected, target) > 0);
    Test.assert(CalendarMath.wallOrder(previous, target) <= 0);
    return true;
}

(:test)
function reviewCalendarAddAcrossFallFold(logger as Test.Logger) as Boolean {
    var source = testWall(2026, 10, 11, 1, 30);
    var result = CalendarMath.addLocalCalendarDays(source, 21);
    Test.assert(!result[:adjusted]);
    Test.assertEqual(CalendarMath.utc(2026, 11, 1, 5, 30, 0), result[:utc]);
    return true;
}

(:test)
function reviewDayOfCycleUsesLocalDateAcrossDst(logger as Test.Logger) as Boolean {
    var inserted = testWall(2026, 3, 7, 23, 30);
    var afterMidnight = testWall(2026, 3, 8, 0, 30);
    Test.assertEqual(2, CalendarMath.dayOfCycle(afterMidnight, inserted));
    return true;
}

(:test)
function reviewSettingsRejectFutureActualInsertion(logger as Test.Logger) as Boolean {
    var now = testWall(2026, 9, 14, 9, 0);
    Test.assert(SettingsBridge.parseInsertion("2026-09-15T09:00", now) == null);
    return true;
}

(:test)
function reviewValidationRejectsMissingReminderDocument(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    state[:reminders] = null;
    Test.assert(!ScheduleModel.validState(state));
    return true;
}

(:test)
function reviewValidationRejectsRemovalBeforeInsertion(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 9, 10, 9, 0);
    var active = ScheduleModel.insertOrReplace(state, start);
    active[:removalUtc] = start - 1;
    active[:ringFreeCeilingUtc] = CalendarMath.addLocalCalendarDays(start - 1, 7)[:utc];
    Test.assert(!ScheduleModel.validState(state));
    return true;
}

(:test)
function reviewTemporaryOutBeforeLimitDoesNotCreateScheduleReminder(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    var start = testWall(2026, 9, 1, 9, 0);
    var out = testWall(2026, 9, 5, 8, 0);
    var now = testWall(2026, 9, 5, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    Test.assert(ScheduleModel.startTemporaryOut(cycle, out));
    Test.assert(ReminderPolicy.evaluate(now, cycle, regimen, reminders,
        ScheduleModel.defaultLedger()) == null);
    return true;
}

(:test)
function reviewExactThreeHoursIsNotGenericActionOverdue(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    reminders[:reminder1Hour] = 23;
    var start = testWall(2026, 9, 1, 9, 0);
    var out = testWall(2026, 9, 5, 8, 0);
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    Test.assert(ScheduleModel.startTemporaryOut(cycle, out));
    Test.assert(ReminderPolicy.evaluate(out + ScheduleModel.TEMP_LIMIT_SECONDS,
        cycle, regimen, reminders, ScheduleModel.defaultLedger()) == null);
    return true;
}

(:test)
function reviewDayOfSuppressesStaleDayBeforeCatchup(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    var start = testWall(2026, 9, 1, 12, 0);
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    var ledger = ScheduleModel.defaultLedger();
    var now = testWall(2026, 9, 22, 10, 0);
    var first = ReminderPolicy.evaluate(now, cycle, regimen, reminders, ledger);
    Test.assertEqual(:dayOf, first[:kind]);
    ReminderPolicy.markSent(ledger, first);
    Test.assert(ReminderPolicy.evaluate(now + 60, cycle, regimen, reminders, ledger) == null);
    return true;
}

(:test)
function reviewWorstCaseHistoryFitsStorageValueLimit(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var history = [];
    for (var cycle = 0; cycle < ScheduleModel.MAX_HISTORY; cycle += 1) {
        var intervals = [];
        for (var interval = 0; interval < ScheduleModel.MAX_TEMP_INTERVALS; interval += 1) {
            var out = 1700000000 + (cycle * 100000) + (interval * 20000);
            intervals.add({:outUtc=>out, :backInUtc=>out + 10900,
                :phaseWeekAtStart=>1, :phaseWeekAtEnd=>1, :thresholdCode=>"over3h"});
        }
        var inserted = 1700000000 + (cycle * 100000);
        history.add(testHistoryCycle(cycle + 1, inserted,
            inserted + 700000, inserted + 800000, intervals));
    }
    state[:history] = history;
    var active = ScheduleModel.newCycle(25, 1800000000, state[:regimen] as Dictionary);
    for (var openIndex = 0; openIndex < ScheduleModel.MAX_TEMP_INTERVALS; openIndex += 1) {
        var activeOut = 1800001000 + (openIndex * 20000);
        Test.assert(ScheduleModel.startTemporaryOut(active, activeOut));
        Test.assert(ScheduleModel.endTemporaryOut(active, activeOut + 10900));
    }
    state[:active] = active;
    state[:nextCycleId] = 26;
    var estimate = RingStore.stateSizeEstimate(state);
    var saved = RingStore.save(state);
    Toybox.Application.Storage.deleteValue(RingStore.STATE_KEY);
    Toybox.Application.Storage.deleteValue(RingStore.GLANCE_KEY);
    Toybox.Application.Storage.deleteValue(RingStore.BACKGROUND_KEY);
    System.println("REVIEW_WORST_CASE_STATE_ESTIMATE=" + estimate + ",saved=" + saved);
    Test.assert(saved);
    Test.assert(estimate < 24576);
    return true;
}

(:test)
function reviewExtendedTemporaryOutHasNoInventedStandardWeek(logger as Test.Logger) as Boolean {
    var regimen = {:daysIn=>35, :daysOut=>0};
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    var day29 = CalendarMath.addLocalCalendarDays(start, 28)[:utc];
    Test.assert(ScheduleModel.startTemporaryOut(cycle, day29));
    Test.assert((ScheduleModel.tempOpen(cycle) as Dictionary)[:phaseWeekAtStart] == null);
    return true;
}

(:test)
function reviewThirtyThirdTemporaryOutIsStillRecordable(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    for (var interval = 0; interval < ScheduleModel.MAX_TEMP_INTERVALS; interval += 1) {
        var out = start + 100 + (interval * 100);
        Test.assert(ScheduleModel.startTemporaryOut(cycle, out));
        Test.assert(ScheduleModel.endTemporaryOut(cycle, out + 10));
    }
    Test.assert(ScheduleModel.startTemporaryOut(cycle, start + 4000));
    return true;
}

(:test)
function reviewPendingInsertionMirrorDoesNotBoomerang(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 9, 1, 9, 0);
    ScheduleModel.insertOrReplace(state, start);
    SettingsBridge.mirrorAll(state);
    var edited = start + 3600;
    state[:active] = ScheduleModel.newCycle(1, edited, state[:regimen] as Dictionary);
    var sync = state[:settingsSync] as Dictionary;
    sync[:lastWatchScheduleEditUtc] = edited;
    sync[:pendingMirrorIso] = SettingsBridge.isoForUtc(edited);
    Test.assert(SettingsBridge.observe(state, edited) == null);
    Test.assertEqual(SettingsBridge.isoForUtc(edited),
        SettingsBridge.isoForPropertyPair(
            Toybox.Application.Properties.getValue("insertionDate"),
            Toybox.Application.Properties.getValue("insertionTime")));
    return true;
}

(:test)
function reviewEmptySettingsInsertionDoesNotClearActiveCycle(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 9, 1, 9, 0);
    ScheduleModel.insertOrReplace(state, start);
    SettingsBridge.mirrorAll(state);
    Toybox.Application.Properties.setValue("insertionDate", 0);
    SettingsBridge.observe(state, start + 100);
    Test.assert(state[:active] != null);
    Test.assertEqual(start, (state[:active] as Dictionary)[:insertionUtc]);
    return true;
}

(:test)
function reviewLoadRecoversSemanticallyInvalidReminderConfig(logger as Test.Logger) as Boolean {
    var raw = RingStore.encodeState(ScheduleModel.defaultState());
    var rawReminders = raw[5] as Array;
    rawReminders[6] = 0;
    Toybox.Application.Storage.setValue(RingStore.STATE_KEY, raw);
    var loaded = RingStore.load();
    Toybox.Application.Storage.deleteValue(RingStore.STATE_KEY);
    Toybox.Application.Storage.deleteValue(RingStore.GLANCE_KEY);
    Toybox.Application.Storage.deleteValue(RingStore.BACKGROUND_KEY);
    Test.assertEqual("recovered", loaded[:loadError]);
    return true;
}

(:test)
function reviewNegativeCountdownDecomposesAbsoluteDuration(logger as Test.Logger) as Boolean {
    var countdown = CalendarMath.countdown(-90061);
    Test.assert(countdown[:overdue]);
    Test.assertEqual(1, countdown[:days]);
    Test.assertEqual(1, countdown[:hours]);
    Test.assertEqual(1, countdown[:minutes]);
    return true;
}

(:test)
function reviewZeroDayRemovalIsImmediatelyDue(logger as Test.Logger) as Boolean {
    var regimen = {:daysIn=>28, :daysOut=>0};
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    var removed = start + 100;
    Test.assert(ScheduleModel.recordRemoval(cycle, removed, regimen));
    var status = ScheduleModel.deriveStatus(removed, cycle, regimen);
    Test.assertEqual(:overdue, status[:phase]);
    Test.assertEqual(:insert, status[:overdueKind]);
    Test.assertEqual(0, status[:secondsRemaining]);
    return true;
}
