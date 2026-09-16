import Toybox.Lang;
import Toybox.WatchUi;

module Menus {
    function item(label, subLabel, id) as WatchUi.MenuItem {
        return new WatchUi.MenuItem(label, subLabel, id, null);
    }

    function insertionMenu() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.InitialInsertionTitle});
        menu.addItem(item(Rez.Strings.InsertedNow, null, :insertNow));
        menu.addItem(item(Rez.Strings.ChooseDateTime, null, :chooseInsert));
        return menu;
    }

    function mainMenu(state as Lang.Dictionary) as WatchUi.Menu2 {
        return mainMenuWithFocus(state, 0);
    }

    function mainMenuWithFocus(state as Lang.Dictionary, focus as Lang.Number) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.MenuTitle, :focus => focus});
        var active = state[:active] as Lang.Dictionary?;
        if (active == null) {
            menu.addItem(item(Rez.Strings.RingInsertedNow, null, :insertNow));
        } else {
            if (active[:removalUtc] == null) {
                var open = ScheduleModel.tempOpen(active);
                if (open != null) { menu.addItem(item(Rez.Strings.RingBackIn, null, :backIn)); }
                menu.addItem(item(Rez.Strings.RingRemovedNow, null, :removeNow));
                if (open == null) { menu.addItem(item(Rez.Strings.RingOutTemporarily, null, :tempOut)); }
                menu.addItem(item(Rez.Strings.RingInsertedNow, null, :insertNow));
            } else {
                menu.addItem(item(Rez.Strings.RingInsertedNow, null, :insertNow));
            }
            menu.addItem(item(Rez.Strings.AdjustDates, null, :adjust));
            menu.addItem(item(Rez.Strings.Upcoming, null, :upcoming));
        }
        menu.addItem(item(Rez.Strings.History, null, :history));
        menu.addItem(item(Rez.Strings.Settings, null, :settings));
        menu.addItem(item(Rez.Strings.AboutDisclaimer, null, :about));
        addDebugMenuItem(menu);
        return menu;
    }

    function adjustMenu(state as Lang.Dictionary) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.AdjustTitle});
        var active = state[:active] as Lang.Dictionary;
        menu.addItem(item(Rez.Strings.Insertion, null, :adjustInsertion));
        if (active[:removalUtc] != null) { menu.addItem(item(Rez.Strings.Removal, null, :adjustRemoval)); }
        return menu;
    }

    function settingsMenu(state as Lang.Dictionary) as WatchUi.Menu2 {
        var regimen = state[:regimen] as Lang.Dictionary;
        var reminders = state[:reminders] as Lang.Dictionary;
        var menu = new WatchUi.Menu2({:title => Rez.Strings.Settings});
        menu.addItem(item(Rez.Strings.Reminder1, Ui.timeOnly(reminders[:reminder1Hour], reminders[:reminder1Minute], reminders[:clockFormat]), :reminder1));
        menu.addItem(item(Rez.Strings.Reminder2, reminders[:reminder2Enabled]
            ? Ui.timeOnly(reminders[:reminder2Hour], reminders[:reminder2Minute], reminders[:clockFormat])
            : Ui.s(Rez.Strings.Off), :reminder2));
        menu.addItem(item(Rez.Strings.DayBeforeReminder,
            reminders[:dayBeforeEnabled] ? Rez.Strings.On : Rez.Strings.Off, :dayBefore));
        menu.addItem(item(Rez.Strings.RepeatOverdue, Ui.fmt(Rez.Strings.HoursShortTemplate, [reminders[:overdueRepeatHours]]), :repeat));
        menu.addItem(item(Rez.Strings.DaysRingIn, regimen[:daysIn].toString(), :daysIn));
        if (regimen[:daysIn] > 28) {
            menu.addItem(item(Rez.Strings.OutsideLabelBadge, null, :outsideLabelInfo));
        }
        menu.addItem(item(Rez.Strings.DaysRingFree, regimen[:daysOut] == 0 ? Rez.Strings.ReplaceImmediately : regimen[:daysOut].toString(), :daysOut));
        menu.addItem(item(Rez.Strings.Vibration, reminders[:vibrationEnabled] ? Rez.Strings.On : Rez.Strings.Off, :vibration));
        menu.addItem(item(Rez.Strings.Sound, reminders[:soundEnabled] ? Rez.Strings.On : Rez.Strings.Off, :sound));
        var clock = reminders[:clockFormat] == 12 ? Rez.Strings.Clock12Hour : (reminders[:clockFormat] == 24 ? Rez.Strings.Clock24Hour : Rez.Strings.ClockSystem);
        menu.addItem(item(Rez.Strings.Clock, clock, :clock));
        menu.addItem(item(Rez.Strings.ResetApp, null, :reset));
        return menu;
    }

    function reminder2Menu(state as Lang.Dictionary) as WatchUi.Menu2 {
        var reminders = state[:reminders] as Lang.Dictionary;
        var menu = new WatchUi.Menu2({:title => Rez.Strings.Reminder2});
        menu.addItem(item(Rez.Strings.Reminder2,
            reminders[:reminder2Enabled] ? Rez.Strings.On : Rez.Strings.Off, :toggleReminder2));
        menu.addItem(item(Rez.Strings.TimeTitle,
            Ui.timeOnly(reminders[:reminder2Hour], reminders[:reminder2Minute], reminders[:clockFormat]), :reminder2Time));
        return menu;
    }

    function repeatMenu() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.RepeatTitle});
        var values = [1, 3, 6, 12, 24];
        for (var i = 0; i < values.size(); i += 1) {
            var label = Ui.fmt(values[i] == 1 ? Rez.Strings.HourTemplate : Rez.Strings.HoursTemplate, [values[i]]);
            menu.addItem(item(label, null, values[i]));
        }
        return menu;
    }

    function clockMenu() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.ClockTitle});
        menu.addItem(item(Rez.Strings.ClockSystem, null, 0));
        menu.addItem(item(Rez.Strings.Clock12Hour, null, 12));
        menu.addItem(item(Rez.Strings.Clock24Hour, null, 24));
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
        menu.addItem(item(Rez.Strings.DemoBeforeRemoval, null, :beforeRemoval));
        menu.addItem(item(Rez.Strings.DemoOverdueRemoval, null, :overdueRemoval));
        menu.addItem(item(Rez.Strings.DemoOverdueLarge, null, :overdueLarge));
        menu.addItem(item(Rez.Strings.DemoRingFree, null, :ringFree));
        menu.addItem(item(Rez.Strings.DemoFreeDay3, null, :freeDay3));
        menu.addItem(item(Rez.Strings.DemoFreeExceeded, null, :freeExceeded));
        menu.addItem(item(Rez.Strings.DemoTemp250, null, :temp250));
        menu.addItem(item(Rez.Strings.DemoTemp310, null, :temp310));
        menu.addItem(item(Rez.Strings.DemoReminder2, null, :reminder2));
        menu.addItem(item(Rez.Strings.DemoExtended35, null, :extended35));
        menu.addItem(item(Rez.Strings.DemoLargestCountdown, null, :largestCountdown));
        menu.addItem(item(Rez.Strings.DemoClock12Long, null, :clock12Long));
        menu.addItem(item(Rez.Strings.DemoClock24, null, :clock24));
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
        else if (item.getId() == :chooseInsert) { PickerFlow.openDate(:insert, currentUtc()); }
    }
    function onBack() as Void { getApp().showMain(); }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var app = getApp();
        if (id == :insertNow && app.getState()[:active] == null) {
            WatchUi.switchToView(Menus.insertionMenu(), new InsertionMenuDelegate(), WatchUi.SLIDE_LEFT);
        }
        else if (id == :insertNow) { app.confirmAction(:replace, currentUtc(), null); }
        else if (id == :removeNow) { app.confirmAction(:remove, currentUtc(), null); }
        else if (id == :tempOut) { app.confirmAction(:tempOut, currentUtc(), null); }
        else if (id == :backIn) { app.confirmAction(:backIn, currentUtc(), null); }
        else if (id == :adjust) { WatchUi.switchToView(Menus.adjustMenu(app.getState()), new AdjustMenuDelegate(), WatchUi.SLIDE_LEFT); }
        else if (id == :upcoming) { app.showUpcoming(); }
        else if (id == :settings) { app.showSettingsMenu(); }
        else if (id == :history) { app.showHistory(); }
        else if (id == :about) { app.showAbout(); }
        else { openOptionalMenu(id); }
    }
    function onBack() as Void { getApp().showMain(); }
}

class AdjustMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary;
        var id = item.getId() as Lang.Symbol;
        var start = active[:insertionUtc];
        if (id == :adjustRemoval) { start = active[:removalUtc]; }
        PickerFlow.openDate(id, start);
    }
    function onBack() as Void { getApp().showMainMenu(); }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var state = getApp().getState();
        var regimen = state[:regimen] as Lang.Dictionary;
        if (id == :reminder1) { PickerFlow.openTime(:setReminder, currentUtc()); }
        else if (id == :reminder2) { WatchUi.switchToView(Menus.reminder2Menu(state), new Reminder2MenuDelegate(), WatchUi.SLIDE_LEFT); }
        else if (id == :dayBefore) { getApp().confirmAction(:toggleDayBefore, currentUtc(), null); }
        else if (id == :daysIn) { PickerFlow.openNumber(:setDaysIn, 21, 35, regimen[:daysIn], Rez.Strings.DaysRingIn); }
        else if (id == :daysOut) { PickerFlow.openNumber(:setDaysOut, 0, 7, regimen[:daysOut], Rez.Strings.DaysRingFree); }
        else if (id == :outsideLabelInfo) { getApp().showInfo(Rez.Strings.OutsideLabelBadge, [Ui.s(Rez.Strings.OutsideLabelNotice)]); }
        else if (id == :repeat) { WatchUi.switchToView(Menus.repeatMenu(), new ValueMenuDelegate(:setRepeat), WatchUi.SLIDE_LEFT); }
        else if (id == :vibration) { getApp().confirmAction(:toggleVibration, currentUtc(), null); }
        else if (id == :sound) { getApp().confirmAction(:toggleSound, currentUtc(), null); }
        else if (id == :clock) { WatchUi.switchToView(Menus.clockMenu(), new ValueMenuDelegate(:setClock), WatchUi.SLIDE_LEFT); }
        else if (id == :reset) { getApp().confirmAction(:reset, currentUtc(), null); }
    }
    function onBack() as Void { getApp().showMain(); }
}

class Reminder2MenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :toggleReminder2) {
            getApp().confirmAction(:toggleReminder2, currentUtc(), null);
        } else if (item.getId() == :reminder2Time) {
            PickerFlow.openTime(:setReminder2, currentUtc());
        }
    }
    function onBack() as Void { getApp().showSettingsMenu(); }
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
    function onSelect(item as WatchUi.MenuItem) as Void { getApp().confirmAction(:demo, currentUtc(), item.getId()); }
    function onBack() as Void { getApp().showMainMenu(); }
}
