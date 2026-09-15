import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

(:testhelper)
function clearReviewStorage() as Void {
    Storage.deleteValue(RingStore.STATE_KEY);
    Storage.deleteValue(RingStore.GLANCE_KEY);
    Storage.deleteValue(RingStore.BACKGROUND_KEY);
    Storage.deleteValue(RingStore.HISTORY_A0_KEY);
    Storage.deleteValue(RingStore.HISTORY_A1_KEY);
    Storage.deleteValue(RingStore.HISTORY_B0_KEY);
    Storage.deleteValue(RingStore.HISTORY_B1_KEY);
    Storage.deleteValue(RingStore.MIRROR_ERROR_KEY);
}

(:test)
function exactSevenDayLimitReachedIsDistinct(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var start = testWall(2026, 9, 1, 9, 0);
    var active = ScheduleModel.newCycle(1, start, regimen);
    Test.assert(ScheduleModel.recordRemoval(active, active[:scheduledRemovalUtc], regimen));
    var status = ScheduleModel.deriveStatus(active[:ringFreeCeilingUtc], active, regimen);
    Test.assert(status[:ringFreeLimitReached]);
    Test.assert(!status[:ringFreeLimitExceeded]);
    Test.assertEqual(:overdue, status[:phase]);
    Test.assertEqual(0, status[:secondsRemaining]);
    return true;
}

(:test)
function plannedOverrideParticipatesInMinimum(logger as Test.Logger) as Boolean {
    var regimen = {:daysIn=>21, :daysOut=>3};
    var start = testWall(2026, 9, 1, 9, 0);
    var active = ScheduleModel.newCycle(1, start, regimen);
    Test.assert(ScheduleModel.recordRemoval(active, active[:scheduledRemovalUtc], regimen));
    var scheduled = active[:scheduledInsertionUtc];
    ScheduleModel.setPlannedOverride(active, CalendarMath.addLocalCalendarDays(start, 25)[:utc], regimen);
    Test.assertEqual(scheduled, active[:finalInsertionUtc]);
    var earlier = CalendarMath.addLocalCalendarDays(start, 22)[:utc];
    ScheduleModel.setPlannedOverride(active, earlier, regimen);
    Test.assertEqual(earlier, ScheduleModel.nextInsertUtc(active, regimen));
    return true;
}

(:test)
function temporaryAndScheduleRemindersStayIndependent(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    var start = testWall(2026, 9, 1, 12, 0);
    var active = ScheduleModel.newCycle(1, start, regimen);
    var dayOf = testWall(2026, 9, 22, 10, 0);
    Test.assert(ScheduleModel.startTemporaryOut(active, dayOf - 3600));
    var scheduleCandidate = ReminderPolicy.evaluate(dayOf, active, regimen, reminders,
        ScheduleModel.defaultLedger());
    Test.assertEqual(:dayOf, scheduleCandidate[:kind]);
    var tempCandidate = ReminderPolicy.evaluate(dayOf + 10801, active, regimen, reminders,
        ScheduleModel.defaultLedger());
    Test.assertEqual(:tempOver3h, tempCandidate[:kind]);
    return true;
}

(:test)
function dayOfConsumesDayBeforeLedger(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var reminders = ScheduleModel.defaultReminders();
    var start = testWall(2026, 9, 1, 12, 0);
    var active = ScheduleModel.newCycle(1, start, regimen);
    var ledger = ScheduleModel.defaultLedger();
    var candidate = ReminderPolicy.evaluate(testWall(2026, 9, 22, 10, 0), active,
        regimen, reminders, ledger);
    Test.assertEqual(:dayOf, candidate[:kind]);
    ReminderPolicy.markSent(ledger, candidate);
    Test.assert(ledger[:dayOfSent]);
    Test.assert(ledger[:dayBeforeSent]);
    return true;
}

(:test)
function thirtyThirdTemporaryOutCompactsOldestShort(logger as Test.Logger) as Boolean {
    var start = testWall(2026, 9, 1, 9, 0);
    var active = ScheduleModel.newCycle(1, start, ScheduleModel.defaultRegimen());
    for (var i = 0; i < ScheduleModel.MAX_TEMP_INTERVALS; i += 1) {
        var out = start + 100 + (i * 100);
        Test.assert(ScheduleModel.startTemporaryOut(active, out));
        Test.assert(ScheduleModel.endTemporaryOut(active, out + 10));
    }
    Test.assert(ScheduleModel.startTemporaryOut(active, start + 4000));
    Test.assertEqual(ScheduleModel.MAX_TEMP_INTERVALS,
        (active[:temporaryOut] as Lang.Array).size());
    var summary = active[:temporaryOutSummary] as Lang.Dictionary;
    Test.assertEqual(1, summary[:shortIntervalCount]);
    Test.assertEqual(10, summary[:shortIntervalSeconds]);
    return true;
}

