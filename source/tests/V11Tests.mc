import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

(:testhelper)
function v11LedgerFor(active as Lang.Dictionary, action as Lang.String,
                      due as Lang.Number) as Lang.Dictionary {
    var ledger = ScheduleModel.defaultLedger();
    ledger[:cycleId] = active[:cycleId];
    ledger[:actionKey] = action + ":" + due.toString();
    return ledger;
}

(:testhelper)
function legacyV2Fixture(state as Lang.Dictionary) as Lang.Array {
    var a = state[:active] as Lang.Dictionary;
    var r = state[:reminders] as Lang.Dictionary;
    var g = state[:regimen] as Lang.Dictionary;
    var wall = a[:insertionWall] as Lang.Dictionary;
    var legacyActive = [a[:cycleId], a[:insertionUtc],
        [wall[:year], wall[:month], wall[:day], wall[:hour], wall[:minute], wall[:second]],
        null, null, a[:removeDueUtc],
        CalendarMath.addLocalCalendarDays(a[:insertionUtc], g[:daysIn] + g[:daysOut])[:utc],
        a[:labelFourWeekUtc], null, null, a[:dstAdjustment], [],
        CalendarMath.addLocalCalendarDays(a[:insertionUtc], g[:daysIn] + g[:daysOut])[:utc], [0, 0]];
    return [2, state[:nextCycleId], state[:setupStep], legacyActive,
        [g[:daysIn], g[:daysOut]],
        [r[:reminder1Hour], r[:reminder1Minute], r[:overdueRepeatHours],
            r[:vibrationEnabled], r[:soundEnabled], r[:clockFormat]],
        [a[:cycleId], "remove:" + a[:removeDueUtc].toString(), false, true,
            null, null, false, false], [],
        ["", "", 0, 0, null, null,
            [r[:reminder1Hour], r[:reminder1Minute], g[:daysIn], g[:daysOut],
                r[:overdueRepeatHours], r[:vibrationEnabled], r[:soundEnabled], r[:clockFormat]], null],
        0, 0, 0];
}

(:test)
function v11ActualRemovalAnchorsZeroThreeSevenDays(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 1, 9, 0);
    var offsets = [-2, 0, 2];
    var daysOut = [0, 3, 7];
    for (var d = 0; d < daysOut.size(); d += 1) {
        var regimen = {:daysIn=>21, :daysOut=>daysOut[d]};
        for (var i = 0; i < offsets.size(); i += 1) {
            var active = ScheduleModel.newCycle(1, start, regimen);
            var removed = CalendarMath.addLocalCalendarDays(active[:removeDueUtc], offsets[i])[:utc];
            Test.assert(ScheduleModel.recordRemoval(active, removed, regimen));
            Test.assertEqual(CalendarMath.addLocalCalendarDays(removed, daysOut[d])[:utc],
                active[:insertDueUtc]);
            Test.assertEqual(removed - active[:removeDueUtc], active[:removalDeltaSeconds]);
        }
    }
    return true;
}

(:test)
function v11InsertionAnchorsNextRemovalAndBothCycleDeltas(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var first = testWall(2026, 9, 1, 9, 0);
    var old = ScheduleModel.insertOrReplace(state, first);
    Test.assert(ScheduleModel.recordRemoval(old, old[:removeDueUtc], state[:regimen]));
    var due = old[:insertDueUtc];
    var inserted = due + 3600;
    var current = ScheduleModel.insertOrReplace(state, inserted);
    Test.assertEqual(due, current[:insertionPlanUtc]);
    Test.assertEqual(3600, current[:insertionDeltaSeconds]);
    Test.assertEqual(CalendarMath.addLocalCalendarDays(inserted, 21)[:utc], current[:removeDueUtc]);
    var archived = (state[:history] as Lang.Array)[0] as Lang.Dictionary;
    Test.assertEqual(3600, archived[:nextInsertionDeltaSeconds]);
    return true;
}

(:test)
function v11EditsRecomputeOnlyDependentAnchors(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var start = testWall(2026, 9, 1, 9, 0);
    var active = ScheduleModel.newCycle(1, start, regimen);
    var removed = testWall(2026, 9, 23, 10, 0);
    Test.assert(ScheduleModel.recordRemoval(active, removed, regimen));
    var insertionDue = active[:insertDueUtc];
    var rebuilt = ScheduleModel.rebuildForInsertion(active, start + 3600, regimen) as Lang.Dictionary;
    Test.assertEqual(insertionDue, rebuilt[:insertDueUtc]);
    Test.assertEqual(removed - rebuilt[:removeDueUtc], rebuilt[:removalDeltaSeconds]);
    var changedRemoval = removed + 7200;
    Test.assert(ScheduleModel.recordRemoval(rebuilt, changedRemoval, regimen));
    Test.assertEqual(CalendarMath.addLocalCalendarDays(changedRemoval, 7)[:utc], rebuilt[:insertDueUtc]);
    Test.assertEqual(CalendarMath.addLocalCalendarDays(changedRemoval, 7)[:utc], rebuilt[:ringFreeCeilingUtc]);
    return true;
}

