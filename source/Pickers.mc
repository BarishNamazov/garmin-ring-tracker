import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
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

    function columnWidth(screenWidth as Lang.Number, columns as Lang.Number) as Lang.Number {
        var ratio = columns == 2 ? 0.35 : 0.28;
        return Math.round(screenWidth * ratio).toNumber();
    }

    function separatorWidth(screenWidth as Lang.Number) as Lang.Number {
        return Math.round(screenWidth * 0.04).toNumber();
    }

    function titleHeight(screenHeight as Lang.Number) as Lang.Number {
        return Math.round(screenHeight * 0.10).toNumber();
    }

    function arrowHeight(screenHeight as Lang.Number) as Lang.Number {
        return Math.round(screenHeight * 0.10).toNumber();
    }
}

module PickerScreen {
    function xForColumn(width as Lang.Number, columns as Lang.Number,
                        column as Lang.Number) as Lang.Number {
        if (columns == 1) { return width / 2; }
        if (columns == 2) {
            return Math.round(width * (column == 0 ? 0.325 : 0.675)).toNumber();
        }
        return Math.round(width * (0.25 + (column * 0.25))).toNumber();
    }

    function focusForX(width as Lang.Number, columns as Lang.Number,
                       x as Lang.Number) as Lang.Number {
        if (columns == 1) { return 0; }
        if (columns == 2) { return x < width / 2 ? 0 : 1; }
        if (x < (width * 3) / 8) { return 0; }
        if (x < (width * 5) / 8) { return 1; }
        return 2;
    }

    // Page behaviors map to DOWN/UP buttons, not numeric order.
    function buttonDelta(nextPage as Lang.Boolean) as Lang.Number {
        return nextPage ? -1 : 1;
    }

    // Only the value and arrow bands are interactive. A title/background tap
    // must never advance a column or finish editing.
    function tapTarget(width as Lang.Number, height as Lang.Number,
                       columns as Lang.Number, x as Lang.Number, y as Lang.Number) as Lang.Array? {
        if (y < (height * 22) / 100 || y > (height * 78) / 100) { return null; }
        var column = focusForX(width, columns, x);
        if ((x - xForColumn(width, columns, column)).abs()
            > PickerValues.columnWidth(width, columns) / 2) { return null; }
        var delta = y < (height * 42) / 100 ? 1
            : (y > (height * 58) / 100 ? -1 : 0);
        return [column, delta];
    }

    function drawArrow(dc as Graphics.Dc, x as Lang.Number, centerY as Lang.Number,
                       pointsDown as Lang.Boolean) as Void {
        var height = PickerValues.arrowHeight(dc.getHeight());
        var halfHeight = height / 2;
        var halfWidth = (height * 3) / 5;
        dc.setColor(Ui.PRIMARY, Graphics.COLOR_TRANSPARENT);
        if (pointsDown) {
            dc.fillPolygon([[x - halfWidth, centerY - halfHeight],
                [x + halfWidth, centerY - halfHeight], [x, centerY + halfHeight]]);
        } else {
            dc.fillPolygon([[x, centerY - halfHeight],
                [x + halfWidth, centerY + halfHeight], [x - halfWidth, centerY + halfHeight]]);
        }
    }

