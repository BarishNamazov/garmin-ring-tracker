import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Timer;
import Toybox.WatchUi;

(:production)
function reportMainScreenMemory() as Void { }

(:debug)
function reportMainScreenMemory() as Void {
    var stats = Toybox.System.getSystemStats();
    Toybox.System.println("RING_TRACKER_MAIN_MEMORY="
        + stats.usedMemory + "/" + stats.totalMemory);
}

class MainView extends WatchUi.View {
    private var _timer as Timer.Timer?;
    private var _memoryReported as Lang.Boolean;

    function initialize() {
        View.initialize();
        _timer = null;
        _memoryReported = false;
    }

    function onShow() as Void {
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary?;
        var interval = 3600000;
        if (active != null) {
            var status = ScheduleModel.deriveStatus(currentUtc(), active,
                state[:regimen] as Lang.Dictionary);
            if (status[:temporaryOutOpen]
                || status[:secondsRemaining].abs() < CalendarMath.SECONDS_PER_DAY) {
                interval = 60000;
            }
        }
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:tick), interval, true);
    }

    function onHide() as Void {
        if (_timer != null) { (_timer as Timer.Timer).stop(); }
        _timer = null;
    }

    function tick() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary?;
        if (active == null) {
            Ui.centered(dc, dc.getHeight() / 2, Ui.s(Rez.Strings.SetupNeeded),
                Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 280));
            reportMemoryOnce();
            return;
        }
        var regimen = state[:regimen] as Lang.Dictionary;
        var reminders = state[:reminders] as Lang.Dictionary;
        var nowUtc = currentUtc();
        var status = ScheduleModel.deriveStatus(nowUtc, active, regimen);
        drawArc(dc, active, regimen, status, nowUtc);
        if (status[:temporaryOutOpen]) {
            drawTemporary(dc, status, reminders, nowUtc);
        } else {
            drawStatus(dc, active, status, reminders, nowUtc);
        }
        reportMemoryOnce();
    }

    private function reportMemoryOnce() as Void {
        if (_memoryReported) { return; }
        _memoryReported = true;
        reportMainScreenMemory();
    }

    private function drawArc(dc as Graphics.Dc, active as Lang.Dictionary,
                             regimen as Lang.Dictionary, status as Lang.Dictionary,
                             nowUtc as Lang.Number) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var radius = Ui.mainArcRadius(dc);
        var stroke = Ui.mainArcStroke(dc);

        if (status[:temporaryOutOpen]) {
            drawTemporaryArc(dc, status[:tempElapsed] as Lang.Number, radius, stroke);
            return;
        }

        dc.setPenWidth(stroke);
        dc.setColor(Ui.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, 90);

        if (status[:ringFreeOverSevenDays] || status[:ringInOverFourWeeks]) {
            dc.setPenWidth(stroke);
            dc.setColor(Ui.RED, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, 90);
            return;
        }

        if (status[:phase] == :overdue) {
            var late = (-status[:secondsRemaining]).toFloat();
            if (late > 0) {
                var fraction = late / (7.0 * CalendarMath.SECONDS_PER_DAY);
                if (fraction > 1.0) { fraction = 1.0; }
                dc.setPenWidth(stroke);
                dc.setColor(Ui.AMBER, Graphics.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE,
                    90, 90.0 - (360.0 * fraction));
            }
            return;
        }

        drawScheduleArc(dc, active, regimen, status, nowUtc, radius, stroke);
    }

    private function drawTemporaryArc(dc as Graphics.Dc, elapsed as Lang.Number,
                                      radius as Lang.Number, stroke as Lang.Number) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var limit = ScheduleModel.TEMP_LIMIT_SECONDS;
        if (elapsed < limit) {
            dc.setPenWidth(stroke);
            dc.setColor(0x463418, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, 90);
            var fraction = elapsed.toFloat() / limit;
            if (fraction <= 0.0) { return; }
            dc.setColor(Ui.AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE,
                90, 90.0 - (360.0 * fraction));
            return;
        }

        var completedStroke = Math.round(stroke * 0.55).toNumber();
        if (completedStroke < Ui.px(dc, 5)) { completedStroke = Ui.px(dc, 5); }
        dc.setPenWidth(completedStroke);
        dc.setColor(Ui.RED, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, 90);

        var overrun = elapsed - limit;
        if (overrun <= 0) { return; }
        var tailFraction = overrun.toFloat() / limit;
        if (tailFraction > 1.0) { tailFraction = 1.0; }
        dc.setPenWidth(stroke);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE,
            90, 90.0 - (360.0 * tailFraction));
    }

    private function drawScheduleArc(dc as Graphics.Dc, active as Lang.Dictionary,
                                     regimen as Lang.Dictionary, status as Lang.Dictionary,
                                     nowUtc as Lang.Number, radius as Lang.Number,
                                     stroke as Lang.Number) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var boundary = active[:removalUtc] == null
            ? active[:removeDueUtc] : active[:removalUtc];
        var cycleEnd = active[:removalUtc] == null
            ? CalendarMath.addLocalCalendarDays(active[:removeDueUtc], regimen[:daysOut])[:utc]
            : active[:insertDueUtc];
        var duration = cycleEnd - active[:insertionUtc];
        var boundaryFraction = duration <= 0 ? 1.0
            : (boundary - active[:insertionUtc]).toFloat() / duration;
        if (boundaryFraction < 0.0) { boundaryFraction = 0.0; }
        if (boundaryFraction > 1.0) { boundaryFraction = 1.0; }
        var boundaryAngle = 90.0 - (360.0 * boundaryFraction);
        var inStart = 89.0;
        var inEnd = boundaryAngle + 1.0;
        var outStart = boundaryAngle - 1.0;
        var outEnd = -269.0;

        var markerUtc = nowUtc;
        if (markerUtc > status[:underlyingActionUtc]) {
            markerUtc = status[:underlyingActionUtc];
        }
        var markerFraction = duration <= 0 ? 1.0
            : (markerUtc - active[:insertionUtc]).toFloat() / duration;
        if (markerFraction < 0.0) { markerFraction = 0.0; }
        if (markerFraction > 1.0) { markerFraction = 1.0; }
        var markerAngle = 90.0 - (360.0 * markerFraction);

        if (markerFraction < boundaryFraction) {
            drawArcRange(dc, cx, cy, radius, inStart, markerAngle,
                stroke, Ui.RING_IN_DIM);
            drawArcRange(dc, cx, cy, radius, markerAngle, inEnd,
                stroke, Ui.RING_IN);
        } else {
            drawArcRange(dc, cx, cy, radius, inStart, inEnd,
                stroke, Ui.RING_IN_DIM);
        }

        if (regimen[:daysOut] > 0) {
            drawArcRange(dc, cx, cy, radius, outStart, outEnd,
                stroke, Ui.CYCLE_FREE_DIM);
            var freeStroke = stroke / 3;
            if (freeStroke < Ui.px(dc, 3)) { freeStroke = Ui.px(dc, 3); }
            if (markerFraction < boundaryFraction) {
                drawArcRange(dc, cx, cy, radius, outStart, outEnd,
                    freeStroke, Ui.RING_FREE);
            } else {
                drawArcRange(dc, cx, cy, radius, outStart, markerAngle,
                    freeStroke, Ui.RING_FREE_DIM);
                drawArcRange(dc, cx, cy, radius, markerAngle, outEnd,
                    freeStroke, Ui.RING_FREE);
            }
        }

        drawSeam(dc, cx, cy, radius, 90, stroke);
        if (regimen[:daysOut] > 0) {
            drawSeam(dc, cx, cy, radius, boundaryAngle, stroke);
        }
        drawMarker(dc, cx, cy, radius, markerAngle, stroke);
    }

    private function drawArcRange(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                                  radius as Lang.Number, startAngle as Lang.Numeric,
                                  endAngle as Lang.Numeric, stroke as Lang.Number,
                                  color as Lang.Number) as Void {
        if (startAngle.toFloat() - endAngle.toFloat() < 0.5) { return; }
        dc.setPenWidth(stroke);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, startAngle, endAngle);
    }

    private function arcPoint(cx as Lang.Number, cy as Lang.Number, radius as Lang.Number,
                              degrees as Lang.Numeric) as Lang.Array<Lang.Number> {
        var radians = degrees.toFloat() * Math.PI / 180.0;
        return [
            Math.round(cx + radius * Math.cos(radians)).toNumber(),
            Math.round(cy - radius * Math.sin(radians)).toNumber()
        ];
    }

    private function drawSeam(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                              radius as Lang.Number, angle as Lang.Numeric,
                              stroke as Lang.Number) as Void {
        var inner = arcPoint(cx, cy, radius - (stroke / 2) - 1, angle);
        var outer = arcPoint(cx, cy, radius + (stroke / 2) + 1, angle);
        dc.setPenWidth(Ui.px(dc, 2));
        dc.setColor(Ui.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(inner[0], inner[1], outer[0], outer[1]);
    }

    private function drawMarker(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                                radius as Lang.Number, angle as Lang.Numeric,
                                stroke as Lang.Number) as Void {
        var point = arcPoint(cx, cy, radius, angle);
        var markerRadius = Math.round(stroke * 0.72).toNumber();
        dc.setColor(Ui.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(point[0], point[1], markerRadius + Ui.px(dc, 2));
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(point[0], point[1], markerRadius);
    }

    private function drawStatus(dc as Graphics.Dc, active as Lang.Dictionary,
                                status as Lang.Dictionary, reminders as Lang.Dictionary,
                                nowUtc as Lang.Number) as Void {
        if (status[:ringFreeOverSevenDays] || status[:ringInOverFourWeeks]) {
            drawSerious(dc, active, status, reminders, nowUtc);
        } else if (status[:phase] == :overdue) {
            drawOverdue(dc, status, reminders);
        } else {
            drawNormal(dc, status, reminders);
        }
    }

    private function drawNormal(dc as Graphics.Dc, status as Lang.Dictionary,
                                reminders as Lang.Dictionary) as Void {
        var ringFree = status[:phase] == :ringFree;
        var phaseText = Ui.s(ringFree ? Rez.Strings.PhaseRingFree : Rez.Strings.PhaseRingIn);
        var phaseColor = ringFree ? Ui.RING_FREE : Ui.RING_IN;
        var warning = status[:clockBeforeInsertion]
            ? Ui.s(Rez.Strings.MainClockBeforeInsertion) : null;
        var warningLayout = warning != null;
        var headerY = Ui.px(dc, warningLayout ? 90 : 113);
        var heroY = Ui.px(dc, warningLayout ? 174 : 205);
        var dateY = Ui.px(dc, warningLayout ? 252 : 297);

        Ui.trackedCentered(dc, headerY, phaseText, Graphics.FONT_SYSTEM_TINY,
            phaseColor, Ui.px(dc, 1));
        Ui.drawMainDuration(dc, heroY,
            Ui.mainCountdownGroups(status[:secondsRemaining]), null, Ui.PRIMARY);
        drawActionDate(dc, dateY, status[:nextAction], status[:underlyingActionUtc],
            reminders[:clockFormat]);
        if (warning != null) {
            drawWarning(dc, warning as Lang.String, Ui.px(dc, 292),
                Ui.px(dc, 370), Ui.RED);
        }
    }

    private function drawOverdue(dc as Graphics.Dc, status as Lang.Dictionary,
                                 reminders as Lang.Dictionary) as Void {
        var heading = status[:nextAction] == :insert ? Ui.s(Rez.Strings.InsertRing)
            : (status[:nextAction] == :replace ? Ui.s(Rez.Strings.ReplaceRing)
            : Ui.s(Rez.Strings.RemoveRing));
        Ui.trackedCentered(dc, Ui.px(dc, 128), heading, Graphics.FONT_SYSTEM_MEDIUM,
            Ui.AMBER, Ui.px(dc, 1));
        if (status[:secondsRemaining] == 0) {
            Ui.centered(dc, Ui.px(dc, 196), Ui.s(Rez.Strings.DueNow),
                Graphics.FONT_SYSTEM_LARGE, Ui.PRIMARY, Ui.px(dc, 280));
        } else {
            Ui.drawMainDuration(dc, Ui.px(dc, 196),
                Ui.mainLatenessGroups(status[:secondsRemaining]),
                Ui.s(Rez.Strings.MainLateSuffix), Ui.PRIMARY);
        }
        drawDueLine(dc, Ui.px(dc, 283), status[:underlyingActionUtc],
            reminders[:clockFormat]);
    }

    private function drawSerious(dc as Graphics.Dc, active as Lang.Dictionary,
                                 status as Lang.Dictionary, reminders as Lang.Dictionary,
                                 nowUtc as Lang.Number) as Void {
        var isFree = status[:ringFreeOverSevenDays];
        var heading = Ui.s(isFree ? Rez.Strings.InsertRing : Rez.Strings.ReplaceRing);
        var elapsed = isFree ? nowUtc - active[:removalUtc]
            : nowUtc - active[:insertionUtc];
        var dueUtc = isFree ? active[:ringFreeCeilingUtc] : active[:labelFourWeekUtc];
        var suffix = Ui.s(isFree ? Rez.Strings.MainOutSuffix : Rez.Strings.MainInSuffix);
        Ui.trackedCentered(dc, Ui.px(dc, 89), heading, Graphics.FONT_SYSTEM_MEDIUM,
            Ui.RED, Ui.px(dc, 1));
        Ui.drawMainDuration(dc, Ui.px(dc, 167),
            [[Math.floor(elapsed / CalendarMath.SECONDS_PER_DAY).toString(),
                Ui.s(Rez.Strings.DayUnit)]], suffix, Ui.PRIMARY);
        drawDueLine(dc, Ui.px(dc, 258), dueUtc, reminders[:clockFormat]);
        Ui.centered(dc, Ui.px(dc, 322), Ui.s(Rez.Strings.MainBackupAdvised),
            Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY,
            Ui.mainChordClearanceBudget(dc, Ui.px(dc, 322)));
    }

    private function actionPrefix(action as Lang.Symbol) as Lang.String {
        if (action == :insert) { return Ui.s(Rez.Strings.MainInsertPrefix); }
        if (action == :replace) { return Ui.s(Rez.Strings.MainReplacePrefix); }
        return Ui.s(Rez.Strings.MainRemovePrefix);
    }

    private function drawActionDate(dc as Graphics.Dc, y as Lang.Number, action as Lang.Symbol,
                                    dueUtc as Lang.Number, clockFormat as Lang.Number) as Void {
        var prefix = actionPrefix(action);
        var date = Ui.shortDate(dueUtc);
        var compact = Ui.compactDate(dueUtc);
        var time = Ui.timeForUtc(dueUtc, clockFormat);
        var separator = Ui.s(Rez.Strings.DateTimeSeparator);
        var font = Graphics.FONT_SYSTEM_TINY;
        var budget = Ui.mainChordBudget(dc, y);

        var fullRuns = [[prefix + separator, Ui.SECONDARY],
            [date + separator + time, Ui.PRIMARY]];
        if (Ui.runsWidth(dc, fullRuns, font) <= budget) {
            Ui.centeredRuns(dc, y, fullRuns, font);
            return;
        }

        var dateRuns = [[prefix + separator, Ui.SECONDARY], [date, Ui.PRIMARY]];
        if (Ui.runsWidth(dc, dateRuns, font) > budget) {
            dateRuns = [[prefix + separator, Ui.SECONDARY], [compact, Ui.PRIMARY]];
        }
        if (Ui.runsWidth(dc, dateRuns, font) > budget) {
            font = Graphics.FONT_SYSTEM_XTINY;
        }
        Ui.centeredRuns(dc, y - Ui.px(dc, 13), dateRuns, font);
        Ui.centered(dc, y + Ui.px(dc, 16), time, Graphics.FONT_SYSTEM_XTINY,
            Ui.PRIMARY, Ui.mainChordBudget(dc, y + Ui.px(dc, 16)));
    }

    private function drawDueLine(dc as Graphics.Dc, y as Lang.Number, dueUtc as Lang.Number,
                                 clockFormat as Lang.Number) as Void {
        var prefix = Ui.s(Rez.Strings.MainWasDue) + " ";
        var separator = Ui.s(Rez.Strings.DateTimeSeparator);
        var time = Ui.timeForUtc(dueUtc, clockFormat);
        var text = prefix + Ui.shortDate(dueUtc) + separator + time;
        var font = Graphics.FONT_SYSTEM_TINY;
        var budget = Ui.mainChordClearanceBudget(dc, y);
        if (dc.getTextWidthInPixels(text, font) > budget) {
            text = prefix + Ui.compactDate(dueUtc) + separator + time;
        }
        if (dc.getTextWidthInPixels(text, font) > budget) {
            font = Graphics.FONT_SYSTEM_XTINY;
            text = prefix + Ui.shortDate(dueUtc) + separator + time;
        }
        if (dc.getTextWidthInPixels(text, font) > budget) {
            text = prefix + Ui.compactDate(dueUtc) + separator + time;
        }
        if (dc.getTextWidthInPixels(text, font) > budget) {
            text = Ui.compactDate(dueUtc) + separator + time;
        }
        Ui.centered(dc, y, text, font, Ui.SECONDARY, budget);
    }

    private function drawTemporary(dc as Graphics.Dc, status as Lang.Dictionary,
                                   reminders as Lang.Dictionary, nowUtc as Lang.Number) as Void {
        var elapsed = status[:tempElapsed] as Lang.Number;
        var over = elapsed >= ScheduleModel.TEMP_LIMIT_SECONDS;
        var stateColor = over ? Ui.RED : Ui.AMBER;
        Ui.trackedCentered(dc, Ui.px(dc, 70), Ui.s(Rez.Strings.RingIsOut),
            Graphics.FONT_SYSTEM_SMALL, stateColor, Ui.px(dc, 1));
        Ui.drawMainDuration(dc, Ui.px(dc, 150), Ui.mainElapsedGroups(elapsed),
            null, Ui.PRIMARY);
        Ui.centered(dc, Ui.px(dc, 211), Ui.mainLimitDeltaText(elapsed),
            Graphics.FONT_SYSTEM_SMALL, stateColor, Ui.px(dc, 250));
        var outUtc = nowUtc - elapsed;
        Ui.centered(dc, Ui.px(dc, 248),
            Ui.fmt(Rez.Strings.MainOutSince,
                [Ui.timeForUtc(outUtc, reminders[:clockFormat])]),
            Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 260));
        if (over) {
            Ui.centered(dc, Ui.px(dc, 292), Ui.s(Rez.Strings.MainReinsertNow),
                Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 270));
            Ui.centered(dc, Ui.px(dc, 326), Ui.s(Rez.Strings.MainBackupAdvised),
                Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY,
                Ui.mainChordClearanceBudget(dc, Ui.px(dc, 326)));
        }
    }

    private function drawWarning(dc as Graphics.Dc, text as Lang.String,
                                 startY as Lang.Number, bottomY as Lang.Number,
                                 color as Lang.Number) as Void {
        var maxWidth = dc.getWidth() - Ui.px(dc, 124);
        var lines = Ui.warningLines(dc, text, Graphics.FONT_SYSTEM_XTINY, maxWidth);
        var lineHeight = Graphics.getFontHeight(Graphics.FONT_SYSTEM_XTINY) + Ui.px(dc, 4);
        var y = startY;
        for (var i = 0; i < lines.size() && y <= bottomY; i += 1) {
            Ui.centered(dc, y, lines[i], Graphics.FONT_SYSTEM_XTINY, color, maxWidth);
            y += lineHeight;
        }
    }
}

class MainDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }

    function onSelect() as Boolean {
        var app = getApp();
        var state = app.getState();
        var active = state[:active] as Lang.Dictionary?;
        if (active == null) { app.showMainMenu(); return true; }
        var status = ScheduleModel.deriveStatus(currentUtc(), active,
            state[:regimen] as Lang.Dictionary);
        if (status[:temporaryOutOpen]) {
            app.confirmAction(:backIn, currentUtc(), null);
        } else {
            app.showMainMenu();
        }
        return true;
    }

    function onMenu() as Boolean { getApp().showMainMenu(); return true; }
    function onNextPage() as Boolean { getApp().showHistory(); return true; }
    function onPreviousPage() as Boolean { getApp().showUpcoming(); return true; }
}