(:test)
function v11WarningsAreStrictAndNeverMoveAction(logger as Test.Logger) as Boolean {
    var extended = {:daysIn=>35, :daysOut=>3};
    var start = testWall(2026, 9, 1, 9, 0);
    var active = ScheduleModel.newCycle(1, start, extended);
    var due = active[:removeDueUtc];
    Test.assert(!ScheduleModel.deriveStatus(active[:labelFourWeekUtc], active, extended)[:ringInOverFourWeeks]);
    var afterFour = ScheduleModel.deriveStatus(active[:labelFourWeekUtc] + 1, active, extended);
    Test.assert(afterFour[:ringInOverFourWeeks]);
    Test.assertEqual(due, afterFour[:actionDueUtc]);
    Test.assertEqual(:ringIn, afterFour[:phase]);
    Test.assert(ScheduleModel.recordRemoval(active, due, extended));
    var insertionDue = active[:insertDueUtc];
    Test.assert(!ScheduleModel.deriveStatus(active[:ringFreeCeilingUtc], active, extended)[:ringFreeOverSevenDays]);
    var afterSeven = ScheduleModel.deriveStatus(active[:ringFreeCeilingUtc] + 1, active, extended);
    Test.assert(afterSeven[:ringFreeOverSevenDays]);
    Test.assertEqual(insertionDue, afterSeven[:actionDueUtc]);
    return true;
}

(:test)
function v11UpcomingUsesActualCurrentAndSixRows(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var start = testWall(2026, 12, 15, 9, 0);
    var active = ScheduleModel.newCycle(8, start, regimen);
    var removed = active[:removeDueUtc] - 86400;
    Test.assert(ScheduleModel.recordRemoval(active, removed, regimen));
    var rows = ScheduleModel.projectUpcoming(active, regimen, 6, start);
    Test.assertEqual(6, rows.size());
    Test.assertEqual(start, (rows[0] as Lang.Dictionary)[:inUtc]);
    Test.assertEqual(removed, (rows[0] as Lang.Dictionary)[:outUtc]);
    Test.assert((rows[0] as Lang.Dictionary)[:isCurrent]);
    Test.assertEqual(active[:insertDueUtc], (rows[1] as Lang.Dictionary)[:inUtc]);
    Test.assertEqual(13, (rows[5] as Lang.Dictionary)[:cycleId]);
    return true;
}

(:test)
function v11ReminderSlotsDeduplicateAndConsumeMissedOlder(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    reminders[:reminder2Enabled] = true;
    var active = ScheduleModel.newCycle(2, testWall(2026, 9, 1, 12, 0), regimen);
    var due = active[:removeDueUtc];
    var ledger = v11LedgerFor(active, "remove", due);
    var morning = ReminderPolicy.evaluate(testWall(2026, 9, 22, 10, 0), active, regimen, reminders, ledger);
    Test.assertEqual(1, morning[:reminderSlot]);
    ReminderPolicy.markSent(ledger, morning);
    Test.assert(ledger[:dayOf1Sent]); Test.assert(!ledger[:dayOf2Sent]);
    var evening = ReminderPolicy.evaluate(testWall(2026, 9, 22, 21, 0), active, regimen, reminders, ledger);
    Test.assertEqual(2, evening[:reminderSlot]);
    ReminderPolicy.markSent(ledger, evening);
    Test.assert(ledger[:dayOf2Sent]);

    var missed = v11LedgerFor(active, "remove", due);
    var latest = ReminderPolicy.evaluate(testWall(2026, 9, 22, 21, 0), active, regimen, reminders, missed);
    Test.assertEqual(2, latest[:reminderSlot]);
    ReminderPolicy.markSent(missed, latest);
    Test.assert(missed[:dayOf1Sent] && missed[:dayOf2Sent]);
    return true;
}

(:test)
function v11EqualReminderTimesPostOnce(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    reminders[:reminder2Enabled] = true;
    reminders[:reminder2Hour] = reminders[:reminder1Hour];
    reminders[:reminder2Minute] = reminders[:reminder1Minute];
    var active = ScheduleModel.newCycle(1, testWall(2026, 9, 1, 12, 0), regimen);
    var ledger = ScheduleModel.defaultLedger();
    var selected = ReminderPolicy.evaluate(testWall(2026, 9, 22, 10, 0),
        active, regimen, reminders, ledger);
    ReminderPolicy.markSent(ledger, selected);
    Test.assert(ledger[:dayOf1Sent] && ledger[:dayOf2Sent]);
    Test.assert(ReminderPolicy.evaluate(testWall(2026, 9, 22, 10, 1),
        active, regimen, reminders, ledger) == null);
    return true;
}

