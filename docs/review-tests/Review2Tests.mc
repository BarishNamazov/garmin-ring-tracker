/*
 * Ring Tracker independent verification review, round 2 — archival test source.
 *
 * Reviewed HEAD: 14356f33e7fcdc0fd3268e120cae7f5da332da07
 * Test timezone: America/New_York
 * SDK/device: Connect IQ SDK 9.2.0, epix2pro47mm
 * Combined result: 78 passed, 0 failed, 8 errors across 86 tests.
 *
 * This file is intentionally outside source/ and is not included by any jungle.
 * During the disposable run it was named source/tests/Round2AdversarialTests.mc.
 * It used testWall(), assertLocalDateTime(), and clearReviewStorage() from the
 * committed test suite.
 *
 * The following test-only seam was inserted inside RingTrackerApp in the
 * disposable copy, immediately after recomputeDeadlines(), exactly as shown:
 *
 *     // Disposable round-2 review seam. This file lives only in
 *     // /tmp/review2-adversarial and is not part of the reviewed worktree.
 *     (:testhelper)
 *     function reviewRecomputeDeadlines(active as Lang.Dictionary,
 *                                       regimen as Lang.Dictionary) as Lang.Boolean {
 *         return recomputeDeadlines(active, regimen);
 *     }
 *
 * Expected ERROR against reviewed HEAD 14356f3:
 * - adversarialValidationRejectsImpossibleFinalDeadline
 * - adversarialValidationRejectsDuplicateNextCycleId
 * - adversarialValidationRejectsUnknownHistoryReason
 * - adversarialInvalidInsertionAcknowledgementStagesRepair
 * - adversarialRejectedDurationChangeStagesCanonicalMirror
 * - adversarialExactRingFreeNotificationDoesNotSayOver
 * - adversarialAboutIncludesMedicalCopyReviewDate
 * - adversarialExceededRingFreeMainCopyMatchesContract
 *
 * All other tests below passed against that HEAD. Garmin's runner reports
 * failed Test.assert/Test.assertEqual calls as ERROR.
 */

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
    var active = ScheduleModel.insertOrReplace(state, inserted);
    Test.assert(ScheduleModel.startTemporaryOut(active, inserted + 3600));
    Test.assert(ScheduleModel.endTemporaryOut(active, inserted + 5400));
    var modern = RingStore.encodeState(state);
    var a = modern[3] as Lang.Array;
    var s = modern[8] as Lang.Array;
    var v1Active = [a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7],
        a[8], a[9], a[10], a[11]];
    var v1Sync = [s[0], s[1], s[2], s[3], s[4], s[5], s[6]];
    var v1 = [1, modern[1], modern[2], v1Active, modern[4], modern[5],
        modern[6], modern[7], v1Sync];
    Storage.setValue(RingStore.STATE_KEY, v1);

    var loaded = RingStore.load();
    Test.assert(ScheduleModel.validState(loaded));
    Test.assertEqual(inserted, (loaded[:active] as Lang.Dictionary)[:insertionUtc]);
    Test.assertEqual(1, ((loaded[:active] as Lang.Dictionary)[:temporaryOut] as Lang.Array).size());
    Test.assert((loaded[:active] as Lang.Dictionary)[:finalInsertionUtc] instanceof Lang.Number);
    var persisted = Storage.getValue(RingStore.STATE_KEY) as Lang.Array;
    Test.assertEqual(ScheduleModel.SCHEMA_VERSION, persisted[0]);
    Test.assert((persisted[9] as Lang.Number) > 0);
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
    var committedRevision = state[:revision] as Lang.Number;
    Storage.setValue(RingStore.GLANCE_KEY, RingStore.encodeGlance(state, committedRevision + 1));
    Storage.deleteValue(RingStore.BACKGROUND_KEY);

    var loaded = RingStore.load();
    Test.assertEqual(inserted, (loaded[:active] as Lang.Dictionary)[:insertionUtc]);
    Test.assertEqual(committedRevision, loaded[:revision]);
    Test.assertEqual(committedRevision, (Storage.getValue(RingStore.GLANCE_KEY) as Lang.Array)[1]);
    Test.assertEqual(committedRevision, (Storage.getValue(RingStore.BACKGROUND_KEY) as Lang.Array)[1]);
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
    var parity = (state[:revision] as Lang.Number) % 2;
    Storage.deleteValue(RingStore.historyKey(0, parity));
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
    assertLocalDateTime(active[:scheduledRemovalUtc], 2026, 3, 28, 23, 59);
    assertLocalDateTime(active[:scheduledInsertionUtc], 2026, 4, 4, 23, 59);
    Test.assertEqual((21 * 86400) - 3600, active[:scheduledRemovalUtc] - inserted);
    var afterShift = testWall(2026, 3, 9, 0, 1);
    Test.assertEqual(3, ScheduleModel.deriveStatus(afterShift, active, regimen)[:dayOfCycle]);
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
    (new RingTrackerApp()).reviewRecomputeDeadlines(active, regimen);
    Test.assertEqual(:ringIn, ScheduleModel.deriveStatus(day25, active, regimen)[:phase]);
    regimen[:daysIn] = 21;
    (new RingTrackerApp()).reviewRecomputeDeadlines(active, regimen);
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
    var closed = (reopened[:temporaryOut] as Lang.Array)[0] as Lang.Dictionary;
    Test.assertEqual("over3h", closed[:thresholdCode]);
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
function adversarialValidationRejectsImpossibleFinalDeadline(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var active = ScheduleModel.insertOrReplace(state, testWall(2026, 8, 1, 9, 0));
    Test.assert(ScheduleModel.recordRemoval(active, active[:scheduledRemovalUtc],
        state[:regimen] as Lang.Dictionary));
    active[:finalInsertionUtc] = active[:removalUtc] - 1;
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
    var history = state[:history] as Lang.Array;
    var first = history[0] as Lang.Dictionary;
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
    Properties.setValue("insertionIso", "");
    var observed = SettingsBridge.observe(state, inserted + 60) as Lang.Dictionary;
    Test.assert(observed[:invalid]);
    var sync = state[:settingsSync] as Lang.Dictionary;
    sync[:pendingSettingsError] = null;
    SettingsBridge.stageMirrors(state);
    Test.assertEqual(SettingsBridge.isoForUtc(inserted),
        (state[:settingsSync] as Lang.Dictionary)[:pendingMirrorIso]);
    SettingsBridge.completePendingMirrors(state);
    Test.assertEqual(SettingsBridge.isoForUtc(inserted), Properties.getValue("insertionIso"));
    return true;
}

