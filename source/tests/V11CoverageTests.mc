import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

(:test)
function v11EarlyOnTimeLateInsertionsAnchorRemoval(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var first = ScheduleModel.insertOrReplace(state, testWall(2026, 1, 1, 9, 0));
    Test.assert(ScheduleModel.recordRemoval(first, first[:removeDueUtc], state[:regimen]));
    var due = first[:insertDueUtc];
    var offsets = [-86400, 0, 2 * 86400];
    for (var i = 0; i < offsets.size(); i += 1) {
        var copy = ScheduleModel.defaultState();
        var prior = ScheduleModel.insertOrReplace(copy, testWall(2026, 1, 1, 9, 0));
        Test.assert(ScheduleModel.recordRemoval(prior, prior[:removeDueUtc], copy[:regimen]));
        var actual = due + offsets[i];
        var active = ScheduleModel.insertOrReplace(copy, actual);
        Test.assertEqual(actual + offsets[i] - offsets[i], active[:insertionUtc]);
        Test.assertEqual(CalendarMath.addLocalCalendarDays(actual, 21)[:utc], active[:removeDueUtc]);
        Test.assertEqual(offsets[i], active[:insertionDeltaSeconds]);
    }
    return true;
}

(:test)
function v11EventDeltaFormattingCoversMinuteHourDayAndOnTime(logger as Test.Logger) as Boolean {
    Test.assertEqual(Ui.s(Rez.Strings.OnTime), Ui.eventDelta(59, false));
    Test.assertEqual("1m early", Ui.eventDelta(-60, false));
    Test.assertEqual("5h 10m late", Ui.eventDelta((5 * 3600) + 600, false));
    Test.assertEqual("2d 3h early", Ui.eventDelta(-((2 * 86400) + (3 * 3600)), false));
    Test.assertEqual(Ui.s(Rez.Strings.FirstCycle), Ui.eventDelta(null, true));
    return true;
}

(:test)
function v11CompactConfirmationTimestampOmitsWeekday(logger as Test.Logger) as Boolean {
    var at = testWall(2026, 9, 14, 17, 26);
    Test.assertEqual("14 Sep", Ui.compactDate(at));
    Test.assertEqual("14 Sep · 5:26 PM", Ui.compactTimestamp(at, 12));
    Test.assertEqual("14 Sep · 17:26", Ui.compactTimestamp(at, 24));
    return true;
}

(:test)
function v11DatePairsKeepSeparatorAndCompactLongestDates(logger as Test.Logger) as Boolean {
    var inUtc = testWall(2026, 9, 30, 9, 0);
    var outUtc = testWall(2026, 10, 21, 9, 0);
    Test.assertEqual("In Wed 30 Sep · Out Wed 21 Oct", Ui.datePairText(inUtc, outUtc, false));
    Test.assertEqual("In 30 Sep · Out 21 Oct", Ui.datePairText(inUtc, outUtc, true));
    var parts = Ui.datePairParts(inUtc, outUtc, true);
    Test.assertEqual("In 30 Sep", parts[0]);
    Test.assertEqual("Out 21 Oct", parts[1]);
    Test.assertEqual("In 30 Sep · Out —", Ui.datePairText(inUtc, null, true));
    return true;
}

(:test)
function v11WarningCopySplitsAtSentenceBoundaries(logger as Test.Logger) as Boolean {
    var free = Ui.sentences("Insert now. Use backup 7 days.");
    Test.assertEqual(2, free.size());
    Test.assertEqual("Insert now.", free[0]);
    Test.assertEqual("Use backup 7 days.", free[1]);
    var temporary = Ui.sentences("Out over 3h. Reinsert now. Use backup 7 days.");
    Test.assertEqual(3, temporary.size());
    Test.assertEqual("Out over 3h.", temporary[0]);
    Test.assertEqual("Reinsert now.", temporary[1]);
    Test.assertEqual("Use backup 7 days.", temporary[2]);
    return true;
}

