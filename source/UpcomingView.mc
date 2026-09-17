import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

module UpcomingUi {
    function boundedTopIndex(value as Lang.Number) as Lang.Number {
        if (value < 0) { return 0; }
        if (value > 3) { return 3; }
        return value;
    }
}

class UpcomingView extends WatchUi.View {
    private var _rows as Lang.Array;
    private var _topIndex as Lang.Number;
    private var _januaryUtc;
    private var _overdueSeconds;

    function initialize() {
        View.initialize();
        _rows = [];
        _topIndex = 0;
        _januaryUtc = null;
        _overdueSeconds = null;
        refresh();
    }

    function onShow() as Void { refresh(); }

    private function refresh() as Void {
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary?;
        _rows = active == null ? [] : ScheduleModel.projectUpcoming(
            active as Lang.Dictionary, state[:regimen] as Lang.Dictionary, 6, currentUtc());
        _januaryUtc = ListUi.firstJanuaryUtc(_rows);
        _overdueSeconds = null;
        if (active != null) {
            var actionDue = (active as Lang.Dictionary)[:removalUtc] == null
                ? (active as Lang.Dictionary)[:removeDueUtc]
                : (active as Lang.Dictionary)[:insertDueUtc];
            var nowUtc = currentUtc();
            if (actionDue != null && actionDue < nowUtc) {
                _overdueSeconds = nowUtc - (actionDue as Lang.Number);
            }
        }
        _topIndex = UpcomingUi.boundedTopIndex(_topIndex);
    }

    function topIndex() as Lang.Number { return _topIndex; }

