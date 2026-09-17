import Toybox.Lang;
import Toybox.Test;

(:test)
function listDateRangeUsesCompactArrowFormat(logger as Test.Logger) as Boolean {
    var inserted = testWall(2026, 9, 30, 9, 0);
    var removed = testWall(2026, 10, 21, 9, 0);
    Test.assertEqual("30 Sep → 21 Oct", ListUi.dateRange(inserted, removed));
    return true;
}

(:test)
function listCurrentRangeUsesPlannedRemoval(logger as Test.Logger) as Boolean {
    var cycle = ScheduleModel.newCycle(25, testWall(2026, 9, 30, 9, 0),
        ScheduleModel.defaultRegimen());
    Test.assertEqual(cycle[:removeDueUtc], ListUi.historyEndUtc(cycle, true));
    Test.assert(ListUi.historyEndIsPlanned(cycle, true));
    Test.assert(!ListUi.historyEndIsPlanned(cycle, false));
    return true;
}

(:test)
function listVarianceIsScopedToCyclesOwnEvents(logger as Test.Logger) as Boolean {
    var cycle = ScheduleModel.newCycle(24, testWall(2026, 9, 30, 9, 0),
        ScheduleModel.defaultRegimen());
    cycle[:removalDeltaSeconds] = -15 * CalendarMath.SECONDS_PER_DAY;
    cycle[:insertionPlanUtc] = cycle[:insertionUtc] - (6 * CalendarMath.SECONDS_PER_DAY);
    cycle[:insertionDeltaSeconds] = 6 * CalendarMath.SECONDS_PER_DAY;
    cycle[:nextInsertionDeltaSeconds] = -30 * CalendarMath.SECONDS_PER_DAY;
    Test.assertEqual("Out 15d early · In 6d late", ListUi.varianceText(cycle));
    Test.assertEqual(ListUi.VARIANCE_RED, ListUi.varianceLevel(cycle));
    return true;
}

(:test)
function listVarianceSeverityKeepsSmallDeltasAmber(logger as Test.Logger) as Boolean {
    var cycle = ScheduleModel.newCycle(2, testWall(2026, 8, 1, 9, 0),
        ScheduleModel.defaultRegimen());
    cycle[:removalDeltaSeconds] = 3 * CalendarMath.SECONDS_PER_DAY;
    Test.assertEqual("Out 3d late", ListUi.varianceText(cycle));
    Test.assertEqual(ListUi.VARIANCE_AMBER, ListUi.varianceLevel(cycle));
    cycle[:removalDeltaSeconds] = 8 * CalendarMath.SECONDS_PER_DAY;
    Test.assertEqual(ListUi.VARIANCE_RED, ListUi.varianceLevel(cycle));
    return true;
}

(:test)
function listJanuaryCueAppearsOnceAtYearBoundary(logger as Test.Logger) as Boolean {
    var rows = [
        {:inUtc=>testWall(2026, 12, 1, 9, 0), :outUtc=>testWall(2026, 12, 22, 9, 0)},
        {:inUtc=>testWall(2027, 1, 1, 9, 0), :outUtc=>testWall(2027, 1, 22, 9, 0)}
    ];
    var january = ListUi.firstJanuaryUtc(rows) as Lang.Number;
    Test.assertEqual((rows[1] as Lang.Dictionary)[:inUtc], january);
    Test.assertEqual("1 Jan '27", ListUi.dateWithYearCue(january, true));
    Test.assertEqual("22 Jan", ListUi.dateWithYearCue(
        (rows[1] as Lang.Dictionary)[:outUtc], false));
    return true;
}
