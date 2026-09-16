// Review 3 adversarial tests, exactly as run with their local helpers.
// Time zone: America/New_York
// Reviewed HEAD: 916b41b74fd06163aea301a0ddee678be52c1144
// Expected failures at that HEAD:
// - review3SpringGapUsesFirstValidMinute
// - review3SecondTemporaryOutGetsItsOwnFirstWarning
// - review3UpcomingFutureRowsAreNotPast

import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

// Independent review-only fixtures. The legacy arrays below reproduce the
// positional schema-2 codec shipped by the v1.0 source at commit 87bf813.

(:testhelper)
function review3WallArray(utc as Lang.Number) as Lang.Array {
    var w = CalendarMath.localFields(utc);
    return [w[:year], w[:month], w[:day], w[:hour], w[:minute], w[:second]];
}

(:testhelper)
function review3LegacyHistory(id as Lang.Number, inserted as Lang.Number,
                              removed as Lang.Number, nextInserted as Lang.Number) as Lang.Array {
    return [id, inserted, removed, nextInserted, "replaced", 21, 7, [], [0, 0]];
}

(:testhelper)
function review3LegacyActive(id as Lang.Number, inserted as Lang.Number, removal,
                             intervals as Lang.Array, plannedOverride) as Lang.Array {
    var removeDue = CalendarMath.addLocalCalendarDays(inserted, 21)[:utc];
    var scheduledInsertion = CalendarMath.addLocalCalendarDays(inserted, 28)[:utc];
    var label = CalendarMath.addLocalCalendarDays(inserted, 28)[:utc];
    var ceiling = removal == null ? null
        : CalendarMath.addLocalCalendarDays(removal as Lang.Number, 7)[:utc];
    var finalInsertion = scheduledInsertion;
    if (removal != null) {
        var fromRemoval = CalendarMath.addLocalCalendarDays(removal as Lang.Number, 7)[:utc];
        if (fromRemoval < finalInsertion) { finalInsertion = fromRemoval; }
        if ((ceiling as Lang.Number) < finalInsertion) { finalInsertion = ceiling; }
        if (plannedOverride != null && (plannedOverride as Lang.Number) < finalInsertion) {
            finalInsertion = plannedOverride;
        }
    }
    return [id, inserted, review3WallArray(inserted), removal,
        removal == null ? null : review3WallArray(removal as Lang.Number),
        removeDue, scheduledInsertion, label, ceiling, plannedOverride, null,
        intervals, finalInsertion, [0, 0]];
}

(:testhelper)
function review3LegacyCanonical(active as Lang.Array, nextCycleId as Lang.Number,
                                revision as Lang.Number, historyCount as Lang.Number,
                                chunkCount as Lang.Number) as Lang.Array {
    var action = active[3] == null ? "remove:" + active[5].toString()
        : "insert:" + active[12].toString();
    return [2, nextCycleId, 3, active, [21, 7], [7, 45, 6, true, false, 24],
        [active[0], action, true, true, 2, 0, true, true], [],
        ["2025-11-03T09:00", "2025-11-03T09:00", 10, 11, null, null,
            [7, 45, 21, 7, 6, true, false, 24],
            [7, 45, 21, 7, 6, true, false, 24]],
        revision, historyCount, chunkCount];
}

(:testhelper)
function review3ClearStorage() as Void {
    clearReviewStorage();
    Storage.deleteValue(RingStore.RECOVERY_KEY);
}