(:test)
function revisionedRecordsShareCanonicalCommit(logger as Test.Logger) as Boolean {
    clearReviewStorage();
    var state = ScheduleModel.defaultState();
    ScheduleModel.insertOrReplace(state, testWall(2026, 9, 1, 9, 0));
    Test.assert(RingStore.save(state));
    var canonical = Storage.getValue(RingStore.STATE_KEY) as Lang.Array;
    var glance = Storage.getValue(RingStore.GLANCE_KEY) as Lang.Array;
    var background = Storage.getValue(RingStore.BACKGROUND_KEY) as Lang.Array;
    Test.assertEqual(canonical[9], glance[1]);
    Test.assertEqual(canonical[9], background[1]);
    Test.assertEqual(state[:revision], canonical[9]);

    glance[1] = canonical[9] - 1;
    Storage.setValue(RingStore.GLANCE_KEY, glance);
    var loaded = RingStore.load();
    var repaired = Storage.getValue(RingStore.GLANCE_KEY) as Lang.Array;
    Test.assertEqual(loaded[:revision], repaired[1]);
    clearReviewStorage();
    return true;
}

(:test)
function settingsConfigurationMirrorIsDurablyPending(logger as Test.Logger) as Boolean {
    clearReviewStorage();
    var state = ScheduleModel.defaultState();
    SettingsBridge.mirrorAll(state);
    var reminders = state[:reminders] as Lang.Dictionary;
    reminders[:localHour] = 17;
    SettingsBridge.stageMirrors(state);
    Test.assert((state[:settingsSync] as Lang.Dictionary)[:pendingConfigSnapshot] instanceof Lang.Array);
    Test.assert(RingStore.save(state));
    var interrupted = RingStore.load();
    Test.assert((interrupted[:settingsSync] as Lang.Dictionary)[:pendingConfigSnapshot] instanceof Lang.Array);
    SettingsBridge.completePendingMirrors(interrupted);
    Test.assertEqual(17, Properties.getValue("reminderHour"));
    Test.assert((interrupted[:settingsSync] as Lang.Dictionary)[:pendingConfigSnapshot] == null);
    Test.assert(RingStore.save(interrupted));
    Test.assert(SettingsBridge.observe(interrupted, testWall(2026, 9, 1, 9, 0)) == null);
    clearReviewStorage();
    return true;
}

(:test)
function insertionEditRejectsFutureChronology(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var start = testWall(2026, 9, 1, 9, 0);
    var active = ScheduleModel.newCycle(1, start, regimen);
    var removed = testWall(2026, 9, 10, 9, 0);
    Test.assert(ScheduleModel.recordRemoval(active, removed, regimen));
    var invalid = testWall(2026, 9, 15, 9, 0);
    Test.assert(!ScheduleModel.validInsertionEdit(active, invalid));
    Test.assert(ScheduleModel.rebuildForInsertion(active, invalid, regimen) == null);
    return true;
}

(:test)
function emptySettingsInsertionCreatesRepairMarker(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 9, 1, 9, 0);
    ScheduleModel.insertOrReplace(state, start);
    SettingsBridge.mirrorAll(state);
    Properties.setValue("insertionIso", "");
    var result = SettingsBridge.observe(state, start + 10) as Lang.Dictionary;
    Test.assert(result[:invalid]);
    Test.assertEqual("emptyInsertionIso",
        (state[:settingsSync] as Lang.Dictionary)[:pendingSettingsError]);
    SettingsBridge.mirrorAll(state);
    Test.assertEqual(SettingsBridge.isoForUtc(start), Properties.getValue("insertionIso"));
    return true;
}

(:test)
function crossedWeekTemporaryGuidanceIncludesEverySection(logger as Test.Logger) as Boolean {
    var interval = {:outUtc=>1, :backInUtc=>2, :phaseWeekAtStart=>2,
        :phaseWeekAtEnd=>3, :thresholdCode=>"over3h"};
    var guidance = ScheduleModel.temporaryGuidance(interval);
    Test.assertEqual(2, guidance.size());
    Test.assertEqual(:week12, guidance[0]);
    Test.assertEqual(:week3, guidance[1]);
    interval[:phaseWeekAtStart] = 3;
    interval[:phaseWeekAtEnd] = null;
    guidance = ScheduleModel.temporaryGuidance(interval);
    Test.assertEqual(:week3, guidance[0]);
    Test.assertEqual(:outside, guidance[1]);
    return true;
}