(:test)
function v11HistoryPrependsActiveAndClearPreservesIt(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var first = ScheduleModel.insertOrReplace(state, testWall(2026, 2, 1, 9, 0));
    ScheduleModel.insertOrReplace(state, first[:removeDueUtc] + 3600);
    var entries = HistoryUi.entries(state);
    Test.assertEqual(2, entries.size());
    Test.assert((entries[0] as Lang.Dictionary)[:active]);
    Test.assertEqual((state[:active] as Lang.Dictionary)[:cycleId],
        ((entries[0] as Lang.Dictionary)[:cycle] as Lang.Dictionary)[:cycleId]);
    var active = state[:active];
    state[:history] = [];
    Test.assertEqual(active, state[:active]);
    Test.assertEqual(1, HistoryUi.entries(state).size());
    return true;
}

(:test)
function v11HistoryVarianceAndScrollBoundsAreCompact(logger as Test.Logger) as Boolean {
    var cycle = ScheduleModel.newCycle(25, testWall(2026, 8, 20, 9, 0),
        ScheduleModel.defaultRegimen());
    cycle[:removalDeltaSeconds] = 12 * CalendarMath.SECONDS_PER_DAY;
    cycle[:nextInsertionDeltaSeconds] = 12 * CalendarMath.SECONDS_PER_DAY;
    Test.assertEqual("Removed 12d late · Inserted 12d late",
        HistoryUi.listVariance(cycle, false));
    var varianceParts = HistoryUi.varianceParts(cycle, false);
    Test.assertEqual(2, varianceParts.size());
    Test.assertEqual("Removed 12d late", varianceParts[0]);
    Test.assertEqual("Inserted 12d late", varianceParts[1]);
    cycle[:removalDeltaSeconds] = 0;
    cycle[:nextInsertionDeltaSeconds] = 0;
    Test.assertEqual(Ui.s(Rez.Strings.OnTime), HistoryUi.listVariance(cycle, false));
    Test.assertEqual(1, HistoryUi.varianceParts(cycle, false).size());
    Test.assertEqual(0, HistoryUi.boundedSelection(-1, 25));
    Test.assertEqual(24, HistoryUi.boundedSelection(99, 25));
    Test.assertEqual(0, HistoryUi.topForSelection(0, 25));
    Test.assertEqual(23, HistoryUi.topForSelection(24, 25));
    return true;
}

(:test)
function v11UpcomingRingInRingFreeZeroDayAndScrollBounds(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 2, 1, 9, 0);
    var regimen = ScheduleModel.defaultRegimen();
    var ringIn = ScheduleModel.newCycle(4, start, regimen);
    var rows = ScheduleModel.projectUpcoming(ringIn, regimen, 6, start);
    Test.assertEqual(CalendarMath.addLocalCalendarDays(ringIn[:removeDueUtc], 7)[:utc],
        (rows[1] as Lang.Dictionary)[:inUtc]);
    var removed = ringIn[:removeDueUtc] - 86400;
    Test.assert(ScheduleModel.recordRemoval(ringIn, removed, regimen));
    rows = ScheduleModel.projectUpcoming(ringIn, regimen, 6, start);
    Test.assertEqual(removed, (rows[0] as Lang.Dictionary)[:outUtc]);
    Test.assertEqual(ringIn[:insertDueUtc], (rows[1] as Lang.Dictionary)[:inUtc]);
    regimen[:daysOut] = 0;
    ScheduleModel.recomputeForRegimen(ringIn, regimen);
    rows = ScheduleModel.projectUpcoming(ringIn, regimen, 6, start);
    Test.assertEqual(removed, (rows[1] as Lang.Dictionary)[:inUtc]);
    Test.assertEqual(0, UpcomingUi.boundedTopIndex(-9));
    Test.assertEqual(3, UpcomingUi.boundedTopIndex(9));
    return true;
}

(:test)
function v11UpcomingUpdatesAfterEditsAndDurationChanges(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var active = ScheduleModel.newCycle(1, testWall(2026, 4, 1, 9, 0), regimen);
    var original = ScheduleModel.projectUpcoming(active, regimen, 6, active[:insertionUtc]);
    regimen[:daysIn] = 28;
    ScheduleModel.recomputeForRegimen(active, regimen);
    var longer = ScheduleModel.projectUpcoming(active, regimen, 6, active[:insertionUtc]);
    Test.assert((original[1] as Lang.Dictionary)[:inUtc] != (longer[1] as Lang.Dictionary)[:inUtc]);
    var edited = ScheduleModel.rebuildForInsertion(active, active[:insertionUtc] + 3600, regimen) as Lang.Dictionary;
    var shifted = ScheduleModel.projectUpcoming(edited, regimen, 6, edited[:insertionUtc]);
    Test.assertEqual((longer[1] as Lang.Dictionary)[:inUtc] + 3600,
        (shifted[1] as Lang.Dictionary)[:inUtc]);
    var removal = edited[:removeDueUtc] - 7200;
    Test.assert(ScheduleModel.recordRemoval(edited, removal, regimen));
    var removedRows = ScheduleModel.projectUpcoming(edited, regimen, 6, edited[:insertionUtc]);
    Test.assertEqual(CalendarMath.addLocalCalendarDays(removal, regimen[:daysOut])[:utc],
        (removedRows[1] as Lang.Dictionary)[:inUtc]);
    return true;
}

