import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

(:test)
function uxCConfirmationFactsUseFlooredWrittenUnits(logger as Test.Logger) as Boolean {
    Test.assertEqual("Due in 2 days", Menus.scheduleFact((2 * 86400) + 86399));
    Test.assertEqual("Due 5 hours ago", Menus.scheduleFact(-((5 * 3600) + 3599)));
    Test.assertEqual("Due in 1 day", Menus.scheduleFact(86400));
    Test.assertEqual("Due 1 hour ago", Menus.scheduleFact(-3600));
    return true;
}

(:test)
function uxCMenuTitlesDescribeCurrentState(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 9, 1, 9, 0);
    Test.assertEqual("No ring logged", Menus.mainTitle(state, start));
    var active = ScheduleModel.insertOrReplace(state, start);
    Test.assertEqual("Ring in · day 5", Menus.mainTitle(state,
        testWall(2026, 9, 5, 9, 0)));
    var removed = testWall(2026, 9, 22, 9, 0);
    Test.assert(ScheduleModel.recordRemoval(active, removed,
        state[:regimen] as Lang.Dictionary));
    Test.assertEqual("Ring-free · day 3", Menus.mainTitle(state,
        testWall(2026, 9, 24, 9, 0)));

    var temporary = ScheduleModel.defaultState();
    var tempActive = ScheduleModel.insertOrReplace(temporary, start);
    var out = testWall(2026, 9, 5, 8, 0);
    Test.assert(ScheduleModel.startTemporaryOut(tempActive, out));
    Test.assertEqual("Ring out · 10 min left", Menus.mainTitle(temporary, out + (2 * 3600) + (50 * 60)));
    Test.assertEqual("Ring out · 10 min over", Menus.mainTitle(temporary, out + (3 * 3600) + (10 * 60)));
    return true;
}

(:test)
function uxCPickerGeometryFitsEveryTarget(logger as Test.Logger) as Boolean {
    var widths = [390, 416, 454];
    for (var i = 0; i < widths.size(); i += 1) {
        var width = widths[i];
        Test.assertEqual(width / 2, PickerScreen.xForColumn(width, 1, 0));
        Test.assertEqual(Math.round(width * 0.25).toNumber(),
            PickerScreen.xForColumn(width, 3, 0));
        Test.assertEqual(Math.round(width * 0.50).toNumber(),
            PickerScreen.xForColumn(width, 3, 1));
        Test.assertEqual(Math.round(width * 0.75).toNumber(),
            PickerScreen.xForColumn(width, 3, 2));
        Test.assert(PickerValues.columnWidth(width, 3) * 3 <= width);
        Test.assert(PickerValues.columnWidth(width, 2) * 2 <= width);
        Test.assert(PickerValues.columnWidth(width, 3) >= (width * 27) / 100);
        Test.assert(PickerValues.columnWidth(width, 2) >= (width * 34) / 100);
        Test.assert(PickerValues.separatorWidth(width) > 0);
        Test.assert(PickerValues.arrowHeight(width) <= (width * 12) / 100);
    }
    return true;
}

(:test)
function uxCRoundTwoCopyContracts(logger as Test.Logger) as Boolean {
    Test.assertEqual("Take out briefly", Ui.s(Rez.Strings.MenuTakeOutBriefly));
    Test.assertEqual("Back in within 3 hours", Ui.s(Rez.Strings.MenuBackWithinThreeHours));
    Test.assertEqual("Starts ring-free week", Ui.s(Rez.Strings.MenuStartsRingFree));
    Test.assertEqual("Starts new 3-week cycle", Ui.s(Rez.Strings.MenuStartsNewCycle));
    Test.assertEqual("Resumes current cycle", Ui.s(Rez.Strings.MenuResumesCycle));
    Test.assertEqual("Counts from removal time", Ui.s(Rez.Strings.MenuCountsFromRemoval));
    Test.assertEqual("Days worn", Ui.s(Rez.Strings.SettingsRingIn));
    Test.assertEqual("Days out", Ui.s(Rez.Strings.SettingsRingOut));
    Test.assertEqual("Ring in", Ui.s(Rez.Strings.TextRegimenIn));
    Test.assertEqual("Ring out", Ui.s(Rez.Strings.TextRegimenOut));
    Test.assertEqual("I understand", Ui.s(Rez.Strings.TextUnderstand));
    Test.assertEqual("Done", Ui.s(Rez.Strings.TextDone));
    Test.assertEqual("OK", Ui.s(Rez.Strings.TextOK));
    Test.assertEqual("What happened?", Ui.s(Rez.Strings.TextWhatHappened));
    Test.assertEqual("Due Wed 16 Sep",
        Ui.fmt(Rez.Strings.TextDueDate, ["Wed 16 Sep"]));
    Test.assertEqual("Use backup 7 days", Ui.s(Rez.Strings.TextBackupDirective));
    Test.assertEqual("Change removal time?",
        Ui.s(Rez.Strings.ConfirmChangeRemovalTitle));
    Test.assertEqual("Change removal time?\n15 Sep · 12:26 PM",
        Ui.fmt(Rez.Strings.ConfirmChangeRemoval, ["15 Sep · 12:26 PM"]));
    Test.assertEqual("Not removed yet", Ui.s(Rez.Strings.EditNotRemovedYet));
    return true;
}

