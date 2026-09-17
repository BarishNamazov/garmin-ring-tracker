import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// Formatting and drawing helpers shared only by the list and cycle-detail
// screens. Keeping these separate avoids coupling the UX-round layout to the
// app-wide UI helpers.
module ListUi {
    const VARIANCE_NONE = 0;
    const VARIANCE_AMBER = 1;
    const VARIANCE_RED = 2;

    function dateWithYearCue(utcSeconds as Lang.Number, showYear as Lang.Boolean) as Lang.String {
        var date = Ui.compactDate(utcSeconds);
        if (!showYear) { return date; }
        var year = (CalendarMath.localFields(utcSeconds)[:year] as Lang.Number) % 100;
        return Ui.fmt(Rez.Strings.ListDateYearTemplate, [date, year.format("%02d")]);
    }

    function firstJanuaryUtc(rows as Lang.Array) {
        for (var i = 0; i < rows.size(); i += 1) {
            var row = rows[i] as Lang.Dictionary;
            var inUtc = row[:inUtc] as Lang.Number;
            if (CalendarMath.localFields(inUtc)[:month] == 1) { return inUtc; }
            var outUtc = row[:outUtc];
            if (outUtc != null && CalendarMath.localFields(outUtc as Lang.Number)[:month] == 1) {
                return outUtc;
            }
        }
        return null;
    }

    function dateRange(startUtc as Lang.Number, endUtc as Lang.Number) as Lang.String {
        return Ui.fmt(Rez.Strings.ListDateRangeTemplate,
            [Ui.compactDate(startUtc), Ui.compactDate(endUtc)]);
    }

    function historyEndUtc(cycle as Lang.Dictionary, isActive as Lang.Boolean) as Lang.Number {
        if (cycle[:removalUtc] != null) { return cycle[:removalUtc] as Lang.Number; }
        return cycle[:removeDueUtc] as Lang.Number;
    }

    function historyEndIsPlanned(cycle as Lang.Dictionary, isActive as Lang.Boolean) as Lang.Boolean {
        return isActive && cycle[:removalUtc] == null;
    }

    function varianceParts(cycle as Lang.Dictionary) as Lang.Array<Lang.String> {
        var labels = [] as Lang.Array<Lang.String>;
        var removalDelta = cycle[:removalDeltaSeconds];
        var insertionDelta = cycle[:insertionDeltaSeconds];
        if (removalDelta != null) {
            labels.add(Ui.fmt(Rez.Strings.ListVarianceOutTemplate,
                [Ui.eventDelta(removalDelta, false)]));
        }
        if (insertionDelta != null) {
            labels.add(Ui.fmt(Rez.Strings.ListVarianceInTemplate,
                [Ui.eventDelta(insertionDelta, false)]));
        }
        if (labels.size() == 2
                && (removalDelta as Lang.Number).abs() < 60
                && (insertionDelta as Lang.Number).abs() < 60) {
            return [Ui.s(Rez.Strings.OnTime)];
        }
        return labels;
    }

    function varianceText(cycle as Lang.Dictionary) as Lang.String {
        var labels = varianceParts(cycle);
        if (labels.size() == 0) { return ""; }
        if (labels.size() == 1) { return labels[0]; }
        return Ui.fmt(Rez.Strings.ListVariancePairTemplate, [labels[0], labels[1]]);
    }

    function deltaLevel(delta) as Lang.Number {
        if (delta == null || (delta as Lang.Number).abs() < 60) { return VARIANCE_NONE; }
        if ((delta as Lang.Number).abs() > (7 * CalendarMath.SECONDS_PER_DAY)) {
            return VARIANCE_RED;
        }
        return VARIANCE_AMBER;
    }

    function varianceLevel(cycle as Lang.Dictionary) as Lang.Number {
        var outLevel = deltaLevel(cycle[:removalDeltaSeconds]);
        var inLevel = deltaLevel(cycle[:insertionDeltaSeconds]);
        return outLevel > inLevel ? outLevel : inLevel;
    }

    function varianceColor(level as Lang.Number) as Lang.Number {
        if (level == VARIANCE_RED) { return Ui.RED; }
        if (level == VARIANCE_AMBER) { return Ui.AMBER; }
        return Ui.SECONDARY;
    }