(:test)
function v11UpcomingCalendarBoundariesStayLocal(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var leap = ScheduleModel.newCycle(1, testWall(2028, 2, 8, 23, 59), regimen);
    assertLocalDateTime(leap[:removeDueUtc], 2028, 2, 29, 23, 59);
    var year = ScheduleModel.newCycle(2, testWall(2026, 12, 20, 9, 0), regimen);
    assertLocalDateTime(year[:removeDueUtc], 2027, 1, 10, 9, 0);
    return true;
}

(:test)
function v11ReminderDefaultsAndIndependentTimes(logger as Test.Logger) as Boolean {
    var reminders = ScheduleModel.defaultReminders();
    Test.assertEqual(9, reminders[:reminder1Hour]);
    Test.assertEqual(20, reminders[:reminder2Hour]);
    Test.assert(!reminders[:reminder2Enabled]);
    Test.assert(reminders[:dayBeforeEnabled]);
    var due = testWall(2026, 6, 22, 9, 0);
    var before = ReminderPolicy.reminderAt(due, -1, reminders[:reminder1Hour], reminders[:reminder1Minute]);
    reminders[:reminder2Hour] = 17;
    Test.assertEqual(before, ReminderPolicy.reminderAt(due, -1, reminders[:reminder1Hour], reminders[:reminder1Minute]));
    reminders[:reminder1Hour] = 7;
    Test.assert(before != ReminderPolicy.reminderAt(due, -1, reminders[:reminder1Hour], reminders[:reminder1Minute]));
    return true;
}

(:test)
function v11Reminder2OffSuppressesOnlySecondSlot(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    var active = ScheduleModel.newCycle(1, testWall(2026, 6, 1, 9, 0), regimen);
    var ledger = v11LedgerFor(active, "remove", active[:removeDueUtc]);
    ledger[:dayOf1Sent] = true;
    var atSecond = testWall(2026, 6, 22, 21, 0);
    var off = ReminderPolicy.evaluate(atSecond, active, regimen, reminders, ledger);
    Test.assertEqual(:overdue, off[:kind]);
    reminders[:reminder2Enabled] = true;
    var on = ReminderPolicy.evaluate(atSecond, active, regimen, reminders, ledger);
    Test.assertEqual(:dayOf, on[:kind]);
    Test.assertEqual(2, on[:reminderSlot]);
    return true;
}

(:test)
function v11Reminder2DoesNotRepeatAfterDisableEnable(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    reminders[:reminder2Enabled] = true;
    var active = ScheduleModel.newCycle(1, testWall(2026, 6, 1, 9, 0), regimen);
    var ledger = v11LedgerFor(active, "remove", active[:removeDueUtc]);
    ledger[:dayOf1Sent] = true;
    var now = testWall(2026, 6, 22, 21, 0);
    var selected = ReminderPolicy.evaluate(now, active, regimen, reminders, ledger);
    ReminderPolicy.markSent(ledger, selected);
    reminders[:reminder2Enabled] = false;
    reminders[:reminder2Enabled] = true;
    Test.assertEqual(:overdue, ReminderPolicy.evaluate(now + 60, active, regimen, reminders, ledger)[:kind]);
    return true;
}

