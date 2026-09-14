import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background, :glance)
class RingTrackerApp extends Application.AppBase {
    private var _state as Lang.Dictionary;
    private var _launchAlert as Lang.Boolean;
    private var _pendingSettings as Lang.Dictionary?;
    private var _backgroundWarning as Lang.Boolean;

    function initialize() {
        AppBase.initialize();
        // AppBase is also instantiated by the background VM. Keep the
        // constructor free of foreground/domain reachability.
        _state = {};
        _launchAlert = false;
        _pendingSettings = null;
        _backgroundWarning = false;
    }

    function onStart(state as Lang.Dictionary?) as Void {
        _state = RingStore.load();
        if (state != null && state[:launchedFromNotification] instanceof Lang.Array) {
            var notificationData = state[:launchedFromNotification] as Lang.Array;
            var active = _state[:active] as Lang.Dictionary?;
            _launchAlert = notificationData.size() >= 2 && active != null
                && notificationData[0] == active[:cycleId];
        }
    }

    (:typecheck(disableBackgroundCheck))
    function getInitialView() {
        registerBackground();
        if (_backgroundWarning) {
            return [new InfoView(Rez.Strings.Settings, [Ui.s(Rez.Strings.ReminderRegistrationError)]), new ScrollDelegate()];
        }
        if (_state[:readOnly] == true) {
            return [new InfoView(Rez.Strings.AppName, [Ui.s(Rez.Strings.IncompatibleData)]), new ScrollDelegate()];
        }
        if (_state[:loadError] != null) {
            return [new InfoView(Rez.Strings.AppName, [Ui.s(Rez.Strings.RecoveredError)]), new ScrollDelegate()];
        }
        if (_state[:setupStep] == 0) {
            return [new DisclaimerView(), new DisclaimerDelegate()];
        }
        if (_state[:setupStep] == 1) {
            return [new RegimenView(), new RegimenDelegate()];
        }
        prepareSettings();
        if (_pendingSettings != null) {
            return [new SettingsReviewView(), new SettingsReviewDelegate()];
        }
        if (_state[:active] == null) {
            var menu = Menus.insertionMenu();
            return [menu, new InsertionMenuDelegate()];
        }
        if (_launchAlert) { return [new AlertView(), new AlertDelegate()]; }
        return [new MainView(), new MainDelegate()];
    }

    function getGlanceView() {
        return [new RingGlanceView()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new RingServiceDelegate()];
    }

    (:typecheck(disableBackgroundCheck))
    function registerBackground() as Void {
        try {
            Background.registerForTemporalEvent(new Time.Duration(60 * 60));
            _backgroundWarning = false;
        } catch (ex) {
            _backgroundWarning = true;
        }
    }

    function getState() as Lang.Dictionary { return _state; }
    function getPendingSettings() as Lang.Dictionary? { return _pendingSettings; }

    function saveOrRecover() as Lang.Boolean {
        if (RingStore.save(_state)) {
            try {
                SettingsBridge.mirrorAll(_state);
                RingStore.save(_state);
            } catch (ignored) {
                // pendingMirrorIso remains durable for the next foreground run.
            }
            return true;
        }
        _state = RingStore.load();
        showInfo(Rez.Strings.AppName, [Ui.s(Rez.Strings.StorageError)]);
        return false;
    }

