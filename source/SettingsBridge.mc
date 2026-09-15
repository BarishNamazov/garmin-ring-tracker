import Toybox.Application.Properties;
import Toybox.Lang;

module SettingsBridge {
    function isoForUtc(utcSeconds as Lang.Number) as Lang.String {
        var f = CalendarMath.localFields(utcSeconds);
        return f[:year].format("%04d") + "-" + f[:month].format("%02d") + "-"
            + f[:day].format("%02d") + "T" + f[:hour].format("%02d") + ":"
            + f[:minute].format("%02d");
    }

    function parseInsertion(value, nowUtc as Lang.Number) as Lang.Dictionary? {
        if (!(value instanceof Lang.String)) { return null; }
        var text = value as Lang.String;
        if (text.length() != 16 || !text.substring(4, 5).equals("-")
            || !text.substring(7, 8).equals("-") || !text.substring(10, 11).equals("T")
            || !text.substring(13, 14).equals(":")) { return null; }
        try {
            var fields = {
                :year => digits(text, 0, 4), :month => digits(text, 5, 7),
                :day => digits(text, 8, 10), :hour => digits(text, 11, 13),
                :minute => digits(text, 14, 16), :second => 0
            };
            var currentYear = CalendarMath.localFields(nowUtc)[:year];
            if (fields[:year] < currentYear - 2 || fields[:year] > currentYear + 2
                || !CalendarMath.validWall(fields)) { return null; }
            var resolved = CalendarMath.wallToUtcUsingDevice(fields);
            if (resolved == null || resolved[:adjusted]) { return null; }
            if (!isoForUtc(resolved[:utc]).equals(text)) { return null; }
            if (resolved[:utc] > nowUtc + 60) { return null; }
            return resolved;
        } catch (ignored) {
            return null;
        }
    }

    function digits(text as Lang.String, start as Lang.Number, stop as Lang.Number) as Lang.Number {
        for (var i = start; i < stop; i += 1) {
            var c = text.substring(i, i + 1);
            if ("0123456789".find(c) == null) { return -1; }
        }
        var parsed = text.substring(start, stop).toNumber();
        return parsed == null ? -1 : parsed;
    }

    function validate(key as Lang.String, value, nowUtc as Lang.Number) as Lang.Boolean {
        if (key.equals("insertionIso")) {
            return value instanceof Lang.String && ((value as Lang.String).length() == 0
                || parseInsertion(value, nowUtc) != null);
        }
        if (key.equals("reminderHour")) { return numberIn(value, 0, 23); }
        if (key.equals("reminderMinute")) { return numberIn(value, 0, 59); }
        if (key.equals("reminder2Hour")) { return numberIn(value, 0, 23); }
        if (key.equals("reminder2Minute")) { return numberIn(value, 0, 59); }
        if (key.equals("daysIn")) { return numberIn(value, 21, 35); }
        if (key.equals("daysOut")) { return numberIn(value, 0, 7); }
        if (key.equals("overdueRepeatHours")) {
            return value == 1 || value == 3 || value == 6 || value == 12 || value == 24;
        }
        if (key.equals("clockFormat")) { return value == 0 || value == 12 || value == 24; }
        if (key.equals("reminder2Enabled") || key.equals("dayBeforeEnabled")
            || key.equals("vibrationEnabled") || key.equals("soundEnabled")) {
            return value instanceof Lang.Boolean;
        }
        return true;
    }

    function numberIn(value, low as Lang.Number, high as Lang.Number) as Lang.Boolean {
        return value instanceof Lang.Number && value >= low && value <= high;
    }

    function configFromState(state as Lang.Dictionary) as Lang.Array {
        var r = state[:reminders] as Lang.Dictionary;
        var g = state[:regimen] as Lang.Dictionary;
        return [r[:reminder1Hour], r[:reminder1Minute], r[:reminder2Hour], r[:reminder2Minute],
            r[:reminder2Enabled], r[:dayBeforeEnabled], g[:daysIn], g[:daysOut],
            r[:overdueRepeatHours], r[:vibrationEnabled], r[:soundEnabled], r[:clockFormat]];
    }

    function configFromProperties() as Lang.Array? {
        var values = [Properties.getValue("reminderHour"), Properties.getValue("reminderMinute"),
            Properties.getValue("reminder2Hour"), Properties.getValue("reminder2Minute"),
            Properties.getValue("reminder2Enabled"), Properties.getValue("dayBeforeEnabled"),
            Properties.getValue("daysIn"), Properties.getValue("daysOut"),
            Properties.getValue("overdueRepeatHours"), Properties.getValue("vibrationEnabled"),
            Properties.getValue("soundEnabled"), Properties.getValue("clockFormat")];
        var keys = ["reminderHour", "reminderMinute", "reminder2Hour", "reminder2Minute",
            "reminder2Enabled", "dayBeforeEnabled", "daysIn", "daysOut",
            "overdueRepeatHours", "vibrationEnabled", "soundEnabled", "clockFormat"];
        for (var i = 0; i < keys.size(); i += 1) {
            if (!validate(keys[i], values[i], currentUtc())) { return null; }
        }
        return values;
    }

    function arraysEqual(a as Lang.Array, b as Lang.Array) as Lang.Boolean {
        if (a.size() != b.size()) { return false; }
        for (var i = 0; i < a.size(); i += 1) { if (a[i] != b[i]) { return false; } }
        return true;
    }

