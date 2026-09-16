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

    function initialize() {
        View.initialize();
        _rows = [];
        _topIndex = 0;
        refresh();
    }

    function onShow() as Void { refresh(); }

    private function refresh() as Void {
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary?;
        _rows = active == null ? [] : ScheduleModel.projectUpcoming(
            active as Lang.Dictionary, state[:regimen] as Lang.Dictionary, 6, currentUtc());
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
        Ui.centered(dc, Ui.px(dc, 48), Ui.s(Rez.Strings.Upcoming),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        if (_rows.size() == 0) {
            Ui.centered(dc, dc.getHeight() / 2, Ui.s(Rez.Strings.SetupNeeded),
                Graphics.FONT_SYSTEM_TINY, Ui.SECONDARY, Ui.px(dc, 270));
            return;
        }
        for (var visible = 0; visible < 3; visible += 1) {
            drawRow(dc, _rows[_topIndex + visible] as Lang.Dictionary,
                Ui.px(dc, 72 + (visible * 90)));
        }
        Ui.drawScrollIndicator(dc, Ui.px(dc, 72), Ui.px(dc, 342),
            _topIndex, 6, 3, Ui.RING_IN);
    }

    private function drawRow(dc as Graphics.Dc, row as Lang.Dictionary, y as Lang.Number) as Void {
        var xLeft = Ui.px(dc, 66);
        var xRight = dc.getWidth() - Ui.px(dc, 66);
        var width = xRight - xLeft;
        var dateLayout = Ui.datePairLayout(dc, row[:inUtc], row[:outUtc], width);
        var headingY = y + Ui.px(dc, dateLayout == 2 ? 10 : 18);
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, headingY, Graphics.FONT_SYSTEM_SMALL,
            Ui.fmt(Rez.Strings.CycleTemplate, [row[:cycleId]]),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (row[:isCurrent]) {
            dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xRight, headingY, Graphics.FONT_SYSTEM_XTINY,
                Ui.s(Rez.Strings.CurrentCycle),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (row[:ifDoneToday]) {
            dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xRight, headingY, Graphics.FONT_SYSTEM_XTINY,
                Ui.s(Rez.Strings.IfDoneToday),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var dateLines = Ui.drawDatePair(dc, y + Ui.px(dc, 46), row[:inUtc], row[:outUtc],
            width, Ui.SECONDARY);

        var regimen = getApp().getState()[:regimen] as Lang.Dictionary;
        var daysIn = regimen[:daysIn] as Lang.Number;
        var daysOut = regimen[:daysOut] as Lang.Number;
        var gap = daysOut > 0 ? Ui.px(dc, 2) : 0;
        var greenWidth = daysOut == 0 ? width
            : ((width - gap) * daysIn) / (daysIn + daysOut);
        var barY = y + Ui.px(dc, dateLines == 2 ? 80 : 70);
        dc.setPenWidth(Ui.px(dc, 5));
        dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(xLeft, barY, xLeft + greenWidth, barY);
        dc.setColor(Ui.RING_FREE, Graphics.COLOR_TRANSPARENT);
        if (daysOut > 0) {
            dc.drawLine(xLeft + greenWidth + gap, barY, xRight, barY);
        } else {
            dc.drawLine(xRight, barY - Ui.px(dc, 4), xRight, barY + Ui.px(dc, 4));
        }
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
