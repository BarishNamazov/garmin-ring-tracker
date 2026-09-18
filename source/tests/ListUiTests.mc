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
    cycle[:removalDeltaSeconds] = 2 * CalendarMath.SECONDS_PER_DAY;
    Test.assertEqual("Out 2d late", ListUi.varianceText(cycle));
    Test.assertEqual(ListUi.VARIANCE_AMBER, ListUi.varianceLevel(cycle));
    cycle[:removalDeltaSeconds] = 3 * CalendarMath.SECONDS_PER_DAY;
    Test.assertEqual(ListUi.VARIANCE_AMBER, ListUi.varianceLevel(cycle));
    cycle[:removalDeltaSeconds] = 7 * CalendarMath.SECONDS_PER_DAY;
    Test.assertEqual(ListUi.VARIANCE_AMBER, ListUi.varianceLevel(cycle));
    cycle[:removalDeltaSeconds] = 8 * CalendarMath.SECONDS_PER_DAY;
    Test.assertEqual(ListUi.VARIANCE_RED, ListUi.varianceLevel(cycle));
    return true;
}

(:test)
function listJanuaryCueMovesToColumnHeader(logger as Test.Logger) as Boolean {
    var rows = [
        {:inUtc=>testWall(2026, 12, 1, 9, 0), :outUtc=>testWall(2026, 12, 22, 9, 0)},
        {:inUtc=>testWall(2027, 1, 1, 9, 0), :outUtc=>testWall(2027, 1, 22, 9, 0)}
    ];
    var january = ListUi.firstJanuaryUtc(rows) as Lang.Number;
    Test.assertEqual((rows[1] as Lang.Dictionary)[:inUtc], january);
    Test.assert(ListUi.januaryIsIn(rows, january));
    Test.assertEqual("IN · 2027", ListUi.yearHeader("IN", january));
    Test.assertEqual("1 Jan", Ui.compactDate(january));
    return true;
}

(:test)
function listJanuaryCueCanBelongToOutColumn(logger as Test.Logger) as Boolean {
    var rows = [
        {:inUtc=>testWall(2026, 12, 11, 9, 0), :outUtc=>testWall(2027, 1, 1, 9, 0)}
    ];
    var january = ListUi.firstJanuaryUtc(rows) as Lang.Number;
    Test.assert(!ListUi.januaryIsIn(rows, january));
    Test.assertEqual("OUT · 2027", ListUi.yearHeader("OUT", january));
    return true;
}

(:test)
function listLatenessUsesHoursUntilFortyEightHours(logger as Test.Logger) as Boolean {
    Test.assertEqual("29h late", ListUi.overdueText(29 * CalendarMath.SECONDS_PER_HOUR));
    Test.assertEqual("47h late", ListUi.overdueText(47 * CalendarMath.SECONDS_PER_HOUR));
    Test.assertEqual("2d late", ListUi.overdueText(48 * CalendarMath.SECONDS_PER_HOUR));
    Test.assertEqual("— projected if removed today", Ui.s(Rez.Strings.ListIfRemovedToday));
    Test.assertEqual("Cycle 25 · NOW", Ui.fmt(Rez.Strings.ListCurrentCycleTemplate, [25]));
    return true;
}

(:test)
function listDetailValuesAreCompactAndBriefOutsHaveUnit(logger as Test.Logger) as Boolean {
    var cycle = ScheduleModel.newCycle(25, testWall(2026, 9, 30, 12, 26),
        ScheduleModel.defaultRegimen());
    var intervals = cycle[:temporaryOut] as Lang.Array;
    var insertion = cycle[:insertionUtc] as Lang.Number;
    intervals.add({:outUtc=>insertion + 100, :backInUtc=>insertion + 200,
        :phaseWeekAtStart=>1, :phaseWeekAtEnd=>1, :thresholdCode=>"under3h"});
    var summary = cycle[:temporaryOutSummary] as Lang.Dictionary;
    summary[:shortIntervalCount] = 31;
    Test.assertEqual("30 Sep · 12:26 PM", ListUi.detailTimestamp(insertion, 12));
    Test.assertEqual("due 21 Oct", ListUi.dueText(cycle[:removeDueUtc] as Lang.Number));
    Test.assertEqual("32×", ListUi.briefOutText(cycle));
    return true;
}

(:test)
function listDemoFixtureRetainsTwentyFourValidCycles(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    state[:setupStep] = 3;
    var active = ScheduleModel.insertOrReplace(state, testWall(2026, 12, 1, 9, 0));
    addListDemoHistory(state, active);
    Test.assert(ScheduleModel.validState(state));
    Test.assertEqual(24, (state[:history] as Lang.Array).size());
    Test.assertEqual(25, active[:cycleId]);
    var latest = (state[:history] as Lang.Array<Lang.Dictionary>)[23];
    Test.assertEqual(-15 * CalendarMath.SECONDS_PER_DAY, latest[:removalDeltaSeconds]);
    Test.assertEqual(15 * CalendarMath.SECONDS_PER_DAY, latest[:insertionDeltaSeconds]);
    var amber = (state[:history] as Lang.Array<Lang.Dictionary>)[22];
    Test.assertEqual(-2 * CalendarMath.SECONDS_PER_DAY, amber[:removalDeltaSeconds]);
    Test.assertEqual(2 * CalendarMath.SECONDS_PER_DAY, amber[:insertionDeltaSeconds]);
    Test.assertEqual(ListUi.VARIANCE_AMBER, ListUi.varianceLevel(amber));
    return true;
}

(:test)
function listMaximumFixtureStressesTimeAndBriefOutCount(logger as Test.Logger) as Boolean {
    var state = demoState(:maximumState, testWall(2026, 1, 1, 0, 0));
    var active = state[:active] as Lang.Dictionary;
    var insertion = CalendarMath.localFields(active[:insertionUtc] as Lang.Number);
    Test.assertEqual(12, insertion[:hour]);
    Test.assertEqual(26, insertion[:minute]);
    Test.assertEqual(12, (state[:reminders] as Lang.Dictionary)[:clockFormat]);
    Test.assertEqual("32×", ListUi.briefOutText(active));
    return true;
}

(:test)
function listRoundEdgeMovesInwardNearBottomChord(logger as Test.Logger) as Boolean {
    var center = ListUi.roundRightEdge(390, 390, 195, 10, 7);
    var lower = ListUi.roundRightEdge(390, 390, 340, 10, 7);
    Test.assert(center > lower);
    Test.assert(lower < 330);
    var scrollX = ListUi.scrollIndicatorX(390, 390, 68, 328, 2);
    Test.assert(scrollX < 350);
    Test.assert(scrollX > 320);
    return true;
}
