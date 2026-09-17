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
    Test.assertEqual("1d 23h", Ui.mainCountdownText(47 * CalendarMath.SECONDS_PER_HOUR));
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
    Test.assertEqual("Wed 30 Sep", Ui.shortDate(testWall(2026, 9, 30, 23, 59)));
    return true;
}
