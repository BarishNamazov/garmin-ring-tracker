import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

(:testhelper)
function testWall(y as Number, m as Number, d as Number, hh as Number, mm as Number) as Number {
    var result = CalendarMath.wallToUtc({
        :year => y, :month => m, :day => d, :hour => hh, :minute => mm, :second => 0
    }, System.getClockTime().timeZoneOffset);
    Test.assert(result != null);
    return (result as Dictionary)[:utc] as Number;
}

(:testhelper)
function assertLocalDateTime(value as Number, y as Number, m as Number, d as Number, hh as Number, mm as Number) as Void {
    var fields = CalendarMath.localFields(value);
    Test.assertEqual(y, fields[:year]);
    Test.assertEqual(m, fields[:month]);
    Test.assertEqual(d, fields[:day]);
    Test.assertEqual(hh, fields[:hour]);
    Test.assertEqual(mm, fields[:minute]);
}

(:test)
function calendarStandardTwentyOneDays(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 1, 9, 0);
    var result = CalendarMath.addLocalCalendarDays(start, 21);
    assertLocalDateTime(result[:utc], 2026, 9, 22, 9, 0);
    return true;
}

(:test)
function calendarLeapAndMonthBoundaries(logger as Test.Logger) as Boolean {
    var start = testWall(2028, 2, 28, 9, 0);
    assertLocalDateTime(CalendarMath.addLocalCalendarDays(start, 1)[:utc], 2028, 2, 29, 9, 0);
    assertLocalDateTime(CalendarMath.addLocalCalendarDays(start, 2)[:utc], 2028, 3, 1, 9, 0);
    return true;
}

(:test)
function calendarYearBoundary(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 12, 31, 23, 59);
    assertLocalDateTime(CalendarMath.addLocalCalendarDays(start, 1)[:utc], 2027, 1, 1, 23, 59);
    return true;
}

(:test)
function calendarValidWallRejectsImpossibleDate(logger as Test.Logger) as Boolean {
    Test.assert(!CalendarMath.validWall({:year=>2026, :month=>2, :day=>29, :hour=>9, :minute=>0, :second=>0}));
    Test.assert(CalendarMath.validWall({:year=>2028, :month=>2, :day=>29, :hour=>9, :minute=>0, :second=>0}));
    return true;
}

(:test)
function countdownBoundaries(logger as Test.Logger) as Boolean {
    var c25 = CalendarMath.countdown(25 * 3600);
    Test.assertEqual(1, c25[:days]);
    Test.assertEqual(1, c25[:hours]);
    Test.assertEqual(:days, CalendarMath.glanceCountdown(25 * 3600)[:unit]);
    Test.assertEqual(2, CalendarMath.glanceCountdown(25 * 3600)[:value]);
    Test.assertEqual(:now, CalendarMath.glanceCountdown(0)[:unit]);
    Test.assertEqual(:now, CalendarMath.glanceCountdown(-1)[:unit]);
    return true;
}

(:test)
function scheduleFirstRun(logger as Test.Logger) as Boolean {
    var status = ScheduleModel.deriveStatus(100, null, ScheduleModel.defaultRegimen());
    Test.assertEqual(:setup, status[:phase]);
    Test.assertEqual(:setUp, status[:nextAction]);
    return true;
}

(:test)
function scheduleRemovalBoundary(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, ScheduleModel.defaultRegimen());
    var due = cycle[:scheduledRemovalUtc];
    Test.assertEqual(:ringIn, ScheduleModel.deriveStatus(due - 1, cycle, ScheduleModel.defaultRegimen())[:phase]);
    Test.assertEqual(:overdue, ScheduleModel.deriveStatus(due, cycle, ScheduleModel.defaultRegimen())[:phase]);
    Test.assertEqual(:overdue, ScheduleModel.deriveStatus(due + 1, cycle, ScheduleModel.defaultRegimen())[:phase]);
    return true;
}

(:test)
function scheduleImmediateReplacement(logger as Test.Logger) as Boolean {
    var regimen = {:daysIn=>28, :daysOut=>0};
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    Test.assertEqual(cycle[:scheduledRemovalUtc], cycle[:scheduledInsertionUtc]);
    Test.assertEqual(:replace, ScheduleModel.deriveStatus(start, cycle, regimen)[:nextAction]);
    return true;
}

