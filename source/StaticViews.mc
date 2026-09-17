import Toybox.Graphics;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class InfoView extends WatchUi.View {
    protected var _title;
    protected var _paragraphs as Lang.Array<Lang.String>;
    protected var _scroll as Lang.Number;
    protected var _lineCount as Lang.Number;
    protected var _visibleLines as Lang.Number;

    function initialize(title, paragraphs as Lang.Array<Lang.String>) {
        View.initialize();
        _title = title;
        _paragraphs = paragraphs;
        _scroll = 0;
        _lineCount = 0;
        _visibleLines = 0;
    }

    function scroll(delta as Lang.Number) as Void {
        _scroll += delta;
        if (_scroll < 0) { _scroll = 0; }
        var maxScroll = _lineCount > _visibleLines ? _lineCount - _visibleLines : 0;
        if (_scroll > maxScroll) { _scroll = maxScroll; }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var titleText = _title instanceof Lang.ResourceId ? Ui.s(_title) : _title as Lang.String;
        Ui.centered(dc, Ui.px(dc, 66), titleText, Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        var startY = Ui.px(dc, 112);
        var bottomY = Ui.px(dc, 350);
        _lineCount = Ui.drawParagraphs(dc, _paragraphs, startY, bottomY, _scroll);
        _visibleLines = Ui.paragraphVisibleLines(dc, startY, bottomY);
        Ui.drawScrollIndicator(dc, startY, bottomY, _scroll, _lineCount, _visibleLines, Ui.RING_IN);
    }
}

class TextActionView extends InfoView {
    protected var _action;

    function initialize(title, paragraphs as Lang.Array<Lang.String>, action) {
        InfoView.initialize(title, paragraphs);
        _action = action;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var titleText = _title instanceof Lang.ResourceId ? Ui.s(_title) : _title as Lang.String;
        Ui.centered(dc, Ui.px(dc, 62), titleText, Graphics.FONT_SYSTEM_SMALL,
            Ui.PRIMARY, Ui.px(dc, 280));
        var startY = Ui.px(dc, 116);
        var bottomY = Ui.px(dc, 286);
        _lineCount = Ui.drawParagraphs(dc, _paragraphs, startY, bottomY, _scroll);
        if (_lineCount > 0) { _lineCount -= 1; }
        _visibleLines = Ui.paragraphVisibleLines(dc, startY, bottomY);
        Ui.drawScrollIndicator(dc, startY, bottomY, _scroll, _lineCount,
            _visibleLines, Ui.RING_IN);
        var actionText = _action instanceof Lang.ResourceId ? Ui.s(_action) : _action as Lang.String;
        Ui.centered(dc, Ui.px(dc, 332), "[ " + actionText + " ]", Graphics.FONT_SYSTEM_XTINY,
            Ui.RING_IN, Ui.px(dc, 280));
    }
}

class DisclaimerView extends TextActionView {
    function initialize() {
        TextActionView.initialize(Rez.Strings.TextFirstRunTitle,
            [Ui.s(Rez.Strings.TextFirstRunBody)], Rez.Strings.TextUnderstand);
    }
}

class DisclaimerDelegate extends ScrollDelegate {
    function initialize() { ScrollDelegate.initialize(); }
    function onSelect() as Boolean {
        getApp().performConfirmed(:acceptDisclaimer, currentUtc(), null);
        return true;
    }
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        return event.getCoordinates()[1] >= 290 ? onSelect() : true;
    }
}

class RegimenView extends WatchUi.View {
    private var _focus as Lang.Number;

    function initialize() { View.initialize(); _focus = 2; }

    function moveFocus(delta as Lang.Number) as Void {
        _focus += delta;
        if (_focus < 0) { _focus = 2; }
        if (_focus > 2) { _focus = 0; }
        WatchUi.requestUpdate();
    }

    function focus() as Lang.Number { return _focus; }
    function setFocus(value as Lang.Number) as Void { _focus = value; WatchUi.requestUpdate(); }

