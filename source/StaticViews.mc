import Toybox.Graphics;
import Toybox.Attention;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

module TextScreenLayout {
    function lines(dc as Graphics.Dc, paragraphs as Lang.Array<Lang.String>,
                   font, maxWidth as Lang.Number, gaps as Lang.Boolean) as Lang.Array<Lang.String> {
        var all = [] as Lang.Array<Lang.String>;
        for (var i = 0; i < paragraphs.size(); i += 1) {
            var wrapped = Ui.wrap(dc, paragraphs[i], font, maxWidth);
            for (var j = 0; j < wrapped.size(); j += 1) { all.add(wrapped[j]); }
            if (gaps && i + 1 < paragraphs.size()) { all.add(""); }
        }
        return all;
    }

    function draw(dc as Graphics.Dc, paragraphs as Lang.Array<Lang.String>,
                  startY as Lang.Number, bottomY as Lang.Number, scrollLine as Lang.Number,
                  gaps as Lang.Boolean) as Lang.Number {
        var font = Graphics.FONT_TINY;
        var lineHeight = Graphics.getFontHeight(font) + Ui.px(dc, 4);
        var all = lines(dc, paragraphs, font, dc.getWidth() - Ui.px(dc, 72), gaps);
        var y = startY;
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        for (var i = scrollLine; i < all.size() && y <= bottomY; i += 1) {
            dc.drawText(dc.getWidth() / 2, y, font, all[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            y += lineHeight;
        }
        return all.size();
    }

    function visibleLines(dc as Graphics.Dc, startY as Lang.Number,
                          bottomY as Lang.Number) as Lang.Number {
        var lineHeight = Graphics.getFontHeight(Graphics.FONT_TINY) + Ui.px(dc, 4);
        return ((bottomY - startY) / lineHeight) + 1;
    }
}

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
        _lineCount = TextScreenLayout.draw(dc, _paragraphs, startY, bottomY, _scroll, true);
        _visibleLines = TextScreenLayout.visibleLines(dc, startY, bottomY);
        Ui.drawScrollIndicator(dc, startY, bottomY, _scroll, _lineCount,
            _visibleLines, Ui.SECONDARY);
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
        var left = Ui.px(dc, 66);
        var right = dc.getWidth() - Ui.px(dc, 66);
        var width = right - left;
        var labelWidth = (width * 56) / 100;
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, y, Graphics.FONT_SYSTEM_TINY,
            Ui.ellipsize(dc, prefix + label, Graphics.FONT_SYSTEM_TINY, labelWidth),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(right, y, Graphics.FONT_SYSTEM_TINY,
            Ui.ellipsize(dc, value + suffix, Graphics.FONT_SYSTEM_TINY, width - labelWidth),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
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
        var action = Ui.s(Rez.Strings.TextDone);
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
            [Ui.s(Rez.Strings.TextProductVersion), Ui.s(Rez.Strings.TextAboutDisclaimer),
             Ui.s(Rez.Strings.TextAboutScope)],
            Rez.Strings.TextDone);
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        Ui.centered(dc, Ui.px(dc, 52), Ui.s(Rez.Strings.TextAboutTitle),
            Graphics.FONT_SYSTEM_SMALL, Ui.PRIMARY, Ui.px(dc, 280));
        var startY = Ui.px(dc, 108);
        var bottomY = Ui.px(dc, 286);
        _lineCount = TextScreenLayout.draw(dc, _paragraphs, startY, bottomY, _scroll, false);
        _visibleLines = TextScreenLayout.visibleLines(dc, startY, bottomY);
        Ui.drawScrollIndicator(dc, startY, bottomY, _scroll, _lineCount,
            _visibleLines, Ui.SECONDARY);
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
        _lineCount = TextScreenLayout.draw(dc, _paragraphs, startY, bottomY, _scroll, true);
        _visibleLines = TextScreenLayout.visibleLines(dc, startY, bottomY);
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

class CorrectDatesDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :pendingRemoval) {
            WatchUi.showToast(Rez.Strings.EditNotRemovedYet, null);
            return;
        }
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary;
        var start = id == :adjustInsertion ? active[:insertionUtc] : active[:removalUtc];
        if (start == null) { return; }
        PickerFlow.openDate(id as Lang.Symbol, start as Lang.Number);
    }
    function onBack() as Void { getApp().showMainMenu(); }
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
        var details = [] as Lang.Array<Lang.String>;
        var alertInterval = getApp().getAlertContext();
        if (alertInterval == null && status[:temporaryOutOpen]
            && status[:tempElapsed] > ScheduleModel.TEMP_LIMIT_SECONDS) {
            alertInterval = ScheduleModel.tempOpen(active);
        }
        if (status[:ringFreeOverSevenDays]) {
            title = Rez.Strings.AlertRingFreeTitle;
            color = Ui.RED;
            details = [Ui.s(Rez.Strings.TextBackupDirective)];
        } else if (alertInterval != null) {
            title = Rez.Strings.AlertTemporaryTitle;
            color = Ui.RED;
            details = [Ui.s(Rez.Strings.TextBackupDirective)];
        } else if (status[:ringInOverFourWeeks]) {
            title = Rez.Strings.AlertDurationTitle;
            color = Ui.RED;
            details = [Ui.s(Rez.Strings.TextBackupDirective)];
        } else if (status[:clockBeforeInsertion]) {
            title = Rez.Strings.AlertDateReviewTitle;
            color = Ui.RED;
            details = [Ui.s(Rez.Strings.AlertReviewDateHint)];
        } else if (status[:secondsRemaining] <= 0) {
            title = Rez.Strings.AlertOverdueTitle;
        }

        var action = Ui.s(Rez.Strings.RemoveRing);
        if (status[:nextAction] == :insert) { action = Ui.s(Rez.Strings.InsertRing); }
        else if (status[:nextAction] == :replace) { action = Ui.s(Rez.Strings.ReplaceRing); }
        else if (status[:nextAction] == :ringBackIn) { action = Ui.s(Rez.Strings.RingBackInAction); }
        var timing = Ui.s(Rez.Strings.DueNow);
        if (status[:temporaryOutOpen]) {
            timing = Ui.fmt(Rez.Strings.AlertOutFor, [Ui.mainElapsedText(status[:tempElapsed])]);
        } else if (status[:secondsRemaining] < 0) {
            timing = Ui.mainLatenessText(status[:secondsRemaining]);
        } else if (CalendarMath.dateOrdinal(nowUtc) == CalendarMath.dateOrdinal(status[:nextActionUtc])) {
            timing = Ui.fmt(Rez.Strings.AlertDueTodayAt,
                            [Ui.timeForUtc(status[:nextActionUtc], (state[:reminders] as Lang.Dictionary)[:clockFormat])]);
        } else {
            timing = Ui.fmt(Rez.Strings.AlertDueIn, [Ui.mainCountdownText(status[:secondsRemaining])]);
        }
        var clock = (state[:reminders] as Lang.Dictionary)[:clockFormat];
        Ui.centered(dc, Ui.px(dc, 52), Ui.s(title), Graphics.FONT_SYSTEM_SMALL, color, Ui.px(dc, 286));
        Ui.centered(dc, Ui.px(dc, 101), action, Graphics.FONT_SYSTEM_MEDIUM, Ui.PRIMARY, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 148), timing, Graphics.FONT_SYSTEM_TINY, color, Ui.px(dc, 300));
        Ui.centered(dc, Ui.px(dc, 202), Ui.fmt(Rez.Strings.TextDueDate,
                    [Ui.dateOnly(status[:nextActionUtc])]),
                    Graphics.FONT_SYSTEM_TINY, Ui.PRIMARY, Ui.px(dc, 310));
        Ui.centered(dc, Ui.px(dc, 238), Ui.timeForUtc(status[:nextActionUtc], clock),
                    Graphics.FONT_SYSTEM_TINY, Ui.SECONDARY, Ui.px(dc, 260));
        if (details.size() > 0) {
            Ui.centered(dc, Ui.px(dc, 278), details[0] as Lang.String, Graphics.FONT_SYSTEM_TINY,
                Ui.PRIMARY, Ui.px(dc, 310));
        }
        Ui.centered(dc, Ui.px(dc, 332), "[ " + Ui.s(Rez.Strings.TextWhatHappened) + " ]",
            Graphics.FONT_SYSTEM_XTINY, Ui.RING_IN, Ui.px(dc, 280));
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
    function onTap(event as WatchUi.ClickEvent) as Boolean {
        var actionTop = (System.getDeviceSettings().screenHeight * 290) / 416;
        return event.getCoordinates()[1] >= actionTop ? onSelect() : true;
    }
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