    function scroll(delta as Lang.Number) as Void {
        _topIndex += delta;
        _topIndex = UpcomingUi.boundedTopIndex(_topIndex);
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        Ui.centered(dc, Ui.px(dc, 40), Ui.s(Rez.Strings.Upcoming),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        if (_rows.size() == 0) {
            Ui.centered(dc, dc.getHeight() / 2, Ui.s(Rez.Strings.SetupNeeded),
                Graphics.FONT_SYSTEM_TINY, Ui.SECONDARY, Ui.px(dc, 270));
            return;
        }

        var xIn = Ui.px(dc, 232);
        var xOut = dc.getWidth() - Ui.px(dc, 64);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xIn, Ui.px(dc, 70), Graphics.FONT_SYSTEM_XTINY,
            Ui.s(Rez.Strings.ListUpcomingIn),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(xOut, Ui.px(dc, 70), Graphics.FONT_SYSTEM_XTINY,
            Ui.s(Rez.Strings.ListUpcomingOut),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        var firstPageWithDivider = _topIndex == 0 && _rows.size() > 1
            && (_rows[1] as Lang.Dictionary)[:ifDoneToday] == true;
        var rowYs = firstPageWithDivider ? [104, 203, 269] : [108, 183, 258];
        for (var visible = 0; visible < 3; visible += 1) {
            var rowIndex = _topIndex + visible;
            if (rowIndex >= _rows.size()) { break; }
            drawRow(dc, _rows[rowIndex] as Lang.Dictionary, rowIndex,
                Ui.px(dc, rowYs[visible]), visible == 0 && rowIndex == 0);
        }
        if (firstPageWithDivider) {
            Ui.centered(dc, Ui.px(dc, 170), Ui.s(Rez.Strings.ListIfRemovedToday),
                Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 250));
        }

        var peekIndex = _topIndex + 3;
        if (peekIndex < _rows.size()) {
            drawRow(dc, _rows[peekIndex] as Lang.Dictionary, peekIndex,
                Ui.px(dc, 363), false);
        }
        Ui.drawScrollIndicator(dc, Ui.px(dc, 72), Ui.px(dc, 348),
            _topIndex, 6, 3, Ui.SECONDARY);
    }

    private function drawRow(dc as Graphics.Dc, row as Lang.Dictionary,
                             rowIndex as Lang.Number, y as Lang.Number,
                             drawCurrentState as Lang.Boolean) as Void {
        var xLeft = Ui.px(dc, 56);
        var xIn = Ui.px(dc, 232);
        var xOut = dc.getWidth() - Ui.px(dc, 64);
        if (rowIndex == 0) {
            dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY,
                Ui.s(Rez.Strings.ListNow),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (rowIndex == 1) {
            dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY,
                Ui.s(Rez.Strings.ListNext),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var inUtc = row[:inUtc] as Lang.Number;
        var outUtc = row[:outUtc] as Lang.Number;
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xIn, y, Graphics.FONT_SYSTEM_SMALL,
            ListUi.dateWithYearCue(inUtc, _januaryUtc != null && inUtc == _januaryUtc),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xOut, y, Graphics.FONT_SYSTEM_SMALL,
            ListUi.dateWithYearCue(outUtc, _januaryUtc != null && outUtc == _januaryUtc),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!drawCurrentState) { return; }
        if (_overdueSeconds != null) {
            dc.setColor(Ui.AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xOut, y + Ui.px(dc, 27), Graphics.FONT_SYSTEM_XTINY,
                ListUi.overdueText(_overdueSeconds as Lang.Number),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        drawCurrentBar(dc, row, y + Ui.px(dc, 45));
    }

    private function drawCurrentBar(dc as Graphics.Dc, row as Lang.Dictionary,
                                    y as Lang.Number) as Void {
        var xLeft = Ui.px(dc, 72);
        var xRight = dc.getWidth() - Ui.px(dc, 72);
        var width = xRight - xLeft;
        var regimen = getApp().getState()[:regimen] as Lang.Dictionary;
        var startUtc = row[:inUtc] as Lang.Number;
        var boundaryUtc = row[:outUtc] as Lang.Number;
        var endUtc = CalendarMath.addLocalCalendarDays(
            boundaryUtc, regimen[:daysOut] as Lang.Number)[:utc] as Lang.Number;
        var total = endUtc - startUtc;
        if (total <= 0) { total = boundaryUtc - startUtc; }
        if (total <= 0) { total = 1; }
        var boundaryX = xLeft + (((boundaryUtc - startUtc) * width) / total);
        if (boundaryX < xLeft) { boundaryX = xLeft; }
        if (boundaryX > xRight) { boundaryX = xRight; }
        var nowX = xLeft + (((currentUtc() - startUtc) * width) / total);
        if (nowX < xLeft) { nowX = xLeft; }
        if (nowX > xRight) { nowX = xRight; }

        dc.setPenWidth(Ui.px(dc, 5));
        dc.setColor(Ui.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(xLeft, y, xRight, y);
        dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(xLeft, y, boundaryX, y);
        if ((regimen[:daysOut] as Lang.Number) > 0) {
            dc.setColor(Ui.RING_FREE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(boundaryX + Ui.px(dc, 2), y, xRight, y);
        }
        dc.setPenWidth(Ui.px(dc, 5));
        dc.setColor(Ui.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(nowX, y - Ui.px(dc, 7), nowX, y + Ui.px(dc, 7));
        dc.setPenWidth(Ui.px(dc, 2));
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(nowX, y - Ui.px(dc, 7), nowX, y + Ui.px(dc, 7));
    }
}

class UpcomingDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    private function view() as UpcomingView {
        return WatchUi.getCurrentView()[0] as UpcomingView;
    }
    function onSelect() as Boolean { return true; }
    function onNextPage() as Boolean { view().scroll(1); return true; }
    function onPreviousPage() as Boolean { view().scroll(-1); return true; }
    function onBack() as Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        if (event.getDirection() == WatchUi.SWIPE_UP) { return onNextPage(); }
        if (event.getDirection() == WatchUi.SWIPE_DOWN) { return onPreviousPage(); }
        if (event.getDirection() == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return false;
    }
}
