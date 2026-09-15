import Toybox.Application.Storage;
import Toybox.Lang;

import Toybox.WatchUi;

(:debug)
function openOptionalMenu(id) as Lang.Boolean {
    if (id != :demo) { return false; }
    WatchUi.pushView(Menus.demoMenu(), new DemoMenuDelegate(), WatchUi.SLIDE_LEFT);
    return true;
}

(:debug)
function optionalActionMessage(action as Lang.Symbol, fallback as Lang.String) as Lang.String {
    return action == :demo ? Ui.s(Rez.Strings.DemoSeedQuestion) : fallback;
}

(:debug)
function optionalSeedState(action as Lang.Symbol, data, nowUtc as Lang.Number) as Lang.Dictionary? {
    return action == :demo ? demoState(data as Lang.Symbol, nowUtc) : null;
}

(:debug)
function isFreshOptionalSeed(action as Lang.Symbol, data) as Lang.Boolean {
    return action == :demo && data == :fresh;
}

(:debug, :background)
function reportOptionalServiceMemory() as Void {
    var stats = Toybox.System.getSystemStats();
    Toybox.System.println("RING_TRACKER_BACKGROUND_MEMORY=" + stats.usedMemory + "/" + stats.totalMemory);
}

(:debug)
function demoState(scenario as Lang.Symbol, nowUtc as Lang.Number) as Lang.Dictionary {
    Storage.setValue("debugNowUtc", nowUtc);
    var state = ScheduleModel.defaultState();
    if (scenario == :fresh) { return state; }
    state[:setupStep] = 3;
    var regimen = state[:regimen] as Lang.Dictionary;
    var insertion = nowUtc - (4 * CalendarMath.SECONDS_PER_DAY);
    if (scenario == :day5) { insertion = nowUtc - (4 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :beforeRemoval) { insertion = nowUtc - (20 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :overdueRemoval) { insertion = nowUtc - (22 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :overdueLarge) {
        insertion = nowUtc - (33 * CalendarMath.SECONDS_PER_DAY) - (23 * CalendarMath.SECONDS_PER_HOUR);
    }
    else if (scenario == :freeDay3) { insertion = nowUtc - (24 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :freeExceeded) { insertion = nowUtc - (30 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :temp250 || scenario == :temp310) { insertion = nowUtc - (5 * CalendarMath.SECONDS_PER_DAY); }
    else if (scenario == :extended35) {
        regimen[:daysIn] = 35;
        insertion = nowUtc - (29 * CalendarMath.SECONDS_PER_DAY);
    }
    var active = ScheduleModel.insertOrReplace(state, insertion);
    if (scenario == :freeDay3) { ScheduleModel.recordRemoval(active, nowUtc - (3 * CalendarMath.SECONDS_PER_DAY), regimen); }
    else if (scenario == :freeExceeded) { ScheduleModel.recordRemoval(active, nowUtc - (8 * CalendarMath.SECONDS_PER_DAY), regimen); }
    else if (scenario == :temp250) { ScheduleModel.startTemporaryOut(active, nowUtc - (2 * 3600) - (50 * 60)); }
    else if (scenario == :temp310) { ScheduleModel.startTemporaryOut(active, nowUtc - (3 * 3600) - (10 * 60)); }
    return state;
}
