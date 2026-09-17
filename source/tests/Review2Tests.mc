// Applicable round-2 adversarial cases, adapted to the v1.1 actual-event model.
import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

(:testhelper)
function clearRound2Storage() as Void {
    clearReviewStorage();
    Storage.deleteValue(RingStore.RECOVERY_KEY);
    Storage.deleteValue("round2NearLimit");
}

(:test)
function adversarialOlderSchemaMigratesAndPersists(logger as Test.Logger) as Boolean {
    clearRound2Storage();
    var state = ScheduleModel.defaultState();
    var inserted = testWall(2026, 8, 1, 23, 59);
    ScheduleModel.insertOrReplace(state, inserted);
    var v2 = legacyV2Fixture(state);
    var v1 = [1];
    for (var i = 1; i <= 8; i += 1) { v1.add(v2[i]); }
    Storage.setValue(RingStore.STATE_KEY, v1);
    var loaded = RingStore.load();
    Test.assert(ScheduleModel.validState(loaded));
    Test.assertEqual(inserted, (loaded[:active] as Lang.Dictionary)[:insertionUtc]);
    Test.assertEqual(3, (Storage.getValue(RingStore.STATE_KEY) as Lang.Array)[0]);
    Test.assert(loaded[:migrationNoticePending]);
    clearRound2Storage();
    return true;
}

(:test)
function adversarialInterruptedMirrorSequenceKeepsCanonical(logger as Test.Logger) as Boolean {
    clearRound2Storage();
    var state = ScheduleModel.defaultState();
    var inserted = testWall(2026, 8, 2, 9, 0);
    ScheduleModel.insertOrReplace(state, inserted);
    Test.assert(RingStore.save(state));
    var committed = state[:revision];
    Storage.setValue(RingStore.GLANCE_KEY, RingStore.encodeGlance(state, committed + 1));
    Storage.deleteValue(RingStore.BACKGROUND_KEY);
    var loaded = RingStore.load();
    Test.assertEqual(inserted, (loaded[:active] as Lang.Dictionary)[:insertionUtc]);
    Test.assertEqual(committed, loaded[:revision]);
    Test.assertEqual(committed, (Storage.getValue(RingStore.GLANCE_KEY) as Lang.Array)[1]);
    Test.assertEqual(committed, (Storage.getValue(RingStore.BACKGROUND_KEY) as Lang.Array)[1]);
    clearRound2Storage();
    return true;
}

(:test)
function adversarialMissingHistoryChunkRecoversInsteadOfMixingRevisions(logger as Test.Logger) as Boolean {
    clearRound2Storage();
    var state = ScheduleModel.defaultState();
    var inserted = testWall(2026, 7, 1, 9, 0);
    ScheduleModel.insertOrReplace(state, inserted);
    ScheduleModel.insertOrReplace(state, inserted + 100);
    Test.assert(RingStore.save(state));
    Storage.deleteValue(RingStore.historyKey(0, (state[:revision] as Lang.Number) % 2));
    var loaded = RingStore.load();
    Test.assertEqual("recovered", loaded[:loadError]);
    Test.assert(loaded[:active] == null);
    Test.assert(Storage.getValue(RingStore.STATE_KEY) == null);
    clearRound2Storage();
    return true;
}

(:test)
function adversarialInsertion2359AcrossDstKeepsWallIntent(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var inserted = testWall(2026, 3, 7, 23, 59);
    var active = ScheduleModel.newCycle(1, inserted, regimen);
    assertLocalDateTime(active[:removeDueUtc], 2026, 3, 28, 23, 59);
    Test.assertEqual((21 * 86400) - 3600, active[:removeDueUtc] - inserted);
    Test.assert(ScheduleModel.recordRemoval(active, active[:removeDueUtc], regimen));
    assertLocalDateTime(active[:insertDueUtc], 2026, 4, 4, 23, 59);
    return true;
}

(:test)
function adversarialDaysInChangeReclassifiesDay25BothWays(logger as Test.Logger) as Boolean {
    var regimen = ScheduleModel.defaultRegimen();
    var inserted = testWall(2026, 8, 1, 9, 0);
    var day25 = CalendarMath.addLocalCalendarDays(inserted, 24)[:utc];
    var active = ScheduleModel.newCycle(1, inserted, regimen);
    Test.assertEqual(:overdue, ScheduleModel.deriveStatus(day25, active, regimen)[:phase]);
    regimen[:daysIn] = 35;
    ScheduleModel.recomputeForRegimen(active, regimen);
    Test.assertEqual(:ringIn, ScheduleModel.deriveStatus(day25, active, regimen)[:phase]);
    regimen[:daysIn] = 21;
    ScheduleModel.recomputeForRegimen(active, regimen);
    Test.assertEqual(:overdue, ScheduleModel.deriveStatus(day25, active, regimen)[:phase]);
    return true;
}

(:test)
function adversarialTemporaryOutSurvivesRebootAndClosesOver3h(logger as Test.Logger) as Boolean {
    clearRound2Storage();
    var state = ScheduleModel.defaultState();
    var inserted = testWall(2026, 8, 10, 9, 0);
    var active = ScheduleModel.insertOrReplace(state, inserted);
    var out = inserted + 3600;
    Test.assert(ScheduleModel.startTemporaryOut(active, out));
    Test.assert(RingStore.save(state));
    var rebooted = RingStore.load();
    var reopened = rebooted[:active] as Lang.Dictionary;
    Test.assert(ScheduleModel.tempOpen(reopened) != null);
    var candidate = ReminderPolicy.evaluate(out + 10801, reopened,
        rebooted[:regimen] as Lang.Dictionary, rebooted[:reminders] as Lang.Dictionary,
        rebooted[:reminderLedger] as Lang.Dictionary);
    Test.assertEqual(:tempOver3h, candidate[:kind]);
    Test.assert(ScheduleModel.endTemporaryOut(reopened, out + 10801));
    Test.assertEqual("over3h", ((reopened[:temporaryOut] as Lang.Array)[0] as Lang.Dictionary)[:thresholdCode]);
    Test.assert(RingStore.save(rebooted));
    Test.assert(ScheduleModel.tempOpen(RingStore.load()[:active] as Lang.Dictionary) == null);
    clearRound2Storage();
    return true;
}