(:test)
function v11ThresholdThenDayOfThenOverdueProgression(logger as Test.Logger) as Boolean {
    var regimen = {:daysIn=>35, :daysOut=>7};
    var reminders = ScheduleModel.defaultReminders();
    reminders[:reminder1Hour] = 8;
    var active = ScheduleModel.newCycle(1, testWall(2026, 5, 1, 9, 0), regimen);
    var now = active[:removeDueUtc] + 3600;
    var ledger = v11LedgerFor(active, "remove", active[:removeDueUtc]);
    var warning = ReminderPolicy.evaluate(now, active, regimen, reminders, ledger);
    Test.assertEqual(:beyondFourWeeks, warning[:kind]);
    ReminderPolicy.markSent(ledger, warning);
    var dayOf = ReminderPolicy.evaluate(now, active, regimen, reminders, ledger);
    Test.assertEqual(:dayOf, dayOf[:kind]);
    ReminderPolicy.markSent(ledger, dayOf);
    Test.assertEqual(:overdue, ReminderPolicy.evaluate(now, active, regimen, reminders, ledger)[:kind]);
    return true;
}

(:test)
function v11NotificationCopyCoversEveryKindAndBody(logger as Test.Logger) as Boolean {
    var service = new RingServiceDelegate();
    var due = testWall(2026, 9, 2, 9, 0);
    var tomorrow = ["Remove tomorrow", "Insert tomorrow", "Replace tomorrow"];
    var today = ["Remove ring", "Insert ring", "Replace ring"];
    var second = ["Still in — remove", "Still out — insert", "Still in — replace"];
    var overdueTitle = ["Remove now", "Insert now", "Replace ring"];
    for (var i = 0; i < 3; i += 1) {
        var before = service.notificationIds(5, i, due, 24, due - 1, 0);
        var dayOf = service.notificationIds(4, i, due, 24, due - 1, 1);
        var dayOf2 = service.notificationIds(4, i, due, 24, due - 1, 2);
        var overdue = service.notificationIds(3, i, due, 24, due + 100800, 0);
        Test.assertEqual(tomorrow[i], before[0]); Test.assertEqual("Wed 2 Sep · 09:00", before[1]); Test.assert(before[2] == null);
        Test.assertEqual(today[i], dayOf[0]); Test.assertEqual("Due today · 09:00", dayOf[1]); Test.assert(dayOf[2] == null);
        Test.assertEqual(second[i], dayOf2[0]); Test.assertEqual("Due 09:00 today", dayOf2[1]); Test.assert(dayOf2[2] != null);
        Test.assertEqual(overdueTitle[i], overdue[0]); Test.assertEqual("1d 4h late · due Wed 2 Sep", overdue[1]); Test.assert(overdue[2] == null);
    }
    var temp = service.notificationIds(1, 0, due, 24, due + 11400, 0);
    Test.assertEqual("Put ring back", temp[0]); Test.assertEqual("Out 3h 10m", temp[1]); Test.assertEqual("Backup advised — see detail.", temp[2]);
    var free = service.notificationIds(0, 1, due, 24, due + 86400, 0);
    Test.assertEqual("Insert ring", free[0]); Test.assertEqual("Break over 7 days · 1d late", free[1]); Test.assertEqual("Backup advised.", free[2]);
    var longIn = service.notificationIds(2, 0, due, 24, due + 86400, 0);
    Test.assertEqual("Replace ring", longIn[0]); Test.assertEqual("In over 4 weeks · 1d over", longIn[1]); Test.assertEqual("Backup advised.", longIn[2]);
    return true;
}

(:test)
function v11V1AndV2MigrationProduceEquivalentV3(logger as Test.Logger) as Boolean {
    clearRound2Storage();
    var state = ScheduleModel.defaultState();
    ScheduleModel.insertOrReplace(state, testWall(2026, 7, 1, 9, 0));
    var v2 = legacyV2Fixture(state);
    Storage.setValue(RingStore.STATE_KEY, v2);
    var fromV2 = RingStore.load();
    clearRound2Storage();
    var v1 = [1];
    for (var i = 1; i <= 8; i += 1) { v1.add(v2[i]); }
    Storage.setValue(RingStore.STATE_KEY, v1);
    var fromV1 = RingStore.load();
    Test.assertEqual((fromV2[:active] as Lang.Dictionary)[:removeDueUtc],
        (fromV1[:active] as Lang.Dictionary)[:removeDueUtc]);
    Test.assertEqual(SettingsBridge.configFromState(fromV2).toString(), SettingsBridge.configFromState(fromV1).toString());
    clearRound2Storage();
    return true;
}