    function showMain() as Void {
        WatchUi.switchToView(new MainView(), new MainDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }

    function showInfo(title, paragraphs as Lang.Array<Lang.String>) as Void {
        WatchUi.pushView(new InfoView(title, paragraphs), new ScrollDelegate(), WatchUi.SLIDE_UP);
    }

    function showMainMenu() as Void {
        var menu = Menus.mainMenu(_state);
        WatchUi.pushView(menu, new MainMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function showSchedule() as Void {
        WatchUi.pushView(new ScheduleView(), new PopDelegate(), WatchUi.SLIDE_UP);
    }

    function showAbout() as Void {
        WatchUi.pushView(new AboutView(), new ScrollDelegate(), WatchUi.SLIDE_UP);
    }

    function showAlert() as Void {
        WatchUi.pushView(new AlertView(), new AlertDelegate(), WatchUi.SLIDE_UP);
    }

    function showSettingsConfirmation() as Void {
        if (_pendingSettings == null) { showMain(); return; }
        var message = Ui.s(Rez.Strings.SettingsReviewQuestion);
        if ((_pendingSettings as Lang.Dictionary)[:insertionUtc] != null && _state[:active] != null) {
            var clock = (_state[:reminders] as Lang.Dictionary)[:clockFormat];
            var watchTime = Ui.timestamp((_state[:active] as Lang.Dictionary)[:insertionUtc], clock);
            var phoneTime = Ui.timestamp((_pendingSettings as Lang.Dictionary)[:insertionUtc], clock);
            message = Ui.fmt(Rez.Strings.RemoteInsertionQuestion, [watchTime, phoneTime]);
        } else if ((_pendingSettings as Lang.Dictionary)[:invalid] == true) {
            message = Ui.s(Rez.Strings.InvalidSettingsQuestion);
        }
        WatchUi.pushView(new WatchUi.Confirmation(message), new SettingsConfirmationDelegate(), WatchUi.SLIDE_UP);
    }

    function resolvePendingSettings(accept as Lang.Boolean) as Void {
        if (_pendingSettings == null) { showMain(); return; }
        var pending = _pendingSettings as Lang.Dictionary;
        var dstNotice = false;
        if (accept && pending[:invalid] != true) {
            if (pending[:config] instanceof Lang.Array) {
                SettingsBridge.applyConfig(_state, pending[:config] as Lang.Array);
                var currentActive = _state[:active] as Lang.Dictionary?;
                if (currentActive != null) { dstNotice = recomputeDeadlines(currentActive, _state[:regimen] as Lang.Dictionary); }
            }
            if (pending[:insertionUtc] instanceof Lang.Number) {
                var incoming = pending[:insertionUtc] as Lang.Number;
                var active = _state[:active] as Lang.Dictionary?;
                if (active == null) {
                    var created = ScheduleModel.insertOrReplace(_state, incoming);
                    dstNotice = created[:dstAdjustment] != null;
                } else {
                    var rebuilt = ScheduleModel.newCycle(active[:cycleId], incoming, _state[:regimen] as Lang.Dictionary);
                    rebuilt[:removalUtc] = active[:removalUtc];
                    rebuilt[:removalWall] = active[:removalWall];
                    rebuilt[:temporaryOut] = active[:temporaryOut];
                    rebuilt[:plannedOverrideUtc] = active[:plannedOverrideUtc];
                    if (active[:removalUtc] != null) {
                        var ceiling = CalendarMath.addLocalCalendarDays(active[:removalUtc], 7);
                        rebuilt[:ringFreeCeilingUtc] = ceiling[:utc];
                        if (ceiling[:adjusted]) { rebuilt[:dstAdjustment] = "advancedToValidLocalTime"; }
                    }
                    _state[:active] = rebuilt;
                    dstNotice = rebuilt[:dstAdjustment] != null;
                }
                var sync = _state[:settingsSync] as Lang.Dictionary;
                sync[:lastSeenInsertionIso] = pending[:insertionIso];
                sync[:lastAcceptedInsertionIso] = pending[:insertionIso];
            }
        }
        var resolvedSync = _state[:settingsSync] as Lang.Dictionary;
        resolvedSync[:pendingSettingsError] = null;
        _pendingSettings = null;
        if (!accept || pending[:invalid] == true) {
            try { SettingsBridge.mirrorAll(_state); } catch (ignored) { }
        }
        if (saveOrRecover()) {
            if (_state[:active] == null) {
                WatchUi.switchToView(Menus.insertionMenu(), new InsertionMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
            } else {
                showMain();
                if (dstNotice) { showDstAdjustment(); }
            }
        }
    }

    (:typecheck(disableBackgroundCheck))
    function onSettingsChanged() as Void {
        prepareSettings();
        if (_pendingSettings != null) {
            WatchUi.pushView(new SettingsReviewView(), new SettingsReviewDelegate(), WatchUi.SLIDE_UP);
        } else {
            WatchUi.requestUpdate();
        }
        registerBackground();
    }

    function onValidateProperty(key as Lang.String, value as Properties.ValueType) as Lang.Boolean or Lang.String {
        return SettingsBridge.validate(key, value, currentUtc())
            ? true : Ui.s(key.equals("insertionIso") ? Rez.Strings.InsertionDateTimeError : Rez.Strings.SettingValueError);
    }

    (:typecheck(disableBackgroundCheck))
    private function prepareSettings() as Void {
        try {
            _pendingSettings = SettingsBridge.observe(_state, currentUtc());
            RingStore.save(_state);
        } catch (ignored) {
            _pendingSettings = { :invalid => true };
        }
    }

    function confirmAction(action as Lang.Symbol, atUtc as Lang.Number, data) as Void {
        var message = Ui.s(Rez.Strings.SaveChangeQuestion);
        var when = Ui.shortTimestamp(atUtc, (_state[:reminders] as Lang.Dictionary)[:clockFormat]);
        if (action == :acceptDisclaimer) { message = Ui.s(Rez.Strings.ContinueQuestion); }
        else if (action == :acceptRegimen) { message = Ui.s(Rez.Strings.ConfirmRegimenQuestion); }
        else if (action == :insert) { message = Ui.fmt(Rez.Strings.RecordInsertionQuestion, [when]); }
        else if (action == :replace) { message = Ui.fmt(Rez.Strings.ReplaceRingQuestion, [when]); }
        else if (action == :remove) { message = Ui.fmt(Rez.Strings.RemoveRingQuestion, [when]); }
        else if (action == :tempOut) { message = Ui.fmt(Rez.Strings.TempOutQuestion, [when]); }
        else if (action == :backIn) { message = Ui.fmt(Rez.Strings.BackInQuestion, [when]); }
        else if (action == :clearHistory) { message = Ui.s(Rez.Strings.ClearHistoryQuestion); }
        else if (action == :reset) { message = Ui.s(Rez.Strings.ResetQuestion); }
        else if (action == :setDaysIn || action == :setDaysOut) {
            var notice = (action == :setDaysIn && data > 28) ? Ui.s(Rez.Strings.OutsideLabelNotice) : Ui.s(Rez.Strings.ExtendedUseNotice);
            message = Ui.fmt(Rez.Strings.AcknowledgeDurationQuestion, [notice]);
        }
        message = optionalActionMessage(action, message);
        WatchUi.pushView(new WatchUi.Confirmation(message), new ActionConfirmationDelegate(action, atUtc, data), WatchUi.SLIDE_UP);
    }

    function performConfirmed(action as Lang.Symbol, atUtc as Lang.Number, data) as Void {
        if (_state[:readOnly] == true) { return; }
        if (action == :acceptDisclaimer) {
            _state[:setupStep] = 1;
            if (saveOrRecover()) { WatchUi.switchToView(new RegimenView(), new RegimenDelegate(), WatchUi.SLIDE_LEFT); }
            return;
        }
        if (action == :acceptRegimen) {
            _state[:setupStep] = 2;
            if (saveOrRecover()) { WatchUi.switchToView(Menus.insertionMenu(), new InsertionMenuDelegate(), WatchUi.SLIDE_LEFT); }
            return;
        }
        if (action == :insert || action == :replace) {
            if (atUtc > currentUtc() + 60) { showInfo(Rez.Strings.InitialInsertionTitle, [Ui.s(Rez.Strings.FutureEvent)]); return; }
            var inserted = ScheduleModel.insertOrReplace(_state, atUtc);
            noteWatchEdit(atUtc);
            if (saveOrRecover()) {
                showMain();
                if (inserted[:dstAdjustment] != null) { showDstAdjustment(); }
            }
            return;
        }

        var active = _state[:active] as Lang.Dictionary?;
        var regimen = _state[:regimen] as Lang.Dictionary;
        if (action == :setDaysIn || action == :setDaysOut) {
            if (action == :setDaysIn) { regimen[:daysIn] = data; }
            else { regimen[:daysOut] = data; }
            var durationDstNotice = active != null && recomputeDeadlines(active as Lang.Dictionary, regimen);
            if (saveOrRecover()) {
                if (_state[:setupStep] == 1) {
                    WatchUi.switchToView(new RegimenView(), new RegimenDelegate(), WatchUi.SLIDE_RIGHT);
                } else if (active == null) {
                    WatchUi.switchToView(Menus.insertionMenu(), new InsertionMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
                } else { showMain(); }
                if (durationDstNotice) { showDstAdjustment(); }
            }
            return;
        }
        if (active == null) { return; }
        var wasOver = false;
        var dstNotice = false;
        if (action == :remove) {
            if (atUtc > currentUtc() + 60 || !ScheduleModel.recordRemoval(active, atUtc, regimen)) {
                showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidEventOrder)]); return;
            }
            dstNotice = active[:dstAdjustment] != null;
        } else if (action == :tempOut) {
            if (!ScheduleModel.startTemporaryOut(active, atUtc)) { return; }
        } else if (action == :backIn) {
            var open = ScheduleModel.tempOpen(active);
            wasOver = open != null && atUtc - open[:outUtc] > ScheduleModel.TEMP_LIMIT_SECONDS;
            if (!ScheduleModel.endTemporaryOut(active, atUtc)) { return; }
        } else if (action == :adjustInsertion) {
            var rebuilt = ScheduleModel.newCycle(active[:cycleId], atUtc, regimen);
            rebuilt[:removalUtc] = active[:removalUtc];
            rebuilt[:removalWall] = active[:removalWall];
            rebuilt[:temporaryOut] = active[:temporaryOut];
            rebuilt[:plannedOverrideUtc] = active[:plannedOverrideUtc];
            if (active[:removalUtc] != null) {
                var ceiling = CalendarMath.addLocalCalendarDays(active[:removalUtc], 7);
                rebuilt[:ringFreeCeilingUtc] = ceiling[:utc];
                if (ceiling[:adjusted]) { rebuilt[:dstAdjustment] = "advancedToValidLocalTime"; }
            }
            _state[:active] = rebuilt;
            dstNotice = rebuilt[:dstAdjustment] != null;
            noteWatchEdit(atUtc);
        } else if (action == :adjustRemoval) {
            if (!ScheduleModel.recordRemoval(active, atUtc, regimen)) { showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidEventOrder)]); return; }
            dstNotice = active[:dstAdjustment] != null;
        } else if (action == :adjustPlanned) {
            active[:plannedOverrideUtc] = atUtc;
        } else if (action == :setReminder) {
            var reminders = _state[:reminders] as Lang.Dictionary;
            var timeValues = data as Lang.Array<Lang.Number>;
            reminders[:localHour] = timeValues[0];
            reminders[:localMinute] = timeValues[1];
        } else if (action == :setRepeat) {
            var rr = _state[:reminders] as Lang.Dictionary;
            rr[:overdueRepeatHours] = data;
        } else if (action == :toggleVibration) {
            var rv = _state[:reminders] as Lang.Dictionary;
            rv[:vibrationEnabled] = !rv[:vibrationEnabled];
        } else if (action == :toggleSound) {
            var rs = _state[:reminders] as Lang.Dictionary;
            rs[:soundEnabled] = !rs[:soundEnabled];
        } else if (action == :setClock) {
            var rc = _state[:reminders] as Lang.Dictionary;
            rc[:clockFormat] = data;
        } else if (action == :clearHistory) {
            _state[:history] = [];
        } else if (action == :reset) {
            _state = ScheduleModel.defaultState();
        }