    function overdueText(seconds as Lang.Number) as Lang.String {
        var elapsed = seconds.abs();
        var amount;
        if (elapsed >= CalendarMath.SECONDS_PER_DAY) {
            amount = Math.floor(elapsed / CalendarMath.SECONDS_PER_DAY).toNumber().toString()
                + Ui.s(Rez.Strings.DayUnit);
        } else if (elapsed >= CalendarMath.SECONDS_PER_HOUR) {
            amount = Math.floor(elapsed / CalendarMath.SECONDS_PER_HOUR).toNumber().toString()
                + Ui.s(Rez.Strings.HourUnit);
        } else {
            var minutes = Math.floor(elapsed / CalendarMath.SECONDS_PER_MINUTE).toNumber();
            if (minutes < 1) { minutes = 1; }
            amount = minutes.toString() + Ui.s(Rez.Strings.MinuteUnit);
        }
        return Ui.fmt(Rez.Strings.ListOverdueTemplate, [amount]);
    }

    function dueText(utcSeconds as Lang.Number) as Lang.String {
        return Ui.fmt(Rez.Strings.ListDueTemplate, [Ui.shortDate(utcSeconds)]);
    }

    function plannedText(utcSeconds as Lang.Number) as Lang.String {
        return Ui.fmt(Rez.Strings.ListPlannedTemplate, [Ui.compactDate(utcSeconds)]);
    }

    function removalCount(state as Lang.Dictionary) as Lang.Number {
        var count = 0;
        var history = state[:history] as Lang.Array<Lang.Dictionary>;
        for (var i = 0; i < history.size(); i += 1) {
            if (history[i][:removalUtc] != null) { count += 1; }
        }
        var active = state[:active] as Lang.Dictionary?;
        if (active != null && (active as Lang.Dictionary)[:removalUtc] != null) { count += 1; }
        return count;
    }

    function briefOutCount(cycle as Lang.Dictionary) as Lang.Number {
        var count = (cycle[:temporaryOut] as Lang.Array).size();
        var summary = cycle[:temporaryOutSummary] as Lang.Dictionary;
        return count + (summary[:shortIntervalCount] as Lang.Number);
    }

    function drawHistoryRange(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                              startUtc as Lang.Number, endUtc as Lang.Number,
                              planned as Lang.Boolean) as Void {
        var start = Ui.compactDate(startUtc) + Ui.s(Rez.Strings.ListRangeArrow);
        var end = Ui.compactDate(endUtc);
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_SYSTEM_SMALL, start,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(planned ? Ui.SECONDARY : Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + dc.getTextWidthInPixels(start, Graphics.FONT_SYSTEM_SMALL), y,
            Graphics.FONT_SYSTEM_SMALL, end,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawDetailContext(dc as Graphics.Dc, xRight as Lang.Number, y as Lang.Number,
                               delta, plannedUtc) as Void {
        var variance = delta == null ? "" : Ui.eventDelta(delta, false);
        var planned = plannedUtc == null ? "" : plannedText(plannedUtc as Lang.Number);
        if (variance.equals("") && planned.equals("")) { return; }
        if (variance.equals("")) {
            dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY, planned,
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        if (planned.equals("")) {
            dc.setColor(varianceColor(deltaLevel(delta)), Graphics.COLOR_TRANSPARENT);
            dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY, variance,
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var separator = Ui.s(Rez.Strings.DateTimeSeparator);
        var plannedWidth = dc.getTextWidthInPixels(planned, Graphics.FONT_SYSTEM_XTINY);
        var separatorWidth = dc.getTextWidthInPixels(separator, Graphics.FONT_SYSTEM_XTINY);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight, y, Graphics.FONT_SYSTEM_XTINY, planned,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(varianceColor(deltaLevel(delta)), Graphics.COLOR_TRANSPARENT);
        dc.drawText(xRight - plannedWidth, y, Graphics.FONT_SYSTEM_XTINY, separator,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(xRight - plannedWidth - separatorWidth, y,
            Graphics.FONT_SYSTEM_XTINY, variance,
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
