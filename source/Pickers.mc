import Toybox.Graphics;
import Toybox.Lang;
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
    function initialize(start as Lang.Number, stop as Lang.Number, format as Lang.String) {
        PickerFactory.initialize();
        _start = start;
        _stop = stop;
        _format = format;
    }
    function getSize() as Lang.Number { return _stop - _start + 1; }
    function getValue(index as Lang.Number) { return _start + index; }
    function getDrawable(index as Lang.Number, selected as Lang.Boolean) as WatchUi.Drawable? {
        var value = (_start + index).format(_format);
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

class RingNumberPicker extends WatchUi.Picker {
    function initialize(start as Lang.Number, stop as Lang.Number, initial as Lang.Number, title) {
        var titleDrawable = new WatchUi.Text({:text=>title, :locX=>WatchUi.LAYOUT_HALIGN_CENTER,
                                               :locY=>WatchUi.LAYOUT_VALIGN_BOTTOM, :color=>Ui.PRIMARY,
                                               :font=>Graphics.FONT_SYSTEM_XTINY});
        var pattern = new Lang.Array<WatchUi.PickerFactory or WatchUi.Text>[1];
        pattern[0] = new RingNumberFactory(start, stop, "%d");
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
        var separator = new WatchUi.Text({:text=>Rez.Strings.DateSeparator, :font=>Graphics.FONT_SYSTEM_SMALL,
                                          :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER, :color=>Ui.SECONDARY});
        var year = CalendarMath.localFields(currentUtc())[:year];
        var pattern = new Lang.Array<WatchUi.PickerFactory or WatchUi.Text>[5];
        pattern[0] = new RingNumberFactory(year - 2, year + 2, "%04d");
        pattern[1] = separator;
        pattern[2] = new RingNumberFactory(1, 12, "%02d");
        pattern[3] = separator;
        pattern[4] = new RingNumberFactory(1, 31, "%02d");
        var defaults = new Lang.Array<Lang.Number>[5];
        defaults[0] = f[:year] - (year - 2);
        defaults[2] = f[:month] - 1;
        defaults[4] = f[:day] - 1;
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
        var fields = {:year=>values[0], :month=>values[2], :day=>values[4], :hour=>original[:hour], :minute=>original[:minute], :second=>0};
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
        var separator = new WatchUi.Text({:text=>Rez.Strings.TimeSeparator, :font=>Graphics.FONT_SYSTEM_LARGE,
                                          :locX=>WatchUi.LAYOUT_HALIGN_CENTER, :locY=>WatchUi.LAYOUT_VALIGN_CENTER, :color=>Ui.SECONDARY});
        if (use24) {
            var pattern24 = new Lang.Array<WatchUi.PickerFactory or WatchUi.Text>[3];
            pattern24[0] = new RingNumberFactory(0, 23, "%02d"); pattern24[1] = separator;
            pattern24[2] = new RingNumberFactory(0, 59, "%02d");
            var defaults24 = new Lang.Array<Lang.Number>[3]; defaults24[0] = f[:hour]; defaults24[2] = f[:minute];
            Picker.initialize({:title=>title, :pattern=>pattern24, :defaults=>defaults24});
        } else {
            var hour = f[:hour] % 12; if (hour == 0) { hour = 12; }
            var pattern12 = new Lang.Array<WatchUi.PickerFactory or WatchUi.Text>[4];
            pattern12[0] = new RingNumberFactory(1, 12, "%d"); pattern12[1] = separator;
            pattern12[2] = new RingNumberFactory(0, 59, "%02d");
            pattern12[3] = new RingWordFactory([Ui.s(Rez.Strings.Am), Ui.s(Rez.Strings.Pm)]);
            var defaults12 = new Lang.Array<Lang.Number>[4];
            defaults12[0] = hour - 1; defaults12[2] = f[:minute]; defaults12[3] = f[:hour] < 12 ? 0 : 1;
            Picker.initialize({:title=>title, :pattern=>pattern12, :defaults=>defaults12});
        }
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
        var hour = values[0] as Lang.Number;
        var minute = values[2] as Lang.Number;
        if (values.size() == 4) {
            if (hour == 12) { hour = 0; }
            if ((values[3] as Lang.String).equals(Ui.s(Rez.Strings.Pm))) { hour += 12; }
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        if (_action == :setReminder) {
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
        getApp().confirmAction(_action, atUtc, resolved[:adjusted]);
        return true;
    }
}