(:test)
function scheduleExtendedLabelBoundary(logger as Test.Logger) as Boolean {
    var regimen = {:daysIn=>35, :daysOut=>7};
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    var boundary = cycle[:labelFourWeekUtc];
    Test.assert(!ScheduleModel.deriveStatus(boundary, cycle, regimen)[:beyondLabelFourWeeks]);
    var after = ScheduleModel.deriveStatus(boundary + 1, cycle, regimen);
    Test.assert(after[:beyondLabelFourWeeks]);
    Test.assertEqual(:ringIn, after[:phase]);
    return true;
}

(:test)
function temporaryOutExactBoundary(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, ScheduleModel.defaultRegimen());
    Test.assert(ScheduleModel.startTemporaryOut(cycle, start + 3600));
    Test.assertEqual(:under, ScheduleModel.deriveStatus(start + 3600 + 10799, cycle, ScheduleModel.defaultRegimen())[:tempBoundary]);
    Test.assertEqual(:at, ScheduleModel.deriveStatus(start + 3600 + 10800, cycle, ScheduleModel.defaultRegimen())[:tempBoundary]);
    Test.assertEqual(:over, ScheduleModel.deriveStatus(start + 3600 + 10801, cycle, ScheduleModel.defaultRegimen())[:tempBoundary]);
    return true;
}

(:test)
function temporaryOutInvalidTransitions(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, ScheduleModel.defaultRegimen());
    Test.assert(!ScheduleModel.startTemporaryOut(cycle, start - 1));
    Test.assert(ScheduleModel.startTemporaryOut(cycle, start + 10));
    Test.assert(!ScheduleModel.startTemporaryOut(cycle, start + 20));
    Test.assert(!ScheduleModel.endTemporaryOut(cycle, start));
    Test.assert(ScheduleModel.endTemporaryOut(cycle, start + 100));
    return true;
}

(:test)
function ringFreeCeilingBoundary(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 1, 9, 0);
    var regimen = ScheduleModel.defaultRegimen();
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    var removed = cycle[:scheduledRemovalUtc];
    Test.assert(ScheduleModel.recordRemoval(cycle, removed, regimen));
    var ceiling = cycle[:ringFreeCeilingUtc];
    Test.assert(!ScheduleModel.deriveStatus(ceiling, cycle, regimen)[:ringFreeLimitExceeded]);
    Test.assert(ScheduleModel.deriveStatus(ceiling + 1, cycle, regimen)[:ringFreeLimitExceeded]);
    return true;
}

(:test)
function earlyRemovalUsesEarlierDeadline(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 1, 9, 0);
    var regimen = ScheduleModel.defaultRegimen();
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    var early = CalendarMath.addLocalCalendarDays(start, 20)[:utc];
    ScheduleModel.recordRemoval(cycle, early, regimen);
    Test.assertEqual(CalendarMath.addLocalCalendarDays(early, 7)[:utc], ScheduleModel.nextInsertUtc(cycle, regimen));
    return true;
}

(:test)
function lateRemovalIsImmediatelyOverdue(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 1, 9, 0);
    var regimen = ScheduleModel.defaultRegimen();
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    var late = cycle[:scheduledInsertionUtc] + 10;
    ScheduleModel.recordRemoval(cycle, late, regimen);
    Test.assertEqual(:overdue, ScheduleModel.deriveStatus(late, cycle, regimen)[:phase]);
    return true;
}

(:test)
function replacementArchivesOneCycle(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 9, 1, 9, 0);
    ScheduleModel.insertOrReplace(state, start);
    ScheduleModel.insertOrReplace(state, start + 100);
    Test.assertEqual(1, state[:history].size());
    var active = state[:active] as Dictionary;
    Test.assertEqual(2, active[:cycleId]);
    return true;
}

(:test)
function historyEvictsOldestWholeCycle(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 1, 1, 9, 0);
    for (var i = 0; i < 26; i += 1) {
        ScheduleModel.insertOrReplace(state, start + (i * 100));
    }
    Test.assertEqual(24, state[:history].size());
    var history = state[:history] as Array<Dictionary>;
    Test.assertEqual(2, history[0][:cycleId]);
    return true;
}

(:test)
function reminderOverdueSlotsDeduplicate(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(7, start, regimen);
    var ledger = ScheduleModel.defaultLedger();
    var due = cycle[:scheduledRemovalUtc];
    var selected = ReminderPolicy.evaluate(due, cycle, regimen, reminders, ledger);
    Test.assertEqual(:overdue, selected[:kind]);
    Test.assertEqual(0, selected[:slot]);
    ReminderPolicy.markSent(ledger, selected);
    Test.assert(ReminderPolicy.evaluate(due + 1, cycle, regimen, reminders, ledger) == null);
    Test.assertEqual(1, ReminderPolicy.evaluate(due + (6 * 3600), cycle, regimen, reminders, ledger)[:slot]);
    return true;
}