(:test)
function adversarialNotificationStaleCycleIsRejected(logger as Test.Logger) as Boolean {
    Test.assert(!ScheduleModel.validNotificationData([41, 3], 42));
    Test.assert(ScheduleModel.validNotificationData([42, 3], 42));
    return true;
}

(:test)
function adversarialSettingsIsoRejectsDstNonexistentTime(logger as Test.Logger) as Boolean {
    var afterGap = testWall(2026, 3, 9, 9, 0);
    Test.assert(SettingsBridge.parseInsertion("2026-03-08T02:30", afterGap) == null);
    Test.assert(!SettingsBridge.validate("insertionIso", "2026-03-08T02:30", afterGap));
    return true;
}

(:test)
function adversarialStorageValueNear32KiBAndPreflight(logger as Test.Logger) as Boolean {
    clearRound2Storage();
    var block = "0123456789abcdef";
    var nearLimit = "";
    for (var i = 0; i < 2000; i += 1) { nearLimit += block; }
    Test.assertEqual(32000, nearLimit.length());
    Storage.setValue("round2NearLimit", nearLimit);
    Test.assertEqual(32000, (Storage.getValue("round2NearLimit") as Lang.String).length());
    Test.assert(!RingStore.withinBudget([nearLimit]));
    clearRound2Storage();
    return true;
}

(:test)
function adversarialValidationRejectsImpossibleDerivedDates(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var active = ScheduleModel.insertOrReplace(state, testWall(2026, 8, 1, 9, 0));
    active[:removeDueUtc] += 1;
    Test.assert(!ScheduleModel.validState(state));
    active[:removeDueUtc] -= 1;
    active[:labelFourWeekUtc] += 1;
    Test.assert(!ScheduleModel.validState(state));
    active[:labelFourWeekUtc] -= 1;
    Test.assert(ScheduleModel.recordRemoval(active, active[:removeDueUtc], state[:regimen]));
    active[:insertDueUtc] -= 1;
    Test.assert(!ScheduleModel.validState(state));
    active[:insertDueUtc] += 1;
    active[:ringFreeCeilingUtc] += 1;
    Test.assert(!ScheduleModel.validState(state));
    return true;
}

(:test)
function adversarialValidationRejectsDuplicateNextCycleId(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    ScheduleModel.insertOrReplace(state, testWall(2026, 8, 1, 9, 0));
    state[:nextCycleId] = 1;
    Test.assert(!ScheduleModel.validState(state));
    return true;
}

(:test)
function adversarialValidationRejectsUnknownHistoryReason(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var inserted = testWall(2026, 8, 1, 9, 0);
    ScheduleModel.insertOrReplace(state, inserted);
    ScheduleModel.insertOrReplace(state, inserted + 100);
    var first = (state[:history] as Lang.Array)[0] as Lang.Dictionary;
    first[:closeReason] = "corrupt-enum";
    Test.assert(!ScheduleModel.validState(state));
    return true;
}

(:test)
function adversarialFractionalNotificationKindIsRejected(logger as Test.Logger) as Boolean {
    Test.assert(!ScheduleModel.validNotificationData([7, 2.5], 7));
    return true;
}

(:test)
function adversarialInvalidInsertionAcknowledgementStagesRepair(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var inserted = testWall(2026, 8, 1, 9, 0);
    ScheduleModel.insertOrReplace(state, inserted);
    SettingsBridge.mirrorAll(state);
    Properties.setValue("insertionDate", 0);
    Test.assert((SettingsBridge.observe(state, inserted + 60) as Lang.Dictionary)[:invalid]);
    SettingsBridge.stageMirrors(state);
    Test.assertEqual(SettingsBridge.isoForUtc(inserted),
        (state[:settingsSync] as Lang.Dictionary)[:pendingMirrorIso]);
    Test.assert(RingStore.save(state));
    SettingsBridge.completePendingMirrors(state);
    Test.assertEqual(SettingsBridge.isoForUtc(inserted), SettingsBridge.isoForPropertyPair(
        Properties.getValue("insertionDate"), Properties.getValue("insertionTime")));
    clearRound2Storage();
    return true;
}

(:test)
function adversarialRejectedDurationChangeStagesCanonicalMirror(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    ScheduleModel.insertOrReplace(state, testWall(2026, 7, 1, 9, 0));
    SettingsBridge.mirrorAll(state);
    Properties.setValue("daysIn", 35);
    Test.assert((SettingsBridge.observe(state, testWall(2026, 8, 1, 9, 0)) as Lang.Dictionary)[:config] instanceof Lang.Array);
    SettingsBridge.stageMirrors(state);
    Test.assert((state[:settingsSync] as Lang.Dictionary)[:pendingConfigSnapshot] instanceof Lang.Array);
    Test.assert(RingStore.save(state));
    SettingsBridge.completePendingMirrors(state);
    Test.assertEqual(21, Properties.getValue("daysIn"));
    clearRound2Storage();
    return true;
}
