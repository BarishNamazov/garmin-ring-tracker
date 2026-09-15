import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

module HistoryUi {
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

    function listVariance(cycle as Lang.Dictionary, isActive as Lang.Boolean) as Lang.String {
        var first = "";
        var second = "";
        if (isActive) {
            var insertion = Ui.eventDelta(cycle[:insertionDeltaSeconds], cycle[:insertionPlanUtc] == null);
            if (!insertion.equals("")) { first = Ui.s(Rez.Strings.InsertLabel) + " " + insertion; }
            if (cycle[:removalDeltaSeconds] != null) {
                second = Ui.s(Rez.Strings.RemoveLabel) + " " + Ui.eventDelta(cycle[:removalDeltaSeconds], false);
            }
        } else {
            if (cycle[:removalDeltaSeconds] != null) {
                first = Ui.s(Rez.Strings.RemoveLabel) + " " + Ui.eventDelta(cycle[:removalDeltaSeconds], false);
            }
            if (cycle[:nextInsertionDeltaSeconds] != null) {
                second = Ui.s(Rez.Strings.InsertLabel) + " " + Ui.eventDelta(cycle[:nextInsertionDeltaSeconds], false);
            }
            if (first.equals("") && cycle[:insertionPlanUtc] == null) { first = Ui.s(Rez.Strings.FirstCycle); }
        }
        if (first.equals("")) { return second; }
        if (second.equals("")) { return first; }
        return first + Ui.s(Rez.Strings.DateTimeSeparator) + second;
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
        if (utc == null) {
            Ui.compactRow(dc, y, label, Ui.s(Rez.Strings.NotRecorded));
        } else {
            Ui.dateTimeRow(dc, y, label, utc as Lang.Number, clock);
        }
        if (!variance.equals("")) {
            var color = variance.equals(Ui.s(Rez.Strings.OnTime)) || variance.equals(Ui.s(Rez.Strings.FirstCycle))
                ? Ui.SECONDARY : Ui.AMBER;
            Ui.centered(dc, y + Ui.px(dc, 31), variance, Graphics.FONT_SYSTEM_XTINY, color, Ui.px(dc, 270));
        }
    }
}
