import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;
import Toybox.WatchUi;

(:testhelper)
class PolishInputProbe extends ScreenInputDelegate {
    var last as Lang.Symbol?;
    function initialize() { ScreenInputDelegate.initialize(); last = null; }
    function onSelect() as Lang.Boolean { last = :select; return true; }
    function onBack() as Lang.Boolean { last = :back; return true; }
    function onPreviousPage() as Lang.Boolean { last = :up; return true; }
    function onNextPage() as Lang.Boolean { last = :down; return true; }
}

(:test)
function polishCoordinateSensitiveScreensBypassBehaviorInterception(logger as Test.Logger) as Boolean {
    var delegates = [new RingTimeDelegate(:setReminder, currentUtc(), null),
        new RingDateDelegate(:insert, currentUtc()), new RingNumberDelegate(:setDaysOut),
        new HistoryDelegate(), new DisclaimerDelegate(), new AboutDelegate(),
        new MigrationDelegate(), new RegimenDelegate(), new AlertDelegate(),
        new CompactConfirmationDelegate(:adjustRemoval, currentUtc(), null)];
    for (var i = 0; i < delegates.size(); i += 1) {
        Test.assert(delegates[i] instanceof ScreenInputDelegate);
        Test.assert(!(delegates[i] instanceof WatchUi.BehaviorDelegate));
    }
    var probe = new PolishInputProbe();
    Test.assert(probe.handleKey(WatchUi.KEY_ENTER));
    Test.assertEqual(:select, probe.last);
    Test.assert(probe.handleKey(WatchUi.KEY_ESC));
    Test.assertEqual(:back, probe.last);
    Test.assert(probe.handleKey(WatchUi.KEY_UP));
    Test.assertEqual(:up, probe.last);
    Test.assert(probe.handleKey(WatchUi.KEY_DOWN));
    Test.assertEqual(:down, probe.last);
    Test.assert(!probe.handleKey(WatchUi.KEY_MENU));
    return true;
}

(:test)
function polishCustomRegimenMenusDoNotPromiseDefaultDurations(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    var regimen = state[:regimen] as Lang.Dictionary;
    Test.assertEqual("Starts new 3-week cycle", Menus.cycleStartLabel(state));
    Test.assertEqual("Starts ring-free week", Menus.ringFreeStartLabel(state));
    regimen[:daysIn] = 35;
    regimen[:daysOut] = 1;
    Test.assertEqual("Starts new cycle", Menus.cycleStartLabel(state));
    Test.assertEqual("Starts ring-free time", Menus.ringFreeStartLabel(state));
    regimen[:daysOut] = 0;
    ScheduleModel.insertOrReplace(state, currentUtc() - 3600);
    var menu = Menus.mainMenu(state);
    Test.assertEqual(:replaceNow, menu.getItem(0).getId());
    return true;
}

(:test)
function polishHistoryFocusCannotEraseHeadingOrAdjacentRows(logger as Test.Logger) as Boolean {
    var sizes = [390, 416, 454];
    for (var i = 0; i < sizes.size(); i += 1) {
        var scale = sizes[i] / 416.0;
        var start = Math.round(82 * scale).toNumber();
        var step = Math.round(92 * scale).toNumber();
        var headerBottom = Math.round(70 * scale).toNumber();
        var gap = Math.round(4 * scale).toNumber();
        var first = HistoryUi.focusBounds(start, step, headerBottom, gap);
        var second = HistoryUi.focusBounds(start + step, step, headerBottom, gap);
        Test.assert(first[0] > headerBottom);
        Test.assert(first[1] <= second[0]);
        Test.assert(first[1] > first[0]);
    }
    // A taller heading still reserves space for its full descenders.
    Test.assertEqual(84, HistoryUi.focusBounds(82, 92, 80, 4)[0]);
    return true;
}

(:test)
function polishPickerButtonsIncreaseUpAndDecreaseDown(logger as Test.Logger) as Boolean {
    var picker = new RingNumberPicker(0, 7, 3, "Days out");
    picker.move(PickerScreen.buttonDelta(false));
    Test.assertEqual(4, picker.value());
    picker.move(PickerScreen.buttonDelta(true));
    Test.assertEqual(3, picker.value());
    var wrapping = new RingNumberPicker(0, 7, 7, "Days out");
    wrapping.move(PickerScreen.buttonDelta(false));
    Test.assertEqual(0, wrapping.value());
    wrapping.move(PickerScreen.buttonDelta(true));
    Test.assertEqual(7, wrapping.value());
    return true;
}

