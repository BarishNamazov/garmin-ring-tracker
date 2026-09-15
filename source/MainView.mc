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
            dc.setColor(status[:ringFreeLimitExceeded] ? Ui.RED : Ui.AMBER, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 120, -180);
            cap(dc, cx, cy, radius, 120, stroke, status[:ringFreeLimitExceeded] ? Ui.RED : Ui.AMBER);
            cap(dc, cx, cy, radius, -180, stroke, status[:ringFreeLimitExceeded] ? Ui.RED : Ui.AMBER);
            return;
        }

        var total = regimen[:daysIn] + regimen[:daysOut];
        var inSweep = 360.0 * regimen[:daysIn] / total;
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
        }

        var cycleEnd = active[:scheduledInsertionUtc];
        var duration = cycleEnd - active[:insertionUtc];
        var fraction = duration <= 0 ? 1.0 : (nowUtc - active[:insertionUtc]).toFloat() / duration;
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
            phaseText = Ui.s(Rez.Strings.PhaseOverdue);
            phaseColor = status[:ringFreeLimitExceeded] ? Ui.RED : Ui.AMBER;
        }
        var overdue = status[:phase] == :overdue;
        var compactWarning = status[:beyondLabelFourWeeks] && dc.getWidth() <= 390;
        Ui.centered(dc, Ui.px(dc, compactWarning ? (overdue ? 60 : 55) : (overdue ? 68 : 80)), phaseText,
                    Graphics.FONT_SYSTEM_XTINY, phaseColor, Ui.px(dc, 280));
        if (!overdue) {
            Ui.centered(dc, Ui.px(dc, compactWarning ? 82 : 108), Ui.fmt(Rez.Strings.DayTemplate, [status[:dayOfCycle]]),
                        Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 280));
        }

        var heading = Ui.s(Rez.Strings.RemoveIn);
        if (status[:nextAction] == :insert) { heading = status[:phase] == :overdue ? Ui.s(Rez.Strings.InsertRing) : Ui.s(Rez.Strings.InsertIn); }
        else if (status[:nextAction] == :replace) { heading = status[:phase] == :overdue ? Ui.s(Rez.Strings.ReplaceRing) : Ui.s(Rez.Strings.ReplaceIn); }
        else if (status[:phase] == :overdue) { heading = Ui.s(Rez.Strings.RemoveRing); }
        if (status[:ringFreeLimitReached]) { heading = Ui.s(Rez.Strings.InsertNow); }
        Ui.centered(dc, Ui.px(dc, compactWarning ? (overdue ? 100 : 115) : (overdue ? 112 : 148)), heading,
                    Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 280));

        var countdownColor = phaseColor;
        if (status[:secondsRemaining] > 0 && status[:secondsRemaining] < CalendarMath.SECONDS_PER_DAY) { countdownColor = Ui.AMBER; }
        if (overdue) {
            Ui.centered(dc, Ui.px(dc, compactWarning ? 137 : 154), Ui.s(Rez.Strings.OverdueBy),
                        Graphics.FONT_SYSTEM_XTINY, countdownColor, Ui.px(dc, 260));
        }
        if (compactWarning) {
            Ui.drawCompactCountdown(dc, Ui.px(dc, overdue ? 186 : 173), status[:secondsRemaining], countdownColor);
        } else {
            Ui.drawCountdown(dc, Ui.px(dc, overdue ? 211 : 212), status[:secondsRemaining], countdownColor);
        }
        Ui.centered(dc, Ui.px(dc, compactWarning ? (overdue ? 240 : 226) : (overdue ? 270 : 276)), Ui.dateOnly(status[:nextActionUtc]),
                    Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, compactWarning ? (overdue ? 268 : 254) : (overdue ? 300 : 307)),
                    Ui.timeForUtc(status[:nextActionUtc], reminders[:clockFormat]),
                    Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 260));

        var hint = Ui.s(Rez.Strings.MenuStartHint);
        var hintColor = Ui.SECONDARY;
        if (status[:clockBeforeInsertion]) { hint = Ui.s(Rez.Strings.WatchBeforeInsertion); hintColor = Ui.RED; }
        else if (status[:ringFreeLimitExceeded]) { hint = Ui.s(Rez.Strings.RingFreeLimitPassed); hintColor = Ui.RED; }
        else if (status[:ringFreeLimitReached]) { hint = Ui.s(Rez.Strings.RingFreeLimitReached); hintColor = Ui.AMBER; }
        else if (status[:beyondLabelFourWeeks]) {
            Ui.centered(dc, Ui.px(dc, compactWarning ? (overdue ? 292 : 280) : 326), Ui.s(Rez.Strings.BeyondFourWeeksLine1),
                        Graphics.FONT_SYSTEM_XTINY, Ui.AMBER, Ui.px(dc, 260));
            Ui.centered(dc, Ui.px(dc, compactWarning ? (overdue ? 312 : 300) : 350), Ui.s(Rez.Strings.BeyondFourWeeksLine2),
                        Graphics.FONT_SYSTEM_XTINY, Ui.AMBER, Ui.px(dc, 220));
            if (compactWarning) {
                Ui.centered(dc, Ui.px(dc, overdue ? 340 : 332), hint, Graphics.FONT_SYSTEM_XTINY,
                            Ui.SECONDARY, Ui.px(dc, 280));
            }
            return;
        }
        else if ((getApp().getState()[:active] as Lang.Dictionary)[:plannedOverrideUtc] != null) { hint = Ui.s(Rez.Strings.AdjustedBadge); hintColor = Ui.AMBER; }
        Ui.centered(dc, Ui.px(dc, 330), hint, Graphics.FONT_SYSTEM_XTINY, hintColor, Ui.px(dc, 300));
    }

    private function drawTemporary(dc as Graphics.Dc, status as Lang.Dictionary) as Void {
        var elapsed = status[:tempElapsed];
        var color = elapsed > ScheduleModel.TEMP_LIMIT_SECONDS ? Ui.RED : (elapsed >= 9000 ? Ui.AMBER : Ui.PRIMARY);
        Ui.centered(dc, Ui.px(dc, 86), Ui.s(Rez.Strings.RingIsOut), Graphics.FONT_SYSTEM_XTINY, color, Ui.px(dc, 280));
        Ui.centered(dc, Ui.px(dc, 148), Ui.s(Rez.Strings.Elapsed), Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 280));
        Ui.drawCountdown(dc, Ui.px(dc, 212), elapsed, color);
        var boundary = Ui.s(Rez.Strings.ReinsertSoon);
        if (elapsed < ScheduleModel.TEMP_LIMIT_SECONDS) {
            var remainingMinutes = (ScheduleModel.TEMP_LIMIT_SECONDS - elapsed + 59) / 60;
            boundary = Ui.fmt(Rez.Strings.ThreeHourInTemplate, [remainingMinutes]);
        } else if (elapsed == ScheduleModel.TEMP_LIMIT_SECONDS) {
            boundary = Ui.s(Rez.Strings.ThreeHourReached);
        } else {
            boundary = Ui.s(Rez.Strings.RecordedOutOver3h);
        }
        if (elapsed == ScheduleModel.TEMP_LIMIT_SECONDS) {
            Ui.drawParagraphs(dc, [boundary], Ui.px(dc, 258), Ui.px(dc, 300), 0);
        } else {
            Ui.centered(dc, Ui.px(dc, 270), boundary, Graphics.FONT_SYSTEM_XTINY, color, Ui.px(dc, 300));
        }
        Ui.centered(dc, Ui.px(dc, 324), Ui.s(Rez.Strings.RingBackIn), Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 260));
        Ui.centered(dc, Ui.px(dc, 354), Ui.s(Rez.Strings.PressStart), Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 260));
    }
}

class MainDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }

    function onSelect() as Boolean {
        var app = getApp();
        var state = app.getState();
        var active = state[:active] as Lang.Dictionary;
        var status = ScheduleModel.deriveStatus(currentUtc(), active, state[:regimen] as Lang.Dictionary);
        if (status[:temporaryOutOpen]) { app.confirmAction(:backIn, currentUtc(), null); }
        else if (status[:phase] == :overdue || status[:beyondLabelFourWeeks] || status[:clockBeforeInsertion]) { app.showAlert(); }
        else { app.showMainMenu(); }
        return true;
    }

    function onMenu() as Boolean { getApp().showMainMenu(); return true; }
    function onNextPage() as Boolean { getApp().showSchedule(); return true; }
    function onPreviousPage() as Boolean { getApp().showSchedule(); return true; }
}
