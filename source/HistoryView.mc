import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class CycleDetailView extends WatchUi.View {
    private var _index as Lang.Number;
    function initialize(index as Lang.Number) { View.initialize(); _index = index; }
    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var state = getApp().getState();
        var cycle = (state[:history] as Lang.Array<Lang.Dictionary>)[_index];
        var clock = (state[:reminders] as Lang.Dictionary)[:clockFormat];
        Ui.centered(dc, Ui.px(dc, 42), Ui.s(Rez.Strings.CycleDetailTitle), Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        Ui.dateTimeRow(dc, Ui.px(dc, 78), Ui.s(Rez.Strings.InsertedLabel), cycle[:insertionUtc], clock);
        if (cycle[:removalUtc] == null) {
            Ui.compactRow(dc, Ui.px(dc, 121), Ui.s(Rez.Strings.RemovedLabel), Ui.s(Rez.Strings.NotRecorded));
        } else {
            Ui.dateTimeRow(dc, Ui.px(dc, 121), Ui.s(Rez.Strings.RemovedLabel), cycle[:removalUtc], clock);
        }
        if (cycle[:nextInsertionUtc] == null) {
            Ui.compactRow(dc, Ui.px(dc, 164), Ui.s(Rez.Strings.NextInsertedLabel), Ui.s(Rez.Strings.NotRecorded));
        } else {
            Ui.dateTimeRow(dc, Ui.px(dc, 164), Ui.s(Rez.Strings.NextInsertedLabel), cycle[:nextInsertionUtc], clock);
        }
        Ui.compactRow(dc, Ui.px(dc, 212), Ui.s(Rez.Strings.RegimenLabel), Ui.fmt(Rez.Strings.PlanTemplate, [cycle[:regimenDaysIn], cycle[:regimenDaysOut]]));
        var intervals = cycle[:temporaryOut] as Lang.Array;
        Ui.compactRow(dc, Ui.px(dc, 248), Ui.s(Rez.Strings.TemporaryOutLabel),
            Ui.fmt(intervals.size() == 1 ? Rez.Strings.EventTemplate : Rez.Strings.EventsTemplate, [intervals.size()]));
        if (intervals.size() > 0) {
            var recent = intervals[intervals.size() - 1] as Lang.Dictionary;
            var end = recent[:backInUtc] == null ? Ui.s(Rez.Strings.OpenInterval)
                : Ui.timeForUtc(recent[:backInUtc], clock);
            var event = Ui.timeForUtc(recent[:outUtc], clock) + Ui.s(Rez.Strings.RangeSeparator) + end;
            Ui.centered(dc, Ui.px(dc, 282), Ui.shortDate(recent[:outUtc]), Graphics.FONT_SYSTEM_XTINY,
                Ui.PRIMARY, Ui.px(dc, 270));
            Ui.centered(dc, Ui.px(dc, 306), event, Graphics.FONT_SYSTEM_XTINY,
                Ui.SECONDARY, Ui.px(dc, 270));
        }
        var summary = cycle[:temporaryOutSummary] as Lang.Dictionary;
        if (summary[:shortIntervalCount] > 0) {
            Ui.centered(dc, Ui.px(dc, 330), Ui.s(Rez.Strings.SummarizedBadge),
                Graphics.FONT_SYSTEM_XTINY, Ui.AMBER, Ui.px(dc, 250));
        }
        Ui.centered(dc, Ui.px(dc, 360), Ui.s(Rez.Strings.BackHint), Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 240));
    }
}
