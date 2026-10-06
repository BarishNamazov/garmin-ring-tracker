import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

(:testhelper)
function v15Same(left, right) as Lang.Boolean {
    if (left instanceof Lang.String) {
        return right instanceof Lang.String && (left as Lang.String).equals(right);
    }
    if (left instanceof Lang.Array) {
        if (!(right instanceof Lang.Array) || left.size() != right.size()) { return false; }
        for (var i = 0; i < left.size(); i += 1) {
            if (!v15Same(left[i], right[i])) { return false; }
        }
        return true;
    }
    return left == right;
}

(:testhelper)
function v15Clear() as Void {
    clearReviewStorage();
    var keys = [BackgroundStatus.KEY, BackgroundStatus.TEST_KEY, "debugNowUtc",
        "debugBackgroundThrow", "debugBackgroundIconThrow", "debugBackgroundFailStage",
        "debugBackgroundNotifyStub", "debugBackgroundNotifyCalls", "debugBackgroundNotifyIcon", "debugBackgroundNotifyDismiss",
        "debugBackgroundScenario", "debugBackgroundResult"];
    for (var i = 0; i < keys.size(); i += 1) { Storage.deleteValue(keys[i]); }
}

(:testhelper)
function v15Seed(scenario as Lang.Symbol) as Lang.Array {
    v15Clear();
    var state = demoState(scenario, testWall(2026, 9, 17, 12, 26));
    Test.assert(RingStore.save(state));
    afterOptionalSeed(:demo, scenario);
    Storage.setValue("debugBackgroundNotifyStub", true);
    return Storage.getValue(RingStore.BACKGROUND_KEY) as Lang.Array;
}

(:testhelper)
function v15Check() as Lang.Array { return (new RingServiceDelegate()).runCheck(); }

(:test)
function v15RegistrationDecision(logger as Test.Logger) as Boolean {
    Test.assert(BackgroundRegistration.needed(null));
    Test.assert(BackgroundRegistration.needed(new Time.Duration(1800)));
    Test.assert(BackgroundRegistration.needed(new Time.Duration(7200)));
    Test.assert(!BackgroundRegistration.needed(new Time.Duration(3600)));
    Test.assert(BackgroundRegistration.needed(new Time.Moment(3600)));
    return true;
}

(:test)
function v15InstallUpdateAndOpenKeepHourlyRegistration(logger as Test.Logger) as Boolean {
    Background.deleteTemporalEvent();
    Application.getApp().onAppInstall();
    Test.assert(!BackgroundRegistration.needed(Background.getTemporalEventRegisteredTime()));
    Application.getApp().onAppUpdate();
    Test.assert(BackgroundRegistration.ensureHourly());
    Test.assert(!BackgroundRegistration.needed(Background.getTemporalEventRegisteredTime()));
    return true;
}

(:test)
function v15StatusRoundTripAndIsolation(logger as Test.Logger) as Boolean {
    v15Seed(:backgroundReminder1);
    var canonical = Storage.getValue(RingStore.STATE_KEY);
    var mirror = Storage.getValue(RingStore.BACKGROUND_KEY);
    var status = BackgroundStatus.begin(currentUtc());
    BackgroundStatus.shown(status, 4);
    BackgroundStatus.save(status);
    Test.assert(v15Same(status, BackgroundStatus.decode(BackgroundStatus.encode(status))));
    Test.assert(v15Same(status, BackgroundStatus.load()));
    Test.assert(v15Same(canonical, Storage.getValue(RingStore.STATE_KEY)));
    Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
    v15Clear();
    return true;
}