(:test)
function reminderLedgerChangesOnlyWhenMarked(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(4, start, regimen);
    var ledger = ScheduleModel.defaultLedger();
    var due = cycle[:scheduledRemovalUtc];
    var first = ReminderPolicy.evaluate(due, cycle, regimen, reminders, ledger);
    var second = ReminderPolicy.evaluate(due, cycle, regimen, reminders, ledger);
    Test.assertEqual(first[:kind], second[:kind]);
    ReminderPolicy.markSent(ledger, first);
    Test.assert(ReminderPolicy.evaluate(due, cycle, regimen, reminders, ledger) == null);
    return true;
}

(:test)
function reminderTemporaryOutHasHigherPriority(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, regimen);
    ScheduleModel.startTemporaryOut(cycle, start);
    var selected = ReminderPolicy.evaluate(start + 10801, cycle, regimen, reminders, ScheduleModel.defaultLedger());
    Test.assertEqual(:tempOver3h, selected[:kind]);
    Test.assertEqual(2, selected[:priority]);
    return true;
}

(:test)
function stateValidationRejectsNewerAndCorrupt(logger as Test.Logger) as Boolean {
    var valid = ScheduleModel.defaultState();
    Test.assert(ScheduleModel.validState(valid));
    valid[:schemaVersion] = 2;
    Test.assert(!ScheduleModel.validState(valid));
    var corrupt = ScheduleModel.defaultState();
    var corruptRegimen = corrupt[:regimen] as Dictionary;
    corruptRegimen[:daysIn] = 99;
    Test.assert(!ScheduleModel.validState(corrupt));
    return true;
}

(:test)
function clockBeforeInsertionFlag(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 1, 9, 0);
    var cycle = ScheduleModel.newCycle(1, start, ScheduleModel.defaultRegimen());
    var status = ScheduleModel.deriveStatus(start - 1, cycle, ScheduleModel.defaultRegimen());
    Test.assert(status[:clockBeforeInsertion]);
    Test.assertEqual(1, status[:dayOfCycle]);
    return true;
}

(:test)
function settingsIsoRoundTrip(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 14, 9, 37);
    var iso = SettingsBridge.isoForUtc(start);
    var parsed = SettingsBridge.parseInsertion(iso, start);
    Test.assert(parsed != null);
    Test.assertEqual(start, (parsed as Dictionary)[:utc]);
    return true;
}

(:test)
function settingsIsoRejectsMalformedAndImpossible(logger as Test.Logger) as Boolean {
    var now = testWall(2026, 9, 14, 9, 0);
    Test.assert(SettingsBridge.parseInsertion("2026-02-31T09:00", now) == null);
    Test.assert(SettingsBridge.parseInsertion("2026/09/14 09:00", now) == null);
    Test.assert(SettingsBridge.parseInsertion("2029-09-14T09:00", now) == null);
    return true;
}

(:test)
function settingsRangeValidation(logger as Test.Logger) as Boolean {
    var now = testWall(2026, 9, 14, 9, 0);
    Test.assert(SettingsBridge.validate("daysIn", 21, now));
    Test.assert(SettingsBridge.validate("daysIn", 35, now));
    Test.assert(!SettingsBridge.validate("daysIn", 36, now));
    Test.assert(SettingsBridge.validate("overdueRepeatHours", 6, now));
    Test.assert(!SettingsBridge.validate("overdueRepeatHours", 5, now));
    return true;
}

(:test)
function storageCodecRoundTrip(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 9, 1, 9, 0);
    ScheduleModel.insertOrReplace(state, start);
    var encoded = RingStore.encodeState(state);
    var decoded = RingStore.decodeState(encoded);
    Test.assert(ScheduleModel.validState(decoded));
    Test.assertEqual(start, (decoded[:active] as Dictionary)[:insertionUtc]);
    Test.assertEqual(21, (decoded[:regimen] as Dictionary)[:daysIn]);
    return true;
}

(:test)
function backgroundLedgerWritePreservesHistory(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 9, 1, 9, 0);
    ScheduleModel.insertOrReplace(state, start);
    ScheduleModel.insertOrReplace(state, start + 100);
    Test.assert(RingStore.save(state));
    var backgroundState = RingStore.loadBackground();
    Test.assert(backgroundState[:history] == null);
    var ledger = backgroundState[:reminderLedger] as Dictionary;
    ledger[:dayOfSent] = true;
    Test.assert(RingStore.saveBackgroundLedger(backgroundState));
    var restored = RingStore.load();
    Test.assertEqual(1, (restored[:history] as Array).size());
    Test.assert((restored[:reminderLedger] as Dictionary)[:dayOfSent]);
    return true;
}

