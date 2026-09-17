import Toybox.Application.Properties;
import Toybox.Lang;
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
function uxCClockOverrideMigratesSilentlyToWatchFormat(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var reminders = state[:reminders] as Lang.Dictionary;
    reminders[:clockFormat] = 12;
    Properties.setValue("settingsSchemaVersion", 2);
    Properties.setValue("clockFormat", 24);
    Test.assert(SettingsBridge.migrateLegacyProperties(state,
        testWall(2026, 9, 16, 12, 0)));
    Test.assertEqual(0, (state[:reminders] as Lang.Dictionary)[:clockFormat]);
    Test.assertEqual(0, Properties.getValue("clockFormat"));
    Test.assertEqual(3, Properties.getValue("settingsSchemaVersion"));
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
