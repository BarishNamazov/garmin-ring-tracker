import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class RingTrackerApp extends Application.AppBase {
    private var _startupState as Lang.Dictionary?;

    function initialize() {
        AppBase.initialize();
        _startupState = null;
    }

    function onStart(state as Lang.Dictionary?) as Void { _startupState = state; }
    (:typecheck(disableBackgroundCheck))
    function getInitialView() { return [new ForegroundEntryView(_startupState)]; }
    (:typecheck(disableBackgroundCheck))
    function onSettingsChanged() as Void {
        WatchUi.switchToView(new ForegroundSettingsEntryView(), null, WatchUi.SLIDE_IMMEDIATE);
    }
    (:typecheck(disableBackgroundCheck))
    function onValidateProperty(key as Lang.String, value as Properties.ValueType) as Lang.Boolean or Lang.String {
        return SettingsBridge.validate(key, value, currentUtc())
            ? true : Ui.s(SettingsBridge.isInsertionKey(key)
                ? Rez.Strings.InsertionDateTimeError : Rez.Strings.SettingValueError);
    }

    (:glance)
    function getGlanceView() { return [new RingGlanceView()]; }

    (:background)
    function getServiceDelegate() as [System.ServiceDelegate] { return [new RingServiceDelegate()]; }

}

module MenuActions {
    function clearTemporaryReminder(ledger as Lang.Dictionary) as Void {
        ledger[:lastTempOutSlot] = null;
        ledger[:tempOutIdentity] = null;
    }

    function undoRingOut(active as Lang.Dictionary, ledger as Lang.Dictionary) as Lang.Boolean {
        var open = ScheduleModel.tempOpen(active);
        if (open == null) { return false; }
        (active[:temporaryOut] as Lang.Array).remove(open);
        clearTemporaryReminder(ledger);
        return true;
    }

    function keepOut(active as Lang.Dictionary, regimen as Lang.Dictionary,
                     ledger as Lang.Dictionary) as Lang.Boolean {
        var open = ScheduleModel.tempOpen(active);
        if (open == null) { return false; }
        var removedAt = (open as Lang.Dictionary)[:outUtc] as Lang.Number;
        if (!ScheduleModel.validRemovalEdit(active, removedAt)) { return false; }
        (active[:temporaryOut] as Lang.Array).remove(open);
        clearTemporaryReminder(ledger);
        return ScheduleModel.recordRemoval(active, removedAt, regimen);
    }

    function syncRepeatPolicy(state as Lang.Dictionary, nowUtc as Lang.Number) as Void {
        var reminders = state[:reminders] as Lang.Dictionary;
        var ledger = state[:reminderLedger] as Lang.Dictionary;
        if (reminders[:overdueRepeatHours] != 24) {
            if (ledger[:lastOverdueSlot] == 2147483647) { ledger[:lastOverdueSlot] = null; }
            if (ledger[:lastTempOutSlot] == 2147483647) {
                ledger[:lastTempOutSlot] = null;
                ledger[:tempOutIdentity] = null;
            }
            return;
        }
        if (state[:active] == null) { return; }
        var active = state[:active] as Lang.Dictionary;
        var status = ScheduleModel.deriveStatus(nowUtc, active,
            state[:regimen] as Lang.Dictionary);
        ledger[:cycleId] = active[:cycleId];
        ledger[:actionKey] = ReminderPolicy.actionKey(status);
        ledger[:lastOverdueSlot] = 2147483647;
        var open = ScheduleModel.tempOpen(active);
        if (open == null) {
            ledger[:lastTempOutSlot] = null;
            ledger[:tempOutIdentity] = null;
        } else {
            ledger[:lastTempOutSlot] = 2147483647;
            ledger[:tempOutIdentity] = (open as Lang.Dictionary)[:outUtc];
        }
    }
}

class ForegroundController {
    private var _state as Lang.Dictionary;
    private var _launchAlert as Lang.Boolean;
    private var _notificationData as Lang.Array?;
    private var _pendingSettings as Lang.Dictionary?;
    private var _backgroundWarning as Lang.Boolean;
    private var _alertContext as Lang.Dictionary?;
    private var _deferredTimer as Timer.Timer?;
    private var _deferredWork as Lang.Dictionary?;