(:test)
function review3DstExistingWallMatrixNewYork(logger as Test.Logger) as Boolean {
    // Spring-forward day: 01:30 exists.
    var spring130 = testWall(2027, 3, 14, 1, 30);
    var springCycle130 = ScheduleModel.newCycle(1, spring130, {:daysIn=>21, :daysOut=>7});
    assertLocalDateTime(springCycle130[:removeDueUtc], 2027, 4, 4, 1, 30);
    assertLocalDateTime(springCycle130[:labelFourWeekUtc], 2027, 4, 11, 1, 30);
    var beforeSpring21 = ScheduleModel.newCycle(2, testWall(2027, 2, 21, 1, 30),
        {:daysIn=>21, :daysOut=>7});
    var beforeSpring28 = ScheduleModel.newCycle(3, testWall(2027, 2, 14, 1, 30),
        {:daysIn=>21, :daysOut=>7});
    assertLocalDateTime(beforeSpring21[:removeDueUtc], 2027, 3, 14, 1, 30);
    assertLocalDateTime(beforeSpring28[:labelFourWeekUtc], 2027, 3, 14, 1, 30);

    // Fall-back day and insertions 21/28 days before it retain both requested
    // wall times. 02:30 is after the fold; 01:30 resolves per the earlier/tie rule.
    var fall130 = testWall(2026, 11, 1, 1, 30);
    var fall230 = testWall(2026, 11, 1, 2, 30);
    assertLocalDateTime(ScheduleModel.newCycle(5, fall130, {:daysIn=>21, :daysOut=>7})[:removeDueUtc],
        2026, 11, 22, 1, 30);
    assertLocalDateTime(ScheduleModel.newCycle(6, fall230, {:daysIn=>21, :daysOut=>7})[:removeDueUtc],
        2026, 11, 22, 2, 30);
    var beforeFall21a = ScheduleModel.newCycle(7, testWall(2026, 10, 11, 1, 30), {:daysIn=>21, :daysOut=>7});
    var beforeFall21b = ScheduleModel.newCycle(8, testWall(2026, 10, 11, 2, 30), {:daysIn=>21, :daysOut=>7});
    var beforeFall28a = ScheduleModel.newCycle(9, testWall(2026, 10, 4, 1, 30), {:daysIn=>21, :daysOut=>7});
    var beforeFall28b = ScheduleModel.newCycle(10, testWall(2026, 10, 4, 2, 30), {:daysIn=>21, :daysOut=>7});
    assertLocalDateTime(beforeFall21a[:removeDueUtc], 2026, 11, 1, 1, 30);
    assertLocalDateTime(beforeFall21b[:removeDueUtc], 2026, 11, 1, 2, 30);
    assertLocalDateTime(beforeFall28a[:labelFourWeekUtc], 2026, 11, 1, 1, 30);
    assertLocalDateTime(beforeFall28b[:labelFourWeekUtc], 2026, 11, 1, 2, 30);
    return true;
}

(:test)
function review3SpringGapUsesFirstValidMinute(logger as Test.Logger) as Boolean {
    // 02:30 does not exist in New York on this date. A selected wall tuple and
    // recurrences landing on it must all advance to 03:00, the first valid minute.
    var direct = CalendarMath.wallToUtc({:year=>2027, :month=>3, :day=>14,
        :hour=>2, :minute=>30, :second=>0}, System.getClockTime().timeZoneOffset);
    Test.assert(direct != null && direct[:adjusted]);
    var from21 = ScheduleModel.newCycle(3, testWall(2027, 2, 21, 2, 30),
        {:daysIn=>21, :daysOut=>7});
    var from28 = ScheduleModel.newCycle(4, testWall(2027, 2, 14, 2, 30),
        {:daysIn=>21, :daysOut=>7});
    var directFields = CalendarMath.localFields(direct[:utc]);
    var removeFields = CalendarMath.localFields(from21[:removeDueUtc]);
    var labelFields = CalendarMath.localFields(from28[:labelFourWeekUtc]);
    System.println("REVIEW3_SPRING_GAP_DIRECT=" + directFields[:hour] + ":" + directFields[:minute]
        + ",REMOVE=" + removeFields[:hour] + ":" + removeFields[:minute]
        + ",LABEL=" + labelFields[:hour] + ":" + labelFields[:minute]);
    Test.assert(directFields[:hour] == 3 && directFields[:minute] == 0
        && removeFields[:hour] == 3 && removeFields[:minute] == 0
        && labelFields[:hour] == 3 && labelFields[:minute] == 0);
    return true;
}

