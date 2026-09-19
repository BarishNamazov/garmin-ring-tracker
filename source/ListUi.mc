import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// List/cycle-detail formatting and shared round-screen geometry. Text screens
// also use the chord-aware edges to keep paragraphs clear of the bezel and
// scrollbar.
module ListUi {
    const VARIANCE_NONE = 0;
    const VARIANCE_AMBER = 1;
    const VARIANCE_RED = 2;

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

    function januaryIsIn(rows as Lang.Array, januaryUtc as Lang.Number) as Lang.Boolean {
        for (var i = 0; i < rows.size(); i += 1) {
            var row = rows[i] as Lang.Dictionary;
            if (row[:inUtc] == januaryUtc) { return true; }
            if (row[:outUtc] == januaryUtc) { return false; }
        }
        return false;
    }

    function yearHeader(label as Lang.String, utcSeconds as Lang.Number) as Lang.String {
        var year = CalendarMath.localFields(utcSeconds)[:year] as Lang.Number;
        return Ui.fmt(Rez.Strings.ListColumnYearTemplate, [label, year]);
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
        return Lateness.format(seconds);
    }

    function roundRightEdge(width as Lang.Number, height as Lang.Number,
                            y as Lang.Number, halfTextHeight as Lang.Number,
                            margin as Lang.Number) as Lang.Number {
        var radius = (width < height ? width : height) / 2;
        var centerX = width / 2;
        var centerY = height / 2;
        var sampleY = y < centerY
            ? y - halfTextHeight - margin
            : y + halfTextHeight + margin;
        var offsetY = (sampleY - centerY).abs();
        if (offsetY >= radius) { return centerX; }
        return centerX + Math.sqrt((radius * radius) - (offsetY * offsetY)).toNumber()
            - margin;
    }

    function textRightEdge(dc as Graphics.Dc, y as Lang.Number, font,
                           margin as Lang.Number) as Lang.Number {
        return roundRightEdge(dc.getWidth(), dc.getHeight(), y,
            Graphics.getFontHeight(font) / 2, margin);
    }

    function scrollIndicatorX(width as Lang.Number, height as Lang.Number,
                              startY as Lang.Number, bottomY as Lang.Number,
                              margin as Lang.Number) as Lang.Number {
        var topEdge = roundRightEdge(width, height, startY, 0, margin);
        var bottomEdge = roundRightEdge(width, height, bottomY, 0, margin);
        var circleEdge = topEdge < bottomEdge ? topEdge : bottomEdge;
        var fixedInset = width - Math.round(width * 0.07).toNumber();
        return circleEdge < fixedInset ? circleEdge : fixedInset;
    }

    function drawRoundScrollIndicator(dc as Graphics.Dc, startY as Lang.Number,
                                      bottomY as Lang.Number, position as Lang.Number,
                                      total as Lang.Number, visible as Lang.Number,
                                      color as Lang.Number) as Void {
        var metrics = Ui.scrollIndicatorMetrics(startY, bottomY, position,
            total, visible, Ui.px(dc, 18));
        if (metrics == null) { return; }
        var trackHeight = bottomY - startY;
        var x = scrollIndicatorX(dc.getWidth(), dc.getHeight(), startY, bottomY,
            Ui.px(dc, 2));
        dc.setColor(Ui.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - Ui.px(dc, 7), startY, Ui.px(dc, 15), trackHeight);
        dc.setColor(Ui.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, startY, Ui.px(dc, 2), trackHeight);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - Ui.px(dc, 1), metrics[0], Ui.px(dc, 4), metrics[1]);
    }

    function dueText(utcSeconds as Lang.Number) as Lang.String {
        return Ui.fmt(Rez.Strings.ListDueTemplate, [Ui.compactDate(utcSeconds)]);
    }

    function detailTimestamp(utcSeconds as Lang.Number, clockFormat as Lang.Number) as Lang.String {
        return Ui.compactDate(utcSeconds) + Ui.s(Rez.Strings.DateTimeSeparator)
            + Ui.timeForUtc(utcSeconds, clockFormat);
    }

    function plannedText(utcSeconds as Lang.Number) as Lang.String {
        return Ui.fmt(Rez.Strings.ListPlannedTemplate, [Ui.compactDate(utcSeconds)]);
    }

    function briefOutCount(cycle as Lang.Dictionary) as Lang.Number {
        var count = (cycle[:temporaryOut] as Lang.Array).size();
        var summary = cycle[:temporaryOutSummary] as Lang.Dictionary;
        return count + (summary[:shortIntervalCount] as Lang.Number);
    }

    function briefOutText(cycle as Lang.Dictionary) as Lang.String {
        return Ui.fmt(Rez.Strings.ListBriefOutCountTemplate, [briefOutCount(cycle)]);
    }

    function drawHistoryRange(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                              startUtc as Lang.Number, endUtc as Lang.Number,
                              planned as Lang.Boolean) as Void {
        var start = Ui.compactDate(startUtc);
        var end = Ui.compactDate(endUtc);
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_SYSTEM_SMALL, start,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        var arrowStart = x + dc.getTextWidthInPixels(start, Graphics.FONT_SYSTEM_SMALL)
            + Ui.px(dc, 8);
        var arrowEnd = arrowStart + Ui.px(dc, 12);
        dc.setPenWidth(Ui.px(dc, 2));
        dc.drawLine(arrowStart, y, arrowEnd, y);
        dc.drawLine(arrowEnd - Ui.px(dc, 4), y - Ui.px(dc, 4), arrowEnd, y);
        dc.drawLine(arrowEnd - Ui.px(dc, 4), y + Ui.px(dc, 4), arrowEnd, y);
        dc.setColor(planned ? Ui.SECONDARY : Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(arrowEnd + Ui.px(dc, 8), y,
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
