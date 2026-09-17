import Toybox.Lang;
import Toybox.WatchUi;

module Menus {
    function item(label, subLabel, id) as WatchUi.MenuItem {
        return new WatchUi.MenuItem(label, subLabel, id, null);
    }

    function toggle(label, id, enabled as Lang.Boolean) as WatchUi.ToggleMenuItem {
        return new WatchUi.ToggleMenuItem(label, null, id, enabled, null);
    }

    function mainTitle(state as Lang.Dictionary, nowUtc as Lang.Number) as Lang.String {
        var active = state[:active] as Lang.Dictionary?;
        if (active == null) { return Ui.s(Rez.Strings.MenuNoCycleTitle); }
        var open = ScheduleModel.tempOpen(active as Lang.Dictionary);
        if (open != null) {
            var elapsed = nowUtc - (open as Lang.Dictionary)[:outUtc];
            if (elapsed < 0) { elapsed = 0; }
            var totalMinutes = elapsed / 60;
            return Ui.fmt(Rez.Strings.MenuRingOutTitle,
                [totalMinutes / 60, (totalMinutes % 60).format("%02d")]);
        }
        if ((active as Lang.Dictionary)[:removalUtc] != null) {
            return Ui.fmt(Rez.Strings.MenuRingFreeTitle,
                [CalendarMath.dayOfCycle(nowUtc, (active as Lang.Dictionary)[:removalUtc])]);
        }
        return Ui.fmt(Rez.Strings.MenuRingInTitle,
            [CalendarMath.dayOfCycle(nowUtc, (active as Lang.Dictionary)[:insertionUtc])]);
    }

    function scheduleFact(deltaSeconds as Lang.Number) as Lang.String {
        if (deltaSeconds.abs() < 60) { return Ui.s(Rez.Strings.ConfirmDueNow); }
        var future = deltaSeconds > 0;
        var absolute = deltaSeconds.abs();
        if (absolute >= CalendarMath.SECONDS_PER_DAY) {
            var days = absolute / CalendarMath.SECONDS_PER_DAY;
            if (future) {
                return Ui.fmt(days == 1 ? Rez.Strings.ConfirmDueInOneDay
                    : Rez.Strings.ConfirmDueInDays, days == 1 ? [] : [days]);
            }
            return Ui.fmt(days == 1 ? Rez.Strings.ConfirmDueOneDayAgo
                : Rez.Strings.ConfirmDueDaysAgo, days == 1 ? [] : [days]);
        }
        var hours = absolute / CalendarMath.SECONDS_PER_HOUR;
        if (hours < 1) { hours = 1; }
        if (future) {
            return Ui.fmt(hours == 1 ? Rez.Strings.ConfirmDueInOneHour
                : Rez.Strings.ConfirmDueInHours, hours == 1 ? [] : [hours]);
        }
        return Ui.fmt(hours == 1 ? Rez.Strings.ConfirmDueOneHourAgo
            : Rez.Strings.ConfirmDueHoursAgo, hours == 1 ? [] : [hours]);
    }