(:test)
function review3LeapMidnightAndTravelAuthority(logger as Test.Logger) as Boolean {
    var leap = ScheduleModel.newCycle(1, testWall(2028, 2, 8, 0, 0), {:daysIn=>21, :daysOut=>7});
    assertLocalDateTime(leap[:removeDueUtc], 2028, 2, 29, 0, 0);
    Test.assertEqual(leap[:removeDueUtc], ScheduleModel.deriveStatus(leap[:removeDueUtc], leap,
        {:daysIn=>21, :daysOut=>7})[:actionDueUtc]);
    Test.assertEqual(:ringIn, ScheduleModel.deriveStatus(leap[:removeDueUtc] - 1, leap,
        {:daysIn=>21, :daysOut=>7})[:phase]);
    Test.assertEqual(:overdue, ScheduleModel.deriveStatus(leap[:removeDueUtc], leap,
        {:daysIn=>21, :daysOut=>7})[:phase]);
    // The persisted UTC deadline is the authority used by status/projection;
    // no display-time local conversion can mutate it during travel.
    var persisted = leap[:removeDueUtc];
    Ui.dateOnly(persisted);
    Test.assertEqual(persisted, leap[:removeDueUtc]);
    return true;
}

(:test)
function review3SecondTemporaryOutGetsItsOwnFirstWarning(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    var active = ScheduleModel.newCycle(1, testWall(2026, 9, 1, 9, 0), regimen);
    var ledger = ScheduleModel.defaultLedger();
    var firstOut = active[:insertionUtc] + 3600;
    Test.assert(ScheduleModel.startTemporaryOut(active, firstOut));
    var first = ReminderPolicy.evaluate(firstOut + 10801, active, regimen, reminders, ledger);
    Test.assertEqual(:tempOver3h, first[:kind]);
    ReminderPolicy.markSent(ledger, first);
    Test.assert(ScheduleModel.endTemporaryOut(active, firstOut + 10900));
    var secondOut = firstOut + 20000;
    Test.assert(ScheduleModel.startTemporaryOut(active, secondOut));
    var second = ReminderPolicy.evaluate(secondOut + 10801, active, regimen, reminders, ledger);
    Test.assert(second != null);
    Test.assertEqual(:tempOver3h, second[:kind]);
    Test.assertEqual(0, second[:slot]);
    return true;
}

(:test)
function review3ReminderTimesDoNotRefireAndInsertionGetsBoth(logger as Test.Logger) as Boolean {
    var regimen = {:daysIn=>21, :daysOut=>3};
    var reminders = ScheduleModel.defaultReminders();
    reminders[:reminder2Enabled] = true;
    var active = ScheduleModel.newCycle(3, testWall(2026, 9, 1, 12, 0), regimen);
    Test.assert(ScheduleModel.recordRemoval(active, active[:removeDueUtc], regimen));
    var due = active[:insertDueUtc];
    var ledger = ScheduleModel.defaultLedger();
    var morning = ReminderPolicy.evaluate(ReminderPolicy.reminderAt(due, 0, 9, 0),
        active, regimen, reminders, ledger);
    Test.assertEqual(1, morning[:reminderSlot]);
    ReminderPolicy.markSent(ledger, morning);
    reminders[:reminder1Hour] = 15;
    Test.assertEqual(2, ReminderPolicy.evaluate(ReminderPolicy.reminderAt(due, 0, 20, 0),
        active, regimen, reminders, ledger)[:reminderSlot]);
    var evening = ReminderPolicy.evaluate(ReminderPolicy.reminderAt(due, 0, 20, 0),
        active, regimen, reminders, ledger);
    ReminderPolicy.markSent(ledger, evening);
    reminders[:reminder2Hour] = 22;
    Test.assertEqual(:overdue, ReminderPolicy.evaluate(ReminderPolicy.reminderAt(due, 0, 22, 1),
        active, regimen, reminders, ledger)[:kind]);
    return true;
}