        var seededState = optionalSeedState(action, data, currentUtc());
        if (seededState != null) { _state = seededState as Lang.Dictionary; }

        if (saveOrRecover()) {
            if (action == :reset) { WatchUi.switchToView(new DisclaimerView(), new DisclaimerDelegate(), WatchUi.SLIDE_IMMEDIATE); }
            else if (isFreshOptionalSeed(action, data)) { WatchUi.switchToView(new DisclaimerView(), new DisclaimerDelegate(), WatchUi.SLIDE_IMMEDIATE); }
            else if (action == :backIn && wasOver) { showAlert(); }
            else {
                showMain();
                if (dstNotice) { showDstAdjustment(); }
            }
        }
    }

    private function recomputeDeadlines(active as Lang.Dictionary, regimen as Lang.Dictionary) as Lang.Boolean {
        var removal = CalendarMath.addLocalCalendarDays(active[:insertionUtc], regimen[:daysIn]);
        var insertion = CalendarMath.addLocalCalendarDays(active[:insertionUtc], regimen[:daysIn] + regimen[:daysOut]);
        var label = regimen[:daysIn] + regimen[:daysOut] == 28
            ? insertion : CalendarMath.addLocalCalendarDays(active[:insertionUtc], 28);
        active[:scheduledRemovalUtc] = removal[:utc];
        active[:scheduledInsertionUtc] = insertion[:utc];
        active[:labelFourWeekUtc] = label[:utc];
        var adjusted = removal[:adjusted] || insertion[:adjusted] || label[:adjusted];
        active[:dstAdjustment] = adjusted ? "advancedToValidLocalTime" : null;
        return adjusted;
    }

    private function showDstAdjustment() as Void {
        showInfo(Rez.Strings.DstAdjustmentTitle, [Ui.s(Rez.Strings.DstAdjustmentBody)]);
    }

    private function noteWatchEdit(atUtc as Lang.Number) as Void {
        var sync = _state[:settingsSync] as Lang.Dictionary;
        sync[:lastWatchScheduleEditUtc] = currentUtc();
        sync[:pendingMirrorIso] = SettingsBridge.isoForUtc(atUtc);
    }
}

function getApp() as RingTrackerApp {
    return Application.getApp() as RingTrackerApp;
}