(:test)
function historyCompactsOlderShortIntervals(logger as Test.Logger) as Boolean {
    var intervals = [];
    for (var i = 0; i < 12; i += 1) {
        intervals.add({:outUtc=>i * 1000, :backInUtc=>(i * 1000) + 600,
            :phaseWeekAtStart=>1, :phaseWeekAtEnd=>1, :thresholdCode=>"under3h"});
    }
    intervals.add({:outUtc=>20000, :backInUtc=>31000,
        :phaseWeekAtStart=>2, :phaseWeekAtEnd=>2, :thresholdCode=>"over3h"});
    intervals.add({:outUtc=>40000, :backInUtc=>null,
        :phaseWeekAtStart=>3, :phaseWeekAtEnd=>null, :thresholdCode=>null});
    var compact = ScheduleModel.compactIntervals(intervals);
    Test.assertEqual(10, (compact[:retained] as Array).size());
    Test.assertEqual(4, compact[:shortCount]);
    Test.assertEqual(2400, compact[:shortSeconds]);
    return true;
}

(:test)
function settingsMirrorClearsInsertionWithoutActiveCycle(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    Toybox.Application.Properties.setValue("insertionIso", "2026-09-14T09:00");
    SettingsBridge.mirrorAll(state);
    Test.assertEqual("", Toybox.Application.Properties.getValue("insertionIso"));
    return true;
}

(:test)
function calendarSpringForwardAdvancesToValidMinute(logger as Test.Logger) as Boolean {
    var fields = {:year=>2026, :month=>3, :day=>8, :hour=>2, :minute=>30, :second=>0};
    var seed = CalendarMath.utc(2026, 3, 8, 7, 30, 0);
    var resolved = CalendarMath.resolveLocalWall(fields, seed);
    Test.assert(resolved != null);
    Test.assert((resolved as Dictionary)[:adjusted]);
    var selected = (resolved as Dictionary)[:utc] as Number;
    var selectedInfo = Toybox.Time.Gregorian.info(new Toybox.Time.Moment(selected), Toybox.Time.FORMAT_SHORT);
    var previousInfo = Toybox.Time.Gregorian.info(new Toybox.Time.Moment(selected - 60), Toybox.Time.FORMAT_SHORT);
    Test.assert(CalendarMath.wallOrder(selectedInfo, fields) > 0);
    Test.assert(CalendarMath.wallOrder(previousInfo, fields) <= 0);
    return true;
}

(:test)
function calendarFallBackTieChoosesEarlierInstant(logger as Test.Logger) as Boolean {
    var fields = {:year=>2026, :month=>11, :day=>1, :hour=>1, :minute=>30, :second=>0};
    var halfway = CalendarMath.utc(2026, 11, 1, 6, 0, 0);
    var resolved = CalendarMath.resolveLocalWall(fields, halfway);
    Test.assert(resolved != null);
    Test.assert(!(resolved as Dictionary)[:adjusted]);
    Test.assertEqual(CalendarMath.utc(2026, 11, 1, 5, 30, 0), (resolved as Dictionary)[:utc]);
    return true;
}

(:test)
function backgroundMirrorStaysReducedAtLimits(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 1, 1, 9, 0);
    for (var cycle = 0; cycle < 25; cycle += 1) {
        ScheduleModel.insertOrReplace(state, start + (cycle * 100));
    }
    var active = state[:active] as Dictionary;
    for (var interval = 0; interval < ScheduleModel.MAX_TEMP_INTERVALS; interval += 1) {
        var outUtc = active[:insertionUtc] + 1000 + (interval * 20);
        Test.assert(ScheduleModel.startTemporaryOut(active, outUtc));
        if (interval < ScheduleModel.MAX_TEMP_INTERVALS - 1) {
            Test.assert(ScheduleModel.endTemporaryOut(active, outUtc + 10));
        }
    }
    Test.assertEqual(ScheduleModel.MAX_HISTORY, (state[:history] as Array).size());
    Test.assert(RingStore.save(state));
    var reduced = RingStore.loadBackground();
    Test.assert(reduced[:history] == null);
    Test.assertEqual(1,
        (((reduced[:active] as Dictionary)[:temporaryOut]) as Array).size());
    Test.assertEqual(1,
        ((((RingStore.loadGlance())[:active] as Dictionary)[:temporaryOut]) as Array).size());
    return true;
}
