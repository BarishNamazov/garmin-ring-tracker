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
    private var _notificationData as Lang.Array?;
    private var _pendingSettings as Lang.Dictionary?;
    private var _backgroundWarning as Lang.Boolean;
    private var _alertContext as Lang.Dictionary?;

    function initialize() {
        AppBase.initialize();
        // AppBase is also instantiated by the background VM. Keep the
        // constructor free of foreground/domain reachability.
        _state = {};
        _launchAlert = false;
        _notificationData = null;
        _pendingSettings = null;
        _backgroundWarning = false;
        _alertContext = null;
    }

    function onStart(state as Lang.Dictionary?) as Void {
        if (state != null && state[:launchedFromNotification] instanceof Lang.Array) {
            _notificationData = state[:launchedFromNotification] as Lang.Array;
        }
    }

    function getInitialView() {
        _state = RingStore.load();
        if (_notificationData != null) {
            var active = _state[:active] as Lang.Dictionary?;
            var data = _notificationData as Lang.Array;
            _launchAlert = active != null && ScheduleModel.validNotificationData(data, active[:cycleId]);
        }
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
    function getAlertContext() as Lang.Dictionary? { return _alertContext; }

    function saveOrRecover() as Lang.Boolean {
        SettingsBridge.stageMirrors(_state);
        if (RingStore.save(_state)) {
            try {
                SettingsBridge.completePendingMirrors(_state);
                if (!RingStore.save(_state)) {
                    _state = RingStore.load();
                    showInfo(Rez.Strings.AppName, [Ui.s(Rez.Strings.SettingsMirrorRetry)]);
                    return false;
                }
            } catch (ignored) {
                // pendingMirrorIso remains durable for the next foreground run.
                _state = RingStore.load();
                showInfo(Rez.Strings.AppName, [Ui.s(Rez.Strings.SettingsMirrorRetry)]);
                return false;
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

    function showAlertMenu() as Void {
        var focus = 0;
        var active = _state[:active] as Lang.Dictionary?;
        if (active != null) {
            var status = ScheduleModel.deriveStatus(currentUtc(), active, _state[:regimen] as Lang.Dictionary);
            if (status[:nextAction] == :remove) { focus = 1; }
            else if (status[:nextAction] == :ringBackIn) { focus = 2; }
        }
        WatchUi.pushView(Menus.mainMenuWithFocus(_state, focus), new MainMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function showSchedule() as Void {
        WatchUi.pushView(new ScheduleView(), new PopDelegate(), WatchUi.SLIDE_UP);
    }

    function showAbout() as Void {
        WatchUi.pushView(new AboutView(), new ScrollDelegate(), WatchUi.SLIDE_UP);
    }

    function showAlert() as Void {
        // A direct alert launch always reflects the live schedule. Temporary
        // interval context is only valid for the immediate "ring back in"
        // flow and must not leak into a later overdue alert.
        _alertContext = null;
        WatchUi.pushView(new AlertView(), new AlertDelegate(), WatchUi.SLIDE_UP);
    }

    function showTemporaryAlert(interval as Lang.Dictionary) as Void {
        _alertContext = interval;
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
        var incomingRejected = false;
        var incomingWasFuture = false;
        if (accept && pending[:invalid] != true) {
            if (pending[:config] instanceof Lang.Array) {
                SettingsBridge.applyConfig(_state, pending[:config] as Lang.Array);
                var currentActive = _state[:active] as Lang.Dictionary?;
                if (currentActive != null) { dstNotice = recomputeDeadlines(currentActive, _state[:regimen] as Lang.Dictionary); }
            }
            if (pending[:insertionUtc] instanceof Lang.Number) {
                var incoming = pending[:insertionUtc] as Lang.Number;
                var active = _state[:active] as Lang.Dictionary?;
                if (incoming > currentUtc() + 60
                    || (active != null && !ScheduleModel.validInsertionEdit(active, incoming))) {
                    incomingWasFuture = incoming > currentUtc() + 60;
                    pending[:invalid] = true;
                    accept = false;
                    incomingRejected = true;
                }
            }
            if (accept && pending[:insertionUtc] instanceof Lang.Number) {
                var acceptedUtc = pending[:insertionUtc] as Lang.Number;
                var acceptedActive = _state[:active] as Lang.Dictionary?;
                if (acceptedActive == null) {
                    var created = ScheduleModel.insertOrReplace(_state, acceptedUtc);
                    dstNotice = created[:dstAdjustment] != null;
                } else {
                    var rebuilt = ScheduleModel.rebuildForInsertion(acceptedActive, acceptedUtc,
                        _state[:regimen] as Lang.Dictionary) as Lang.Dictionary;
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
        if (saveOrRecover()) {
            if (incomingRejected) {
                showInfo(Rez.Strings.AdjustDates, [Ui.s(incomingWasFuture
                    ? Rez.Strings.FutureEvent : Rez.Strings.InvalidEventOrder)]);
                return;
            }
            if (_state[:active] == null) {
                WatchUi.switchToView(Menus.insertionMenu(), new InsertionMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
            } else {
                showMain();
                if (dstNotice) { showDstAdjustment(); }
            }
        }
    }

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
        var clock = (_state[:reminders] as Lang.Dictionary)[:clockFormat];
        var whenParts = [Ui.dateOnly(atUtc), Ui.timeForUtc(atUtc, clock)];
        if (action == :acceptDisclaimer) { message = Ui.s(Rez.Strings.ContinueQuestion); }
        else if (action == :acceptRegimen) { message = Ui.s(Rez.Strings.ConfirmRegimenQuestion); }
        else if (action == :insert) { message = Ui.fmt(Rez.Strings.RecordInsertionQuestion, whenParts); }
        else if (action == :replace) { message = Ui.fmt(Rez.Strings.ReplaceRingQuestion, whenParts); }
        else if (action == :remove) { message = Ui.fmt(Rez.Strings.RemoveRingQuestion, whenParts); }
        else if (action == :tempOut) { message = Ui.fmt(Rez.Strings.TempOutQuestion, whenParts); }
        else if (action == :backIn) { message = Ui.fmt(Rez.Strings.BackInQuestion, whenParts); }
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
            var previous = _state[:active] as Lang.Dictionary?;
            if (previous != null && !ScheduleModel.validReplacementTime(previous, atUtc)) {
                showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidEventOrder)]);
                return;
            }
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
        if ((action == :remove || action == :tempOut || action == :backIn
            || action == :adjustInsertion || action == :adjustRemoval)
            && atUtc > currentUtc() + 60) {
            showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.FutureEvent)]);
            return;
        }
        var wasOver = false;
        var closedAlertInterval = null;
        var dstNotice = false;
        if (action == :remove) {
            if (atUtc > currentUtc() + 60 || !ScheduleModel.recordRemoval(active, atUtc, regimen)) {
                showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidEventOrder)]); return;
            }
            dstNotice = active[:dstAdjustment] != null;
        } else if (action == :tempOut) {
            if (!ScheduleModel.startTemporaryOut(active, atUtc)) {
                showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.TemporaryOutStorageError)]);
                return;
            }
        } else if (action == :backIn) {
            var open = ScheduleModel.tempOpen(active);
            wasOver = open != null && atUtc - open[:outUtc] > ScheduleModel.TEMP_LIMIT_SECONDS;
            if (!ScheduleModel.endTemporaryOut(active, atUtc)) { return; }
            if (wasOver) { closedAlertInterval = open; }
        } else if (action == :adjustInsertion) {
            var rebuilt = ScheduleModel.rebuildForInsertion(active, atUtc, regimen);
            if (rebuilt == null) {
                showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidEventOrder)]);
                return;
            }
            _state[:active] = rebuilt;
            dstNotice = (rebuilt as Lang.Dictionary)[:dstAdjustment] != null;
            noteWatchEdit(atUtc);
        } else if (action == :adjustRemoval) {
            if (!ScheduleModel.recordRemoval(active, atUtc, regimen)) { showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidEventOrder)]); return; }
            dstNotice = active[:dstAdjustment] != null;
        } else if (action == :adjustPlanned) {
            ScheduleModel.setPlannedOverride(active, atUtc, regimen);
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
            else if (action == :backIn && closedAlertInterval != null) {
                showTemporaryAlert(closedAlertInterval as Lang.Dictionary);
            }
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
        ScheduleModel.refreshFinalInsertionUtc(active, regimen);
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
