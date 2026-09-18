import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

module PickerValues {
    function clamp(value as Lang.Number, low as Lang.Number, high as Lang.Number) as Lang.Number {
        if (value < low) { return low; }
        if (value > high) { return high; }
        return value;
    }

    function isLeapYear(year as Lang.Number) as Lang.Boolean {
        return (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
    }

    function daysInMonth(year as Lang.Number, month as Lang.Number) as Lang.Number {
        if (month == 2) { return isLeapYear(year) ? 29 : 28; }
        return (month == 4 || month == 6 || month == 9 || month == 11) ? 30 : 31;
    }

    function clampDay(year as Lang.Number, month as Lang.Number, day as Lang.Number) as Lang.Number {
        return clamp(day, 1, daysInMonth(year, month));
    }

    function minuteEntries() as Lang.Array {
        var result = [];
        for (var minute = 0; minute < 60; minute += 1) {
            result.add(minute);
        }
        return result;
    }

    function indexOf(values as Lang.Array, value) as Lang.Number {
        for (var i = 0; i < values.size(); i += 1) {
            if (values[i] == value) { return i; }
        }
        return 0;
    }
}

module PickerFlow {
    function openDate(action as Lang.Symbol, initialUtc as Lang.Number) as Void {
        WatchUi.pushView(new RingDatePicker(action, initialUtc),
            new RingDateDelegate(action, initialUtc), WatchUi.SLIDE_UP);
    }

    function openTime(action as Lang.Symbol, initialUtc as Lang.Number) as Void {
        WatchUi.pushView(new RingTimePicker(action, initialUtc),
            new RingTimeDelegate(action, initialUtc, null), WatchUi.SLIDE_UP);
    }