    function insertionMenu() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.MenuNoCycleTitle});
        menu.addItem(item(Rez.Strings.MenuInsertNow, null, :insertNow));
        menu.addItem(item(Rez.Strings.MenuRingAlreadyIn, Rez.Strings.MenuChooseDateTime, :alreadyIn));
        menu.addItem(item(Rez.Strings.Settings, null, :settings));
        menu.addItem(item(Rez.Strings.AboutDisclaimer, null, :about));
        return menu;
    }

    function mainMenu(state as Lang.Dictionary) as WatchUi.Menu2 {
        return mainMenuWithFocus(state, 0);
    }

    function mainMenuWithFocus(state as Lang.Dictionary, focus as Lang.Number) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => mainTitle(state, currentUtc()), :focus => focus});
        var active = state[:active] as Lang.Dictionary?;
        if (active == null) {
            menu.addItem(item(Rez.Strings.MenuInsertNow, null, :insertNow));
            menu.addItem(item(Rez.Strings.MenuRingAlreadyIn, Rez.Strings.MenuChooseDateTime, :alreadyIn));
        } else {
            if (active[:removalUtc] == null) {
                var open = ScheduleModel.tempOpen(active);
                if (open != null) {
                    menu.addItem(item(Rez.Strings.MenuPutRingBack, Rez.Strings.MenuLogsCurrentTime, :backIn));
                    menu.addItem(item(Rez.Strings.MenuKeepOut, Rez.Strings.MenuStartRingFree, :keepOut));
                    menu.addItem(item(Rez.Strings.MenuUndoRingOut, Rez.Strings.MenuRemoveEntry, :undoRingOut));
                } else {
                    menu.addItem(item(Rez.Strings.MenuRemoveRing, Rez.Strings.MenuStartRingFree, :removeNow));
                    menu.addItem(item(Rez.Strings.MenuRingOutBriefly, Rez.Strings.MenuBackWithinThreeHours, :tempOut));
                    menu.addItem(item(Rez.Strings.MenuEditInsertion, null, :adjust));
                    menu.addItem(item(Rez.Strings.History, null, :history));
                }
            } else {
                menu.addItem(item(Rez.Strings.MenuInsertRing, Rez.Strings.MenuLogsCurrentTime, :insertNow));
                menu.addItem(item(Rez.Strings.MenuEditRemoval, null, :adjust));
                menu.addItem(item(Rez.Strings.History, null, :history));
            }
        }
        menu.addItem(item(Rez.Strings.Settings, null, :settings));
        menu.addItem(item(Rez.Strings.AboutDisclaimer, null, :about));
        addDebugMenuItem(menu);
        return menu;
    }

    function settingsMenu(state as Lang.Dictionary) as WatchUi.Menu2 {
        return settingsMenuWithFocus(state, 0);
    }

    function settingsMenuWithFocus(state as Lang.Dictionary, focus as Lang.Number) as WatchUi.Menu2 {
        var regimen = state[:regimen] as Lang.Dictionary;
        var reminders = state[:reminders] as Lang.Dictionary;
        var menu = new WatchUi.Menu2({:title => Rez.Strings.Settings, :focus => focus});
        menu.addItem(item(Rez.Strings.SettingsReminder1,
            Ui.timeOnly(reminders[:reminder1Hour], reminders[:reminder1Minute], 0), :reminder1));
        menu.addItem(toggle(Rez.Strings.SettingsReminder2, :toggleReminder2,
            reminders[:reminder2Enabled]));
        if (reminders[:reminder2Enabled]) {
            menu.addItem(item(Rez.Strings.SettingsReminder2Time,
                Ui.timeOnly(reminders[:reminder2Hour], reminders[:reminder2Minute], 0), :reminder2Time));
        }
        menu.addItem(toggle(Rez.Strings.SettingsDayBefore, :toggleDayBefore,
            reminders[:dayBeforeEnabled]));
        menu.addItem(item(Rez.Strings.SettingsRepeatIfMissed,
            repeatLabel(reminders[:overdueRepeatHours]), :repeat));
        menu.addItem(item(Rez.Strings.SettingsRingIn,
            Ui.fmt(Rez.Strings.SettingsDaysValue, [regimen[:daysIn]]), :daysIn));
        menu.addItem(item(Rez.Strings.SettingsRingOut,
            Ui.fmt(Rez.Strings.SettingsDaysValue, [regimen[:daysOut]]), :daysOut));
        menu.addItem(toggle(Rez.Strings.SettingsVibration, :toggleVibration,
            reminders[:vibrationEnabled]));
        menu.addItem(toggle(Rez.Strings.SettingsSound, :toggleSound,
            reminders[:soundEnabled]));
        return menu;
    }

    function settingsFocusForId(state as Lang.Dictionary, id) as Lang.Number {
        var secondOn = (state[:reminders] as Lang.Dictionary)[:reminder2Enabled];
        if (id == :toggleReminder2) { return 1; }
        if (id == :reminder2Time) { return 2; }
        var offset = secondOn ? 1 : 0;
        if (id == :toggleDayBefore) { return 2 + offset; }
        if (id == :repeat) { return 3 + offset; }
        if (id == :daysIn) { return 4 + offset; }
        if (id == :daysOut) { return 5 + offset; }
        if (id == :toggleVibration) { return 6 + offset; }
        if (id == :toggleSound) { return 7 + offset; }
        return 0;
    }

    function repeatLabel(value as Lang.Number) as Lang.String {
        if (value == 1) { return Ui.s(Rez.Strings.SettingsEveryHour); }
        if (value == 3) { return Ui.s(Rez.Strings.SettingsEveryThreeHours); }
        if (value == 6) { return Ui.s(Rez.Strings.SettingsEverySixHours); }
        return Ui.s(Rez.Strings.SettingsRepeatOff);
    }

    function repeatMenu(current as Lang.Number) as WatchUi.Menu2 {
        var values = [1, 3, 6, 24];
        var menu = new WatchUi.Menu2({:title => Rez.Strings.SettingsRepeatIfMissed,
            :focus => PickerValues.indexOf(values, current)});
        for (var i = 0; i < values.size(); i += 1) {
            menu.addItem(item(repeatLabel(values[i]),
                values[i] == current ? Rez.Strings.SettingsSelected : null, values[i]));
        }
        return menu;
    }

    (:production)
    function addDebugMenuItem(menu as WatchUi.Menu2) as Void { }

    (:debug)
    function addDebugMenuItem(menu as WatchUi.Menu2) as Void {
        menu.addItem(item(Rez.Strings.DemoScenarios, null, :demo));
    }

    (:debug)
    function demoMenu() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.DemoScenarios});
        menu.addItem(item(Rez.Strings.DemoFresh, null, :fresh));
        menu.addItem(item(Rez.Strings.DemoNoCycle, null, :noCycle));
        menu.addItem(item(Rez.Strings.DemoDay5, null, :day5));
        menu.addItem(item(Rez.Strings.DemoRingIn1d12h, null, :ringIn1d12h));
        menu.addItem(item(Rez.Strings.DemoRingIn14h, null, :ringIn14h));
        menu.addItem(item(Rez.Strings.DemoRingIn45m, null, :ringIn45m));
        menu.addItem(item(Rez.Strings.DemoBeforeRemoval, null, :beforeRemoval));
        menu.addItem(item(Rez.Strings.DemoOverdueRemoval, null, :overdueRemoval));
        menu.addItem(item(Rez.Strings.DemoOverdue29h, null, :overdue29h));
        menu.addItem(item(Rez.Strings.DemoOverdue2d, null, :overdue2d));
        menu.addItem(item(Rez.Strings.DemoOverdueLarge, null, :overdueLarge));
        menu.addItem(item(Rez.Strings.DemoRingFree, null, :ringFree));
        menu.addItem(item(Rez.Strings.DemoFreeDay3, null, :freeDay3));
        menu.addItem(item(Rez.Strings.DemoFreeExceeded, null, :freeExceeded));
        menu.addItem(item(Rez.Strings.DemoTemp250, null, :temp250));
        menu.addItem(item(Rez.Strings.DemoTemp310, null, :temp310));
        menu.addItem(item(Rez.Strings.DemoReminder2, null, :reminder2));
        menu.addItem(item(Rez.Strings.DemoExtended35, null, :extended35));
        menu.addItem(item(Rez.Strings.DemoRingIn29d, null, :ringIn29d));
        menu.addItem(item(Rez.Strings.DemoRingFree8d, null, :ringFree8d));
        menu.addItem(item(Rez.Strings.DemoWarningWrapLong, null, :warningWrapLong));
        menu.addItem(item(Rez.Strings.DemoLargestCountdown, null, :largestCountdown));
        menu.addItem(item(Rez.Strings.DemoClock12Long, null, :clock12Long));
        menu.addItem(item(Rez.Strings.DemoClock24, null, :clock24));
        menu.addItem(item(Rez.Strings.DemoPicker12, null, :picker12));
        menu.addItem(item(Rez.Strings.DemoPicker24, null, :picker24));
        menu.addItem(item(Rez.Strings.DemoPickerDate, null, :pickerDate));
        menu.addItem(item(Rez.Strings.DemoMigration, null, :migration));
        menu.addItem(item(Rez.Strings.DemoMaximumState, null, :maximumState));
        menu.addItem(item(Rez.Strings.DemoNotificationDayBefore, null, :notificationDayBefore));
        menu.addItem(item(Rez.Strings.DemoNotificationReminder1, null, :notificationReminder1));
        menu.addItem(item(Rez.Strings.DemoNotificationReminder2, null, :notificationReminder2));
        menu.addItem(item(Rez.Strings.DemoNotificationOverdue, null, :notificationOverdue));
        menu.addItem(item(Rez.Strings.DemoNotificationTemp, null, :notificationTemp));
        menu.addItem(item(Rez.Strings.DemoNotificationFree, null, :notificationFree));
        menu.addItem(item(Rez.Strings.DemoNotificationFourWeeks, null, :notificationFourWeeks));
        menu.addItem(item(Rez.Strings.DemoBackgroundDayBefore, null, :backgroundDayBefore));
        menu.addItem(item(Rez.Strings.DemoBackgroundReminder1, null, :backgroundReminder1));
        menu.addItem(item(Rez.Strings.DemoBackgroundReminder2, null, :backgroundReminder2));
        menu.addItem(item(Rez.Strings.DemoBackgroundOverdue, null, :backgroundOverdue));
        menu.addItem(item(Rez.Strings.DemoBackgroundTemp, null, :backgroundTemp));
        menu.addItem(item(Rez.Strings.DemoBackgroundFree, null, :backgroundFree));
        menu.addItem(item(Rez.Strings.DemoBackgroundFourWeeks, null, :backgroundFourWeeks));
        menu.addItem(item(Rez.Strings.DemoBackgroundNoOp, null, :backgroundNoOp));
        menu.addItem(item(Rez.Strings.DemoBackgroundNil, null, :backgroundNil));
        menu.addItem(item(Rez.Strings.DemoBackgroundCorrupt, null, :backgroundCorrupt));
        menu.addItem(item(Rez.Strings.DemoBackgroundThrow, null, :backgroundThrow));
        return menu;
    }
}

class InsertionMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :insertNow) { getApp().confirmAction(:insert, currentUtc(), null); }
        else if (item.getId() == :alreadyIn) { PickerFlow.openDate(:insert, currentUtc()); }
        else if (item.getId() == :settings) { getApp().showSettingsMenu(); }
        else if (item.getId() == :about) { getApp().showAbout(); }
    }
    function onBack() as Void { getApp().showMain(); }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var app = getApp();
        if (id == :insertNow && app.getState()[:active] == null) { app.confirmAction(:insert, currentUtc(), null); }
        else if (id == :alreadyIn) { PickerFlow.openDate(:insert, currentUtc()); }
        else if (id == :insertNow) { app.confirmAction(:replace, currentUtc(), null); }
        else if (id == :removeNow) { app.confirmAction(:remove, currentUtc(), null); }
        else if (id == :tempOut) { app.confirmAction(:tempOut, currentUtc(), null); }
        else if (id == :backIn) { app.confirmAction(:backIn, currentUtc(), null); }
        else if (id == :keepOut) { app.confirmAction(:keepOut, currentUtc(), null); }
        else if (id == :undoRingOut) { app.confirmAction(:undoRingOut, currentUtc(), null); }
        else if (id == :adjust) { WatchUi.switchToView(new CorrectDatesView(), new CorrectDatesDelegate(), WatchUi.SLIDE_LEFT); }
        else if (id == :upcoming) { app.showUpcoming(); }
        else if (id == :settings) { app.showSettingsMenu(); }
        else if (id == :history) { app.showHistory(); }
        else if (id == :about) { app.showAbout(); }
        else { openOptionalMenu(id); }
    }
    function onBack() as Void { getApp().showMain(); }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var state = getApp().getState();
        var regimen = state[:regimen] as Lang.Dictionary;
        if (id == :reminder1) { PickerFlow.openTime(:setReminder, currentUtc()); }
        else if (id == :reminder2Time) { PickerFlow.openTime(:setReminder2, currentUtc()); }
        else if (id == :daysIn) { PickerFlow.openNumber(:setDaysIn, 21, 35, regimen[:daysIn], Rez.Strings.SettingsRingIn); }
        else if (id == :daysOut) { PickerFlow.openNumber(:setDaysOut, 0, 7, regimen[:daysOut], Rez.Strings.SettingsRingOut); }
        else if (id == :repeat) {
            WatchUi.switchToView(Menus.repeatMenu((state[:reminders] as Lang.Dictionary)[:overdueRepeatHours]),
                new ValueMenuDelegate(:setRepeat), WatchUi.SLIDE_LEFT);
        }
        else if (id == :toggleReminder2 || id == :toggleDayBefore
            || id == :toggleVibration || id == :toggleSound) {
            getApp().setToggle(id, (item as WatchUi.ToggleMenuItem).isEnabled());
        }
    }
    function onBack() as Void { getApp().showMain(); }
}

class ValueMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _action as Lang.Symbol;
    function initialize(action as Lang.Symbol) { Menu2InputDelegate.initialize(); _action = action; }
    function onSelect(item as WatchUi.MenuItem) as Void { getApp().confirmAction(_action, currentUtc(), item.getId()); }
    function onBack() as Void { getApp().showSettingsMenu(); }
}

(:debug)
class DemoMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :picker12 || id == :picker24) {
            var reminders = getApp().getState()[:reminders] as Lang.Dictionary;
            reminders[:clockFormat] = id == :picker12 ? 12 : 24;
            PickerFlow.openTime(:setReminder, currentUtc());
        } else if (id == :pickerDate) {
            PickerFlow.openDate(:insert, currentUtc());
        } else {
            getApp().confirmAction(:demo, currentUtc(), id);
        }
    }
    function onBack() as Void { getApp().showMainMenu(); }
}
