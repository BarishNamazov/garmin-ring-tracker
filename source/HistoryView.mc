import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

module HistoryUi {
    const VISIBLE_ROWS = 3;

    function entries(state as Lang.Dictionary) as Lang.Array {
        var result = [];
        var active = state[:active] as Lang.Dictionary?;
        if (active != null) {
            result.add({:id=>:activeCycle, :cycle=>active, :active=>true});
        }
        var history = state[:history] as Lang.Array<Lang.Dictionary>;
        for (var i = history.size() - 1; i >= 0; i -= 1) {
            result.add({:id=>i, :cycle=>history[i], :active=>false});
        }
        return result;
    }

    function varianceParts(cycle as Lang.Dictionary, isActive as Lang.Boolean) as Lang.Array<Lang.String> {
        return ListUi.varianceParts(cycle);
    }

    function listVariance(cycle as Lang.Dictionary, isActive as Lang.Boolean) as Lang.String {
        return ListUi.varianceText(cycle);
    }

    function boundedSelection(value as Lang.Number, count as Lang.Number) as Lang.Number {
        if (count <= 0 || value < 0) { return 0; }
        if (value >= count) { return count - 1; }
        return value;
    }

    function focusBounds(rowTop as Lang.Number, rowStep as Lang.Number,
                         headerBottom as Lang.Number, gap as Lang.Number) as Lang.Array {
        var top = rowTop - gap;
        if (top < headerBottom + gap) { top = headerBottom + gap; }
        return [top, rowTop + rowStep - gap];
    }

    function topForSelection(selection as Lang.Number, count as Lang.Number) as Lang.Number {
        if (count <= VISIBLE_ROWS) { return 0; }
        var top = selection - VISIBLE_ROWS + 1;
        if (top < 0) { return 0; }
        var maximum = count - VISIBLE_ROWS;
        return top > maximum ? maximum : top;
    }
}

class HistoryView extends WatchUi.View {
    private var _entries as Lang.Array;
    private var _hasClear as Lang.Boolean;
    private var _selected as Lang.Number;
    private var _topIndex as Lang.Number;
    private var _rowStart as Lang.Number;
    private var _rowStep as Lang.Number;

    function initialize() {
        View.initialize();
        _entries = [];
        _hasClear = false;
        _selected = 0;
        _topIndex = 0;
        _rowStart = 0;
        _rowStep = 1;
        refresh();
    }

    function onShow() as Void { refresh(); }

    private function refresh() as Void {
        var state = getApp().getState();
        _entries = HistoryUi.entries(state);
        _hasClear = (state[:history] as Lang.Array).size() > 0;
        _selected = HistoryUi.boundedSelection(_selected, itemCount());
        _topIndex = HistoryUi.topForSelection(_selected, itemCount());
    }

    function itemCount() as Lang.Number { return _entries.size() + (_hasClear ? 1 : 0); }

    function moveSelection(delta as Lang.Number) as Void {
        _selected = HistoryUi.boundedSelection(_selected + delta, itemCount());
        _topIndex = HistoryUi.topForSelection(_selected, itemCount());
        WatchUi.requestUpdate();
    }

    function selectAt(y as Lang.Number) as Lang.Boolean {
        if (y < _rowStart || y >= _rowStart + (_rowStep * HistoryUi.VISIBLE_ROWS)) { return false; }
        var index = _topIndex + ((y - _rowStart) / _rowStep);
        if (index >= itemCount()) { return false; }
        _selected = index;
        return true;
    }

