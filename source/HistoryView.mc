import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

module HistoryUi {
    const VISIBLE_ROWS = 2;

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
        var labels = [] as Lang.Array<Lang.String>;
        var allOnTime = true;
        if (isActive) {
            if (cycle[:insertionDeltaSeconds] != null) {
                var insertion = Ui.eventDelta(cycle[:insertionDeltaSeconds], false);
                labels.add(Ui.s(Rez.Strings.InsertedLabel) + " " + insertion);
                allOnTime = insertion.equals(Ui.s(Rez.Strings.OnTime));
            }
            if (cycle[:removalDeltaSeconds] != null) {
                var removal = Ui.eventDelta(cycle[:removalDeltaSeconds], false);
                labels.add(Ui.s(Rez.Strings.RemovedLabel) + " " + removal);
                allOnTime = allOnTime && removal.equals(Ui.s(Rez.Strings.OnTime));
            }
        } else {
            if (cycle[:removalDeltaSeconds] != null) {
                var removed = Ui.eventDelta(cycle[:removalDeltaSeconds], false);
                labels.add(Ui.s(Rez.Strings.RemovedLabel) + " " + removed);
                allOnTime = removed.equals(Ui.s(Rez.Strings.OnTime));
            }
            if (cycle[:nextInsertionDeltaSeconds] != null) {
                var inserted = Ui.eventDelta(cycle[:nextInsertionDeltaSeconds], false);
                labels.add(Ui.s(Rez.Strings.InsertedLabel) + " " + inserted);
                allOnTime = allOnTime && inserted.equals(Ui.s(Rez.Strings.OnTime));
            }
        }
        if (labels.size() == 0) { return labels; }
        if (allOnTime) { return [Ui.s(Rez.Strings.OnTime)]; }
        return labels;
    }

    function listVariance(cycle as Lang.Dictionary, isActive as Lang.Boolean) as Lang.String {
        var labels = varianceParts(cycle, isActive);
        if (labels.size() == 0) { return ""; }
        if (labels.size() == 1) { return labels[0]; }
        return labels[0] + Ui.s(Rez.Strings.DateTimeSeparator) + labels[1];
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

        _rowStart = Ui.px(dc, 68);
        _rowStep = Ui.px(dc, 130);
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
        Ui.drawScrollIndicator(dc, _rowStart, Ui.px(dc, 338),
            _topIndex, itemCount(), HistoryUi.VISIBLE_ROWS, Ui.RING_IN);
    }

    private function drawFocus(dc as Graphics.Dc, y as Lang.Number, selected as Lang.Boolean) as Void {
        if (!selected) { return; }
        dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(Ui.px(dc, 43), y + Ui.px(dc, 7), Ui.px(dc, 4), Ui.px(dc, 34));
    }

    private function drawCycle(dc as Graphics.Dc, entry as Lang.Dictionary,
                               y as Lang.Number, selected as Lang.Boolean) as Void {
        var cycle = entry[:cycle] as Lang.Dictionary;
        var active = entry[:active] as Lang.Boolean;
        var xLeft = Ui.px(dc, 58);
        var xRight = dc.getWidth() - Ui.px(dc, 58);
        var width = xRight - xLeft;
        drawFocus(dc, y, selected);
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y + Ui.px(dc, 18), Graphics.FONT_SYSTEM_SMALL,
            Ui.fmt(Rez.Strings.CycleTemplate, [cycle[:cycleId]]),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (active) {
            dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xRight, y + Ui.px(dc, 18), Graphics.FONT_SYSTEM_XTINY,
                Ui.s(Rez.Strings.CurrentCycle),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var dateLines = Ui.drawDatePair(dc, y + Ui.px(dc, 48), cycle[:insertionUtc],
            cycle[:removalUtc], width, Ui.SECONDARY);

        var varianceParts = HistoryUi.varianceParts(cycle, active);
        var variance = HistoryUi.listVariance(cycle, active);
        var barOffset = dateLines == 2 ? 110 : 103;
        if (!variance.equals("")) {
            var varianceColor = variance.equals(Ui.s(Rez.Strings.OnTime)) ? Ui.SECONDARY : Ui.AMBER;
            dc.setColor(varianceColor, Graphics.COLOR_TRANSPARENT);
            if (varianceParts.size() == 2
                    && dc.getTextWidthInPixels(variance, Graphics.FONT_SYSTEM_XTINY) > width) {
                var firstVarianceOffset = dateLines == 2 ? 80 : 68;
                var secondVarianceOffset = dateLines == 2 ? 101 : 89;
                dc.drawText(dc.getWidth() / 2, y + Ui.px(dc, firstVarianceOffset), Graphics.FONT_SYSTEM_XTINY,
                    varianceParts[0], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                dc.drawText(dc.getWidth() / 2, y + Ui.px(dc, secondVarianceOffset), Graphics.FONT_SYSTEM_XTINY,
                    varianceParts[1], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                barOffset = dateLines == 2 ? 122 : 112;
            } else {
                var varianceOffset = dateLines == 2 ? 84 : 76;
                dc.drawText(dc.getWidth() / 2, y + Ui.px(dc, varianceOffset), Graphics.FONT_SYSTEM_XTINY, variance,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        var state = getApp().getState();
        var regimen = state[:regimen] as Lang.Dictionary;
        var daysIn = active ? regimen[:daysIn] : cycle[:regimenDaysIn];
        var daysOut = active ? regimen[:daysOut] : cycle[:regimenDaysOut];
        var gap = daysOut > 0 ? Ui.px(dc, 2) : 0;
        var greenWidth = daysOut == 0 ? width : ((width - gap) * daysIn) / (daysIn + daysOut);
        var barY = y + Ui.px(dc, barOffset);
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

    private function drawClear(dc as Graphics.Dc, y as Lang.Number, selected as Lang.Boolean) as Void {
        drawFocus(dc, y, selected);
        Ui.centered(dc, y + Ui.px(dc, 43), Ui.s(Rez.Strings.ClearHistory),
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
        Ui.centered(dc, Ui.px(dc, 42), Ui.fmt(Rez.Strings.CycleDetailTitle, [cycle[:cycleId]]),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));

        drawEvent(dc, Ui.px(dc, 80), Ui.s(Rez.Strings.InsertedLabel), cycle[:insertionUtc],
            Ui.eventDelta(cycle[:insertionDeltaSeconds], cycle[:insertionPlanUtc] == null), clock);
        drawEvent(dc, Ui.px(dc, 151), Ui.s(Rez.Strings.RemovedLabel), cycle[:removalUtc],
            cycle[:removalUtc] == null ? "" : Ui.eventDelta(cycle[:removalDeltaSeconds], false), clock);
        var nextUtc = activeRow ? null : cycle[:nextInsertionUtc];
        var nextDelta = activeRow ? null : cycle[:nextInsertionDeltaSeconds];
        drawEvent(dc, Ui.px(dc, 222), Ui.s(Rez.Strings.NextInsertedLabel), nextUtc,
            nextUtc == null ? "" : Ui.eventDelta(nextDelta, false), clock);

        var daysIn = activeRow ? (state[:regimen] as Lang.Dictionary)[:daysIn] : cycle[:regimenDaysIn];
        var daysOut = activeRow ? (state[:regimen] as Lang.Dictionary)[:daysOut] : cycle[:regimenDaysOut];
        Ui.compactRow(dc, Ui.px(dc, 293), Ui.s(Rez.Strings.RegimenLabel),
            Ui.fmt(Rez.Strings.PlanTemplate, [daysIn, daysOut]));
        var intervals = cycle[:temporaryOut] as Lang.Array;
        Ui.compactRow(dc, Ui.px(dc, 326), Ui.s(Rez.Strings.TemporaryOutLabel),
            Ui.fmt(intervals.size() == 1 ? Rez.Strings.EventTemplate : Rez.Strings.EventsTemplate, [intervals.size()]));
        var summary = cycle[:temporaryOutSummary] as Lang.Dictionary;
        if (summary[:shortIntervalCount] > 0) {
            Ui.centered(dc, Ui.px(dc, 355), Ui.s(Rez.Strings.SummarizedBadge),
                Graphics.FONT_SYSTEM_XTINY, Ui.AMBER, Ui.px(dc, 280));
        }
    }

    private function drawEvent(dc as Graphics.Dc, y as Lang.Number, label as Lang.String,
                               utc, variance as Lang.String, clock as Lang.Number) as Void {
        var xLeft = Ui.px(dc, 58);
        var xRight = dc.getWidth() - Ui.px(dc, 58);
        var width = xRight - xLeft;
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xLeft, y, Graphics.FONT_SYSTEM_XTINY, label,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (utc == null) {
            dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY, Ui.s(Rez.Strings.NotRecorded),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var date = Ui.shortDate(utc as Lang.Number);
            var available = width - dc.getTextWidthInPixels(label, Graphics.FONT_SYSTEM_XTINY) - Ui.px(dc, 12);
            dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY,
                Ui.ellipsize(dc, date, Graphics.FONT_SYSTEM_XTINY, available),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xRight, y + Ui.px(dc, 23), Graphics.FONT_SYSTEM_XTINY,
                Ui.timeForUtc(utc as Lang.Number, clock),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        if (!variance.equals("")) {
            var color = variance.equals(Ui.s(Rez.Strings.OnTime)) || variance.equals(Ui.s(Rez.Strings.FirstCycle))
                ? Ui.SECONDARY : Ui.AMBER;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xRight, y + Ui.px(dc, 47), Graphics.FONT_SYSTEM_XTINY,
                Ui.ellipsize(dc, variance, Graphics.FONT_SYSTEM_XTINY, width),
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