(:test)
function review3RealV10RingInOpenTempAndTwentyFourHistoryMigrates(logger as Test.Logger) as Boolean {
    review3ClearStorage();
    var history = [];
    var inserted = testWall(2024, 1, 1, 9, 0);
    for (var i = 0; i < 24; i += 1) {
        var removed = CalendarMath.addLocalCalendarDays(inserted, 21)[:utc];
        var nextInserted = CalendarMath.addLocalCalendarDays(removed, 7)[:utc];
        history.add(review3LegacyHistory(i + 1, inserted, removed, nextInserted));
        inserted = nextInserted;
    }
    var openOut = CalendarMath.addLocalCalendarDays(inserted, 5)[:utc];
    var override = CalendarMath.addLocalCalendarDays(inserted, 26)[:utc];
    var active = review3LegacyActive(25, inserted, null,
        [[openOut, null, 1, null, null]], override);
    var revision = 8;
    Storage.setValue(RingStore.STATE_KEY, review3LegacyCanonical(active, 26, revision, 24, 2));
    var first = [];
    var second = [];
    for (var h = 0; h < 24; h += 1) { (h < 12 ? first : second).add(history[h]); }
    Storage.setValue(RingStore.HISTORY_A0_KEY, [2, revision, first]);
    Storage.setValue(RingStore.HISTORY_B0_KEY, [2, revision, second]);

    var loaded = RingStore.load();
    Test.assert(ScheduleModel.validState(loaded));
    Test.assertEqual(24, (loaded[:history] as Lang.Array).size());
    var migrated = loaded[:active] as Lang.Dictionary;
    Test.assert(ScheduleModel.tempOpen(migrated) != null);
    Test.assertEqual(override, active[9]);
    Test.assert(migrated[:plannedOverrideUtc] == null);
    Test.assertEqual(inserted, migrated[:insertionUtc]);
    Test.assert(migrated[:insertionPlanUtc] != null);
    Test.assertEqual(7, (loaded[:reminders] as Lang.Dictionary)[:reminder1Hour]);
    Test.assertEqual(45, (loaded[:reminders] as Lang.Dictionary)[:reminder1Minute]);
    Test.assertEqual(12, ((loaded[:settingsSync] as Lang.Dictionary)[:configSnapshot] as Lang.Array).size());
    var migratedLedger = loaded[:reminderLedger] as Lang.Dictionary;
    Test.assert(migratedLedger[:dayOf1Sent] && migratedLedger[:dayOf2Sent]);
    Test.assertEqual(1, ((loaded[:history] as Lang.Array)[0] as Lang.Dictionary)[:cycleId]);
    Test.assertEqual(24, ((loaded[:history] as Lang.Array)[23] as Lang.Dictionary)[:cycleId]);
    Test.assertEqual(3, (Storage.getValue(RingStore.STATE_KEY) as Lang.Array)[0]);
    review3ClearStorage();
    return true;
}

(:test)
function review3RealV10LateRemovalDropsMinimumAndOverride(logger as Test.Logger) as Boolean {
    review3ClearStorage();
    var inserted = testWall(2026, 6, 1, 9, 0);
    var removalDue = CalendarMath.addLocalCalendarDays(inserted, 21)[:utc];
    var removed = CalendarMath.addLocalCalendarDays(removalDue, 2)[:utc];
    var override = CalendarMath.addLocalCalendarDays(inserted, 27)[:utc];
    var active = review3LegacyActive(1, inserted, removed, [], override);
    Storage.setValue(RingStore.STATE_KEY, review3LegacyCanonical(active, 2, 3, 0, 0));
    var loaded = RingStore.load();
    Test.assert(ScheduleModel.validState(loaded));
    var migrated = loaded[:active] as Lang.Dictionary;
    var expected = CalendarMath.addLocalCalendarDays(removed, 7)[:utc];
    Test.assertEqual(expected, migrated[:insertDueUtc]);
    Test.assert(expected > active[6]);
    Test.assert(expected > override);
    Test.assertEqual(:ringFree, ScheduleModel.deriveStatus(removed + 1, migrated,
        loaded[:regimen] as Lang.Dictionary)[:phase]);
    Test.assertEqual(removed - removalDue, migrated[:removalDeltaSeconds]);
    review3ClearStorage();
    return true;
}

(:test)
function review3UpcomingFutureRowsAreNotPast(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var active = ScheduleModel.newCycle(1, testWall(2026, 6, 1, 9, 0), regimen);
    var now = testWall(2026, 7, 20, 9, 0);
    var rows = ScheduleModel.projectUpcoming(active, regimen, 6, now);
    // Row 1 is explicitly Current and may contain actual/past dates. Rows 2-6
    // are presented as upcoming cycles and must not begin in the past.
    for (var i = 1; i < rows.size(); i += 1) {
        Test.assert((rows[i] as Lang.Dictionary)[:inUtc] >= now);
    }
    return true;
}
