import Toybox.Lang;
import Toybox.Test;

(:test)
function mainCountdownUsesDaysOnlyAtFortyEightHours(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual("17d", Ui.mainCountdownText(17 * CalendarMath.SECONDS_PER_DAY));
    Test.assertEqual("2d", Ui.mainCountdownText(2 * CalendarMath.SECONDS_PER_DAY));
    return true;
}

(:test)
function mainCountdownKeepsHoursBetweenOneAndTwoDays(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual("1d 12h", Ui.mainCountdownText(
        CalendarMath.SECONDS_PER_DAY + (12 * CalendarMath.SECONDS_PER_HOUR)));
    Test.assertEqual("1d 23h", Ui.mainCountdownText(47 * CalendarMath.SECONDS_PER_HOUR));
    Test.assertEqual("1d 23h", Ui.mainCountdownText(
        (2 * CalendarMath.SECONDS_PER_DAY) - 1));
    Test.assertEqual("1d", Ui.mainCountdownText(CalendarMath.SECONDS_PER_DAY));
    return true;
}

(:test)
function mainCountdownUsesOneUnitBelowOneDay(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual("14h", Ui.mainCountdownText(14 * CalendarMath.SECONDS_PER_HOUR));
    Test.assertEqual("45m", Ui.mainCountdownText(45 * CalendarMath.SECONDS_PER_MINUTE));
    return true;
}

(:test)
function mainCountdownNeverShowsAZeroRemainingComponent(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual("1m", Ui.mainCountdownText(59));
    Test.assertEqual("Now", Ui.mainCountdownText(0));
    return true;
}

(:test)
function mainLatenessUsesHoursThroughFortySevenHours(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual("29h late", Ui.mainLatenessText(-29 * CalendarMath.SECONDS_PER_HOUR));
    Test.assertEqual("47h late", Ui.mainLatenessText(-47 * CalendarMath.SECONDS_PER_HOUR));
    return true;
}

(:test)
function mainLatenessSwitchesToDaysAtFortyEightHours(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual("2d late", Ui.mainLatenessText(-2 * CalendarMath.SECONDS_PER_DAY));
    Test.assertEqual("2d late", Ui.mainLatenessText(
        -((2 * CalendarMath.SECONDS_PER_DAY) + (23 * CalendarMath.SECONDS_PER_HOUR))));
    return true;
}

(:test)
function mainTemporaryElapsedKeepsHoursAndMinutes(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual("2h 50m", Ui.mainElapsedText(
        (2 * CalendarMath.SECONDS_PER_HOUR) + (50 * CalendarMath.SECONDS_PER_MINUTE)));
    Test.assertEqual("3h 10m", Ui.mainElapsedText(
        (3 * CalendarMath.SECONDS_PER_HOUR) + (10 * CalendarMath.SECONDS_PER_MINUTE)));
    return true;
}

(:test)
function mainTemporaryLimitCopyChangesAtThreeHours(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual("10m left", Ui.mainLimitDeltaText(
        ScheduleModel.TEMP_LIMIT_SECONDS - (10 * CalendarMath.SECONDS_PER_MINUTE)));
    Test.assertEqual("3h limit reached", Ui.mainLimitDeltaText(
        ScheduleModel.TEMP_LIMIT_SECONDS));
    Test.assertEqual("10m over", Ui.mainLimitDeltaText(
        ScheduleModel.TEMP_LIMIT_SECONDS + (10 * CalendarMath.SECONDS_PER_MINUTE)));
    return true;
}

(:test)
function mainSeriousElapsedCopyUsesWholeDays(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual("29d in", Ui.mainWholeDaysText(
        29 * CalendarMath.SECONDS_PER_DAY, Ui.s(Rez.Strings.MainInSuffix)));
    Test.assertEqual("8d out", Ui.mainWholeDaysText(
        8 * CalendarMath.SECONDS_PER_DAY, Ui.s(Rez.Strings.MainOutSuffix)));
    return true;
}