    private function regimenRow(dc as Graphics.Dc, y as Lang.Number,
                                label as Lang.String, value as Lang.String,
                                focused as Lang.Boolean) as Void {
        var prefix = focused ? "[ " : "";
        var suffix = focused ? " ]" : "";
        Ui.row(dc, y, prefix + label, value + suffix);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var regimen = getApp().getState()[:regimen] as Lang.Dictionary;
        Ui.centered(dc, Ui.px(dc, 62), Ui.s(Rez.Strings.TextRegimenTitle), Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        Ui.centered(dc, Ui.px(dc, 108), Ui.s(Rez.Strings.TextRegimenSubtitle), Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 300));
        regimenRow(dc, Ui.px(dc, 180), Ui.s(Rez.Strings.TextRegimenIn),
            Ui.fmt(Rez.Strings.DaysTemplate, [regimen[:daysIn]]), _focus == 0);
        regimenRow(dc, Ui.px(dc, 234), Ui.s(Rez.Strings.TextRegimenOut),
            Ui.fmt(regimen[:daysOut] == 1 ? Rez.Strings.OneDayTemplate : Rez.Strings.DaysTemplate,
                [regimen[:daysOut]]), _focus == 1);
        var action = Ui.s(Rez.Strings.TextContinue);
        if (_focus == 2) { action = "[ " + action + " ]"; }
        Ui.centered(dc, Ui.px(dc, 332), action, Graphics.FONT_SYSTEM_XTINY,
            Ui.RING_IN, Ui.px(dc, 280));
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
        else { getApp().performConfirmed(:acceptRegimen, currentUtc(), null); }
        return true;
    }
    function onNextPage() as Boolean { view().moveFocus(1); return true; }
    function onPreviousPage() as Boolean { view().moveFocus(-1); return true; }
    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        if (event.getDirection() == WatchUi.SWIPE_UP) { return onNextPage(); }
        if (event.getDirection() == WatchUi.SWIPE_DOWN) { return onPreviousPage(); }
        return false;
    }
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var y = event.getCoordinates()[1];
        if (y < 210) { view().setFocus(0); }
        else if (y < 282) { view().setFocus(1); }
        else { view().setFocus(2); }
        return onSelect();
    }
}

class AboutView extends TextActionView {
    function initialize() {
        TextActionView.initialize(Rez.Strings.TextAboutTitle,
            [Ui.s(Rez.Strings.TextAboutDisclaimer), Ui.s(Rez.Strings.SupportedScope),
             Ui.s(Rez.Strings.AnnoveraUnsupported), Ui.s(Rez.Strings.ReminderLimit),
             Ui.s(Rez.Strings.Privacy), Ui.s(Rez.Strings.SourcesTitle),
             Ui.s(Rez.Strings.SourcesLine1), Ui.s(Rez.Strings.SourcesLine2)],
            Rez.Strings.TextDone);
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        Ui.centered(dc, Ui.px(dc, 52), Ui.s(Rez.Strings.TextAboutTitle),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        Ui.centered(dc, Ui.px(dc, 88), Ui.s(Rez.Strings.TextProductVersion),
            Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 280));
        var startY = Ui.px(dc, 126);
        var bottomY = Ui.px(dc, 286);
        _lineCount = Ui.drawParagraphs(dc, _paragraphs, startY, bottomY, _scroll);
        if (_lineCount > 0) { _lineCount -= 1; }
        _visibleLines = Ui.paragraphVisibleLines(dc, startY, bottomY);
        Ui.drawScrollIndicator(dc, startY, bottomY, _scroll, _lineCount,
            _visibleLines, Ui.RING_IN);
        Ui.centered(dc, Ui.px(dc, 332), "[ " + Ui.s(Rez.Strings.TextDone) + " ]",
            Graphics.FONT_SYSTEM_XTINY, Ui.RING_IN, Ui.px(dc, 280));
    }
}

class AboutDelegate extends ScrollDelegate {
    function initialize() { ScrollDelegate.initialize(); }
    function onSelect() as Boolean { return onBack(); }
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        if (event.getCoordinates()[1] >= 290) { return onSelect(); }
        return true;
    }
}

class MigrationView extends TextActionView {
    function initialize() {
        TextActionView.initialize(Rez.Strings.TextMigrationTitle,
            [Ui.s(Rez.Strings.TextMigrationBody)], Rez.Strings.TextOK);
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        Ui.centered(dc, Ui.px(dc, 108), Ui.s(Rez.Strings.TextMigrationTitle),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        var startY = Ui.px(dc, 158);
        var bottomY = Ui.px(dc, 266);
        _lineCount = Ui.drawParagraphs(dc, _paragraphs, startY, bottomY, _scroll);
        if (_lineCount > 0) { _lineCount -= 1; }
        _visibleLines = Ui.paragraphVisibleLines(dc, startY, bottomY);
        Ui.centered(dc, Ui.px(dc, 332), "[ " + Ui.s(Rez.Strings.TextOK) + " ]",
            Graphics.FONT_SYSTEM_XTINY, Ui.RING_IN, Ui.px(dc, 280));
    }
}

class MigrationDelegate extends ScrollDelegate {
    function initialize() { ScrollDelegate.initialize(); }
    function onSelect() as Boolean { getApp().showMain(); return true; }
    function onBack() as Boolean { getApp().showMain(); return true; }
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        return event.getCoordinates()[1] >= 290 ? onSelect() : true;
    }
}