(:test)
function uxCClockOverrideMigratesSilentlyToWatchFormat(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var reminders = state[:reminders] as Lang.Dictionary;
    reminders[:clockFormat] = 12;
    reminders[:overdueRepeatHours] = 12;
    Properties.setValue("settingsSchemaVersion", 2);
    Properties.setValue("clockFormat", 24);
    Properties.setValue("overdueRepeatHours", 12);
    Test.assert(SettingsBridge.migrateLegacyProperties(state,
        testWall(2026, 9, 16, 12, 0)));
    Test.assertEqual(0, (state[:reminders] as Lang.Dictionary)[:clockFormat]);
    Test.assertEqual(24, (state[:reminders] as Lang.Dictionary)[:overdueRepeatHours]);
    Test.assertEqual(0, Properties.getValue("clockFormat"));
    Test.assertEqual(24, Properties.getValue("overdueRepeatHours"));
    Test.assertEqual(3, Properties.getValue("settingsSchemaVersion"));
    return true;
}

(:test)
function uxCDebugPickerFixturesCoverBothWatchFormats(logger as Test.Logger) as Boolean {
    var reminders = ScheduleModel.defaultReminders();
    reminders[:clockFormat] = 12;
    Test.assert(!pickerUses24Hour(reminders));
    reminders[:clockFormat] = 24;
    Test.assert(pickerUses24Hour(reminders));
    return true;
}

(:test)
function uxCRepeatOffSuppressesMissedReminderSlots(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var start = testWall(2026, 9, 1, 9, 0);
    var active = ScheduleModel.insertOrReplace(state, start);
    var reminders = state[:reminders] as Lang.Dictionary;
    reminders[:overdueRepeatHours] = 24;
    MenuActions.syncRepeatPolicy(state, start);
    var ledger = state[:reminderLedger] as Lang.Dictionary;
    Test.assertEqual(ReminderPolicy.actionKey(ScheduleModel.deriveStatus(start,
        active, state[:regimen] as Lang.Dictionary)), ledger[:actionKey]);
    Test.assertEqual(2147483647, ledger[:lastOverdueSlot]);
    reminders[:overdueRepeatHours] = 6;
    MenuActions.syncRepeatPolicy(state, start);
    Test.assert(ledger[:lastOverdueSlot] == null);
    return true;
}

(:test)
function uxCUndoRingOutRemovesOpenEntryAndReminderIdentity(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var active = ScheduleModel.insertOrReplace(state, testWall(2026, 9, 1, 9, 0));
    var out = testWall(2026, 9, 5, 12, 0);
    Test.assert(ScheduleModel.startTemporaryOut(active, out));
    var ledger = state[:reminderLedger] as Lang.Dictionary;
    ledger[:lastTempOutSlot] = 2;
    ledger[:tempOutIdentity] = out;
    Test.assert(MenuActions.undoRingOut(active, ledger));
    Test.assert(ScheduleModel.tempOpen(active) == null);
    Test.assertEqual(0, (active[:temporaryOut] as Lang.Array).size());
    Test.assert(ledger[:lastTempOutSlot] == null);
    Test.assert(ledger[:tempOutIdentity] == null);
    Test.assert(ScheduleModel.validState(state));
    return true;
}

(:test)
function uxCKeepOutStartsRingFreeWeekAtOriginalOutTime(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var active = ScheduleModel.insertOrReplace(state, testWall(2026, 9, 1, 9, 0));
    var out = testWall(2026, 9, 5, 12, 0);
    Test.assert(ScheduleModel.startTemporaryOut(active, out));
    Test.assert(MenuActions.keepOut(active, state[:regimen] as Lang.Dictionary,
        state[:reminderLedger] as Lang.Dictionary));
    Test.assertEqual(out, active[:removalUtc]);
    Test.assertEqual(0, (active[:temporaryOut] as Lang.Array).size());
    Test.assertEqual(CalendarMath.addLocalCalendarDays(out, 7)[:utc], active[:insertDueUtc]);
    Test.assertEqual(:ringFree, ScheduleModel.deriveStatus(out, active,
        state[:regimen] as Lang.Dictionary)[:phase]);
    Test.assert(ScheduleModel.validState(state));
    return true;
}
