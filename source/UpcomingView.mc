import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

module UpcomingUi {
    function timePosition(startUtc as Lang.Number, endUtc as Lang.Number,
                          atUtc as Lang.Number, width as Lang.Number) as Lang.Number {
        if (atUtc <= startUtc) { return 0; }
        if (endUtc <= startUtc || atUtc >= endUtc) { return width; }
        // Multiply only after converting to float: long-overdue cycles can
        // overflow a 32-bit seconds * pixels product.
        return (((atUtc - startUtc).toFloat() / (endUtc - startUtc)) * width).toNumber();
    }

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

        var dateFont = dateFontFor(dc);
        var xIn = inColumnEdge(dc, dateFont);
        var xOut = xIn + Ui.px(dc, 16);
        var inHeader = Ui.s(Rez.Strings.ListUpcomingIn);
        var outHeader = Ui.s(Rez.Strings.ListUpcomingOut);
        if (_januaryUtc != null) {
            if (ListUi.januaryIsIn(_rows, _januaryUtc as Lang.Number)) {
                inHeader = ListUi.yearHeader(inHeader, _januaryUtc as Lang.Number);
            } else {
                outHeader = ListUi.yearHeader(outHeader, _januaryUtc as Lang.Number);
            }
        }
        // Leave room for the full title, including the descending 'g'.
        var headerY = Ui.px(dc, 40)
            + ((Graphics.getFontHeight(Graphics.FONT_SYSTEM_SMALL)
                + Graphics.getFontHeight(Graphics.FONT_SYSTEM_XTINY)) / 2) + Ui.px(dc, 4);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xIn, headerY, Graphics.FONT_SYSTEM_XTINY,
            inHeader,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(xOut, headerY, Graphics.FONT_SYSTEM_XTINY,
            outHeader,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        var firstPageWithDivider = _topIndex == 0 && _rows.size() > 1
            && (_rows[1] as Lang.Dictionary)[:ifDoneToday] == true;
        var firstRowY = headerY + ((Graphics.getFontHeight(Graphics.FONT_SYSTEM_XTINY)
            + Graphics.getFontHeight(dateFont)) / 2) + Ui.px(dc, 4);
        var rowY = firstRowY;
        var rowPitch = Ui.px(dc, 78);
        var currentExtra = Ui.px(dc, 29);
        for (var visible = 0; visible < 3; visible += 1) {
            var rowIndex = _topIndex + visible;
            if (rowIndex >= _rows.size()) { break; }
            drawRow(dc, _rows[rowIndex] as Lang.Dictionary, rowIndex,
                rowY, visible == 0 && rowIndex == 0, xIn, xOut, dateFont);
            rowY += rowPitch;
            if (rowIndex == 0) { rowY += currentExtra; }
        }
        if (firstPageWithDivider) {
            dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText((dc.getWidth() / 2) - Ui.px(dc, 8), firstRowY + rowPitch,
                Graphics.FONT_SYSTEM_XTINY, Ui.s(Rez.Strings.ListIfRemovedToday),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Three complete rows; a fourth date pair is cut by the bottom chord.
        ListUi.drawRoundScrollIndicator(dc, Ui.px(dc, 72), Ui.px(dc, 350),
            _topIndex, 6, 3, Ui.SECONDARY);
    }

    private function drawRow(dc as Graphics.Dc, row as Lang.Dictionary,
                             rowIndex as Lang.Number, y as Lang.Number,
                             drawCurrentState as Lang.Boolean,
                             xIn as Lang.Number, defaultXOut as Lang.Number,
                             dateFont) as Void {
        var xLeft = Ui.px(dc, 56);
        if (rowIndex == 0) {
            dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
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
        dc.drawText(xIn, y, dateFont, Ui.compactDate(inUtc),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(drawCurrentState && _overdueSeconds != null
            ? Ui.AMBER : Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(defaultXOut, y, dateFont, Ui.compactDate(outUtc),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        if (!drawCurrentState) { return; }
        if (_overdueSeconds != null) {
            dc.setColor(Ui.AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawText(defaultXOut, y + Ui.px(dc, 29), Graphics.FONT_SYSTEM_XTINY,
                ListUi.overdueText(_overdueSeconds as Lang.Number),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        drawCurrentBar(dc, row, y + Ui.px(dc, 50));
    }

    private function dateFontFor(dc as Graphics.Dc) {
        var small = Graphics.FONT_SYSTEM_SMALL;
        var left = Ui.px(dc, 56) + widestEyebrow(dc) + Ui.px(dc, 12);
        var right = ListUi.scrollIndicatorX(dc.getWidth(), dc.getHeight(),
            Ui.px(dc, 72), Ui.px(dc, 350), Ui.px(dc, 2)) - Ui.px(dc, 9);
        if (widestDateColumns(dc, small) + Ui.px(dc, 16) <= right - left) {
            return small;
        }
        return Graphics.FONT_SYSTEM_TINY;
    }

    private function widestEyebrow(dc as Graphics.Dc) as Lang.Number {
        var nowWidth = dc.getTextWidthInPixels(Ui.s(Rez.Strings.ListNow),
            Graphics.FONT_SYSTEM_XTINY);
        var nextWidth = dc.getTextWidthInPixels(Ui.s(Rez.Strings.ListNext),
            Graphics.FONT_SYSTEM_XTINY);
        return nowWidth > nextWidth ? nowWidth : nextWidth;
    }

    private function widestDateColumns(dc as Graphics.Dc, font) as Lang.Number {
        var widestIn = 0;
        var widestOut = 0;
        for (var i = 0; i < _rows.size(); i += 1) {
            var row = _rows[i] as Lang.Dictionary;
            var inUtc = row[:inUtc] as Lang.Number;
            var outUtc = row[:outUtc] as Lang.Number;
            var inWidth = dc.getTextWidthInPixels(Ui.compactDate(inUtc), font);
            var outWidth = dc.getTextWidthInPixels(Ui.compactDate(outUtc), font);
            if (inWidth > widestIn) { widestIn = inWidth; }
            if (outWidth > widestOut) { widestOut = outWidth; }
        }
        return widestIn + widestOut;
    }

    private function inColumnEdge(dc as Graphics.Dc, font) as Lang.Number {
        var widestIn = 0;
        for (var i = 0; i < _rows.size(); i += 1) {
            var row = _rows[i] as Lang.Dictionary;
            var inUtc = row[:inUtc] as Lang.Number;
            var width = dc.getTextWidthInPixels(Ui.compactDate(inUtc), font);
            if (width > widestIn) { widestIn = width; }
        }
        return Ui.px(dc, 56) + widestEyebrow(dc) + Ui.px(dc, 12) + widestIn;
    }

    private function drawCurrentBar(dc as Graphics.Dc, row as Lang.Dictionary,
                                    y as Lang.Number) as Void {
        var xLeft = Ui.px(dc, 72);
        var xRight = dc.getWidth() - Ui.px(dc, 72);
        var width = xRight - xLeft;
        var regimen = getApp().getState()[:regimen] as Lang.Dictionary;
        var startUtc = row[:inUtc] as Lang.Number;
        var boundaryUtc = row[:outUtc] as Lang.Number;
        var scheduledEndUtc = CalendarMath.addLocalCalendarDays(
            boundaryUtc, regimen[:daysOut] as Lang.Number)[:utc] as Lang.Number;
        var nowUtc = currentUtc();
        var endUtc = nowUtc > scheduledEndUtc ? nowUtc : scheduledEndUtc;
        var boundaryX = xLeft + UpcomingUi.timePosition(startUtc, endUtc, boundaryUtc, width);
        var dueUtc = row[:outActual] == true ? scheduledEndUtc : boundaryUtc;
        var dueX = xLeft + UpcomingUi.timePosition(startUtc, endUtc, dueUtc, width);
        var nowX = xLeft + UpcomingUi.timePosition(startUtc, endUtc, nowUtc, width);

        dc.setPenWidth(Ui.px(dc, 5));
        dc.setColor(Ui.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(xLeft, y, xRight, y);
        if (row[:outActual] == true) {
            dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(xLeft, y, boundaryX, y);
            dc.setColor(Ui.RING_FREE, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(boundaryX, y, nowX < dueX ? nowX : dueX, y);
        } else {
            dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(xLeft, y, nowX < dueX ? nowX : dueX, y);
        }
        if (_overdueSeconds != null) {
            dc.setColor(Ui.AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(dueX, y, nowX, y);
        }
        dc.setPenWidth(Ui.px(dc, 5));
        dc.setColor(Ui.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(nowX, y - Ui.px(dc, 3), nowX, y + Ui.px(dc, 3));
        dc.setPenWidth(Ui.px(dc, 2));
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(nowX, y - Ui.px(dc, 3), nowX, y + Ui.px(dc, 3));
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