(:test)
function mainLongestDateFixtureUsesExpectedCalendarLabel(logger as Test.Logger) as Lang.Boolean {
    var due = testWall(2026, 9, 30, 12, 26);
    Test.assertEqual("Wed 30 Sep", Ui.shortDate(due));
    Test.assertEqual("12:26 PM", Ui.timeForUtc(due, 12));
    return true;
}

(:test)
function mainDemoFixturesCoverCountdownAndLatenessTiers(logger as Test.Logger) as Lang.Boolean {
    var now = mainDemoReferenceUtc(testWall(2026, 9, 17, 12, 26));
    var dayAndHalf = demoState(:ringIn1d12h, now);
    var fourteen = demoState(:ringIn14h, now);
    var fortyFive = demoState(:ringIn45m, now);
    var lateHours = demoState(:overdue29h, now);
    var lateDays = demoState(:overdue2d, now);
    Test.assertEqual(CalendarMath.SECONDS_PER_DAY
        + (12 * CalendarMath.SECONDS_PER_HOUR),
        ScheduleModel.deriveStatus(now, dayAndHalf[:active],
            dayAndHalf[:regimen])[:secondsRemaining]);
    Test.assertEqual(14 * CalendarMath.SECONDS_PER_HOUR,
        ScheduleModel.deriveStatus(now, fourteen[:active], fourteen[:regimen])[:secondsRemaining]);
    Test.assertEqual(45 * CalendarMath.SECONDS_PER_MINUTE,
        ScheduleModel.deriveStatus(now, fortyFive[:active], fortyFive[:regimen])[:secondsRemaining]);
    Test.assertEqual(-29 * CalendarMath.SECONDS_PER_HOUR,
        ScheduleModel.deriveStatus(now, lateHours[:active], lateHours[:regimen])[:secondsRemaining]);
    Test.assertEqual(-2 * CalendarMath.SECONDS_PER_DAY,
        ScheduleModel.deriveStatus(now, lateDays[:active], lateDays[:regimen])[:secondsRemaining]);
    return true;
}

(:test)
function mainDemoFixturesCoverSeriousTemporaryAndLongDateStates(logger as Test.Logger) as Lang.Boolean {
    var now = mainDemoReferenceUtc(testWall(2026, 9, 17, 12, 26));
    var free = demoState(:ringFree8d, now);
    var worn = demoState(:ringIn29d, now);
    var tempBefore = demoState(:temp250, now);
    var tempAfter = demoState(:temp310, now);
    var warning = demoState(:warningWrapLong, now);
    var longDate = demoState(:clock12Long, now);
    Test.assert(ScheduleModel.deriveStatus(now, free[:active], free[:regimen])[:ringFreeOverSevenDays]);
    Test.assert(ScheduleModel.deriveStatus(now, worn[:active], worn[:regimen])[:ringInOverFourWeeks]);
    Test.assertEqual((2 * CalendarMath.SECONDS_PER_HOUR) + (50 * CalendarMath.SECONDS_PER_MINUTE),
        ScheduleModel.deriveStatus(now, tempBefore[:active], tempBefore[:regimen])[:tempElapsed]);
    Test.assertEqual((3 * CalendarMath.SECONDS_PER_HOUR) + (10 * CalendarMath.SECONDS_PER_MINUTE),
        ScheduleModel.deriveStatus(now, tempAfter[:active], tempAfter[:regimen])[:tempElapsed]);
    Test.assert(ScheduleModel.deriveStatus(now, warning[:active], warning[:regimen])[:clockBeforeInsertion]);
    Test.assert(Ui.s(Rez.Strings.MainClockBeforeInsertion).length() > 60);
    var longDue = (longDate[:active] as Lang.Dictionary)[:removeDueUtc];
    Test.assertEqual("Wed 30 Sep", Ui.shortDate(longDue));
    Test.assertEqual("12:26 PM", Ui.timeForUtc(longDue, 12));
    return true;
}
