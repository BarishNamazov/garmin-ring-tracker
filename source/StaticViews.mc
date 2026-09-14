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
        _lineCount = Ui.drawParagraphs(dc, _paragraphs, Ui.px(dc, 112), Ui.px(dc, 326), _scroll);
        Ui.centered(dc, Ui.px(dc, 354), Ui.s(Rez.Strings.BackHint), Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 240));
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

class AlertView extends InfoView {
    private var _attentionPlayed as Lang.Boolean;

    function initialize() {
        var paragraphs = [Ui.s(Rez.Strings.ActionDueBody)];
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary;
        var status = ScheduleModel.deriveStatus(currentUtc(), active, state[:regimen] as Lang.Dictionary);
        if (status[:ringFreeLimitExceeded]) { paragraphs = [Ui.s(Rez.Strings.RingFreeExceededBody)]; }
        else if (status[:temporaryOutOpen] && status[:tempElapsed] > ScheduleModel.TEMP_LIMIT_SECONDS) {
            var open = ScheduleModel.tempOpen(active) as Lang.Dictionary;
            paragraphs = [Ui.s(open[:phaseWeekAtStart] == 3 ? Rez.Strings.TempOverBody3 : Rez.Strings.TempOverBody12)];
        } else if (status[:beyondLabelFourWeeks]) { paragraphs = [Ui.s(Rez.Strings.ExtendedBody)]; }
        InfoView.initialize(Rez.Strings.ActionDueTitle, paragraphs);
        _attentionPlayed = false;
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
        InfoView.onUpdate(dc);
        Ui.centered(dc, Ui.px(dc, 337), Ui.s(Rez.Strings.StartOpenActions), Graphics.FONT_SYSTEM_XTINY, Ui.PRIMARY, Ui.px(dc, 280));
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

class AlertDelegate extends ScrollDelegate {
    function initialize() { ScrollDelegate.initialize(); }
    function onSelect() as Boolean { getApp().showMainMenu(); return true; }
}

class SettingsReviewView extends InfoView {
    function initialize() {
        var pending = getApp().getPendingSettings();
        var body = pending != null && (pending as Lang.Dictionary)[:invalid] == true
            ? Rez.Strings.InvalidSettingsBody : Rez.Strings.SettingsReviewBody;
        InfoView.initialize(Rez.Strings.SettingsReviewTitle, [Ui.s(body)]);
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        InfoView.onUpdate(dc);
        Ui.centered(dc, Ui.px(dc, 326), Ui.s(Rez.Strings.StartReview),
            Graphics.FONT_SYSTEM_XTINY, Ui.PRIMARY, Ui.px(dc, 280));
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