class CorrectDatesView extends WatchUi.View {
    private var _focus as Lang.Number;

    function initialize() {
        View.initialize();
        var active = getApp().getState()[:active] as Lang.Dictionary;
        _focus = active[:removalUtc] == null ? 0 : 1;
    }

    function focus() as Lang.Number { return _focus; }

    function setFocus(value as Lang.Number) as Lang.Boolean {
        var active = getApp().getState()[:active] as Lang.Dictionary;
        if (value == 1 && active[:removalUtc] == null) { return false; }
        _focus = value;
        WatchUi.requestUpdate();
        return true;
    }

    function moveFocus(delta as Lang.Number) as Void {
        var active = getApp().getState()[:active] as Lang.Dictionary;
        if (active[:removalUtc] == null) { return; }
        _focus = _focus == 0 ? 1 : 0;
        WatchUi.requestUpdate();
    }

    private function row(dc as Graphics.Dc, y as Lang.Number, label as Lang.String,
                         value as Lang.String, focused as Lang.Boolean,
                         editable as Lang.Boolean) as Void {
        var left = Ui.px(dc, 48);
        var right = dc.getWidth() - Ui.px(dc, 48);
        if (focused) {
            dc.setColor(Ui.RING_FREE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(Ui.px(dc, 31), y - Ui.px(dc, 35), Ui.px(dc, 4), Ui.px(dc, 72));
        }
        dc.setColor(editable ? Ui.PRIMARY : Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, y - Ui.px(dc, 13), Graphics.FONT_SYSTEM_SMALL,
            Ui.ellipsize(dc, label, Graphics.FONT_SYSTEM_SMALL, right - left),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(editable ? Ui.SECONDARY : 0x78858C, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, y + Ui.px(dc, 21), Graphics.FONT_SYSTEM_XTINY,
            Ui.ellipsize(dc, value, Graphics.FONT_SYSTEM_XTINY, right - left),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        var active = getApp().getState()[:active] as Lang.Dictionary;
        Ui.centered(dc, Ui.px(dc, 58), Ui.s(Rez.Strings.EditCorrectDates),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        row(dc, Ui.px(dc, 151), Ui.s(Rez.Strings.EditInserted),
            Ui.shortTimestamp(active[:insertionUtc], 0), _focus == 0, true);
        var removed = active[:removalUtc];
        var removalText = removed == null
            ? Ui.fmt(Rez.Strings.EditNotYetDue, [Ui.shortDate(active[:removeDueUtc])])
            : Ui.shortTimestamp(removed as Lang.Number, 0);
        row(dc, Ui.px(dc, 266), Ui.s(Rez.Strings.EditRemoved), removalText,
            _focus == 1, removed != null);
    }
}

class CorrectDatesDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    private function view() as CorrectDatesView {
        return WatchUi.getCurrentView()[0] as CorrectDatesView;
    }
    function onSelect() as Boolean {
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary;
        var id = view().focus() == 0 ? :adjustInsertion : :adjustRemoval;
        var start = id == :adjustInsertion ? active[:insertionUtc] : active[:removalUtc];
        if (start == null) { return true; }
        PickerFlow.openDate(id, start as Lang.Number);
        return true;
    }
    function onNextPage() as Boolean { view().moveFocus(1); return true; }
    function onPreviousPage() as Boolean { view().moveFocus(-1); return true; }
    function onBack() as Boolean { getApp().showMainMenu(); return true; }
    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        if (event.getDirection() == WatchUi.SWIPE_UP) { return onNextPage(); }
        if (event.getDirection() == WatchUi.SWIPE_DOWN) { return onPreviousPage(); }
        if (event.getDirection() == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return false;
    }
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var y = event.getCoordinates()[1];
        if (y < 105 || y > 325) { return true; }
        if (!view().setFocus(y < 210 ? 0 : 1)) { return true; }
        return onSelect();
    }
}

class AlertView extends WatchUi.View {
    private var _attentionPlayed as Lang.Boolean;

    function initialize() {
        View.initialize();
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
        var details = [Ui.s(Rez.Strings.ActionDueBody)];
        var alertInterval = getApp().getAlertContext();
        if (alertInterval == null && status[:temporaryOutOpen]
            && status[:tempElapsed] > ScheduleModel.TEMP_LIMIT_SECONDS) {
            alertInterval = ScheduleModel.tempOpen(active);
        }
        if (status[:ringFreeOverSevenDays]) {
            title = Rez.Strings.AlertRingFreeTitle;
            color = Ui.RED;
            details = [Ui.s(Rez.Strings.RingFreeExceededBody)];
        } else if (alertInterval != null) {
            title = Rez.Strings.AlertTemporaryTitle;
            color = Ui.RED;
            details = [Ui.s(Rez.Strings.TempOverBody12)];
        } else if (status[:ringInOverFourWeeks]) {
            title = Rez.Strings.AlertDurationTitle;
            details = [Ui.s(Rez.Strings.ExtendedBody)];
        } else if (status[:clockBeforeInsertion]) {
            title = Rez.Strings.AlertDateReviewTitle;
            color = Ui.RED;
        } else if (status[:secondsRemaining] <= 0) {
            title = Rez.Strings.AlertOverdueTitle;
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
        Ui.centered(dc, Ui.px(dc, 56), Ui.s(title), Graphics.FONT_SYSTEM_SMALL, color, Ui.px(dc, 286));
        Ui.centered(dc, Ui.px(dc, 106), action, Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 151), timing, Graphics.FONT_SYSTEM_TINY, color, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 216), Ui.dateOnly(status[:nextActionUtc]),
                    Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 252), Ui.timeForUtc(status[:nextActionUtc], clock),
                    Graphics.FONT_SYSTEM_XTINY, Ui.SECONDARY, Ui.px(dc, 260));
        Ui.drawParagraphs(dc, details, Ui.px(dc, 292), Ui.px(dc, 350), 0);
    }
}

class ScrollDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onNextPage() as Boolean { (WatchUi.getCurrentView()[0] as InfoView).scroll(1); return true; }
    function onPreviousPage() as Boolean { (WatchUi.getCurrentView()[0] as InfoView).scroll(-1); return true; }
    function onBack() as Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        if (event.getDirection() == WatchUi.SWIPE_UP) { return onNextPage(); }
        if (event.getDirection() == WatchUi.SWIPE_DOWN) { return onPreviousPage(); }
        if (event.getDirection() == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return false;
    }
}

class PopDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onBack() as Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onNextPage() as Boolean { WatchUi.popView(WatchUi.SLIDE_DOWN); return true; }
    function onPreviousPage() as Boolean { WatchUi.popView(WatchUi.SLIDE_UP); return true; }
}

class AlertDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onSelect() as Boolean { getApp().showAlertMenu(); return true; }
    function onBack() as Boolean { getApp().showMain(); return true; }
    function onSwipe(event as WatchUi.SwipeEvent) as Boolean {
        if (event.getDirection() == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return false;
    }
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
        var startY = Ui.px(dc, 112);
        var bottomY = Ui.px(dc, 344);
        _lineCount = Ui.drawParagraphs(dc, _paragraphs, startY, bottomY, _scroll);
        _visibleLines = Ui.paragraphVisibleLines(dc, startY, bottomY);
        Ui.drawScrollIndicator(dc, startY, bottomY, _scroll, _lineCount, _visibleLines, Ui.RING_IN);
    }
}

class SettingsReviewDelegate extends ScrollDelegate {
    function initialize() { ScrollDelegate.initialize(); }
    function onSelect() as Boolean { getApp().showSettingsConfirmation(); return true; }
}

class SettingsConfirmationDelegate extends WatchUi.ConfirmationDelegate {
    function initialize() { ConfirmationDelegate.initialize(); }
    function onResponse(value as WatchUi.Confirm) as Boolean {
        getApp().deferSettings(value == WatchUi.CONFIRM_YES);
        return true;
    }
}

class ActionConfirmationDelegate extends WatchUi.ConfirmationDelegate {
    private var _action as Lang.Symbol;
    private var _atUtc as Lang.Number;
    private var _data;
    function initialize(action as Lang.Symbol, atUtc as Lang.Number, data) {
        ConfirmationDelegate.initialize();
        _action = action;
        _atUtc = atUtc;
        _data = data;
    }
    function onResponse(value as WatchUi.Confirm) as Boolean {
        if (value == WatchUi.CONFIRM_YES) {
            getApp().deferAction(_action, _atUtc, _data);
        }
        return true;
    }
}