    function drawFrame(dc as Graphics.Dc, title as Lang.String, columns as Lang.Array,
                       fonts as Lang.Array, focus as Lang.Number) as Void {
        Ui.clear(dc);
        var count = columns.size();
        var width = dc.getWidth();
        var height = dc.getHeight();
        var valueY = height / 2;
        Ui.centered(dc, PickerValues.titleHeight(height), title,
            Graphics.FONT_SYSTEM_XTINY, Ui.PRIMARY, Math.round(width * 0.84).toNumber());
        for (var i = 0; i < count; i += 1) {
            var x = xForColumn(width, count, i);
            var shown = Ui.ellipsize(dc, columns[i] as Lang.String, fonts[i],
                PickerValues.columnWidth(width, count));
            dc.setColor(i == focus ? Ui.PRIMARY : Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, valueY, fonts[i], shown,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        var arrowX = xForColumn(width, count, focus);
        var offset = Math.round(height * 0.18).toNumber();
        drawArrow(dc, arrowX, valueY - offset, false);
        drawArrow(dc, arrowX, valueY + offset, true);
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

class RingNumberPicker extends WatchUi.View {
    private var _start as Lang.Number;
    private var _stop as Lang.Number;
    private var _value as Lang.Number;
    private var _title;

    function initialize(start as Lang.Number, stop as Lang.Number, initial as Lang.Number, title) {
        View.initialize();
        _start = start;
        _stop = stop;
        _value = PickerValues.clamp(initial, start, stop);
        _title = title;
    }
    function value() as Lang.Number { return _value; }
    function move(delta as Lang.Number) as Void {
        _value += delta;
        if (_value < _start) { _value = _stop; }
        if (_value > _stop) { _value = _start; }
        WatchUi.requestUpdate();
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        var title = _title instanceof Lang.ResourceId ? Ui.s(_title) : _title as Lang.String;
        PickerScreen.drawFrame(dc, title, [_value.toString()],
            [Graphics.FONT_SYSTEM_LARGE], 0);
    }
}

class RingNumberDelegate extends ScreenInputDelegate {
    private var _action as Lang.Symbol;
    function initialize(action as Lang.Symbol) { ScreenInputDelegate.initialize(); _action = action; }
    private function view() as RingNumberPicker {
        return WatchUi.getCurrentView()[0] as RingNumberPicker;
    }
    function onBack() as Lang.Boolean { WatchUi.popView(WatchUi.SLIDE_RIGHT); return true; }
    function onSelect() as Lang.Boolean {
        var value = view().value();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        getApp().confirmAction(_action, currentUtc(), value);
        return true;
    }
    function onNextPage() as Lang.Boolean { view().move(PickerScreen.buttonDelta(true)); return true; }
    function onPreviousPage() as Lang.Boolean { view().move(PickerScreen.buttonDelta(false)); return true; }
    function onSwipe(event as WatchUi.SwipeEvent) as Lang.Boolean {
        if (event.getDirection() == WatchUi.SWIPE_UP) { return onPreviousPage(); }
        if (event.getDirection() == WatchUi.SWIPE_DOWN) { return onNextPage(); }
        if (event.getDirection() == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return false;
    }
    function onTap(event as WatchUi.ClickEvent) as Lang.Boolean {
        var device = System.getDeviceSettings();
        var point = event.getCoordinates();
        var target = PickerScreen.tapTarget(device.screenWidth, device.screenHeight, 1, point[0], point[1]);
        if (target == null) { return true; }
        if (target[1] != 0) { view().move(target[1]); return true; }
        return onSelect();
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
    function hour() as Lang.Number { return _hour; }
    function minute() as Lang.Number { return _minute; }
    function uses24Hour() as Lang.Boolean { return _use24; }
    function title() as Lang.String { return Ui.timeOnly(_hour, _minute, _use24 ? 24 : 12); }
}

class RingTimePicker extends WatchUi.View {
    private var _selection as RingTimeSelection;
    private var _focus as Lang.Number;
    private var _columns as Lang.Number;

    function initialize(action as Lang.Symbol, initialUtc as Lang.Number) {
        View.initialize();
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
        _focus = 0;
        _columns = use24 ? 2 : 3;
    }

    function focus() as Lang.Number { return _focus; }
    function columnCount() as Lang.Number { return _columns; }
    function hour() as Lang.Number { return _selection.hour(); }
    function minute() as Lang.Number { return _selection.minute(); }
    function uses24Hour() as Lang.Boolean { return _selection.uses24Hour(); }
    function setFocus(value as Lang.Number) as Lang.Boolean {
        var next = PickerValues.clamp(value, 0, _columns - 1);
        var changed = next != _focus;
        _focus = next;
        WatchUi.requestUpdate();
        return changed;
    }
    function advance() as Lang.Boolean {
        if (_focus + 1 >= _columns) { return true; }
        setFocus(_focus + 1);
        return false;
    }
    function retreat() as Lang.Boolean {
        if (_focus == 0) { return false; }
        setFocus(_focus - 1);
        return true;
    }
    function move(delta as Lang.Number) as Void {
        if (_focus == 0) {
            if (_selection.uses24Hour()) {
                var hour24 = (_selection.hour() + delta + 24) % 24;
                _selection.setHour24(hour24);
            } else {
                var hour12 = _selection.hour() % 12;
                if (hour12 == 0) { hour12 = 12; }
                hour12 = ((hour12 - 1 + delta + 12) % 12) + 1;
                _selection.setHour12(hour12);
            }
        } else if (_focus == 1) {
            _selection.setMinute((_selection.minute() + delta + 60) % 60);
        } else {
            _selection.setPeriod(_selection.hour() >= 12 ? 0 : 1);
        }
        WatchUi.requestUpdate();
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        var hour = _selection.hour();
        var shownHour = hour;
        if (!_selection.uses24Hour()) {
            shownHour = hour % 12;
            if (shownHour == 0) { shownHour = 12; }
        }
        var columns = [shownHour.format(_selection.uses24Hour() ? "%02d" : "%d"),
            _selection.minute().format("%02d")];
        var fonts = [Graphics.FONT_SYSTEM_LARGE, Graphics.FONT_SYSTEM_LARGE];
        if (!_selection.uses24Hour()) {
            columns.add(Ui.s(hour < 12 ? Rez.Strings.Am : Rez.Strings.Pm));
            fonts.add(Graphics.FONT_SYSTEM_SMALL);
        }
        PickerScreen.drawFrame(dc, _selection.title(), columns, fonts, _focus);
        var first = PickerScreen.xForColumn(dc.getWidth(), _columns, 0);
        var second = PickerScreen.xForColumn(dc.getWidth(), _columns, 1);
        dc.setColor(Ui.SECONDARY, Graphics.COLOR_TRANSPARENT);
        dc.drawText((first + second) / 2, dc.getHeight() / 2,
            Graphics.FONT_SYSTEM_LARGE, Ui.s(Rez.Strings.TimeSeparator),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class RingTimeDelegate extends ScreenInputDelegate {
    private var _action as Lang.Symbol;
    private var _initialUtc as Lang.Number;
    private var _dateFields as Lang.Dictionary?;
    function initialize(action as Lang.Symbol, initialUtc as Lang.Number,
                        dateFields as Lang.Dictionary?) {
        ScreenInputDelegate.initialize();
        _action = action;
        _initialUtc = initialUtc;
        _dateFields = dateFields;
    }
    private function view() as RingTimePicker {
        return WatchUi.getCurrentView()[0] as RingTimePicker;
    }
    function onBack() as Lang.Boolean {
        if (!view().retreat()) { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
        return true;
    }
    function onSelect() as Lang.Boolean {
        if (!view().advance()) { return true; }
        var hour = view().hour();
        var minute = view().minute();
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
    function onNextPage() as Lang.Boolean { view().move(PickerScreen.buttonDelta(true)); return true; }
    function onPreviousPage() as Lang.Boolean { view().move(PickerScreen.buttonDelta(false)); return true; }
    function onSwipe(event as WatchUi.SwipeEvent) as Lang.Boolean {
        if (event.getDirection() == WatchUi.SWIPE_UP) { return onPreviousPage(); }
        if (event.getDirection() == WatchUi.SWIPE_DOWN) { return onNextPage(); }
        if (event.getDirection() == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return false;
    }
    function onTap(event as WatchUi.ClickEvent) as Lang.Boolean {
        var current = view();
        var device = System.getDeviceSettings();
        var point = event.getCoordinates();
        var target = PickerScreen.tapTarget(device.screenWidth, device.screenHeight,
            current.columnCount(), point[0], point[1]);
        if (target == null) { return true; }
        if (current.setFocus(target[0])) { return true; }
        if (target[1] != 0) { current.move(target[1]); return true; }
        return onSelect();
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
    function year() as Lang.Number { return _year; }
    function month() as Lang.Number { return _month; }
    function day() as Lang.Number { return _day; }
    function title() as Lang.String {
        var noon = CalendarMath.utc(_year, _month, _day, 12, 0, 0);
        var info = Gregorian.utcInfo(new Time.Moment(noon), Time.FORMAT_SHORT);
        return Ui.weekdayName(info.day_of_week) + " " + _day.toString() + " "
            + Ui.monthName(_month) + " " + _year.toString();
    }
}

class RingDatePicker extends WatchUi.View {
    private var _selection as RingDateSelection;
    private var _focus as Lang.Number;
    private var _startYear as Lang.Number;
    private var _stopYear as Lang.Number;

    function initialize(action as Lang.Symbol, initialUtc as Lang.Number) {
        View.initialize();
        var f = CalendarMath.localFields(initialUtc);
        var currentYear = CalendarMath.localFields(currentUtc())[:year];
        _startYear = currentYear - 2;
        _stopYear = currentYear + 2;
        var selectedYear = PickerValues.clamp(f[:year], _startYear, _stopYear);
        var selectedDay = PickerValues.clampDay(selectedYear, f[:month], f[:day]);
        _selection = new RingDateSelection(selectedYear, f[:month], selectedDay);
        _focus = 0;
    }

    function focus() as Lang.Number { return _focus; }
    function year() as Lang.Number { return _selection.year(); }
    function month() as Lang.Number { return _selection.month(); }
    function day() as Lang.Number { return _selection.day(); }
    function setFocus(value as Lang.Number) as Lang.Boolean {
        var next = PickerValues.clamp(value, 0, 2);
        var changed = next != _focus;
        _focus = next;
        WatchUi.requestUpdate();
        return changed;
    }
    function advance() as Lang.Boolean {
        if (_focus == 2) { return true; }
        setFocus(_focus + 1);
        return false;
    }
    function retreat() as Lang.Boolean {
        if (_focus == 0) { return false; }
        setFocus(_focus - 1);
        return true;
    }
    function move(delta as Lang.Number) as Void {
        if (_focus == 0) {
            var maxDay = PickerValues.daysInMonth(_selection.year(), _selection.month());
            var day = _selection.day() + delta;
            if (day < 1) { day = maxDay; }
            if (day > maxDay) { day = 1; }
            _selection.setDay(day);
        } else if (_focus == 1) {
            var month = ((_selection.month() - 1 + delta + 12) % 12) + 1;
            _selection.setMonth(month);
        } else {
            var year = _selection.year() + delta;
            if (year < _startYear) { year = _stopYear; }
            if (year > _stopYear) { year = _startYear; }
            _selection.setYear(year);
        }
        WatchUi.requestUpdate();
    }
    function onUpdate(dc as Graphics.Dc) as Void {
        PickerScreen.drawFrame(dc, _selection.title(),
            [_selection.day().toString(), Ui.monthName(_selection.month()),
             _selection.year().toString()],
            [Graphics.FONT_SYSTEM_LARGE, Graphics.FONT_SYSTEM_TINY,
             Graphics.FONT_SYSTEM_TINY], _focus);
    }
}

class RingDateDelegate extends ScreenInputDelegate {
    private var _action as Lang.Symbol;
    private var _initialUtc as Lang.Number;
    function initialize(action as Lang.Symbol, initialUtc as Lang.Number) {
        ScreenInputDelegate.initialize();
        _action = action;
        _initialUtc = initialUtc;
    }
    private function view() as RingDatePicker {
        return WatchUi.getCurrentView()[0] as RingDatePicker;
    }
    function onBack() as Lang.Boolean {
        if (!view().retreat()) { WatchUi.popView(WatchUi.SLIDE_RIGHT); }
        return true;
    }
    function onSelect() as Lang.Boolean {
        if (!view().advance()) { return true; }
        var year = view().year();
        var month = view().month();
        var day = PickerValues.clampDay(year, month, view().day());
        var original = CalendarMath.localFields(_initialUtc);
        var fields = {:year=>year, :month=>month, :day=>day,
            :hour=>original[:hour], :minute=>original[:minute], :second=>0};
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.pushView(new RingTimePicker(_action, _initialUtc),
            new RingTimeDelegate(_action, _initialUtc, fields), WatchUi.SLIDE_LEFT);
        return true;
    }
    function onNextPage() as Lang.Boolean { view().move(PickerScreen.buttonDelta(true)); return true; }
    function onPreviousPage() as Lang.Boolean { view().move(PickerScreen.buttonDelta(false)); return true; }
    function onSwipe(event as WatchUi.SwipeEvent) as Lang.Boolean {
        if (event.getDirection() == WatchUi.SWIPE_UP) { return onPreviousPage(); }
        if (event.getDirection() == WatchUi.SWIPE_DOWN) { return onNextPage(); }
        if (event.getDirection() == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return false;
    }
    function onTap(event as WatchUi.ClickEvent) as Lang.Boolean {
        var device = System.getDeviceSettings();
        var point = event.getCoordinates();
        var target = PickerScreen.tapTarget(device.screenWidth, device.screenHeight, 3, point[0], point[1]);
        if (target == null) { return true; }
        if (view().setFocus(target[0])) { return true; }
        if (target[1] != 0) { view().move(target[1]); return true; }
        return onSelect();
    }
}
