import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

module PickerFlow {
    function openDate(action as Lang.Symbol, initialUtc as Lang.Number) as Void {
        WatchUi.pushView(new RingDatePicker(action, initialUtc), new RingDateDelegate(action, initialUtc), WatchUi.SLIDE_UP);
    }

    function openTime(action as Lang.Symbol, initialUtc as Lang.Number) as Void {
        WatchUi.pushView(new RingTimePicker(action, initialUtc), new RingTimeDelegate(action, initialUtc, null), WatchUi.SLIDE_UP);
    }

    function openNumber(action as Lang.Symbol, start as Lang.Number, stop as Lang.Number,
                        initial as Lang.Number, title) as Void {
        WatchUi.pushView(new RingNumberPicker(start, stop, initial, title), new RingNumberDelegate(action), WatchUi.SLIDE_UP);
    }
}

class RingNumberFactory extends WatchUi.PickerFactory {
    private var _start as Lang.Number;
    private var _stop as Lang.Number;
    private var _format as Lang.String;
    private var _prefix as Lang.String;
    function initialize(start as Lang.Number, stop as Lang.Number, format as Lang.String, prefix as Lang.String) {
        PickerFactory.initialize();
        _start = start;
        _stop = stop;
        _format = format;
        _prefix = prefix;
    }
    function getSize() as Lang.Number { return _stop - _start + 1; }
    function getValue(index as Lang.Number) { return _start + index; }
    function getDrawable(index as Lang.Number, selected as Lang.Boolean) as WatchUi.Drawable? {
        var value = _prefix + (_start + index).format(_format);
        return new WatchUi.Text({:text=>value, :font=>Graphics.FONT_SYSTEM_LARGE, :color=>selected ? Ui.PRIMARY : Ui.SECONDARY,
                                 :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER});
    }
}

class RingWordFactory extends WatchUi.PickerFactory {
    private var _values as Lang.Array;
    function initialize(values as Lang.Array) { PickerFactory.initialize(); _values = values; }
    function getSize() as Lang.Number { return _values.size(); }
    function getValue(index as Lang.Number) { return _values[index]; }
    function getDrawable(index as Lang.Number, selected as Lang.Boolean) as WatchUi.Drawable? {
        return new WatchUi.Text({:text=>_values[index], :font=>Graphics.FONT_SYSTEM_SMALL, :color=>selected ? Ui.PRIMARY : Ui.SECONDARY,
                                 :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER});
    }
}

class RingDateFactory extends WatchUi.PickerFactory {
    private var _startUtc as Lang.Number;
    private var _size as Lang.Number;
    function initialize(startYear as Lang.Number, stopYear as Lang.Number) {
        PickerFactory.initialize();
        _startUtc = CalendarMath.utc(startYear, 1, 1, 12, 0, 0);
        var stopUtc = CalendarMath.utc(stopYear, 12, 31, 12, 0, 0);
        _size = ((stopUtc - _startUtc) / CalendarMath.SECONDS_PER_DAY) + 1;
    }
    function getSize() as Lang.Number { return _size; }
    function getValue(index as Lang.Number) { return _startUtc + (index * CalendarMath.SECONDS_PER_DAY); }
    function getDrawable(index as Lang.Number, selected as Lang.Boolean) as WatchUi.Drawable? {
        var value = getValue(index) as Lang.Number;
        var info = Gregorian.utcInfo(new Time.Moment(value), Time.FORMAT_SHORT);
        var text = Ui.weekdayName(info.day_of_week) + " " + info.day.toString()
            + " " + Ui.monthName(info.month);
        return new WatchUi.Text({:text=>text, :font=>Graphics.FONT_SYSTEM_XTINY,
            :color=>selected ? Ui.PRIMARY : Ui.SECONDARY,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER});
    }
}

class RingTimeFactory extends WatchUi.PickerFactory {
    private var _clockFormat as Lang.Number;
    function initialize(use24 as Lang.Boolean) {
        PickerFactory.initialize();
        _clockFormat = use24 ? 24 : 12;
    }
    function getSize() as Lang.Number { return 24 * 60; }
    function getValue(index as Lang.Number) { return index; }
    function getDrawable(index as Lang.Number, selected as Lang.Boolean) as WatchUi.Drawable? {
        var text = Ui.timeOnly(index / 60, index % 60, _clockFormat);
        return new WatchUi.Text({:text=>text, :font=>Graphics.FONT_SYSTEM_TINY,
            :color=>selected ? Ui.PRIMARY : Ui.SECONDARY,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER});
    }
}

class RingNumberPicker extends WatchUi.Picker {
    function initialize(start as Lang.Number, stop as Lang.Number, initial as Lang.Number, title) {
        var titleDrawable = new WatchUi.Text({:text=>title, :locX=>WatchUi.LAYOUT_HALIGN_CENTER,
                                               :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Ui.PRIMARY,
                                               :font=>Graphics.FONT_SYSTEM_XTINY});
        var pattern = new Lang.Array<WatchUi.PickerFactory or WatchUi.Text>[1];
        pattern[0] = new RingNumberFactory(start, stop, "%d", "");
        var defaults = new Lang.Array<Lang.Number>[1];
        defaults[0] = initial - start;
        Picker.initialize({:title=>titleDrawable, :pattern=>pattern, :defaults=>defaults});
    }
    function onUpdate(dc as Graphics.Dc) as Void { Ui.clear(dc); Picker.onUpdate(dc); }
}

class RingNumberDelegate extends WatchUi.PickerDelegate {
    private var _action as Lang.Symbol;
    function initialize(action as Lang.Symbol) { PickerDelegate.initialize(); _action = action; }
    function onCancel() as Lang.Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onAccept(values as Lang.Array) as Lang.Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        getApp().confirmAction(_action, currentUtc(), values[0]);
        return true;
    }
}