(:test)
function polishTimePickerDirectionsWrapWithoutChangingOtherColumns(logger as Test.Logger) as Boolean {
    var state = getApp().getState();
    var oldReminders = state[:reminders];
    var reminders = ScheduleModel.defaultReminders();
    state[:reminders] = reminders;
    reminders[:clockFormat] = 24;
    var picker = new RingTimePicker(:insert, testWall(2026, 9, 1, 23, 59));
    picker.move(PickerScreen.buttonDelta(false));
    Test.assertEqual(0, picker.hour());
    Test.assertEqual(59, picker.minute());
    picker.move(PickerScreen.buttonDelta(true));
    Test.assertEqual(23, picker.hour());
    picker.setFocus(1);
    picker.move(PickerScreen.buttonDelta(false));
    Test.assertEqual(0, picker.minute());
    Test.assertEqual(23, picker.hour());
    picker.move(PickerScreen.buttonDelta(true));
    Test.assertEqual(59, picker.minute());

    reminders[:clockFormat] = 12;
    var twelve = new RingTimePicker(:insert, testWall(2026, 9, 1, 11, 7));
    twelve.move(PickerScreen.buttonDelta(false));
    Test.assertEqual(0, twelve.hour()); // 12 AM, not an implicit period change
    twelve.setFocus(2);
    twelve.move(PickerScreen.buttonDelta(false));
    Test.assertEqual(12, twelve.hour());
    Test.assertEqual(7, twelve.minute());
    state[:reminders] = oldReminders;
    return true;
}

(:test)
function polishDatePickerDirectionsAndMonthClamping(logger as Test.Logger) as Boolean {
    var year = CalendarMath.localFields(currentUtc())[:year];
    var picker = new RingDatePicker(:insert, testWall(year, 3, 1, 9, 0));
    picker.move(PickerScreen.buttonDelta(false));
    Test.assertEqual(2, picker.day());
    picker.move(PickerScreen.buttonDelta(true));
    picker.move(PickerScreen.buttonDelta(true));
    Test.assertEqual(31, picker.day());
    picker.setFocus(1);
    picker.move(PickerScreen.buttonDelta(false));
    Test.assertEqual(4, picker.month());
    Test.assertEqual(30, picker.day());
    return true;
}

(:test)
function polishPickerTouchTargetsMatchArrowsOnEverySize(logger as Test.Logger) as Boolean {
    var sizes = [390, 416, 454];
    for (var i = 0; i < sizes.size(); i += 1) {
        var size = sizes[i];
        for (var columns = 1; columns <= 3; columns += 1) {
            for (var column = 0; column < columns; column += 1) {
                var x = PickerScreen.xForColumn(size, columns, column);
                var up = PickerScreen.tapTarget(size, size, columns, x, (size * 32) / 100);
                var down = PickerScreen.tapTarget(size, size, columns, x, (size * 68) / 100);
                var value = PickerScreen.tapTarget(size, size, columns, x, size / 2);
                Test.assertEqual(column, up[0]);
                Test.assertEqual(1, up[1]);
                Test.assertEqual(-1, down[1]);
                Test.assertEqual(0, value[1]);
                Test.assert(PickerScreen.tapTarget(size, size, columns, x, size / 10) == null);
                Test.assert(PickerScreen.tapTarget(size, size, columns, x, size - 10) == null);
            }
        }
    }
    return true;
}

(:test)
function polishActionTargetsScaleAndIgnoreBackground(logger as Test.Logger) as Boolean {
    var sizes = [390, 416, 454];
    for (var i = 0; i < sizes.size(); i += 1) {
        var size = sizes[i];
        Test.assert(TouchTargets.action((size * 332) / 416, size));
        Test.assert(!TouchTargets.action((size * 270) / 416, size));
        Test.assert(!TouchTargets.action(size - 5, size));
        Test.assertEqual(0, TouchTargets.regimenFocus((size * 180) / 416, size));
        Test.assertEqual(1, TouchTargets.regimenFocus((size * 234) / 416, size));
        Test.assertEqual(2, TouchTargets.regimenFocus((size * 332) / 416, size));
        Test.assertEqual(-1, TouchTargets.regimenFocus(size / 4, size));
        Test.assertEqual(0, TouchTargets.confirmationChoice((size * 27) / 100,
            (size * 224) / 416, size, size));
        Test.assertEqual(1, TouchTargets.confirmationChoice((size * 73) / 100,
            (size * 224) / 416, size, size));
        Test.assertEqual(-1, TouchTargets.confirmationChoice((size * 73) / 100,
            (size * 128) / 416, size, size));
        Test.assertEqual(-1, TouchTargets.confirmationChoice(size / 2,
            (size * 224) / 416, size, size));
    }
    return true;
}

