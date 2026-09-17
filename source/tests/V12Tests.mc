import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Test;

(:test)
function v12PickerMinuteColumnContainsEveryMinute(logger as Test.Logger) as Boolean {
    var minutes = PickerValues.minuteEntries();
    Test.assertEqual(60, minutes.size());
    Test.assertEqual(0, minutes[0]);
    Test.assertEqual(7, minutes[7]);
    Test.assertEqual(59, minutes[59]);
    return true;
}

(:test)
function v12QuarterHourRoundingWrapsAndUsesNearestEntry(logger as Test.Logger) as Boolean {
    Test.assertEqual(0, SettingsBridge.roundToQuarter(0));
    Test.assertEqual(0, SettingsBridge.roundToQuarter(7));
    Test.assertEqual(15, SettingsBridge.roundToQuarter(8));
    Test.assertEqual(15, SettingsBridge.roundToQuarter(22));
    Test.assertEqual(30, SettingsBridge.roundToQuarter(23));
    Test.assertEqual(0, SettingsBridge.roundToQuarter(1439));
    return true;
}

(:test)
function v12ListValueRoundTripsHourAndMinute(logger as Test.Logger) as Boolean {
    var samples = [0, 15, 9 * 60, (12 * 60) + 30, (23 * 60) + 45];
    for (var i = 0; i < samples.size(); i += 1) {
        var parts = SettingsBridge.partsFromMinutes(samples[i]);
        Test.assertEqual(samples[i], SettingsBridge.minutesFromParts(parts[0], parts[1]));
        Test.assert(SettingsBridge.validListMinutes(samples[i]));
    }
    Test.assert(!SettingsBridge.validListMinutes(7));
    Test.assert(!SettingsBridge.validListMinutes(1440));
    return true;
}

(:test)
function v12NativeDateUsesUtcCalendarFieldsNotLocalInstant(logger as Test.Logger) as Boolean {
    // In the America/New_York test simulator, this UTC instant is still the
    // previous local evening. Native date values nevertheless mean March 8.
    var nativeDate = CalendarMath.utc(2026, 3, 8, 0, 0, 0);
    var localInstant = CalendarMath.localFields(nativeDate);
    var date = SettingsBridge.dateFields(nativeDate) as Lang.Dictionary;
    Test.assertEqual(8, date[:day]);
    Test.assert(localInstant[:day] != date[:day]);
    var parsed = SettingsBridge.parseInsertionProperties(nativeDate, 90,
        CalendarMath.utc(2026, 12, 1, 0, 0, 0)) as Lang.Dictionary;
    assertLocalDateTime(parsed[:utc], 2026, 3, 8, 1, 30);
    return true;
}

(:test)
function v12NativeDateAndTimeRespectDstOffsets(logger as Test.Logger) as Boolean {
    var now = CalendarMath.utc(2026, 12, 1, 0, 0, 0);
    var winterDate = CalendarMath.utc(2026, 1, 15, 0, 0, 0);
    var summerDate = CalendarMath.utc(2026, 7, 15, 0, 0, 0);
    var winter = SettingsBridge.parseInsertionProperties(winterDate, 9 * 60, now) as Lang.Dictionary;
    var summer = SettingsBridge.parseInsertionProperties(summerDate, 9 * 60, now) as Lang.Dictionary;
    assertLocalDateTime(winter[:utc], 2026, 1, 15, 9, 0);
    assertLocalDateTime(summer[:utc], 2026, 7, 15, 9, 0);
    var winterWall = CalendarMath.utc(2026, 1, 15, 9, 0, 0);
    var summerWall = CalendarMath.utc(2026, 7, 15, 9, 0, 0);
    Test.assertEqual(5 * 3600, winter[:utc] - winterWall);
    Test.assertEqual(4 * 3600, summer[:utc] - summerWall);
    var gapDate = CalendarMath.utc(2026, 3, 8, 0, 0, 0);
    Test.assert(SettingsBridge.parseInsertionProperties(gapDate, 150, now) == null);
    return true;
}

(:test)
function v12LegacyPropertiesMigrateNumericsAndIso(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    Properties.setValue("settingsSchemaVersion", 0);
    Properties.setValue("reminderHour", 9);
    Properties.setValue("reminderMinute", 7);
    Properties.setValue("reminder2Hour", 20);
    Properties.setValue("reminder2Minute", 52);
    Properties.setValue("insertionIso", "2026-09-14T23:59");
    Test.assert(SettingsBridge.migrateLegacyProperties(state,
        testWall(2026, 9, 16, 12, 0)));
    var reminders = state[:reminders] as Lang.Dictionary;
    Test.assertEqual(9, reminders[:reminder1Hour]);
    Test.assertEqual(7, reminders[:reminder1Minute]);
    Test.assertEqual(20, reminders[:reminder2Hour]);
    Test.assertEqual(52, reminders[:reminder2Minute]);
    Test.assertEqual(9 * 60, Properties.getValue("reminder1Minutes"));
    Test.assertEqual((20 * 60) + 45, Properties.getValue("reminder2Minutes"));
    Test.assertEqual("2026-09-15T00:00", SettingsBridge.isoForPropertyPair(
        Properties.getValue("insertionDate"), Properties.getValue("insertionTime")));
    Test.assertEqual(2, Properties.getValue("settingsSchemaVersion"));
    return true;
}

(:test)
function v12WatchMirrorRoundsPropertiesButKeepsCanonicalMinutes(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var reminders = state[:reminders] as Lang.Dictionary;
    reminders[:reminder1Hour] = 9;
    reminders[:reminder1Minute] = 7;
    var inserted = testWall(2026, 9, 14, 10, 8);
    ScheduleModel.insertOrReplace(state, inserted);
    SettingsBridge.mirrorAll(state);
    Test.assertEqual(9 * 60, Properties.getValue("reminder1Minutes"));
    Test.assertEqual(7, reminders[:reminder1Minute]);
    Test.assertEqual("2026-09-14T10:15", SettingsBridge.isoForPropertyPair(
        Properties.getValue("insertionDate"), Properties.getValue("insertionTime")));
    Test.assertEqual(inserted, (state[:active] as Lang.Dictionary)[:insertionUtc]);
    return true;
}

(:test)
function v12PhoneQuarterHourIsAcceptedExactly(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    SettingsBridge.mirrorAll(state);
    Properties.setValue("reminder1Minutes", (9 * 60) + 15);
    Test.assert(SettingsBridge.observe(state, currentUtc()) == null);
    var reminders = state[:reminders] as Lang.Dictionary;
    Test.assertEqual(9, reminders[:reminder1Hour]);
    Test.assertEqual(15, reminders[:reminder1Minute]);
    return true;
}

(:test)
function v12PickerDateClampCoversMonthAndLeapYear(logger as Test.Logger) as Boolean {
    Test.assertEqual(28, PickerValues.clampDay(2026, 2, 31));
    Test.assertEqual(29, PickerValues.clampDay(2028, 2, 31));
    Test.assertEqual(28, PickerValues.clampDay(2100, 2, 29));
    Test.assertEqual(29, PickerValues.clampDay(2000, 2, 31));
    Test.assertEqual(30, PickerValues.clampDay(2026, 9, 31));
    Test.assertEqual(31, PickerValues.clampDay(2026, 10, 31));
    return true;
}
