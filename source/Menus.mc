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
        var menu = new WatchUi.Menu2({:title => Rez.Strings.MenuTitle});
        var active = state[:active] as Lang.Dictionary?;
        if (active == null) {
            menu.addItem(item(Rez.Strings.RingInsertedNow, Rez.Strings.NoCycleReason, :insertNow));
        } else {
            var replace = active[:removalUtc] == null;
            menu.addItem(item(replace ? Rez.Strings.RingReplacedNow : Rez.Strings.RingInsertedNow, null, :insertNow));
            if (active[:removalUtc] == null) {
                menu.addItem(item(Rez.Strings.RingRemovedNow, null, :removeNow));
                var open = ScheduleModel.tempOpen(active);
                menu.addItem(item(open == null ? Rez.Strings.RingOutTemporarily : Rez.Strings.RingBackIn, null,
                                  open == null ? :tempOut : :backIn));
            }
            menu.addItem(item(Rez.Strings.AdjustDates, null, :adjust));
        }
        menu.addItem(item(Rez.Strings.Settings, null, :settings));
        menu.addItem(item(Rez.Strings.History, null, :history));
        menu.addItem(item(Rez.Strings.AboutDisclaimer, null, :about));
        addDebugMenuItem(menu);
        return menu;
    }

    function adjustMenu(state as Lang.Dictionary) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => Rez.Strings.AdjustTitle});
        var active = state[:active] as Lang.Dictionary;
        menu.addItem(item(Rez.Strings.Insertion, null, :adjustInsertion));
        if (active[:removalUtc] != null) { menu.addItem(item(Rez.Strings.Removal, null, :adjustRemoval)); }
        menu.addItem(item(Rez.Strings.PlannedNextAction, active[:plannedOverrideUtc] == null ? null : Rez.Strings.AdjustedBadge, :adjustPlanned));
        return menu;
    }

    function settingsMenu(state as Lang.Dictionary) as WatchUi.Menu2 {
        var regimen = state[:regimen] as Lang.Dictionary;
        var reminders = state[:reminders] as Lang.Dictionary;
        var menu = new WatchUi.Menu2({:title => Rez.Strings.Settings, :footer => Rez.Strings.ForegroundOnlyFooter});
        menu.addItem(item(Rez.Strings.ReminderTime, Ui.timeOnly(reminders[:localHour], reminders[:localMinute], reminders[:clockFormat]), :reminderTime));
        menu.addItem(item(Rez.Strings.DaysRingIn, regimen[:daysIn].toString(), :daysIn));
        menu.addItem(item(Rez.Strings.DaysRingFree, regimen[:daysOut] == 0 ? Rez.Strings.ReplaceImmediately : regimen[:daysOut].toString(), :daysOut));
        menu.addItem(item(Rez.Strings.RepeatOverdue, Ui.fmt(Rez.Strings.HoursShortTemplate, [reminders[:overdueRepeatHours]]), :repeat));
        menu.addItem(item(Rez.Strings.Vibration, reminders[:vibrationEnabled] ? Rez.Strings.On : Rez.Strings.Off, :vibration));
        menu.addItem(item(Rez.Strings.Sound, reminders[:soundEnabled] ? Rez.Strings.On : Rez.Strings.Off, :sound));
        var clock = reminders[:clockFormat] == 12 ? Rez.Strings.Clock12Hour : (reminders[:clockFormat] == 24 ? Rez.Strings.Clock24Hour : Rez.Strings.ClockSystem);
        menu.addItem(item(Rez.Strings.Clock, clock, :clock));
        menu.addItem(item(Rez.Strings.ResetApp, null, :reset));
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

    function historyMenu(state as Lang.Dictionary) as WatchUi.Menu2 {
        var history = state[:history] as Lang.Array<Lang.Dictionary>;
        var menu = new WatchUi.Menu2({:title => Rez.Strings.History, :footer => Ui.fmt(Rez.Strings.HistoryCountTemplate, [history.size()])});
        if (history.size() == 0) { menu.addItem(item(Rez.Strings.HistoryEmpty, null, :empty)); }
        for (var i = history.size() - 1; i >= 0; i -= 1) {
            var cycle = history[i];
            var end = cycle[:nextInsertionUtc] == null ? cycle[:removalUtc] : cycle[:nextInsertionUtc];
            var label = Ui.shortDate(cycle[:insertionUtc]) + Ui.s(Rez.Strings.RangeSeparator)
                + (end == null ? Ui.s(Rez.Strings.NotRecorded) : Ui.shortDate(end));
            var summary = cycle[:temporaryOutSummary] as Lang.Dictionary;
            var sub = Ui.fmt(summary[:shortIntervalCount] > 0
                ? Rez.Strings.HistoryPlanSummaryTemplate : Rez.Strings.HistoryPlanTemplate,
                [cycle[:regimenDaysIn], cycle[:regimenDaysOut]]);
            menu.addItem(item(label, sub, i));
        }
        if (history.size() > 0) { menu.addItem(item(Rez.Strings.ClearHistory, null, :clear)); }
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
        menu.addItem(item(Rez.Strings.DemoDay5, null, :day5));
        menu.addItem(item(Rez.Strings.DemoBeforeRemoval, null, :beforeRemoval));
        menu.addItem(item(Rez.Strings.DemoOverdueRemoval, null, :overdueRemoval));
        menu.addItem(item(Rez.Strings.DemoFreeDay3, null, :freeDay3));
        menu.addItem(item(Rez.Strings.DemoFreeExceeded, null, :freeExceeded));
        menu.addItem(item(Rez.Strings.DemoTemp250, null, :temp250));
        menu.addItem(item(Rez.Strings.DemoTemp310, null, :temp310));
        menu.addItem(item(Rez.Strings.DemoExtended35, null, :extended35));
        return menu;
    }
}

class InsertionMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :insertNow) { getApp().confirmAction(:insert, currentUtc(), null); }
        else if (item.getId() == :chooseInsert) { PickerFlow.openDate(:insert, currentUtc()); }
    }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var app = getApp();
        if (id == :insertNow) { app.confirmAction(app.getState()[:active] == null ? :insert : :replace, currentUtc(), null); }
        else if (id == :removeNow) { app.confirmAction(:remove, currentUtc(), null); }
        else if (id == :tempOut) { app.confirmAction(:tempOut, currentUtc(), null); }
        else if (id == :backIn) { app.confirmAction(:backIn, currentUtc(), null); }
        else if (id == :adjust) { WatchUi.pushView(Menus.adjustMenu(app.getState()), new AdjustMenuDelegate(), WatchUi.SLIDE_LEFT); }
        else if (id == :settings) { WatchUi.pushView(Menus.settingsMenu(app.getState()), new SettingsMenuDelegate(), WatchUi.SLIDE_LEFT); }
        else if (id == :history) { WatchUi.pushView(Menus.historyMenu(app.getState()), new HistoryMenuDelegate(), WatchUi.SLIDE_LEFT); }
        else if (id == :about) { app.showAbout(); }
        else { openOptionalMenu(id); }
    }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

class AdjustMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var state = getApp().getState();
        var active = state[:active] as Lang.Dictionary;
        var id = item.getId() as Lang.Symbol;
        var start = active[:insertionUtc];
        if (id == :adjustRemoval) { start = active[:removalUtc]; }
        else if (id == :adjustPlanned) { start = ScheduleModel.deriveStatus(currentUtc(), active, state[:regimen] as Lang.Dictionary)[:nextActionUtc]; }
        PickerFlow.openDate(id, start);
    }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        var state = getApp().getState();
        var regimen = state[:regimen] as Lang.Dictionary;
        if (id == :reminderTime) { PickerFlow.openTime(:setReminder, currentUtc()); }
        else if (id == :daysIn) { PickerFlow.openNumber(:setDaysIn, 21, 35, regimen[:daysIn], Rez.Strings.DaysRingIn); }
        else if (id == :daysOut) { PickerFlow.openNumber(:setDaysOut, 0, 7, regimen[:daysOut], Rez.Strings.DaysRingFree); }
        else if (id == :repeat) { WatchUi.pushView(Menus.repeatMenu(), new ValueMenuDelegate(:setRepeat), WatchUi.SLIDE_LEFT); }
        else if (id == :vibration) { getApp().confirmAction(:toggleVibration, currentUtc(), null); }
        else if (id == :sound) { getApp().confirmAction(:toggleSound, currentUtc(), null); }
        else if (id == :clock) { WatchUi.pushView(Menus.clockMenu(), new ValueMenuDelegate(:setClock), WatchUi.SLIDE_LEFT); }
        else if (id == :reset) { getApp().confirmAction(:reset, currentUtc(), null); }
    }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

class ValueMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _action as Lang.Symbol;
    function initialize(action as Lang.Symbol) { Menu2InputDelegate.initialize(); _action = action; }
    function onSelect(item as WatchUi.MenuItem) as Void { getApp().confirmAction(_action, currentUtc(), item.getId()); }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

class HistoryMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Lang.Number) { WatchUi.pushView(new CycleDetailView(id), new PopDelegate(), WatchUi.SLIDE_LEFT); }
        else if (id == :clear) { getApp().confirmAction(:clearHistory, currentUtc(), null); }
    }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}

(:debug)
class DemoMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item as WatchUi.MenuItem) as Void { getApp().confirmAction(:demo, currentUtc(), item.getId()); }
    function onBack() as Void { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
}