    // Returns only changes that require user review. Harmless configuration
    // values are applied immediately, as permitted by the settings contract.
    function observe(state as Lang.Dictionary, nowUtc as Lang.Number) as Lang.Dictionary? {
        var sync = state[:settingsSync] as Lang.Dictionary;
        completePendingMirrors(state);
        var result = {};
        var iso = Properties.getValue("insertionIso");
        if (iso instanceof Lang.String && !(iso as Lang.String).equals(sync[:lastSeenInsertionIso] as Lang.String)) {
            if ((iso as Lang.String).length() > 0) {
                var parsed = parseInsertion(iso, nowUtc);
                if (parsed == null) {
                    sync[:pendingSettingsError] = "insertionIso";
                    result[:invalid] = true;
                } else {
                    result[:insertionUtc] = parsed[:utc];
                    result[:insertionIso] = iso;
                }
            } else if (state[:active] != null) {
                sync[:pendingSettingsError] = "emptyInsertionIso";
                result[:invalid] = true;
            } else {
                sync[:lastSeenInsertionIso] = "";
                sync[:lastAcceptedInsertionIso] = "";
            }
        }

        var fromPhone = configFromProperties();
        var snapshot = sync[:configSnapshot] as Lang.Array?;
        if (snapshot == null) {
            stageMirrors(state);
            completePendingMirrors(state);
        } else if (fromPhone == null) {
            sync[:pendingSettingsError] = "configuration";
            result[:invalid] = true;
        } else if (!arraysEqual(snapshot, fromPhone)) {
            var current = configFromState(state);
            var durationChanged = current[6] != fromPhone[6] || current[7] != fromPhone[7];
            if (durationChanged && state[:active] != null) {
                result[:config] = fromPhone;
            } else {
                applyConfig(state, fromPhone);
                sync[:configSnapshot] = fromPhone;
            }
        }
        sync[:lastSettingsObservationUtc] = nowUtc;
        return result.size() == 0 ? null : result;
    }

    function applyConfig(state as Lang.Dictionary, values as Lang.Array) as Void {
        var r = state[:reminders] as Lang.Dictionary;
        var g = state[:regimen] as Lang.Dictionary;
        r[:reminder1Hour] = values[0]; r[:reminder1Minute] = values[1];
        r[:reminder2Hour] = values[2]; r[:reminder2Minute] = values[3];
        r[:reminder2Enabled] = values[4]; r[:dayBeforeEnabled] = values[5];
        g[:daysIn] = values[6]; g[:daysOut] = values[7];
        r[:overdueRepeatHours] = values[8]; r[:vibrationEnabled] = values[9];
        r[:soundEnabled] = values[10]; r[:clockFormat] = values[11];
    }

    function completePendingMirrors(state as Lang.Dictionary) as Void {
        var sync = state[:settingsSync] as Lang.Dictionary;
        if (sync[:pendingMirrorIso] != null) {
            Properties.setValue("insertionIso", sync[:pendingMirrorIso]);
            sync[:lastSeenInsertionIso] = sync[:pendingMirrorIso];
            sync[:lastAcceptedInsertionIso] = sync[:pendingMirrorIso];
            sync[:pendingMirrorIso] = null;
        }
        if (sync[:pendingConfigSnapshot] instanceof Lang.Array) {
            var values = sync[:pendingConfigSnapshot] as Lang.Array;
            Properties.setValue("reminderHour", values[0]);
            Properties.setValue("reminderMinute", values[1]);
            Properties.setValue("reminder2Hour", values[2]);
            Properties.setValue("reminder2Minute", values[3]);
            Properties.setValue("reminder2Enabled", values[4]);
            Properties.setValue("dayBeforeEnabled", values[5]);
            Properties.setValue("daysIn", values[6]);
            Properties.setValue("daysOut", values[7]);
            Properties.setValue("overdueRepeatHours", values[8]);
            Properties.setValue("vibrationEnabled", values[9]);
            Properties.setValue("soundEnabled", values[10]);
            Properties.setValue("clockFormat", values[11]);
            sync[:configSnapshot] = values;
            sync[:pendingConfigSnapshot] = null;
        }
    }

    function stageMirrors(state as Lang.Dictionary) as Void {
        var sync = state[:settingsSync] as Lang.Dictionary;
        var values = configFromState(state);
        var properties = configFromProperties();
        if (properties == null || !arraysEqual(properties as Lang.Array, values)) {
            sync[:pendingConfigSnapshot] = values;
        } else {
            sync[:configSnapshot] = values;
        }
        if (state[:active] != null) {
            var iso = isoForUtc((state[:active] as Lang.Dictionary)[:insertionUtc]);
            var propertyIso = Properties.getValue("insertionIso");
            if (!(propertyIso instanceof Lang.String) || !iso.equals(propertyIso as Lang.String)) {
                sync[:pendingMirrorIso] = iso;
            } else {
                sync[:lastSeenInsertionIso] = iso;
                sync[:lastAcceptedInsertionIso] = iso;
            }
        } else {
            var emptyProperty = Properties.getValue("insertionIso");
            if (!(emptyProperty instanceof Lang.String) || !(emptyProperty as Lang.String).equals("")) {
                sync[:pendingMirrorIso] = "";
            } else {
                sync[:lastSeenInsertionIso] = "";
                sync[:lastAcceptedInsertionIso] = "";
            }
        }
    }

    // Synchronous helper retained for setup/tests. Production mutations stage
    // markers, save them, complete the property writes, then save the cleared
    // markers in RingTrackerApp.saveOrRecover().
    function mirrorAll(state as Lang.Dictionary) as Void {
        var sync = state[:settingsSync] as Lang.Dictionary;
        sync[:pendingConfigSnapshot] = configFromState(state);
        sync[:pendingMirrorIso] = state[:active] == null ? ""
            : isoForUtc((state[:active] as Lang.Dictionary)[:insertionUtc]);
        completePendingMirrors(state);
    }
}