    function activateSelection() as Lang.Boolean {
        if (itemCount() == 0) { return true; }
        if (_selected < _entries.size()) {
            var entry = _entries[_selected] as Lang.Dictionary;
            WatchUi.pushView(new CycleDetailView(entry[:id]), new PopDelegate(), WatchUi.SLIDE_LEFT);
        } else {
            getApp().confirmAction(:clearHistory, currentUtc(), null);
        }
        return true;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        Ui.centered(dc, Ui.px(dc, 48), Ui.s(Rez.Strings.History),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        if (itemCount() == 0) {
            Ui.centered(dc, dc.getHeight() / 2, Ui.s(Rez.Strings.HistoryEmpty),
                Graphics.FONT_SYSTEM_TINY, Ui.SECONDARY, Ui.px(dc, 270));
            return;
        }

        _rowStart = Ui.px(dc, 82);
        _rowStep = Ui.px(dc, 92);
        // Paint the selection before any rows, and never into the heading or
        // adjacent row. Content-dependent padding used to erase descenders.
        var selectedY = _rowStart + ((_selected - _topIndex) * _rowStep);
        var bounds = HistoryUi.focusBounds(selectedY, _rowStep,
            Ui.px(dc, 48) + Graphics.getFontHeight(Graphics.FONT_SYSTEM_SMALL) / 2,
            Ui.px(dc, 4));
        dc.setColor(Ui.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, bounds[0], dc.getWidth(), bounds[1] - bounds[0]);
        for (var visible = 0; visible < HistoryUi.VISIBLE_ROWS; visible += 1) {
            var index = _topIndex + visible;
            if (index >= itemCount()) { break; }
            var y = _rowStart + (visible * _rowStep);
            if (index < _entries.size()) {
                drawCycle(dc, _entries[index] as Lang.Dictionary, y);
            } else {
                drawClear(dc, y);
            }
        }
        ListUi.drawRoundScrollIndicator(dc, _rowStart, Ui.px(dc, 350),
            _topIndex, itemCount(), HistoryUi.VISIBLE_ROWS, Ui.SECONDARY);
    }

    private function drawCycle(dc as Graphics.Dc, entry as Lang.Dictionary,
                               y as Lang.Number) as Void {
        var cycle = entry[:cycle] as Lang.Dictionary;
        var active = entry[:active] as Lang.Boolean;
        var xLeft = Ui.px(dc, 48);
        var xRight = ListUi.scrollIndicatorX(dc.getWidth(), dc.getHeight(),
            _rowStart, Ui.px(dc, 350), Ui.px(dc, 2)) - Ui.px(dc, 9);
        var rangeY = y + Ui.px(dc, 18);
        var cycleY = y + Ui.px(dc, 47);
        var varianceY = y + Ui.px(dc, 72);
        var variance = HistoryUi.listVariance(cycle, active);
        var endUtc = ListUi.historyEndUtc(cycle, active);
        ListUi.drawHistoryRange(dc, xLeft, rangeY,
            cycle[:insertionUtc] as Lang.Number, endUtc,
            ListUi.historyEndIsPlanned(cycle, active));

        var cycleText = Ui.fmt(Rez.Strings.CycleTemplate, [cycle[:cycleId]]);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, cycleY, Graphics.FONT_SYSTEM_XTINY,
            cycleText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (active) {
            dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xLeft + dc.getTextWidthInPixels(cycleText, Graphics.FONT_SYSTEM_XTINY),
                cycleY, Graphics.FONT_SYSTEM_XTINY,
                Ui.s(Rez.Strings.DateTimeSeparator) +
                Ui.s(Rez.Strings.ListNow),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (!variance.equals("")) {
            var edge = ListUi.textRightEdge(dc, varianceY, Graphics.FONT_SYSTEM_XTINY, Ui.px(dc, 4));
            var left = dc.getWidth() - edge;
            if (left < xLeft) { left = xLeft; }
            var right = edge < xRight ? edge : xRight;
            dc.setColor(ListUi.varianceColor(ListUi.varianceLevel(cycle)),
                Graphics.COLOR_TRANSPARENT);
            dc.drawText(left, varianceY, Graphics.FONT_SYSTEM_XTINY,
                Ui.ellipsize(dc, variance, Graphics.FONT_SYSTEM_XTINY, right - left),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawClear(dc as Graphics.Dc, y as Lang.Number) as Void {
        var textY = y + Ui.px(dc, 47);
        Ui.centered(dc, textY, Ui.s(Rez.Strings.ClearHistory),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
    }
}

class HistoryDelegate extends ScreenInputDelegate {
    function initialize() { ScreenInputDelegate.initialize(); }
    private function view() as HistoryView { return WatchUi.getCurrentView()[0] as HistoryView; }
    function onSelect() as Boolean { return view().activateSelection(); }
    function onNextPage() as Boolean { view().moveSelection(1); return true; }
    function onPreviousPage() as Boolean { view().moveSelection(-1); return true; }
    function onBack() as Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coordinates = event.getCoordinates();
        if (view().selectAt(coordinates[1])) { return view().activateSelection(); }
        return true;
    }
    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        if (event.getDirection() == WatchUi.SWIPE_UP) { return onNextPage(); }
        if (event.getDirection() == WatchUi.SWIPE_DOWN) { return onPreviousPage(); }
        if (event.getDirection() == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return false;
    }
}

class CycleDetailView extends WatchUi.View {
    private var _index;
    function initialize(index) { View.initialize(); _index = index; }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var state = getApp().getState();
        var activeRow = _index == :activeCycle;
        var cycle = activeRow ? state[:active] as Lang.Dictionary
            : (state[:history] as Lang.Array<Lang.Dictionary>)[_index as Lang.Number];
        var clock = (state[:reminders] as Lang.Dictionary)[:clockFormat];
        var titleY = Ui.px(dc, 35);
        var detailFont = Graphics.FONT_SYSTEM_XTINY;
        var detailHeight = Graphics.getFontHeight(detailFont);
        Ui.centered(dc, titleY, Ui.fmt(Rez.Strings.CycleDetailTitle, [cycle[:cycleId]]),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        var headerBottom = titleY + (Graphics.getFontHeight(Graphics.FONT_SYSTEM_SMALL) / 2);
        if (cycle[:insertionPlanUtc] == null) {
            var subtitleTop = headerBottom + Ui.px(dc, 12);
            var subtitleY = subtitleTop + (detailHeight / 2);
            Ui.centered(dc, subtitleY, Ui.s(Rez.Strings.ListFirstRecorded),
                detailFont, Ui.SECONDARY, Ui.px(dc, 280));
            headerBottom = subtitleTop + detailHeight + Ui.px(dc, 20);
        } else {
            headerBottom += Ui.px(dc, 20);
        }

        var hasThird = (activeRow && cycle[:removalUtc] != null && cycle[:insertDueUtc] != null)
            || (!activeRow && cycle[:nextInsertionUtc] != null);
        var insertedContext = cycle[:insertionPlanUtc] != null
            || cycle[:insertionDeltaSeconds] != null;
        var removedContext = cycle[:removalUtc] != null
            && (cycle[:removeDueUtc] != null || cycle[:removalDeltaSeconds] != null);
        var thirdContext = !activeRow && hasThird;
        var eventCount = hasThird ? 3 : 2;
        var contextOffset = Ui.px(dc, 25);
        var rowGap = Ui.px(dc, 8);
        var dividerGap = Ui.px(dc, 12);
        var dividerToStats = Ui.px(dc, 12);
        var totalHeight = (eventCount * detailHeight)
            + (insertedContext ? contextOffset : 0)
            + (removedContext ? contextOffset : 0)
            + (thirdContext ? contextOffset : 0)
            + ((eventCount - 1) * rowGap)
            + dividerGap + Ui.px(dc, 1) + dividerToStats
            + (2 * detailHeight);
        var safeBottom = dc.getHeight() - Ui.px(dc, 72);
        var contentTop = headerBottom
            + ((safeBottom - headerBottom - totalHeight) / 2);
        if (contentTop < headerBottom) { contentTop = headerBottom; }
        var cursor = contentTop;

        drawRecordedEvent(dc, cursor + (detailHeight / 2), Ui.s(Rez.Strings.InsertedLabel),
            cycle[:insertionUtc] as Lang.Number, cycle[:insertionPlanUtc],
            cycle[:insertionDeltaSeconds], clock);
        cursor += detailHeight + (insertedContext ? contextOffset : 0) + rowGap;
        if (cycle[:removalUtc] == null) {
            drawDueEvent(dc, cursor + (detailHeight / 2), Ui.s(Rez.Strings.RemovedLabel),
                cycle[:removeDueUtc] as Lang.Number);
        } else {
            drawRecordedEvent(dc, cursor + (detailHeight / 2), Ui.s(Rez.Strings.RemovedLabel),
                cycle[:removalUtc] as Lang.Number, cycle[:removeDueUtc],
                cycle[:removalDeltaSeconds], clock);
        }
        cursor += detailHeight + (removedContext ? contextOffset : 0);

        if (hasThird) {
            cursor += rowGap;
            if (activeRow) {
                drawDueEvent(dc, cursor + (detailHeight / 2), Ui.s(Rez.Strings.ListNextIn),
                    cycle[:insertDueUtc] as Lang.Number);
            } else {
                var nextPlan = cycle[:removalUtc] == null
                    ? cycle[:removeDueUtc] : cycle[:insertDueUtc];
                drawRecordedEvent(dc, cursor + (detailHeight / 2),
                    Ui.s(Rez.Strings.ListNextIn), cycle[:nextInsertionUtc] as Lang.Number,
                    nextPlan, cycle[:nextInsertionDeltaSeconds], clock);
            }
            cursor += detailHeight + (thirdContext ? contextOffset : 0);
        }

        var daysIn = activeRow ? (state[:regimen] as Lang.Dictionary)[:daysIn] : cycle[:regimenDaysIn];
        var daysOut = activeRow ? (state[:regimen] as Lang.Dictionary)[:daysOut] : cycle[:regimenDaysOut];
        cursor += dividerGap;
        dc.setPenWidth(Ui.px(dc, 1));
        dc.setColor(Ui.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(Ui.px(dc, 50), cursor,
            dc.getWidth() - Ui.px(dc, 50), cursor);
        cursor += Ui.px(dc, 1) + dividerToStats;
        drawStat(dc, cursor + (detailHeight / 2), Ui.s(Rez.Strings.RegimenLabel),
            Ui.fmt(Rez.Strings.PlanTemplate, [daysIn, daysOut]));
        cursor += detailHeight;
        drawStat(dc, cursor + (detailHeight / 2), Ui.s(Rez.Strings.ListBriefOuts),
            ListUi.briefOutText(cycle));
    }

    private function drawRecordedEvent(dc as Graphics.Dc, y as Lang.Number,
                                       label as Lang.String, utc as Lang.Number,
                                       plannedUtc, delta, clock as Lang.Number) as Void {
        var xLeft = Ui.px(dc, 50);
        var xRight = dc.getWidth() - Ui.px(dc, 50);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY,
            ListUi.detailTimestamp(utc, clock),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        ListUi.drawDetailContext(dc, xRight, y + Ui.px(dc, 25), delta, plannedUtc);
    }

    private function drawDueEvent(dc as Graphics.Dc, y as Lang.Number,
                                  label as Lang.String, dueUtc as Lang.Number) as Void {
        var xLeft = Ui.px(dc, 50);
        var xRight = dc.getWidth() - Ui.px(dc, 50);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY, ListUi.dueText(dueUtc),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawStat(dc as Graphics.Dc, y as Lang.Number,
                              label as Lang.String, value as Lang.String) as Void {
        var xLeft = Ui.px(dc, 50);
        var xRight = dc.getWidth() - Ui.px(dc, 50);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY, value,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
