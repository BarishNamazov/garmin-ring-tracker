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

        _rowStart = Ui.px(dc, 67);
        _rowStep = Ui.px(dc, 91);
        for (var visible = 0; visible < HistoryUi.VISIBLE_ROWS; visible += 1) {
            var index = _topIndex + visible;
            if (index >= itemCount()) { break; }
            var y = _rowStart + (visible * _rowStep);
            if (index < _entries.size()) {
                drawCycle(dc, _entries[index] as Lang.Dictionary, y, index == _selected);
            } else {
                drawClear(dc, y, index == _selected);
            }
        }
        Ui.drawScrollIndicator(dc, _rowStart, Ui.px(dc, 342),
            _topIndex, itemCount(), HistoryUi.VISIBLE_ROWS, Ui.SECONDARY);
    }

    private function drawFocus(dc as Graphics.Dc, y as Lang.Number, selected as Lang.Boolean,
                               xLeft as Lang.Number, xRight as Lang.Number) as Void {
        if (!selected) { return; }
        dc.setColor(Ui.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(xLeft - Ui.px(dc, 8), y + Ui.px(dc, 4),
            (xRight - xLeft) + Ui.px(dc, 16), Ui.px(dc, 83));
    }

    private function drawCycle(dc as Graphics.Dc, entry as Lang.Dictionary,
                               y as Lang.Number, selected as Lang.Boolean) as Void {
        var cycle = entry[:cycle] as Lang.Dictionary;
        var active = entry[:active] as Lang.Boolean;
        var xLeft = Ui.px(dc, 54);
        var xRight = dc.getWidth() - Ui.px(dc, 54);
        var width = xRight - xLeft;
        drawFocus(dc, y, selected, xLeft, xRight);

        var endUtc = ListUi.historyEndUtc(cycle, active);
        ListUi.drawHistoryRange(dc, xLeft, y + Ui.px(dc, 20),
            cycle[:insertionUtc] as Lang.Number, endUtc,
            ListUi.historyEndIsPlanned(cycle, active));

        var cycleText = Ui.fmt(Rez.Strings.CycleTemplate, [cycle[:cycleId]]);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y + Ui.px(dc, 48), Graphics.FONT_SYSTEM_XTINY,
            cycleText, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (active) {
            dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xLeft + dc.getTextWidthInPixels(cycleText, Graphics.FONT_SYSTEM_XTINY),
                y + Ui.px(dc, 48), Graphics.FONT_SYSTEM_XTINY,
                Ui.s(Rez.Strings.DateTimeSeparator) +
                Ui.s(Rez.Strings.CurrentCycle),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var variance = HistoryUi.listVariance(cycle, active);
        if (!variance.equals("")) {
            dc.setColor(ListUi.varianceColor(ListUi.varianceLevel(cycle)),
                Graphics.COLOR_TRANSPARENT);
            dc.drawText(xLeft, y + Ui.px(dc, 73), Graphics.FONT_SYSTEM_XTINY,
                Ui.ellipsize(dc, variance, Graphics.FONT_SYSTEM_XTINY, width),
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawClear(dc as Graphics.Dc, y as Lang.Number, selected as Lang.Boolean) as Void {
        var xLeft = Ui.px(dc, 54);
        var xRight = dc.getWidth() - Ui.px(dc, 54);
        drawFocus(dc, y, selected, xLeft, xRight);
        Ui.centered(dc, y + Ui.px(dc, 45), Ui.s(Rez.Strings.ClearHistory),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
    }
}

class HistoryDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
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
        Ui.centered(dc, Ui.px(dc, 35), Ui.fmt(Rez.Strings.CycleDetailTitle, [cycle[:cycleId]]),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        if (cycle[:insertionPlanUtc] == null) {
            Ui.centered(dc, Ui.px(dc, 62), Ui.s(Rez.Strings.ListFirstRecorded),
                Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 280));
        }

        drawRecordedEvent(dc, Ui.px(dc, 93), Ui.s(Rez.Strings.InsertedLabel),
            cycle[:insertionUtc] as Lang.Number, cycle[:insertionPlanUtc],
            cycle[:insertionDeltaSeconds], clock);
        if (cycle[:removalUtc] == null) {
            drawDueEvent(dc, Ui.px(dc, 158), Ui.s(Rez.Strings.RemovedLabel),
                cycle[:removeDueUtc] as Lang.Number);
        } else {
            drawRecordedEvent(dc, Ui.px(dc, 158), Ui.s(Rez.Strings.RemovedLabel),
                cycle[:removalUtc] as Lang.Number, cycle[:removeDueUtc],
                cycle[:removalDeltaSeconds], clock);
        }

        if (activeRow && cycle[:removalUtc] != null && cycle[:insertDueUtc] != null) {
            drawDueEvent(dc, Ui.px(dc, 223), Ui.s(Rez.Strings.ListNextIn),
                cycle[:insertDueUtc] as Lang.Number);
        } else if (!activeRow && cycle[:nextInsertionUtc] != null) {
            var nextPlan = cycle[:removalUtc] == null ? cycle[:removeDueUtc] : cycle[:insertDueUtc];
            drawRecordedEvent(dc, Ui.px(dc, 223), Ui.s(Rez.Strings.ListNextIn),
                cycle[:nextInsertionUtc] as Lang.Number, nextPlan,
                cycle[:nextInsertionDeltaSeconds], clock);
        }

        var daysIn = activeRow ? (state[:regimen] as Lang.Dictionary)[:daysIn] : cycle[:regimenDaysIn];
        var daysOut = activeRow ? (state[:regimen] as Lang.Dictionary)[:daysOut] : cycle[:regimenDaysOut];
        dc.setPenWidth(Ui.px(dc, 1));
        dc.setColor(Ui.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(Ui.px(dc, 48), Ui.px(dc, 270),
            dc.getWidth() - Ui.px(dc, 48), Ui.px(dc, 270));
        drawStat(dc, Ui.px(dc, 294), Ui.s(Rez.Strings.RegimenLabel),
            Ui.fmt(Rez.Strings.PlanTemplate, [daysIn, daysOut]));
        drawStat(dc, Ui.px(dc, 324), Ui.s(Rez.Strings.ListBriefOuts),
            ListUi.briefOutCount(cycle).toString());
        drawStat(dc, Ui.px(dc, 354), Ui.s(Rez.Strings.ListRemovalsAll),
            ListUi.removalCount(state).toString());
    }

    private function drawRecordedEvent(dc as Graphics.Dc, y as Lang.Number,
                                       label as Lang.String, utc as Lang.Number,
                                       plannedUtc, delta, clock as Lang.Number) as Void {
        var xLeft = Ui.px(dc, 48);
        var xRight = dc.getWidth() - Ui.px(dc, 48);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY,
            Ui.shortTimestamp(utc, clock),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        ListUi.drawDetailContext(dc, xRight, y + Ui.px(dc, 25), delta, plannedUtc);
    }

    private function drawDueEvent(dc as Graphics.Dc, y as Lang.Number,
                                  label as Lang.String, dueUtc as Lang.Number) as Void {
        var xLeft = Ui.px(dc, 48);
        var xRight = dc.getWidth() - Ui.px(dc, 48);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY, ListUi.dueText(dueUtc),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawStat(dc as Graphics.Dc, y as Lang.Number,
                              label as Lang.String, value as Lang.String) as Void {
        var xLeft = Ui.px(dc, 48);
        var xRight = dc.getWidth() - Ui.px(dc, 48);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY, value,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