(:test)
function v15StatusCorruptFallback(logger as Test.Logger) as Boolean {
    v15Clear();
    var bad = [null, "bad", {}, [], [1, 2], [2, null, 0, 0, null, null, null],
        [1, "bad", 4, 0, null, null, null], [1, 100, 99, 0, null, null, null],
        [1, 100, 6, 0, null, null, null], [1, 100, 5, 0, null, null, null],
        [1, 100, 4, 0, null, 100, null], [1, null, 4, 0, null, null, null],
        [1, 100, 6, 99, null, null, null], [1, 100, 5, 0, 99, 100, 99]];
    for (var i = 0; i < bad.size(); i += 1) {
        Test.assert(v15Same(BackgroundStatus.empty(), BackgroundStatus.decode(bad[i])));
    }
    Storage.setValue(BackgroundStatus.KEY, ["bad"]);
    Test.assert(BackgroundStatus.load()[1] == null);
    Test.assert(!BackgroundStatus.consumeTest());
    Storage.setValue(BackgroundStatus.TEST_KEY, "bad");
    Test.assert(!BackgroundStatus.consumeTest());
    Test.assert(Storage.getValue(BackgroundStatus.TEST_KEY) == null);
    v15Clear();
    return true;
}

(:test)
function v15NoActiveOutcome(logger as Test.Logger) as Boolean {
    v15Seed(:backgroundNoActive);
    var status = v15Check();
    Test.assertEqual(BackgroundStatus.NO_ACTIVE, status[2]);
    Test.assertEqual(currentUtc(), status[1]);
    Test.assert(Storage.getValue("debugBackgroundNotifyCalls") == null);
    v15Clear();
    return true;
}

(:test)
function v15MirrorInvalidOutcome(logger as Test.Logger) as Boolean {
    v15Seed(:backgroundCorrupt);
    Test.assertEqual(BackgroundStatus.MIRROR_INVALID, v15Check()[2]);
    Test.assert(Storage.getValue(RingStore.MIRROR_ERROR_KEY) != null);
    v15Clear();
    return true;
}

(:test)
function v15NilMirrorOutcome(logger as Test.Logger) as Boolean {
    v15Seed(:backgroundNil);
    Test.assertEqual(BackgroundStatus.MIRROR_INVALID, v15Check()[2]);
    v15Clear();
    return true;
}

(:test)
function v15CanonicalMismatchOutcome(logger as Test.Logger) as Boolean {
    var mirror = v15Seed(:backgroundMismatch);
    Test.assert(BackgroundRuntime.valid(mirror));
    Test.assertEqual(BackgroundStatus.CANONICAL_MISMATCH, v15Check()[2]);
    v15Clear();
    return true;
}

(:test)
function v15NothingDueOutcome(logger as Test.Logger) as Boolean {
    var mirror = v15Seed(:backgroundNoOp);
    Test.assertEqual(BackgroundStatus.NOTHING_DUE, v15Check()[2]);
    Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
    v15Clear();
    return true;
}

(:test)
function v15AllReminderKindsRecorded(logger as Test.Logger) as Boolean {
    var fixtures = [:backgroundFree, :backgroundTemp, :backgroundFourWeeks,
        :backgroundOverdue, :backgroundReminder1, :backgroundDayBefore, :backgroundReminder2];
    for (var i = 0; i < fixtures.size(); i += 1) {
        v15Seed(fixtures[i]);
        var status = v15Check();
        Test.assertEqual(BackgroundStatus.ALERT_SHOWN, status[2]);
        Test.assertEqual(i, status[4]);
        Test.assertEqual(i, status[6]);
        Test.assertEqual(currentUtc(), status[5]);
        Test.assertEqual(1, Storage.getValue("debugBackgroundNotifyCalls"));
        Test.assert((RingStore.load()[:reminderLedger] as Lang.Dictionary)[:cycleId] > 0);
    }
    v15Clear();
    return true;
}

(:test)
function v15StageFailuresKeepPersistedLedger(logger as Test.Logger) as Boolean {
    var stages = [BackgroundStatus.LOAD, BackgroundStatus.EVALUATE, BackgroundStatus.NOTIFY, BackgroundStatus.SAVE];
    for (var i = 0; i < stages.size(); i += 1) {
        var mirror = v15Seed(:backgroundReminder1);
        Storage.setValue("debugBackgroundFailStage", stages[i]);
        var status = v15Check();
        Test.assertEqual(BackgroundStatus.FAILED, status[2]);
        Test.assertEqual(stages[i], status[3]);
        Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
        Test.assert(status[5] == (stages[i] == BackgroundStatus.SAVE ? currentUtc() : null));
        Test.assert(v15Same(status, BackgroundStatus.load()));
    }
    v15Clear();
    return true;
}