class RingDatePicker extends WatchUi.Picker {
    function initialize(action as Lang.Symbol, initialUtc as Lang.Number) {
        var f = CalendarMath.localFields(initialUtc);
        var titleId = action == :adjustRemoval ? Rez.Strings.RemovalDate : (action == :adjustPlanned ? Rez.Strings.PlannedDate : Rez.Strings.InsertionDate);
        var title = new WatchUi.Text({:text=>titleId, :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM,
                                      :font=>Graphics.FONT_SYSTEM_XTINY, :color=>Ui.PRIMARY});
        var year = CalendarMath.localFields(currentUtc())[:year];
        var startYear = year - 2;
        var startUtc = CalendarMath.utc(startYear, 1, 1, 12, 0, 0);
        var selectedUtc = CalendarMath.utc(f[:year], f[:month], f[:day], 12, 0, 0);
        var pattern = new Lang.Array<WatchUi.PickerFactory>[1];
        pattern[0] = new RingDateFactory(startYear, year + 2);
        var defaults = new Lang.Array<Lang.Number>[1];
        defaults[0] = (selectedUtc - startUtc) / CalendarMath.SECONDS_PER_DAY;
        Picker.initialize({:title=>title, :pattern=>pattern, :defaults=>defaults});
    }
    function onUpdate(dc as Graphics.Dc) as Void { Ui.clear(dc); Picker.onUpdate(dc); }
}

class RingDateDelegate extends WatchUi.PickerDelegate {
    private var _action as Lang.Symbol;
    private var _initialUtc as Lang.Number;
    function initialize(action as Lang.Symbol, initialUtc as Lang.Number) {
        PickerDelegate.initialize(); _action = action; _initialUtc = initialUtc;
    }
    function onCancel() as Lang.Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onAccept(values as Lang.Array) as Lang.Boolean {
        var original = CalendarMath.localFields(_initialUtc);
        var selected = Gregorian.utcInfo(new Time.Moment(values[0]), Time.FORMAT_SHORT);
        var fields = {:year=>selected.year, :month=>selected.month, :day=>selected.day,
            :hour=>original[:hour], :minute=>original[:minute], :second=>0};
        if (!CalendarMath.validWall(fields)) {
            getApp().showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidDate)]);
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.pushView(new RingTimePicker(_action, _initialUtc), new RingTimeDelegate(_action, _initialUtc, fields), WatchUi.SLIDE_LEFT);
        return true;
    }
}

class RingTimePicker extends WatchUi.Picker {
    function initialize(action as Lang.Symbol, initialUtc as Lang.Number) {
        var state = getApp().getState();
        var reminders = state[:reminders] as Lang.Dictionary;
        var f = CalendarMath.localFields(initialUtc);
        if (action == :setReminder) { f[:hour] = reminders[:localHour]; f[:minute] = reminders[:localMinute]; }
        var use24 = reminders[:clockFormat] == 24 || (reminders[:clockFormat] == 0 && Toybox.System.getDeviceSettings().is24Hour);
        var title = new WatchUi.Text({:text=>Rez.Strings.TimeTitle, :locX=>WatchUi.LAYOUT_HALIGN_CENTER,
                                      :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :font=>Graphics.FONT_SYSTEM_XTINY, :color=>Ui.PRIMARY});
        var pattern = new Lang.Array<WatchUi.PickerFactory>[1];
        pattern[0] = new RingTimeFactory(use24);
        var defaults = new Lang.Array<Lang.Number>[1];
        defaults[0] = (f[:hour] * 60) + f[:minute];
        Picker.initialize({:title=>title, :pattern=>pattern, :defaults=>defaults});
    }
    function onUpdate(dc as Graphics.Dc) as Void { Ui.clear(dc); Picker.onUpdate(dc); }
}

class RingTimeDelegate extends WatchUi.PickerDelegate {
    private var _action as Lang.Symbol;
    private var _initialUtc as Lang.Number;
    private var _dateFields as Lang.Dictionary?;
    function initialize(action as Lang.Symbol, initialUtc as Lang.Number, dateFields as Lang.Dictionary?) {
        PickerDelegate.initialize(); _action = action; _initialUtc = initialUtc; _dateFields = dateFields;
    }
    function onCancel() as Lang.Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onAccept(values as Lang.Array) as Lang.Boolean {
        var minuteOfDay = values[0] as Lang.Number;
        var hour = minuteOfDay / 60;
        var minute = minuteOfDay % 60;
        if (_action == :setReminder) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            getApp().confirmAction(:setReminder, currentUtc(), [hour, minute]);
            return true;
        }
        var fields = _dateFields == null ? CalendarMath.localFields(_initialUtc) : _dateFields as Lang.Dictionary;
        fields[:hour] = hour; fields[:minute] = minute; fields[:second] = 0;
        var resolved = CalendarMath.wallToUtcUsingDevice(fields);
        if (resolved == null) { getApp().showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidDate)]); return true; }
        var atUtc = resolved[:utc];
        if ((_action == :insert || _action == :adjustInsertion || _action == :adjustRemoval) && atUtc > currentUtc() + 60) {
            getApp().showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.FutureEvent)]); return true;
        }
        var active = getApp().getState()[:active] as Lang.Dictionary?;
        if (_action == :adjustInsertion && active != null
            && !ScheduleModel.validInsertionEdit(active, atUtc)) {
            getApp().showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidEventOrder)]);
            return true;
        }
        if (_action == :adjustRemoval && active != null
            && !ScheduleModel.validRemovalEdit(active, atUtc)) {
            getApp().showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidEventOrder)]);
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        getApp().confirmAction(_action, atUtc, resolved[:adjusted]);
        return true;
    }
}
