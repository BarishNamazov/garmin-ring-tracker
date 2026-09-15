import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Timer;
import Toybox.WatchUi;

class MainView extends WatchUi.View {
    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
        _timer = null;
    }

    function onShow() as Void {
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary?;
        var interval = 3600000;
        if (active != null) {
            var status = ScheduleModel.deriveStatus(currentUtc(), active, state[:regimen] as Lang.Dictionary);
            if (status[:temporaryOutOpen] || status[:secondsRemaining].abs() < CalendarMath.SECONDS_PER_DAY) { interval = 60000; }
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
            Ui.centered(dc, dc.getHeight() / 2, Ui.s(Rez.Strings.SetupNeeded), Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 280));
            return;
        }
        var regimen = state[:regimen] as Lang.Dictionary;
        var reminders = state[:reminders] as Lang.Dictionary;
        var nowUtc = currentUtc();
        var status = ScheduleModel.deriveStatus(nowUtc, active, regimen);
        drawArc(dc, active, regimen, status, nowUtc);
        if (status[:temporaryOutOpen]) { drawTemporary(dc, status); }
        else { drawStatus(dc, status, reminders); }
    }

    private function drawArc(dc as Graphics.Dc, active as Lang.Dictionary, regimen as Lang.Dictionary,
                             status as Lang.Dictionary, nowUtc as Lang.Number) as Void {
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        var radius = Ui.px(dc, 184);
        var stroke = Ui.px(dc, 14);
        dc.setPenWidth(stroke);
        dc.setColor(Ui.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, 90);

        if (status[:phase] == :overdue && !status[:temporaryOutOpen]) {
            dc.setColor(status[:ringFreeOverSevenDays] || status[:ringInOverFourWeeks] ? Ui.RED : Ui.AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 120, -180);
            cap(dc, cx, cy, radius, 120, stroke, status[:ringFreeOverSevenDays] || status[:ringInOverFourWeeks] ? Ui.RED : Ui.AMBER);
            cap(dc, cx, cy, radius, -180, stroke, status[:ringFreeOverSevenDays] || status[:ringInOverFourWeeks] ? Ui.RED : Ui.AMBER);
            return;
        }

        var boundary = active[:removalUtc] == null ? active[:removeDueUtc] : active[:removalUtc];
        var cycleEnd = active[:removalUtc] == null
            ? CalendarMath.addLocalCalendarDays(active[:removeDueUtc], regimen[:daysOut])[:utc]
            : active[:insertDueUtc];
        var cycleDuration = cycleEnd - active[:insertionUtc];
        var boundaryFraction = cycleDuration <= 0 ? 1.0
            : (boundary - active[:insertionUtc]).toFloat() / cycleDuration;
        if (boundaryFraction < 0.0) { boundaryFraction = 0.0; }
        if (boundaryFraction > 1.0) { boundaryFraction = 1.0; }
        var inSweep = 360.0 * boundaryFraction;
        var dim = status[:temporaryOutOpen];
        var inColor = dim ? 0x144B39 : Ui.RING_IN;
        var outColor = dim ? 0x372C59 : Ui.RING_FREE;
        dc.setColor(inColor, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 89, 91 - inSweep);
        cap(dc, cx, cy, radius, 89, stroke, inColor);
        cap(dc, cx, cy, radius, 91 - inSweep, stroke, inColor);
        if (regimen[:daysOut] > 0) {
            dc.setColor(outColor, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 89 - inSweep, -269);
            cap(dc, cx, cy, radius, 89 - inSweep, stroke, outColor);
            cap(dc, cx, cy, radius, -269, stroke, outColor);
        } else {
            dc.setPenWidth(Ui.px(dc, 5));
            dc.setColor(outColor, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 91 - inSweep, 88 - inSweep);
        }

        var duration = cycleEnd - active[:insertionUtc];
        var markerUtc = nowUtc;
        if (markerUtc > status[:underlyingActionUtc]) { markerUtc = status[:underlyingActionUtc]; }
        var fraction = duration <= 0 ? 1.0 : (markerUtc - active[:insertionUtc]).toFloat() / duration;
        if (fraction < 0) { fraction = 0.0; }
        if (fraction > 1) { fraction = 1.0; }
        var angle = 90.0 - (360.0 * fraction);
        var point = arcPoint(cx, cy, radius, angle);
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(point[0], point[1], Ui.px(dc, 8));
        dc.setColor(Ui.BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(point[0], point[1], Ui.px(dc, 3));
    }

    private function arcPoint(cx as Lang.Number, cy as Lang.Number, radius as Lang.Number, degrees as Lang.Numeric) as Lang.Array<Lang.Number> {
        var radians = degrees.toFloat() * Math.PI / 180.0;
        return [
            Math.round(cx + radius * Math.cos(radians)).toNumber(),
            Math.round(cy - radius * Math.sin(radians)).toNumber()
        ];
    }

    private function cap(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number, radius as Lang.Number,
                         degrees as Lang.Numeric, stroke as Lang.Number, color as Lang.Number) as Void {
        var point = arcPoint(cx, cy, radius, degrees);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(point[0], point[1], stroke / 2);
    }

    private function drawStatus(dc as Graphics.Dc, status as Lang.Dictionary, reminders as Lang.Dictionary) as Void {
        var phaseText = Ui.s(Rez.Strings.PhaseRingIn);
        var phaseColor = Ui.RING_IN;
        if (status[:phase] == :ringFree) {
            phaseText = Ui.s(Rez.Strings.PhaseRingFree);
            phaseColor = Ui.RING_FREE;
        } else if (status[:phase] == :overdue) {
            phaseText = status[:nextAction] == :insert ? Ui.s(Rez.Strings.InsertRing)
                : (status[:nextAction] == :replace ? Ui.s(Rez.Strings.ReplaceRing)
                : Ui.s(Rez.Strings.RemoveRing));
            phaseColor = status[:ringFreeOverSevenDays] || status[:ringInOverFourWeeks] ? Ui.RED : Ui.AMBER;
        }
        var overdue = status[:phase] == :overdue;
        var warning = null;
        if (status[:clockBeforeInsertion]) { warning = Ui.s(Rez.Strings.WatchBeforeInsertion); }
        else if (status[:ringFreeOverSevenDays]) { warning = Ui.s(Rez.Strings.RingFreeLimitPassed); }
        else if (status[:ringInOverFourWeeks]) { warning = Ui.s(Rez.Strings.BeyondFourWeeks); }
        var warningLayout = warning != null;
        Ui.centered(dc, Ui.px(dc, warningLayout ? 68 : 90), phaseText,
                    Graphics.FONT_SYSTEM_SMALL, phaseColor, Ui.px(dc, 286));
        var countdownColor = phaseColor;
        if (status[:secondsRemaining] > 0 && status[:secondsRemaining] < CalendarMath.SECONDS_PER_DAY) { countdownColor = Ui.AMBER; }
        if (overdue) {
            Ui.centered(dc, Ui.px(dc, warningLayout ? 168 : 194),
                status[:secondsRemaining] == 0 ? Ui.s(Rez.Strings.DueNow)
                    : Ui.fmt(Rez.Strings.LateTemplate, [Ui.compactElapsed(status[:secondsRemaining])]),
                Graphics.FONT_SYSTEM_LARGE, countdownColor, Ui.px(dc, 300));
        } else {
            Ui.drawCountdown(dc, Ui.px(dc, warningLayout ? 168 : 194), status[:secondsRemaining], countdownColor);
        }
        var dateId = status[:nextAction] == :insert ? Rez.Strings.MainInsertDate
            : (status[:nextAction] == :replace ? Rez.Strings.MainReplaceDate : Rez.Strings.MainRemoveDate);
        var dueTime = Ui.timeForUtc(status[:underlyingActionUtc], reminders[:clockFormat]);
        var dueLabel = Ui.fmt(dateId, [Ui.dateOnly(status[:underlyingActionUtc]), dueTime]);
        if (overdue) {
            dueLabel = Ui.fmt(Rez.Strings.MainDueDate,
                [Ui.dateOnly(status[:underlyingActionUtc]),
                 Ui.timeForUtc(status[:underlyingActionUtc], reminders[:clockFormat])]);
        }
        var separator = Ui.s(Rez.Strings.DateTimeSeparator);
        var dateLength = dueLabel.length() - dueTime.length() - separator.length();
        var datePart = dateLength > 0 ? dueLabel.substring(0, dateLength) : dueLabel;
        Ui.centered(dc, Ui.px(dc, warningLayout ? 238 : 270), datePart,
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 330));
        Ui.centered(dc, Ui.px(dc, warningLayout ? 266 : 300), dueTime,
            Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 270));
        if (warning != null) {
            drawWarning(dc, warning as Lang.String, Ui.px(dc, 294), Ui.px(dc, 354));
        }
    }

    private function drawTemporary(dc as Graphics.Dc, status as Lang.Dictionary) as Void {
        var elapsed = status[:tempElapsed];
        var color = elapsed > ScheduleModel.TEMP_LIMIT_SECONDS ? Ui.RED : (elapsed >= 9000 ? Ui.AMBER : Ui.PRIMARY);
        var warningLayout = elapsed >= ScheduleModel.TEMP_LIMIT_SECONDS;
        Ui.centered(dc, Ui.px(dc, warningLayout ? 68 : 90), Ui.s(Rez.Strings.RingIsOut),
            Graphics.FONT_SYSTEM_SMALL, color, Ui.px(dc, 280));
        Ui.drawCountdown(dc, Ui.px(dc, warningLayout ? 168 : 194), elapsed, color);
        var boundary = Ui.s(Rez.Strings.ReinsertSoon);
        if (elapsed < ScheduleModel.TEMP_LIMIT_SECONDS) {
            boundary = Ui.s(Rez.Strings.ThreeHourInTemplate);
        } else if (elapsed == ScheduleModel.TEMP_LIMIT_SECONDS) {
            boundary = Ui.s(Rez.Strings.ThreeHourReached);
        } else {
            boundary = Ui.s(Rez.Strings.RecordedOutOver3h);
        }
        if (elapsed == ScheduleModel.TEMP_LIMIT_SECONDS) {
            drawWarning(dc, boundary, Ui.px(dc, 304), Ui.px(dc, 354));
        } else if (elapsed > ScheduleModel.TEMP_LIMIT_SECONDS) {
            drawWarning(dc, boundary, Ui.px(dc, 278), Ui.px(dc, 365));
        } else {
            Ui.centered(dc, Ui.px(dc, 285), boundary, Graphics.FONT_SYSTEM_XTINY, color, Ui.px(dc, 300));
        }
    }

    private function drawWarning(dc as Graphics.Dc, text as Lang.String,
                                 startY as Lang.Number, bottomY as Lang.Number) as Void {
        var lines = Ui.warningLines(dc, text, Graphics.FONT_SYSTEM_XTINY, dc.getWidth() - Ui.px(dc, 124));
        var lineHeight = Graphics.getFontHeight(Graphics.FONT_SYSTEM_XTINY) + Ui.px(dc, 4);
        var y = startY;
        for (var i = 0; i < lines.size() && y <= bottomY; i += 1) {
            Ui.centered(dc, y, lines[i], Graphics.FONT_SYSTEM_XTINY, Ui.RED, Ui.px(dc, 292));
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
        var status = ScheduleModel.deriveStatus(currentUtc(), active, state[:regimen] as Lang.Dictionary);
        if (status[:temporaryOutOpen]) { app.confirmAction(:backIn, currentUtc(), null); }
        else { app.showMainMenu(); }
        return true;
    }

    function onMenu() as Boolean { getApp().showMainMenu(); return true; }
    function onNextPage() as Boolean { getApp().showHistory(); return true; }
    function onPreviousPage() as Boolean { getApp().showUpcoming(); return true; }
}