    function openNumber(action as Lang.Symbol, start as Lang.Number, stop as Lang.Number,
                        initial as Lang.Number, title) as Void {
        WatchUi.pushView(new RingNumberPicker(start, stop, initial, title),
            new RingNumberDelegate(action), WatchUi.SLIDE_UP);
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
        return new WatchUi.Text({:text=>value, :font=>Graphics.FONT_SYSTEM_LARGE,
            :color=>selected ? Ui.PRIMARY : Ui.SECONDARY,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER});
    }
}

class RingNumberPicker extends WatchUi.Picker {
    function initialize(start as Lang.Number, stop as Lang.Number, initial as Lang.Number, title) {
        var titleDrawable = new WatchUi.Text({:text=>title,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM,
            :color=>Ui.PRIMARY, :font=>Graphics.FONT_SYSTEM_XTINY});
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

class RingTimeSelection {
    private var _hour as Lang.Number;
    private var _minute as Lang.Number;
    private var _use24 as Lang.Boolean;

    function initialize(hour as Lang.Number, minute as Lang.Number, use24 as Lang.Boolean) {
        _hour = hour;
        _minute = minute;
        _use24 = use24;
    }

    function setHour24(hour as Lang.Number) as Lang.Boolean {
        if (_hour == hour) { return false; }
        _hour = hour;
        return true;
    }
    function setMinute(minute as Lang.Number) as Lang.Boolean {
        if (_minute == minute) { return false; }
        _minute = minute;
        return true;
    }
    function setHour12(hour as Lang.Number) as Lang.Boolean {
        var value = (hour % 12) + (_hour >= 12 ? 12 : 0);
        if (_hour == value) { return false; }
        _hour = value;
        return true;
    }
    function setPeriod(period as Lang.Number) as Lang.Boolean {
        var value = (_hour % 12) + (period == 1 ? 12 : 0);
        if (_hour == value) { return false; }
        _hour = value;
        return true;
    }
    function title() as Lang.String { return Ui.timeOnly(_hour, _minute, _use24 ? 24 : 12); }
}

class RingTimeTitleDrawable extends WatchUi.Drawable {
    private var _selection as RingTimeSelection;
    function initialize(selection as RingTimeSelection) {
        Drawable.initialize({});
        _selection = selection;
    }
    function draw(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SYSTEM_XTINY,
            _selection.title(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class RingTimeValueFactory extends WatchUi.PickerFactory {
    private var _values as Lang.Array;
    private var _kind as Lang.Symbol;
    private var _selection as RingTimeSelection;
    private var _format as Lang.String;
    private var _font;

    function initialize(values as Lang.Array, kind as Lang.Symbol,
                        selection as RingTimeSelection, format as Lang.String, font) {
        PickerFactory.initialize();
        _values = values;
        _kind = kind;
        _selection = selection;
        _format = format;
        _font = font;
    }

    function getSize() as Lang.Number { return _values.size(); }
    function getValue(index as Lang.Number) { return _values[index]; }
    function getDrawable(index as Lang.Number, selected as Lang.Boolean) as WatchUi.Drawable? {
        var value = _values[index] as Lang.Number;
        var changed = false;
        if (selected) {
            if (_kind == :hour24) { changed = _selection.setHour24(value); }
            else if (_kind == :hour12) { changed = _selection.setHour12(value); }
            else if (_kind == :minute) { changed = _selection.setMinute(value); }
            else { changed = _selection.setPeriod(value); }
        }
        if (changed) { WatchUi.requestUpdate(); }
        var text = value.format(_format);
        if (_kind == :period) { text = Ui.s(value == 0 ? Rez.Strings.Am : Rez.Strings.Pm); }
        return new WatchUi.Text({:text=>text, :font=>_font,
            :color=>selected ? Ui.PRIMARY : Ui.SECONDARY,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER});
    }
}

class RingTimePicker extends WatchUi.Picker {
    private var _selection as RingTimeSelection;

    function initialize(action as Lang.Symbol, initialUtc as Lang.Number) {
        var state = getApp().getState();
        var reminders = state[:reminders] as Lang.Dictionary;
        var f = CalendarMath.localFields(initialUtc);
        if (action == :setReminder) {
            f[:hour] = reminders[:reminder1Hour];
            f[:minute] = reminders[:reminder1Minute];
        } else if (action == :setReminder2) {
            f[:hour] = reminders[:reminder2Hour];
            f[:minute] = reminders[:reminder2Minute];
        }
        var use24 = pickerUses24Hour(reminders);
        _selection = new RingTimeSelection(f[:hour], f[:minute], use24);

        var hours = [];
        if (use24) {
            for (var h24 = 0; h24 < 24; h24 += 1) { hours.add(h24); }
        } else {
            for (var h12 = 1; h12 <= 12; h12 += 1) { hours.add(h12); }
        }
        var minutes = PickerValues.minuteEntries();
        var title = new RingTimeTitleDrawable(_selection);

        if (use24) {
            var pattern24 = new Lang.Array<WatchUi.PickerFactory>[2];
            pattern24[0] = new RingTimeValueFactory(hours, :hour24, _selection,
                "%02d", Graphics.FONT_SYSTEM_LARGE);
            pattern24[1] = new RingTimeValueFactory(minutes, :minute, _selection,
                "%02d", Graphics.FONT_SYSTEM_LARGE);
            var defaults24 = [f[:hour], PickerValues.indexOf(minutes, f[:minute])];
            Picker.initialize({:title=>title, :pattern=>pattern24, :defaults=>defaults24});
        } else {
            var pattern12 = new Lang.Array<WatchUi.PickerFactory>[3];
            pattern12[0] = new RingTimeValueFactory(hours, :hour12, _selection,
                "%d", Graphics.FONT_SYSTEM_LARGE);
            pattern12[1] = new RingTimeValueFactory(minutes, :minute, _selection,
                "%02d", Graphics.FONT_SYSTEM_LARGE);
            pattern12[2] = new RingTimeValueFactory([0, 1], :period, _selection,
                "%d", Graphics.FONT_SYSTEM_SMALL);
            var initial12 = f[:hour] % 12;
            if (initial12 == 0) { initial12 = 12; }
            var defaults12 = [initial12 - 1,
                PickerValues.indexOf(minutes, f[:minute]), f[:hour] >= 12 ? 1 : 0];
            Picker.initialize({:title=>title, :pattern=>pattern12, :defaults=>defaults12});
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        Picker.onUpdate(dc);
    }
}

class RingTimeDelegate extends WatchUi.PickerDelegate {
    private var _action as Lang.Symbol;
    private var _initialUtc as Lang.Number;
    private var _dateFields as Lang.Dictionary?;
    function initialize(action as Lang.Symbol, initialUtc as Lang.Number,
                        dateFields as Lang.Dictionary?) {
        PickerDelegate.initialize();
        _action = action;
        _initialUtc = initialUtc;
        _dateFields = dateFields;
    }
    function onCancel() as Lang.Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onAccept(values as Lang.Array) as Lang.Boolean {
        var hour = values[0] as Lang.Number;
        var minute = values[1] as Lang.Number;
        if (values.size() == 3) {
            hour = (hour % 12) + ((values[2] as Lang.Number) == 1 ? 12 : 0);
        }
        if (_action == :setReminder || _action == :setReminder2) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            getApp().confirmAction(_action, currentUtc(), [hour, minute]);
            return true;
        }
        var fields = _dateFields == null
            ? CalendarMath.localFields(_initialUtc) : _dateFields as Lang.Dictionary;
        fields[:hour] = hour;
        fields[:minute] = minute;
        fields[:second] = 0;
        var resolved = CalendarMath.wallToUtcUsingDevice(fields);
        if (resolved == null) {
            getApp().showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.InvalidDate)]);
            return true;
        }
        var atUtc = resolved[:utc];
        if ((_action == :insert || _action == :adjustInsertion || _action == :adjustRemoval)
            && atUtc > currentUtc() + 60) {
            getApp().showInfo(Rez.Strings.AdjustDates, [Ui.s(Rez.Strings.FutureEvent)]);
            return true;
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

class RingDateSelection {
    private var _year as Lang.Number;
    private var _month as Lang.Number;
    private var _day as Lang.Number;

    function initialize(year as Lang.Number, month as Lang.Number, day as Lang.Number) {
        _year = year;
        _month = month;
        _day = PickerValues.clampDay(year, month, day);
    }
    function setDay(day as Lang.Number) as Lang.Boolean {
        var value = PickerValues.clampDay(_year, _month, day);
        if (_day == value) { return false; }
        _day = value;
        return true;
    }
    function setMonth(month as Lang.Number) as Lang.Boolean {
        var oldMonth = _month;
        var oldDay = _day;
        _month = month;
        _day = PickerValues.clampDay(_year, _month, _day);
        return oldMonth != _month || oldDay != _day;
    }
    function setYear(year as Lang.Number) as Lang.Boolean {
        var oldYear = _year;
        var oldDay = _day;
        _year = year;
        _day = PickerValues.clampDay(_year, _month, _day);
        return oldYear != _year || oldDay != _day;
    }
    function title() as Lang.String {
        var noon = CalendarMath.utc(_year, _month, _day, 12, 0, 0);
        var info = Gregorian.utcInfo(new Time.Moment(noon), Time.FORMAT_SHORT);
        return Ui.weekdayName(info.day_of_week) + " " + _day.toString() + " "
            + Ui.monthName(_month) + " " + _year.toString();
    }
}

class RingDateTitleDrawable extends WatchUi.Drawable {
    private var _selection as RingDateSelection;
    function initialize(selection as RingDateSelection) {
        Drawable.initialize({});
        _selection = selection;
    }
    function draw(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SYSTEM_XTINY,
            _selection.title(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class RingDateValueFactory extends WatchUi.PickerFactory {
    private var _start as Lang.Number;
    private var _stop as Lang.Number;
    private var _kind as Lang.Symbol;
    private var _selection as RingDateSelection;

    function initialize(start as Lang.Number, stop as Lang.Number, kind as Lang.Symbol,
                        selection as RingDateSelection) {
        PickerFactory.initialize();
        _start = start;
        _stop = stop;
        _kind = kind;
        _selection = selection;
    }
    function getSize() as Lang.Number { return _stop - _start + 1; }
    function getValue(index as Lang.Number) { return _start + index; }
    function getDrawable(index as Lang.Number, selected as Lang.Boolean) as WatchUi.Drawable? {
        var value = _start + index;
        var changed = false;
        if (selected) {
            if (_kind == :day) { changed = _selection.setDay(value); }
            else if (_kind == :month) { changed = _selection.setMonth(value); }
            else { changed = _selection.setYear(value); }
        }
        if (changed) { WatchUi.requestUpdate(); }
        var text = _kind == :month ? Ui.monthName(value) : value.toString();
        var font = _kind == :day ? Graphics.FONT_SYSTEM_LARGE : Graphics.FONT_SYSTEM_TINY;
        return new WatchUi.Text({:text=>text, :font=>font,
            :color=>selected ? Ui.PRIMARY : Ui.SECONDARY,
            :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER});
    }
}

class RingDatePicker extends WatchUi.Picker {
    private var _selection as RingDateSelection;

    function initialize(action as Lang.Symbol, initialUtc as Lang.Number) {
        var f = CalendarMath.localFields(initialUtc);
        var currentYear = CalendarMath.localFields(currentUtc())[:year];
        var startYear = currentYear - 2;
        var stopYear = currentYear + 2;
        var selectedYear = PickerValues.clamp(f[:year], startYear, stopYear);
        var selectedDay = PickerValues.clampDay(selectedYear, f[:month], f[:day]);
        _selection = new RingDateSelection(selectedYear, f[:month], selectedDay);
        var title = new RingDateTitleDrawable(_selection);
        var pattern = new Lang.Array<WatchUi.PickerFactory>[3];
        pattern[0] = new RingDateValueFactory(1, 31, :day, _selection);
        pattern[1] = new RingDateValueFactory(1, 12, :month, _selection);
        pattern[2] = new RingDateValueFactory(startYear, stopYear, :year, _selection);
        var defaults = [selectedDay - 1, f[:month] - 1, selectedYear - startYear];
        Picker.initialize({:title=>title, :pattern=>pattern, :defaults=>defaults});
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Ui.clear(dc);
        Picker.onUpdate(dc);
    }
}

class RingDateDelegate extends WatchUi.PickerDelegate {
    private var _action as Lang.Symbol;
    private var _initialUtc as Lang.Number;
    function initialize(action as Lang.Symbol, initialUtc as Lang.Number) {
        PickerDelegate.initialize();
        _action = action;
        _initialUtc = initialUtc;
    }
    function onCancel() as Lang.Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onAccept(values as Lang.Array) as Lang.Boolean {
        var year = values[2] as Lang.Number;
        var month = values[1] as Lang.Number;
        var day = PickerValues.clampDay(year, month, values[0] as Lang.Number);
        var original = CalendarMath.localFields(_initialUtc);
        var fields = {:year=>year, :month=>month, :day=>day,
            :hour=>original[:hour], :minute=>original[:minute], :second=>0};
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.pushView(new RingTimePicker(_action, _initialUtc),
            new RingTimeDelegate(_action, _initialUtc, fields), WatchUi.SLIDE_LEFT);
        return true;
    }
}