(:test)
function notificationLaunchRequiresKnownTypedKind(logger as Test.Logger) as Boolean {
    Test.assert(ScheduleModel.validNotificationData([7, 0], 7));
    Test.assert(!ScheduleModel.validNotificationData([7, 6], 7));
    Test.assert(!ScheduleModel.validNotificationData([7, "overdue"], 7));
    Test.assert(!ScheduleModel.validNotificationData([8, 0], 7));
    Test.assert(!ScheduleModel.validNotificationData([7], 7));
    return true;
}

(:test)
function replacementReminderUsesReplacementCopy(logger as Test.Logger) as Boolean {
    var service = new RingServiceDelegate();
    Test.assertEqual(Rez.Strings.NotificationReplaceTomorrow,
        service.notificationIds(5, 2)[1]);
    Test.assertEqual(Rez.Strings.NotificationReplaceToday,
        service.notificationIds(4, 2)[1]);
    return true;
}

(:test)
function constrainedMirrorValidationFailsInertAndMarksError(logger as Test.Logger) as Boolean {
    clearReviewStorage();
    var state = ScheduleModel.defaultState();
    ScheduleModel.insertOrReplace(state, testWall(2026, 9, 1, 9, 0));
    Test.assert(RingStore.save(state));
    var raw = Storage.getValue(RingStore.BACKGROUND_KEY) as Lang.Array;
    var reminders = raw[5] as Lang.Array;
    reminders[2] = 0;
    Storage.setValue(RingStore.BACKGROUND_KEY, raw);
    Test.assert(BackgroundRuntime.load() == null);
    Test.assert(Storage.getValue(RingStore.MIRROR_ERROR_KEY) instanceof Lang.String);
    clearReviewStorage();
    return true;
}

(:test)
function splitHistoryValuesRemainUnderBudgetAndRoundTrip(logger as Test.Logger) as Boolean {
    clearReviewStorage();
    var state = ScheduleModel.defaultState();
    var history = [];
    for (var c = 0; c < ScheduleModel.MAX_HISTORY; c += 1) {
        var inserted = 1700000000 + (c * 1000000);
        var intervals = [];
        for (var i = 0; i < ScheduleModel.MAX_TEMP_INTERVALS; i += 1) {
            var out = inserted + 1000 + (i * 12000);
            intervals.add({:outUtc=>out, :backInUtc=>out + 10900,
                :phaseWeekAtStart=>1, :phaseWeekAtEnd=>1, :thresholdCode=>"over3h"});
        }
        history.add({:cycleId=>c + 1, :insertionUtc=>inserted,
            :removalUtc=>inserted + 500000, :nextInsertionUtc=>inserted + 600000,
            :closeReason=>"replaced", :regimenDaysIn=>21, :regimenDaysOut=>7,
            :temporaryOut=>intervals,
            :temporaryOutSummary=>{:shortIntervalCount=>0, :shortIntervalSeconds=>0}});
    }
    state[:history] = history;
    state[:nextCycleId] = 25;
    Test.assert(RingStore.compactForStorage(state));
    var sizes = RingStore.historySizeEstimates(state);
    Test.assertEqual(2, sizes.size());
    Test.assert(sizes[0] < RingStore.VALUE_BUDGET);
    Test.assert(sizes[1] < RingStore.VALUE_BUDGET);
    Test.assert(RingStore.save(state));
    Test.assertEqual(ScheduleModel.MAX_HISTORY, (RingStore.load()[:history] as Lang.Array).size());
    clearReviewStorage();
    return true;
}

(:test)
function storageFullExceptionGetsDistinctSaveClassification(logger as Test.Logger) as Boolean {
    var error = new Lang.StorageFullException("simulated full store");
    Test.assertEqual("storageFull", RingStore.saveExceptionKind(error));
    Test.assertEqual("write", RingStore.saveExceptionKind(new Lang.InvalidValueException("other")));
    return true;
}

(:test)
function copyAndFormattingContractsMatchRegimen(logger as Test.Logger) as Boolean {
    var disclaimer = Ui.s(Rez.Strings.DisclaimerLine1) + " "
        + Ui.s(Rez.Strings.DisclaimerLine2) + " "
        + Ui.s(Rez.Strings.DisclaimerLine3);
    Test.assertEqual("This app is a scheduling aid, not medical advice. It cannot determine whether contraception is effective. Follow the instructions supplied with your ring and contact a qualified clinician or pharmacist if a ring is late, has been out too long, or pregnancy is possible.", disclaimer);
    Test.assertEqual("3-hour limit reached; reinsert now and follow product instructions.",
        Ui.s(Rez.Strings.ThreeHourReached));
    Test.assertEqual("Mon 5 Oct", Ui.shortDate(testWall(2026, 10, 5, 17, 6)));
    Test.assertEqual("5:06 PM", Ui.timeOnly(17, 6, 12));
    Test.assertEqual("17:06", Ui.timeOnly(17, 6, 24));
    return true;
}