(:test)
function v15BothNotificationAttemptsFailThenRetry(logger as Test.Logger) as Boolean {
    var mirror = v15Seed(:backgroundThrow);
    var status = v15Check();
    Test.assertEqual(BackgroundStatus.FAILED, status[2]);
    Test.assertEqual(BackgroundStatus.NOTIFY, status[3]);
    Test.assert(status[5] == null);
    Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
    Storage.deleteValue("debugBackgroundThrow");
    Test.assertEqual(BackgroundStatus.ALERT_SHOWN, v15Check()[2]);
    Test.assert(!v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
    v15Clear();
    return true;
}

(:test)
function v15IconFailureFallsBackAndSavesLedger(logger as Test.Logger) as Boolean {
    v15Seed(:backgroundIconRetry);
    Test.assertEqual(BackgroundStatus.ALERT_SHOWN, v15Check()[2]);
    Test.assertEqual(false, Storage.getValue("debugBackgroundNotifyIcon"));
    Test.assert((RingStore.load()[:reminderLedger] as Lang.Dictionary)[:dayOf1Sent]);
    v15Clear();
    return true;
}

(:test)
function v15TestFlagConsumedOnceKeepsLedger(logger as Test.Logger) as Boolean {
    var mirror = v15Seed(:backgroundTest);
    var canonical = Storage.getValue(RingStore.STATE_KEY);
    var status = v15Check();
    Test.assertEqual(BackgroundStatus.ALERT_SHOWN, status[2]);
    Test.assertEqual(BackgroundStatus.TEST, status[6]);
    Test.assertEqual(false, Storage.getValue("debugBackgroundNotifyDismiss"));
    Test.assert(Storage.getValue(BackgroundStatus.TEST_KEY) == null);
    Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
    Test.assert(v15Same(canonical, Storage.getValue(RingStore.STATE_KEY)));
    Test.assertEqual(BackgroundStatus.NOTHING_DUE, v15Check()[2]);
    Test.assertEqual(1, Storage.getValue("debugBackgroundNotifyCalls"));
    Test.assertEqual(status[5], BackgroundStatus.load()[5]);
    Test.assertEqual(BackgroundStatus.TEST, BackgroundStatus.load()[6]);
    v15Clear();
    return true;
}

(:test)
function v15FailedTestConsumedOnceKeepsLedger(logger as Test.Logger) as Boolean {
    var mirror = v15Seed(:backgroundTestThrow);
    var status = v15Check();
    Test.assertEqual(BackgroundStatus.FAILED, status[2]);
    Test.assertEqual(BackgroundStatus.NOTIFY, status[3]);
    Test.assertEqual(BackgroundStatus.TEST, status[4]);
    Test.assert(Storage.getValue(BackgroundStatus.TEST_KEY) == null);
    Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
    Storage.deleteValue("debugBackgroundThrow");
    Test.assertEqual(BackgroundStatus.NOTHING_DUE, v15Check()[2]);
    Test.assert(Storage.getValue("debugBackgroundNotifyCalls") == null);
    v15Clear();
    return true;
}

(:test)
function v15TestPreservesInvalidScheduleAndRetriesIcon(logger as Test.Logger) as Boolean {
    v15Seed(:backgroundCorrupt);
    var mirror = Storage.getValue(RingStore.BACKGROUND_KEY);
    BackgroundStatus.queueTest();
    Storage.setValue("debugBackgroundIconThrow", true);
    var status = v15Check();
    Test.assertEqual(BackgroundStatus.MIRROR_INVALID, status[2]);
    Test.assertEqual(BackgroundStatus.TEST, status[6]);
    Test.assert(BackgroundStatus.valid(status));
    Test.assertEqual("Reminder data invalid", ReminderCheckUi.problem(status, currentUtc()));
    Test.assertEqual(false, Storage.getValue("debugBackgroundNotifyIcon"));
    Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
    v15Clear();
    return true;
}

(:test)
function v15ForegroundRepairPreservesEvidence(logger as Test.Logger) as Boolean {
    v15Seed(:backgroundMismatch);
    var status = v15Check();
    var error = Storage.getValue(RingStore.MIRROR_ERROR_KEY);
    var state = RingStore.load();
    RingStore.repairMirrors(state);
    Test.assert(v15Same(status, BackgroundStatus.load()));
    Test.assertEqual(error, Storage.getValue(RingStore.MIRROR_ERROR_KEY));
    Test.assert(BackgroundRuntime.load() != null);
    Test.assertEqual(BackgroundStatus.NOTHING_DUE, v15Check()[2]);
    Test.assert(Storage.getValue(RingStore.MIRROR_ERROR_KEY) == null);
    v15Clear();
    return true;
}

(:test)
function v15NewCheckKeepsLastAlert(logger as Test.Logger) as Boolean {
    v15Seed(:backgroundReminder1);
    var shown = v15Check();
    Storage.deleteValue(RingStore.BACKGROUND_KEY);
    var invalid = v15Check();
    Test.assertEqual(BackgroundStatus.MIRROR_INVALID, invalid[2]);
    Test.assertEqual(shown[5], invalid[5]);
    Test.assertEqual(shown[6], invalid[6]);
    v15Clear();
    return true;
}

(:test)
function v15SettingsSublabelStates(logger as Test.Logger) as Boolean {
    v15Clear();
    var now = testWall(2026, 9, 17, 10, 12);
    Test.assertEqual("Not checked yet", ReminderCheckUi.sublabel(BackgroundStatus.empty(), now));
    var status = BackgroundStatus.begin(now);
    Test.assertEqual(Ui.fmt(Rez.Strings.CheckRecent, [Ui.timeForUtc(now, 0)]), ReminderCheckUi.sublabel(status, now));
    Test.assertEqual("No check for 2 h", ReminderCheckUi.sublabel(status, now + 7200));
    Test.assertEqual("No check for 3 h", ReminderCheckUi.sublabel(status, now + 10800));
    Test.assert(ReminderCheckUi.sublabel(status, now - 1).find("Checked") != null);
    Test.assertEqual("Test queued", Ui.s(Rez.Strings.CheckTestQueued));
    Test.assertEqual("Next hourly check", Ui.s(Rez.Strings.CheckTestNext));
    Test.assert(ReminderCheckUi.problem(status, now) == null);
    Test.assertEqual("No check for 3 h", ReminderCheckUi.problem(status, now + 10800));
    v15Clear();
    return true;
}

(:test)
function v15RelativeDayUsesLocalDateAcrossDst(logger as Test.Logger) as Boolean {
    var today = testWall(2026, 11, 1, 12, 0);
    var yesterday = testWall(2026, 10, 31, 12, 0);
    Test.assert(ReminderCheckUi.timestamp(today, today).find("Today") != null);
    Test.assert(ReminderCheckUi.timestamp(yesterday, today).find("Yesterday") != null);
    Test.assertEqual("None yet", ReminderCheckUi.timestamp(null, today));
    Test.assert(ReminderCheckUi.timestamp(yesterday - 86400, today).find("Yesterday") == null);
    Test.assertEqual("Reminder 2", ReminderCheckUi.kindLabel(6));
    return true;
}

(:test)
function v15ProblemCopyForEveryFailure(logger as Test.Logger) as Boolean {
    v15Clear();
    var status = BackgroundStatus.begin(100);
    status[2] = BackgroundStatus.MIRROR_INVALID;
    Test.assertEqual("Reminder data invalid", ReminderCheckUi.problem(status, 100));
    status[2] = BackgroundStatus.CANONICAL_MISMATCH;
    Test.assertEqual("Reminder data mismatch", ReminderCheckUi.problem(status, 100));
    var copy = ["Check failed: load", "Check failed: evaluate", "Alert failed", "Check failed: save"];
    for (var i = 0; i < copy.size(); i += 1) {
        BackgroundStatus.failed(status, i + 1);
        Test.assertEqual(copy[i], ReminderCheckUi.problem(status, 100));
    }
    Storage.setValue(RingStore.MIRROR_ERROR_KEY, "old failure");
    Test.assertEqual("Reminder data invalid", ReminderCheckUi.problem(BackgroundStatus.empty(), 100));
    v15Clear();
    return true;
}

(:test)
function v15SettingsRowWithReminder2OnAndOff(logger as Test.Logger) as Boolean {
    v15Clear();
    var state = ScheduleModel.defaultState();
    var reminders = state[:reminders] as Lang.Dictionary;
    reminders[:reminder2Enabled] = false;
    Test.assertEqual(8, Menus.settingsFocusForId(state, :reminderCheck));
    Test.assertEqual(:reminderCheck, Menus.settingsMenu(state).getItem(8).getId());
    reminders[:reminder2Enabled] = true;
    Test.assertEqual(9, Menus.settingsFocusForId(state, :reminderCheck));
    Test.assertEqual(:reminderCheck, Menus.settingsMenu(state).getItem(9).getId());
    v15Clear();
    return true;
}

(:test)
function v15QueuedTestWaitsForEveryReminderKind(logger as Test.Logger) as Boolean {
    var fixtures = [:backgroundFree, :backgroundTemp, :backgroundFourWeeks,
        :backgroundOverdue, :backgroundReminder1, :backgroundDayBefore, :backgroundReminder2];
    for (var i = 0; i < fixtures.size(); i += 1) {
        var mirror = v15Seed(fixtures[i]);
        BackgroundStatus.queueTest();
        var status = v15Check();
        Test.assertEqual(BackgroundStatus.ALERT_SHOWN, status[2]);
        Test.assertEqual(i, status[6]);
        Test.assertEqual(true, Storage.getValue(BackgroundStatus.TEST_KEY));
        Test.assertEqual(true, Storage.getValue("debugBackgroundNotifyDismiss"));
        Test.assertEqual(1, Storage.getValue("debugBackgroundNotifyCalls"));
        Test.assert(!v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
        Test.assert(BackgroundStatus.valid(status));
    }
    v15Clear();
    return true;
}

(:test)
function v15QueuedTestFollowsRealReminderAtNothingDue(logger as Test.Logger) as Boolean {
    v15Seed(:backgroundDayBefore);
    BackgroundStatus.queueTest();
    Test.assertEqual(5, v15Check()[6]);
    Test.assertEqual(true, Storage.getValue(BackgroundStatus.TEST_KEY));
    var marked = Storage.getValue(RingStore.BACKGROUND_KEY);
    var canonical = Storage.getValue(RingStore.STATE_KEY);
    Test.assertEqual(BackgroundStatus.TEST, v15Check()[6]);
    Test.assert(Storage.getValue(BackgroundStatus.TEST_KEY) == null);
    Test.assertEqual(false, Storage.getValue("debugBackgroundNotifyDismiss"));
    Test.assertEqual(2, Storage.getValue("debugBackgroundNotifyCalls"));
    Test.assert(v15Same(marked, Storage.getValue(RingStore.BACKGROUND_KEY)));
    Test.assert(v15Same(canonical, Storage.getValue(RingStore.STATE_KEY)));
    Test.assertEqual(BackgroundStatus.NOTHING_DUE, v15Check()[2]);
    Test.assertEqual(2, Storage.getValue("debugBackgroundNotifyCalls"));
    v15Clear();
    return true;
}

(:test)
function v15QueuedTestRemainsAfterRealNotifyOrSaveFailure(logger as Test.Logger) as Boolean {
    var fixtures = [:backgroundThrow, :backgroundSaveFailure];
    var stages = [BackgroundStatus.NOTIFY, BackgroundStatus.SAVE];
    for (var i = 0; i < fixtures.size(); i += 1) {
        var mirror = v15Seed(fixtures[i]);
        BackgroundStatus.queueTest();
        var status = v15Check();
        Test.assertEqual(BackgroundStatus.FAILED, status[2]);
        Test.assertEqual(stages[i], status[3]);
        Test.assertEqual(4, status[4]);
        Test.assertEqual(true, Storage.getValue(BackgroundStatus.TEST_KEY));
        Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
        Test.assert(BackgroundStatus.valid(status));
    }
    v15Clear();
    return true;
}

(:test)
function v15QueuedTestWithNoCycleKeepsLedger(logger as Test.Logger) as Boolean {
    var mirror = v15Seed(:backgroundNoActive);
    var canonical = Storage.getValue(RingStore.STATE_KEY);
    BackgroundStatus.queueTest();
    Test.assertEqual(BackgroundStatus.TEST, v15Check()[6]);
    Test.assert(Storage.getValue(BackgroundStatus.TEST_KEY) == null);
    Test.assertEqual(false, Storage.getValue("debugBackgroundNotifyDismiss"));
    Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
    Test.assert(v15Same(canonical, Storage.getValue(RingStore.STATE_KEY)));
    Test.assertEqual(BackgroundStatus.NO_ACTIVE, v15Check()[2]);
    Test.assertEqual(1, Storage.getValue("debugBackgroundNotifyCalls"));
    v15Clear();
    return true;
}

(:test)
function v15QueuedTestPreservesMirrorAndLoadProblems(logger as Test.Logger) as Boolean {
    var fixtures = [:backgroundNil, :backgroundCorrupt, :backgroundMismatch,
        :backgroundLoadFailure, :backgroundEvaluateFailure];
    var outcomes = [BackgroundStatus.MIRROR_INVALID, BackgroundStatus.MIRROR_INVALID,
        BackgroundStatus.CANONICAL_MISMATCH, BackgroundStatus.FAILED, BackgroundStatus.FAILED];
    var stages = [BackgroundStatus.NONE, BackgroundStatus.NONE, BackgroundStatus.NONE,
        BackgroundStatus.LOAD, BackgroundStatus.EVALUATE];
    for (var i = 0; i < fixtures.size(); i += 1) {
        v15Seed(fixtures[i]);
        var mirror = Storage.getValue(RingStore.BACKGROUND_KEY);
        var canonical = Storage.getValue(RingStore.STATE_KEY);
        BackgroundStatus.queueTest();
        var status = v15Check();
        Test.assertEqual(outcomes[i], status[2]);
        Test.assertEqual(stages[i], status[3]);
        Test.assertEqual(BackgroundStatus.TEST, status[4]);
        Test.assertEqual(BackgroundStatus.TEST, status[6]);
        Test.assertEqual(currentUtc(), status[5]);
        Test.assert(BackgroundStatus.valid(status));
        Test.assert(v15Same(status, BackgroundStatus.load()));
        Test.assert(ReminderCheckUi.problem(status, currentUtc()) != null);
        Test.assert(Storage.getValue(BackgroundStatus.TEST_KEY) == null);
        Test.assertEqual(false, Storage.getValue("debugBackgroundNotifyDismiss"));
        Test.assertEqual(1, Storage.getValue("debugBackgroundNotifyCalls"));
        Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
        Test.assert(v15Same(canonical, Storage.getValue(RingStore.STATE_KEY)));
        if (i < 3) { Test.assert(Storage.getValue(RingStore.MIRROR_ERROR_KEY) != null); }
    }
    v15Clear();
    return true;
}

(:test)
function v15FailedTestAlsoPreservesOriginalProblem(logger as Test.Logger) as Boolean {
    var mirror = v15Seed(:backgroundMismatch);
    BackgroundStatus.queueTest();
    Storage.setValue("debugBackgroundThrow", true);
    var status = v15Check();
    Test.assertEqual(BackgroundStatus.CANONICAL_MISMATCH, status[2]);
    Test.assertEqual(BackgroundStatus.NONE, status[3]);
    Test.assertEqual(BackgroundStatus.TEST, status[4]);
    Test.assert(status[5] == null);
    Test.assert(BackgroundStatus.valid(status));
    Test.assert(Storage.getValue(BackgroundStatus.TEST_KEY) == null);
    Test.assert(v15Same(mirror, Storage.getValue(RingStore.BACKGROUND_KEY)));
    Test.assertEqual("Reminder data mismatch", ReminderCheckUi.problem(status, currentUtc()));
    v15Clear();
    return true;
}
