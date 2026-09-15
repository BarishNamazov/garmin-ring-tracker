import Toybox.Graphics;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class InfoView extends WatchUi.View {
    protected var _title;
    protected var _paragraphs as Lang.Array<Lang.String>;
    protected var _scroll as Lang.Number;
    protected var _lineCount as Lang.Number;

    function initialize(title, paragraphs as Lang.Array<Lang.String>) {
        View.initialize();
        _title = title;
        _paragraphs = paragraphs;
        _scroll = 0;
        _lineCount = 0;
    }

    function scroll(delta as Lang.Number) as Void {
        _scroll += delta;
        if (_scroll < 0) { _scroll = 0; }
        if (_scroll >= _lineCount) { _scroll = _lineCount > 0 ? _lineCount - 1 : 0; }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var titleText = _title instanceof Lang.ResourceId ? Ui.s(_title) : _title as Lang.String;
        Ui.centered(dc, Ui.px(dc, 66), titleText, Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        _lineCount = Ui.drawParagraphs(dc, _paragraphs, Ui.px(dc, 112), Ui.px(dc, 316), _scroll);
        Ui.centered(dc, Ui.px(dc, 356), Ui.s(Rez.Strings.BackHint), Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 240));
    }
}

class DisclaimerView extends InfoView {
    function initialize() {
        InfoView.initialize(Rez.Strings.ScheduleAidTitle, [Ui.s(Rez.Strings.DisclaimerLine1), Ui.s(Rez.Strings.DisclaimerLine2), Ui.s(Rez.Strings.DisclaimerLine3), Ui.s(Rez.Strings.DisclaimerLine4)]);
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        Ui.centered(dc, Ui.px(dc, 68), Ui.s(Rez.Strings.ScheduleAidTitle), Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        _lineCount = Ui.drawParagraphs(dc, _paragraphs, Ui.px(dc, 118), Ui.px(dc, 286), _scroll);
        Ui.centered(dc, Ui.px(dc, 328), Ui.s(Rez.Strings.StartContinue), Graphics.FONT_SYSTEM_TINY, Ui.PRIMARY, Ui.px(dc, 280));
    }
}

class DisclaimerDelegate extends ScrollDelegate {
    function initialize() { ScrollDelegate.initialize(); }
    function onSelect() as Boolean { getApp().confirmAction(:acceptDisclaimer, currentUtc(), null); return true; }
}

class RegimenView extends WatchUi.View {
    private var _focus as Lang.Number;

    function initialize() { View.initialize(); _focus = 3; }

    function moveFocus(delta as Lang.Number) as Void {
        _focus += delta;
        if (_focus < 0) { _focus = 3; }
        if (_focus > 3) { _focus = 0; }
        WatchUi.requestUpdate();
    }

    function focus() as Lang.Number { return _focus; }

    private function focusRail(dc as Graphics.Dc, y as Lang.Number) as Void {
        dc.setColor(Ui.RING_IN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(Ui.px(dc, 46), y - Ui.px(dc, 15), Ui.px(dc, 10), Ui.px(dc, 30));
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var regimen = getApp().getState()[:regimen] as Lang.Dictionary;
        Ui.centered(dc, Ui.px(dc, 66), Ui.s(Rez.Strings.RegimenTitle), Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        Ui.centered(dc, Ui.px(dc, 112), Ui.s(Rez.Strings.ProductLine1), Graphics.FONT_SYSTEM_XTINY, Ui.PRIMARY, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 142), Ui.s(Rez.Strings.ProductLine2), Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 300));
        Ui.row(dc, Ui.px(dc, 205), Ui.s(Rez.Strings.InRing), Ui.fmt(Rez.Strings.DaysTemplate, [regimen[:daysIn]]));
        Ui.row(dc, Ui.px(dc, 245), Ui.s(Rez.Strings.RingFree),
            Ui.fmt(regimen[:daysOut] == 1 ? Rez.Strings.OneDayTemplate : Rez.Strings.DaysTemplate, [regimen[:daysOut]]));
        Ui.centered(dc, Ui.px(dc, 292), Ui.s(Rez.Strings.AnnoveraUnsupported), Graphics.FONT_SYSTEM_XTINY, Ui.AMBER, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 340), Ui.s(Rez.Strings.StartConfirm), Graphics.FONT_SYSTEM_TINY, Ui.PRIMARY, Ui.px(dc, 280));
        var ys = [205, 245, 292, 340];
        focusRail(dc, Ui.px(dc, ys[_focus]));
    }
}

class RegimenDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    private function view() as RegimenView { return WatchUi.getCurrentView()[0] as RegimenView; }
    function onSelect() as Boolean {
        var focus = view().focus();
        var regimen = getApp().getState()[:regimen] as Lang.Dictionary;
        if (focus == 0) { PickerFlow.openNumber(:setDaysIn, 21, 35, regimen[:daysIn], Rez.Strings.DaysRingIn); }
        else if (focus == 1) { PickerFlow.openNumber(:setDaysOut, 0, 7, regimen[:daysOut], Rez.Strings.DaysRingFree); }
        else if (focus == 2) { getApp().showAbout(); }
        else { getApp().confirmAction(:acceptRegimen, currentUtc(), null); }
        return true;
    }
    function onNextPage() as Boolean { view().moveFocus(1); return true; }
    function onPreviousPage() as Boolean { view().moveFocus(-1); return true; }
}

class ScheduleView extends WatchUi.View {
    function initialize() { View.initialize(); }
    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary;
        var regimen = state[:regimen] as Lang.Dictionary;
        var reminders = state[:reminders] as Lang.Dictionary;
        var status = ScheduleModel.deriveStatus(currentUtc(), active, regimen);
        Ui.centered(dc, Ui.px(dc, 48), Ui.s(Rez.Strings.ScheduleTitle), Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        Ui.compactRow(dc, Ui.px(dc, 92), Ui.s(Rez.Strings.InsertedLabel), Ui.shortTimestamp(active[:insertionUtc], reminders[:clockFormat]));
        Ui.compactRow(dc, Ui.px(dc, 132), Ui.s(Rez.Strings.RemoveLabel), Ui.shortTimestamp(active[:scheduledRemovalUtc], reminders[:clockFormat]));
        Ui.compactRow(dc, Ui.px(dc, 172), Ui.s(Rez.Strings.InsertLabel), Ui.shortTimestamp(active[:scheduledInsertionUtc], reminders[:clockFormat]));
        Ui.compactRow(dc, Ui.px(dc, 232), Ui.s(Rez.Strings.CycleDayLabel), status[:dayOfCycle].toString());
        Ui.compactRow(dc, Ui.px(dc, 272), Ui.s(Rez.Strings.PlanLabel), Ui.fmt(Rez.Strings.PlanTemplate, [regimen[:daysIn], regimen[:daysOut]]));
        Ui.centered(dc, Ui.px(dc, 320), Ui.s(Rez.Strings.TimesCurrentLocal), Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 350), Ui.s(Rez.Strings.BackHint), Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 240));
    }
}

class AboutView extends InfoView {
    function initialize() {
        InfoView.initialize(Rez.Strings.AboutTitle, [Ui.s(Rez.Strings.ProductVersion), Ui.s(Rez.Strings.DisclaimerLine1), Ui.s(Rez.Strings.DisclaimerLine2), Ui.s(Rez.Strings.DisclaimerLine3), Ui.s(Rez.Strings.DisclaimerLine4), Ui.s(Rez.Strings.SupportedScope), Ui.s(Rez.Strings.AnnoveraUnsupported), Ui.s(Rez.Strings.ReminderLimit), Ui.s(Rez.Strings.Privacy), Ui.s(Rez.Strings.SourcesTitle), Ui.s(Rez.Strings.SourcesLine1), Ui.s(Rez.Strings.SourcesLine2), Ui.s(Rez.Strings.ReviewDate)]);
    }
}

class AlertView extends WatchUi.View {
    private var _attentionPlayed as Lang.Boolean;
    private var _detail as Lang.Boolean;

    function initialize() {
        View.initialize();
        _attentionPlayed = false;
        _detail = false;
    }

    function scroll(delta as Lang.Number) as Void {
        _detail = delta > 0;
        WatchUi.requestUpdate();
    }