(:test)
function polishWrappingHandlesExplicitBreaksAndTinyWidths(logger as Test.Logger) as Boolean {
    var reference = Graphics.createBufferedBitmap({:width=>32, :height=>32});
    var bitmap = reference.get() as Graphics.BufferedBitmap;
    var dc = bitmap.getDc();
    var font = Graphics.FONT_SYSTEM_XTINY;
    var lines = Ui.wrap(dc, "First\n\nLast", font, 300);
    Test.assertEqual(3, lines.size());
    Test.assertEqual("First", lines[0]);
    Test.assertEqual("", lines[1]);
    Test.assertEqual("Last", lines[2]);
    Test.assertEqual(2, Ui.wrap(dc, "WW", font, 0).size());
    Test.assertEqual("", Ui.ellipsize(dc, "Long text", font, 0));
    return true;
}

(:test)
function polishParagraphsLeaveSpaceForRoundEdgesAndScrollbar(logger as Test.Logger) as Boolean {
    var reference = Graphics.createBufferedBitmap({:width=>416, :height=>416, :colorDepth=>1});
    var bitmap = reference.get() as Graphics.BufferedBitmap;
    var dc = bitmap.getDc();
    var font = Graphics.FONT_TINY;
    var width = Ui.paragraphWidth(dc, font, Graphics.getFontHeight(font) + 4, 116, 286);
    var scrollbar = ListUi.scrollIndicatorX(416, 416, 116, 286, 2);
    Test.assert(208 + width / 2 <= scrollbar - 10);
    Test.assert(208 + width / 2 <= ListUi.textRightEdge(dc, 116, font, 8));
    var lines = TextScreenLayout.lines(dc, [Ui.s(Rez.Strings.TextFirstRunBody)], font, width, true);
    for (var i = 0; i < lines.size(); i += 1) {
        Test.assert(dc.getTextWidthInPixels(lines[i], font) <= width);
    }
    var shortTrack = Ui.scrollIndicatorMetrics(100, 110, 99, 100, 1, 18);
    Test.assertEqual(100, shortTrack[0]);
    Test.assertEqual(10, shortTrack[1]);
    Test.assert(Ui.scrollIndicatorMetrics(110, 100, 0, 100, 1, 18) == null);
    return true;
}

(:test)
function polishLongOverdueProgressDoesNotOverflow(logger as Test.Logger) as Boolean {
    var start = 1700000000;
    var year = 365 * CalendarMath.SECONDS_PER_DAY;
    Test.assertEqual(150, UpcomingUi.timePosition(start, start + year, start + year / 2, 300));
    Test.assertEqual(300, UpcomingUi.timePosition(start, start + year, start + year, 300));
    Test.assertEqual(0, UpcomingUi.timePosition(start, start + year, start - 1, 300));
    return true;
}

(:test)
function polishSubHourConfirmationFactsUseMinutes(logger as Test.Logger) as Boolean {
    Test.assertEqual("Due in 45 minutes", Menus.scheduleFact(45 * 60));
    Test.assertEqual("Due 59 minutes ago", Menus.scheduleFact(-3599));
    Test.assertEqual("Due in 1 minute", Menus.scheduleFact(60));
    Test.assertEqual("Due 1 minute ago", Menus.scheduleFact(-60));
    Test.assertEqual("Due now", Menus.scheduleFact(0));
    return true;
}

(:test)
function polishGlanceRoundingCarriesMinutesIntoHours(logger as Test.Logger) as Boolean {
    var glance = new RingGlanceView();
    Test.assertEqual("1 h", glance.durationText(3599));
    Test.assertEqual("2 h", glance.durationText(7199));
    Test.assertEqual("2 h 1 min", glance.durationText(7201));
    Test.assertEqual("Now", glance.temporaryText(0));
    Test.assertEqual("2 h over", glance.temporaryText(-7199));
    return true;
}