(:test)
function v11DayOfAfterDueOutranksOverdue(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    reminders[:reminder1Hour] = 20;
    var active = ScheduleModel.newCycle(1, testWall(2026, 9, 1, 9, 0), regimen);
    var selected = ReminderPolicy.evaluate(testWall(2026, 9, 22, 21, 0),
        active, regimen, reminders, ScheduleModel.defaultLedger());
    Test.assertEqual(:dayOf, selected[:kind]);
    return true;
}

(:test)
function v11ValidationRejectsDerivedIdsReasonsAndDeltas(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var active = ScheduleModel.insertOrReplace(state, testWall(2026, 9, 1, 9, 0));
    active[:removeDueUtc] += 1;
    Test.assert(!ScheduleModel.validState(state));
    active[:removeDueUtc] -= 1;
    state[:nextCycleId] = active[:cycleId];
    Test.assert(!ScheduleModel.validState(state));
    state[:nextCycleId] = active[:cycleId] + 1;
    ScheduleModel.insertOrReplace(state, active[:removeDueUtc]);
    var history = state[:history] as Lang.Array;
    var first = history[0] as Lang.Dictionary;
    first[:closeReason] = "unknown";
    Test.assert(!ScheduleModel.validState(state));
    first[:closeReason] = "replaced";
    first[:nextInsertionDeltaSeconds] += 1;
    Test.assert(!ScheduleModel.validState(state));
    return true;
}

(:test)
function v11Schema2MigrationPreservesReminderAndMapsLedger(logger as Test.Logger) as Boolean {
    clearReviewStorage();
    var old = ScheduleModel.defaultState();
    var active = ScheduleModel.insertOrReplace(old, testWall(2026, 9, 1, 9, 0));
    var raw = legacyV2Fixture(old);
    Storage.setValue(RingStore.STATE_KEY, raw);
    var loaded = RingStore.load();
    var reminders = loaded[:reminders] as Lang.Dictionary;
    Test.assertEqual(9, reminders[:reminder1Hour]);
    Test.assertEqual(20, reminders[:reminder2Hour]);
    Test.assert(!reminders[:reminder2Enabled]);
    Test.assert(reminders[:dayBeforeEnabled]);
    var ledger = loaded[:reminderLedger] as Lang.Dictionary;
    Test.assert(ledger[:dayOf1Sent] && ledger[:dayOf2Sent]);
    Test.assert(loaded[:migrationNoticePending]);
    Test.assertEqual(3, (Storage.getValue(RingStore.STATE_KEY) as Lang.Array)[0]);
    Test.assertEqual(active[:removeDueUtc], (loaded[:active] as Lang.Dictionary)[:removeDueUtc]);
    clearReviewStorage();
    return true;
}

(:test)
function v11RejectedPhoneValuesStageDurableCanonicalMirror(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var inserted = testWall(2026, 9, 1, 9, 0);
    ScheduleModel.insertOrReplace(state, inserted);
    SettingsBridge.mirrorAll(state);
    Properties.setValue("insertionDate", 0);
    Properties.setValue("daysIn", 35);
    var observed = SettingsBridge.observe(state, inserted + 60) as Lang.Dictionary;
    Test.assert(observed[:invalid]);
    SettingsBridge.stageMirrors(state);
    var sync = state[:settingsSync] as Lang.Dictionary;
    Test.assert(sync[:pendingMirrorIso] instanceof Lang.String);
    Test.assert(sync[:pendingConfigSnapshot] instanceof Lang.Array);
    Test.assert(RingStore.save(state));
    SettingsBridge.completePendingMirrors(state);
    Test.assertEqual(SettingsBridge.isoForUtc(inserted), SettingsBridge.isoForPropertyPair(
        Properties.getValue("insertionDate"), Properties.getValue("insertionTime")));
    Test.assertEqual(21, Properties.getValue("daysIn"));
    clearReviewStorage();
    return true;
}

(:test)
function v11ForegroundAndBackgroundCandidatesMatch(logger as Test.Logger) as Boolean {
    clearReviewStorage();
    var state = ScheduleModel.defaultState();
    var active = ScheduleModel.insertOrReplace(state, testWall(2026, 9, 1, 12, 0));
    var reminders = state[:reminders] as Lang.Dictionary;
    reminders[:reminder2Enabled] = true;
    Test.assert(RingStore.save(state));
    var now = testWall(2026, 9, 22, 21, 0);
    var foreground = ReminderPolicy.evaluate(now, active,
        state[:regimen] as Lang.Dictionary, state[:reminders] as Lang.Dictionary,
        state[:reminderLedger] as Lang.Dictionary) as Lang.Dictionary;
    var background = BackgroundRuntime.evaluate(now, BackgroundRuntime.load() as Lang.Array) as Lang.Array;
    Test.assertEqual(:dayOf, foreground[:kind]);
    Test.assertEqual(4, background[0]);
    Test.assertEqual(foreground[:reminderSlot], background[3]);
    clearReviewStorage();
    return true;
}