(:test)
function adversarialRejectedDurationChangeStagesCanonicalMirror(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    ScheduleModel.insertOrReplace(state, testWall(2026, 7, 1, 9, 0));
    SettingsBridge.mirrorAll(state);
    Properties.setValue("daysIn", 35);
    var observed = SettingsBridge.observe(state, testWall(2026, 8, 1, 9, 0)) as Lang.Dictionary;
    Test.assert(observed[:config] instanceof Lang.Array);
    SettingsBridge.stageMirrors(state);
    Test.assert((state[:settingsSync] as Lang.Dictionary)[:pendingConfigSnapshot] instanceof Lang.Array);
    SettingsBridge.completePendingMirrors(state);
    Test.assertEqual(21, Properties.getValue("daysIn"));
    return true;
}

(:test)
function adversarialExactRingFreeNotificationDoesNotSayOver(logger as Test.Logger) as Boolean {
    clearRound2Storage();
    var state = ScheduleModel.defaultState();
    var regimen = state[:regimen] as Lang.Dictionary;
    var active = ScheduleModel.insertOrReplace(state, testWall(2026, 8, 1, 9, 0));
    Test.assert(ScheduleModel.recordRemoval(active, active[:scheduledRemovalUtc], regimen));
    Test.assert(RingStore.save(state));
    var compact = BackgroundRuntime.load() as Lang.Array;
    var selected = BackgroundRuntime.evaluate(active[:ringFreeCeilingUtc], compact) as Lang.Array;
    Test.assertEqual(0, selected[0]);
    var ids = (new RingServiceDelegate()).notificationIds(selected[0], selected[1]);
    Test.assertEqual("7-day limit reached", Ui.s(ids[1]));
    clearRound2Storage();
    return true;
}

(:test)
function adversarialAboutIncludesMedicalCopyReviewDate(logger as Test.Logger) as Boolean {
    var sources = Ui.s(Rez.Strings.SourcesLine1) + " " + Ui.s(Rez.Strings.SourcesLine2)
        + " " + Ui.s(Rez.Strings.SourcesLine3);
    Test.assert(sources.find("reviewed") != null || sources.find("Review date") != null);
    return true;
}

(:test)
function adversarialExceededRingFreeMainCopyMatchesContract(logger as Test.Logger) as Boolean {
    Test.assertEqual("Ring-free interval exceeded 7 days", Ui.s(Rez.Strings.RingFreeLimitPassed));
    return true;
}