class CompactConfirmationView extends WatchUi.View {
    private var _title as Lang.String;
    private var _detail as Lang.String;

    function initialize(title as Lang.String, detail as Lang.String) {
        View.initialize();
        _title = title;
        _detail = detail;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        Ui.centered(dc, Ui.px(dc, 90), _title, Graphics.FONT_SYSTEM_TINY,
            Ui.PRIMARY, Ui.px(dc, 330));
        Ui.centered(dc, Ui.px(dc, 128), _detail, Graphics.FONT_SYSTEM_TINY,
            Ui.PRIMARY, Ui.px(dc, 330));
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(Math.round(dc.getWidth() * 0.27).toNumber(), Ui.px(dc, 224),
            Graphics.FONT_SYSTEM_SMALL, Ui.s(Rez.Strings.ConfirmCancel),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(Math.round(dc.getWidth() * 0.73).toNumber(), Ui.px(dc, 224),
            Graphics.FONT_SYSTEM_SMALL, Ui.s(Rez.Strings.ConfirmAccept),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class CompactConfirmationDelegate extends WatchUi.BehaviorDelegate {
    private var _action as Lang.Symbol;
    private var _atUtc as Lang.Number;
    private var _data;

    function initialize(action as Lang.Symbol, atUtc as Lang.Number, data) {
        BehaviorDelegate.initialize();
        _action = action;
        _atUtc = atUtc;
        _data = data;
    }

    function onSelect() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        getApp().deferAction(_action, _atUtc, _data);
        return true;
    }

    function onBack() as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onTap(event as WatchUi.ClickEvent) as Lang.Boolean {
        return event.getCoordinates()[0] < System.getDeviceSettings().screenWidth / 2
            ? onBack() : onSelect();
    }

    function onSwipe(event as WatchUi.SwipeEvent) as Lang.Boolean {
        return event.getDirection() == WatchUi.SWIPE_RIGHT ? onBack() : false;
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