    function initialize() {
        _state = {};
        _launchAlert = false;
        _notificationData = null;
        _pendingSettings = null;
        _backgroundWarning = false;
        _alertContext = null;
        _deferredTimer = null;
        _deferredWork = null;
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
        if (SettingsBridge.migrateLegacyProperties(_state, currentUtc())) {
            RingStore.save(_state);
        }
        if (_state[:migrationNoticePending] == true) {
            _state[:migrationNoticePending] = false;
            RingStore.save(_state);
            return [new MigrationView(), new MigrationDelegate()];
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
            if (_state[:setupStep] == 2) {
                var menu = Menus.insertionMenu();
                return [menu, new InsertionMenuDelegate()];
            }
            return [new MainView(), new MainDelegate()];
        }
        if (_launchAlert) { return [new AlertView(), new AlertDelegate()]; }
        return [new MainView(), new MainDelegate()];
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

    function deferAction(action as Lang.Symbol, atUtc as Lang.Number, data) as Void {
        deferWork({ :kind=>:action, :action=>action, :atUtc=>atUtc, :data=>data });
    }

    function deferSettings(accept as Lang.Boolean) as Void {
        deferWork({ :kind=>:settings, :accept=>accept });
    }

    private function deferWork(work as Lang.Dictionary) as Void {
        if (_deferredTimer != null) { (_deferredTimer as Timer.Timer).stop(); }
        _deferredWork = work;
        _deferredTimer = new Timer.Timer();
        (_deferredTimer as Timer.Timer).start(method(:applyDeferred), 1000, false);
    }

    function applyDeferred() as Void {
        if (_deferredTimer != null) { (_deferredTimer as Timer.Timer).stop(); }
        _deferredTimer = null;
        var work = _deferredWork;
        _deferredWork = null;
        if (work == null) { return; }
        if ((work as Lang.Dictionary)[:kind] == :settings) {
            resolvePendingSettings((work as Lang.Dictionary)[:accept]);
        } else {
            performConfirmed((work as Lang.Dictionary)[:action],
                (work as Lang.Dictionary)[:atUtc], (work as Lang.Dictionary)[:data]);
        }
    }


    function saveOrRecover() as Lang.Boolean {
        MenuActions.syncRepeatPolicy(_state, currentUtc());
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
        WatchUi.switchToView(menu, new MainMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function showAlertMenu() as Void {
        WatchUi.switchToView(Menus.mainMenuWithFocus(_state, 0), new MainMenuDelegate(), WatchUi.SLIDE_UP);
    }

    function showUpcoming() as Void {
        WatchUi.pushView(new UpcomingView(), new UpcomingDelegate(), WatchUi.SLIDE_DOWN);
    }

    function showHistory() as Void {
        WatchUi.pushView(new HistoryView(), new HistoryDelegate(), WatchUi.SLIDE_UP);
    }

    function showAbout() as Void {
        WatchUi.pushView(new AboutView(), new AboutDelegate(), WatchUi.SLIDE_UP);
    }

    function showSettingsMenu() as Void {
        WatchUi.switchToView(Menus.settingsMenu(_state), new SettingsMenuDelegate(), WatchUi.SLIDE_RIGHT);
    }

    function showCorrectDates() as Void {
        WatchUi.switchToView(Menus.correctDatesMenu(_state),
            new CorrectDatesDelegate(), WatchUi.SLIDE_LEFT);
    }

    function setToggle(id, enabled as Lang.Boolean) as Void {
        var reminders = _state[:reminders] as Lang.Dictionary;
        if (id == :toggleReminder2) { reminders[:reminder2Enabled] = enabled; }
        else if (id == :toggleDayBefore) { reminders[:dayBeforeEnabled] = enabled; }
        else if (id == :toggleVibration) { reminders[:vibrationEnabled] = enabled; }
        else if (id == :toggleSound) { reminders[:soundEnabled] = enabled; }
        else { return; }
        if (saveOrRecover()) {
            WatchUi.switchToView(Menus.settingsMenuWithFocus(_state,
                Menus.settingsFocusForId(_state, id)), new SettingsMenuDelegate(),
                WatchUi.SLIDE_IMMEDIATE);
        }
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
            var watchTime = Ui.compactDate((_state[:active] as Lang.Dictionary)[:insertionUtc]) + " "
                + Ui.timeForUtc((_state[:active] as Lang.Dictionary)[:insertionUtc], 24);
            var phoneTime = Ui.compactDate((_pendingSettings as Lang.Dictionary)[:insertionUtc]) + " "
                + Ui.timeForUtc((_pendingSettings as Lang.Dictionary)[:insertionUtc], 24);
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
                showMain();
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
            showMain();
        }
        registerBackground();
    }

    function onValidateProperty(key as Lang.String, value as Properties.ValueType) as Lang.Boolean or Lang.String {
        return SettingsBridge.validate(key, value, currentUtc())
            ? true : Ui.s(SettingsBridge.isInsertionKey(key)
                ? Rez.Strings.InsertionDateTimeError : Rez.Strings.SettingValueError);
    }

    private function prepareSettings() as Void {
        try {
            _pendingSettings = SettingsBridge.observe(_state, currentUtc());
            MenuActions.syncRepeatPolicy(_state, currentUtc());
            RingStore.save(_state);
        } catch (ignored) {
            _pendingSettings = { :invalid => true };
        }
    }

    function confirmAction(action as Lang.Symbol, atUtc as Lang.Number, data) as Void {
        var message = Ui.s(Rez.Strings.SaveChangeQuestion);
        var clock = 0;
        var timestamp = Ui.compactTimestamp(atUtc, clock);
        if (action == :acceptDisclaimer) { message = Ui.s(Rez.Strings.ContinueQuestion); }
        else if (action == :acceptRegimen) { message = Ui.s(Rez.Strings.ConfirmRegimenQuestion); }
        else if (action == :insert) {
            message = data == null
                ? Ui.fmt(Rez.Strings.ConfirmInsertNow, [Ui.s(Rez.Strings.ConfirmFirstCycle)])
                : Ui.fmt(Rez.Strings.ConfirmRecordInsertion, [timestamp]);
        }
        else if (action == :replace) {
            var replacing = _state[:active] as Lang.Dictionary;
            var replaceDue = replacing[:removalUtc] == null ? replacing[:removeDueUtc] : replacing[:insertDueUtc];
            var scheduleFact = Menus.scheduleFact(replaceDue - atUtc);
            if (replacing[:removalUtc] != null && atUtc < replaceDue) {
                var day = CalendarMath.dayOfCycle(atUtc, replacing[:removalUtc]);
                message = Ui.fmt(Rez.Strings.ConfirmEarlyInsert,
                    [day, (_state[:regimen] as Lang.Dictionary)[:daysOut], scheduleFact]);
            } else {
                message = Ui.fmt(replacing[:removalUtc] == null
                    ? Rez.Strings.ConfirmReplaceNow : Rez.Strings.ConfirmInsertNow, [scheduleFact]);
            }
        }
        else if (action == :remove) {
            var removing = _state[:active] as Lang.Dictionary;
            message = Ui.fmt(Rez.Strings.ConfirmRemoveNow,
                [Menus.scheduleFact(removing[:removeDueUtc] - atUtc)]);
        }
        else if (action == :tempOut) { message = Ui.s(Rez.Strings.ConfirmRingOutBriefly); }
        else if (action == :backIn) {
            var backInCycle = _state[:active] as Lang.Dictionary;
            var open = ScheduleModel.tempOpen(backInCycle);
            var outFor = open == null ? 0 : atUtc - open[:outUtc];
            message = Ui.fmt(Rez.Strings.ConfirmPutRingBack, [Ui.compactElapsed(outFor)]);
        }
        else if (action == :keepOut) {
            var keepingOut = _state[:active] as Lang.Dictionary;
            var keepOpen = ScheduleModel.tempOpen(keepingOut);
            var removedAt = keepOpen == null ? atUtc : (keepOpen as Lang.Dictionary)[:outUtc];
            message = Ui.fmt(Rez.Strings.ConfirmKeepOut,
                [Ui.compactTimestamp(removedAt, clock)]);
        }
        else if (action == :undoRingOut) {
            message = Ui.s(Rez.Strings.ConfirmUndoRingOut);
        }
        else if (action == :adjustInsertion) {
            message = Ui.fmt(Rez.Strings.ConfirmChangeInsertion, [timestamp]);
        }
        else if (action == :adjustRemoval) {
            WatchUi.pushView(new CompactConfirmationView(
                Ui.s(Rez.Strings.ConfirmChangeRemovalTitle), timestamp),
                new CompactConfirmationDelegate(action, atUtc, data), WatchUi.SLIDE_UP);
            return;
        }
        else if (action == :clearHistory) { message = Ui.s(Rez.Strings.ClearHistoryQuestion); }
        else if (action == :reset) { message = Ui.s(Rez.Strings.ResetQuestion); }
        else if (action == :setDaysIn || action == :setDaysOut) {
            var active = _state[:active] as Lang.Dictionary?;
            if (active == null) {
                message = Ui.s(Rez.Strings.AcknowledgeDurationQuestion);
            } else {
                var oldDue = (active as Lang.Dictionary)[:removalUtc] == null
                    ? (active as Lang.Dictionary)[:removeDueUtc] : (active as Lang.Dictionary)[:insertDueUtc];
                var newDue = oldDue;
                if ((active as Lang.Dictionary)[:removalUtc] == null && action == :setDaysIn) {
                    newDue = CalendarMath.addLocalCalendarDays((active as Lang.Dictionary)[:insertionUtc], data)[:utc];
                } else if ((active as Lang.Dictionary)[:removalUtc] != null && action == :setDaysOut) {
                    newDue = CalendarMath.addLocalCalendarDays((active as Lang.Dictionary)[:removalUtc], data)[:utc];
                }
                message = Ui.fmt(Rez.Strings.RegimenChangeQuestion,
                    [Ui.compactDate(oldDue) + " " + Ui.timeForUtc(oldDue, clock),
                     Ui.compactDate(newDue) + " " + Ui.timeForUtc(newDue, clock)]);
            }
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
            _state[:setupStep] = 3;
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
                } else { showSettingsMenu(); }
                if (durationDstNotice) { showDstAdjustment(); }
            }
            return;
        }
        if (action == :setReminder || action == :setReminder2 || action == :setRepeat) {
            var settingReminders = _state[:reminders] as Lang.Dictionary;
            if (action == :setReminder || action == :setReminder2) {
                var timeValues = data as Lang.Array<Lang.Number>;
                if (action == :setReminder) {
                    settingReminders[:reminder1Hour] = timeValues[0];
                    settingReminders[:reminder1Minute] = timeValues[1];
                } else {
                    settingReminders[:reminder2Hour] = timeValues[0];
                    settingReminders[:reminder2Minute] = timeValues[1];
                }
            } else if (action == :setRepeat) {
                settingReminders[:overdueRepeatHours] = data;
            }
            if (saveOrRecover()) { showSettingsMenu(); }
            return;
        }

        // State-level actions remain valid while no cycle is active.
        if (action == :clearHistory) {
            _state[:history] = [];
            if (saveOrRecover()) { showMain(); }
            return;
        }
        if (action == :reset) {
            _state = ScheduleModel.defaultState();
            if (saveOrRecover()) {
                WatchUi.switchToView(new DisclaimerView(), new DisclaimerDelegate(), WatchUi.SLIDE_IMMEDIATE);
            }
            return;
        }
        var seededState = optionalSeedState(action, data, currentUtc());
        if (seededState != null) {
            _state = seededState as Lang.Dictionary;
            if (isTransientOptionalSeed(action, data)) {
                // The maximum-memory QA fixture is intentionally in-memory:
                // constructing and serializing every retained object in the
                // same callback can exceed the device watchdog, while normal
                // user growth is spread across many confirmed actions.
                showMain();
                return;
            }
            if (saveOrRecover()) {
                afterOptionalSeed(action, data);
                if (isFreshOptionalSeed(action, data)) {
                    WatchUi.switchToView(new DisclaimerView(), new DisclaimerDelegate(), WatchUi.SLIDE_IMMEDIATE);
                } else {
                    showMain();
                    previewOptionalNotification(data, _state, currentUtc());
                }
            }
            return;
        }

        if (active == null) { return; }
        if ((action == :remove || action == :tempOut || action == :backIn
            || action == :keepOut || action == :undoRingOut
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
        } else if (action == :keepOut) {
            if (!MenuActions.keepOut(active, regimen,
                    _state[:reminderLedger] as Lang.Dictionary)) {
                showInfo(Rez.Strings.EditCorrectDates, [Ui.s(Rez.Strings.InvalidEventOrder)]);
                return;
            }
            dstNotice = active[:dstAdjustment] != null;
        } else if (action == :undoRingOut) {
            if (!MenuActions.undoRingOut(active,
                    _state[:reminderLedger] as Lang.Dictionary)) { return; }
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
        }

        if (saveOrRecover()) {
            if (action == :backIn && closedAlertInterval != null) {
                showTemporaryAlert(closedAlertInterval as Lang.Dictionary);
            }
            else {
                showMain();
                if (dstNotice) { showDstAdjustment(); }
            }
        }
    }

    private function recomputeDeadlines(active as Lang.Dictionary, regimen as Lang.Dictionary) as Lang.Boolean {
        return ScheduleModel.recomputeForRegimen(active, regimen);
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

module ForegroundRuntime {
    var instance as ForegroundController? = null;

    function controller() as ForegroundController {
        if (instance == null) { instance = new ForegroundController(); }
        return instance as ForegroundController;
    }
}

class ForegroundEntryView extends WatchUi.View {
    private var _startupState as Lang.Dictionary?;

    function initialize(state as Lang.Dictionary?) {
        View.initialize();
        _startupState = state;
    }

    function onShow() as Void {
        var controller = ForegroundRuntime.controller();
        controller.onStart(_startupState);
        var initial = controller.getInitialView() as Lang.Array;
        var delegate = initial.size() > 1 ? initial[1] : null;
        WatchUi.switchToView(initial[0] as WatchUi.View, delegate as WatchUi.InputDelegate?, WatchUi.SLIDE_IMMEDIATE);
    }
}

class ForegroundSettingsEntryView extends WatchUi.View {
    function initialize() { View.initialize(); }
    function onShow() as Void { ForegroundRuntime.controller().onSettingsChanged(); }
}

function getApp() as ForegroundController { return ForegroundRuntime.controller(); }