    function onShow() as Void {
        if (_attentionPlayed) { return; }
        _attentionPlayed = true;
        var reminders = getApp().getState()[:reminders] as Lang.Dictionary;
        var device = System.getDeviceSettings();
        if (!device.doNotDisturb && reminders[:vibrationEnabled] && device.vibrateOn) {
            Attention.vibrate([new Attention.VibeProfile(50, 300)]);
        }
        if (!device.doNotDisturb && reminders[:soundEnabled] && device.tonesOn) {
            Attention.playTone(Attention.TONE_ALERT_LO);
        }
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary?;
        if (active == null) {
            Ui.centered(dc, dc.getHeight() / 2, Ui.s(Rez.Strings.SetupNeeded),
                        Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 280));
            return;
        }
        var nowUtc = currentUtc();
        var status = ScheduleModel.deriveStatus(nowUtc, active, state[:regimen] as Lang.Dictionary);
        var title = Rez.Strings.ActionDueTitle;
        var color = Ui.AMBER;
        var detail = Rez.Strings.ActionDueBody;
        var hint = Rez.Strings.AlertRecordHint;
        if (status[:ringFreeLimitExceeded]) {
            title = Rez.Strings.AlertRingFreeTitle;
            color = Ui.RED;
            detail = Rez.Strings.RingFreeExceededBody;
            hint = Rez.Strings.AlertLabelHint;
        } else if (status[:temporaryOutOpen] && status[:tempElapsed] > ScheduleModel.TEMP_LIMIT_SECONDS) {
            title = Rez.Strings.AlertTemporaryTitle;
            color = Ui.RED;
            var open = ScheduleModel.tempOpen(active) as Lang.Dictionary;
            detail = open[:phaseWeekAtStart] == 3 ? Rez.Strings.TempOverBody3 : Rez.Strings.TempOverBody12;
            hint = Rez.Strings.AlertLabelHint;
        } else if (status[:beyondLabelFourWeeks]) {
            title = Rez.Strings.AlertDurationTitle;
            detail = Rez.Strings.ExtendedBody;
            hint = Rez.Strings.AlertLabelHint;
        } else if (status[:clockBeforeInsertion]) {
            title = Rez.Strings.AlertDateReviewTitle;
            color = Ui.RED;
            hint = Rez.Strings.AlertReviewDateHint;
        } else if (status[:secondsRemaining] <= 0) {
            title = Rez.Strings.AlertOverdueTitle;
        }

        if (_detail) {
            Ui.centered(dc, Ui.px(dc, 62), Ui.s(Rez.Strings.LabelInformationTitle),
                        Graphics.FONT_SYSTEM_SMALL, color, Ui.px(dc, 280));
            Ui.drawParagraphs(dc, [Ui.s(detail), Ui.s(Rez.Strings.AboutSourcesHint)],
                              Ui.px(dc, 108), Ui.px(dc, 310), 0);
            Ui.centered(dc, Ui.px(dc, 354), Ui.s(Rez.Strings.AlertActionsHint),
                        Graphics.FONT_SYSTEM_XTINY, Ui.PRIMARY, Ui.px(dc, 300));
            return;
        }

        var action = Ui.s(Rez.Strings.RemoveRing);
        if (status[:nextAction] == :insert) { action = Ui.s(Rez.Strings.InsertRing); }
        else if (status[:nextAction] == :replace) { action = Ui.s(Rez.Strings.ReplaceRing); }
        else if (status[:nextAction] == :ringBackIn) { action = Ui.s(Rez.Strings.RingBackInAction); }
        var timing = Ui.s(Rez.Strings.DueNow);
        if (status[:temporaryOutOpen]) {
            timing = Ui.fmt(Rez.Strings.AlertOutFor, [Ui.countdownText(status[:tempElapsed])]);
        } else if (status[:secondsRemaining] < 0) {
            timing = Ui.fmt(Rez.Strings.AlertOverdueBy, [Ui.countdownText(status[:secondsRemaining])]);
        } else if (CalendarMath.dateOrdinal(nowUtc) == CalendarMath.dateOrdinal(status[:nextActionUtc])) {
            timing = Ui.fmt(Rez.Strings.AlertDueTodayAt,
                            [Ui.timeForUtc(status[:nextActionUtc], (state[:reminders] as Lang.Dictionary)[:clockFormat])]);
        } else {
            timing = Ui.fmt(Rez.Strings.AlertDueIn, [Ui.countdownText(status[:secondsRemaining])]);
        }
        var clock = (state[:reminders] as Lang.Dictionary)[:clockFormat];
        Ui.centered(dc, Ui.px(dc, 58), Ui.s(title), Graphics.FONT_SYSTEM_SMALL, color, Ui.px(dc, 286));
        Ui.centered(dc, Ui.px(dc, 112), action, Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 164), timing, Graphics.FONT_SYSTEM_TINY, color, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 213), Ui.s(Rez.Strings.NextActionLabel),
                    Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 280));
        Ui.centered(dc, Ui.px(dc, 246), Ui.dateOnly(status[:nextActionUtc]),
                    Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 277), Ui.timeForUtc(status[:nextActionUtc], clock),
                    Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 260));
        Ui.centered(dc, Ui.px(dc, 316), Ui.s(hint), Graphics.FONT_SYSTEM_XTINY, color, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 354), Ui.s(Rez.Strings.AlertActionsHint),
                    Graphics.FONT_SYSTEM_XTINY, Ui.PRIMARY, Ui.px(dc, 300));
    }
}

class ScrollDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onNextPage() as Boolean { (WatchUi.getCurrentView()[0] as InfoView).scroll(1); return true; }
    function onPreviousPage() as Boolean { (WatchUi.getCurrentView()[0] as InfoView).scroll(-1); return true; }
    function onBack() as Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
}

class PopDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onBack() as Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onNextPage() as Boolean { WatchUi.popView(WatchUi.SLIDE_DOWN); return true; }
    function onPreviousPage() as Boolean { WatchUi.popView(WatchUi.SLIDE_UP); return true; }
}

class AlertDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    private function view() as AlertView { return WatchUi.getCurrentView()[0] as AlertView; }
    function onSelect() as Boolean { getApp().showAlertMenu(); return true; }
    function onNextPage() as Boolean { view().scroll(1); return true; }
    function onPreviousPage() as Boolean { view().scroll(-1); return true; }
    function onBack() as Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
}

class SettingsReviewView extends InfoView {
    function initialize() {
        var pending = getApp().getPendingSettings();
        var body = pending != null && (pending as Lang.Dictionary)[:invalid] == true
            ? Rez.Strings.InvalidSettingsBody : Rez.Strings.SettingsReviewBody;
        InfoView.initialize(Rez.Strings.SettingsReviewTitle, [Ui.s(body)]);
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var titleText = _title instanceof Lang.ResourceId ? Ui.s(_title) : _title as Lang.String;
        Ui.centered(dc, Ui.px(dc, 66), titleText, Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        _lineCount = Ui.drawParagraphs(dc, _paragraphs, Ui.px(dc, 112), Ui.px(dc, 292), _scroll);
        Ui.centered(dc, Ui.px(dc, 350), Ui.s(Rez.Strings.SettingsReviewActionsHint),
                    Graphics.FONT_SYSTEM_XTINY, Ui.PRIMARY, Ui.px(dc, 300));
    }
}

class SettingsReviewDelegate extends ScrollDelegate {
    function initialize() { ScrollDelegate.initialize(); }
    function onSelect() as Boolean { getApp().showSettingsConfirmation(); return true; }
}

class SettingsConfirmationDelegate extends WatchUi.ConfirmationDelegate {
    private var _timer as Timer.Timer?;
    private var _accept as Lang.Boolean;
    function initialize() { ConfirmationDelegate.initialize(); _timer = null; _accept = false; }
    function onResponse(value as WatchUi.Confirm) as Boolean {
        _accept = value == WatchUi.CONFIRM_YES;
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:apply), 100, false);
        return true;
    }
    function apply() as Void {
        if (_timer != null) { (_timer as Timer.Timer).stop(); }
        getApp().resolvePendingSettings(_accept);
    }
}

class ActionConfirmationDelegate extends WatchUi.ConfirmationDelegate {
    private var _action as Lang.Symbol;
    private var _atUtc as Lang.Number;
    private var _data;
    private var _timer as Timer.Timer?;
    function initialize(action as Lang.Symbol, atUtc as Lang.Number, data) {
        ConfirmationDelegate.initialize();
        _action = action;
        _atUtc = atUtc;
        _data = data;
        _timer = null;
    }
    function onResponse(value as WatchUi.Confirm) as Boolean {
        if (value == WatchUi.CONFIRM_YES) {
            _timer = new Timer.Timer();
            (_timer as Timer.Timer).start(method(:apply), 100, false);
        }
        return true;
    }
    function apply() as Void {
        if (_timer != null) { (_timer as Timer.Timer).stop(); }
        getApp().performConfirmed(_action, _atUtc, _data);
    }
}
