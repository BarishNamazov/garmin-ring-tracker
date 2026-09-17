import Toybox.Application.Properties;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

module SettingsBridge {
    const PROPERTY_SCHEMA_VERSION = 3;

    function isoForUtc(utcSeconds as Lang.Number) as Lang.String {
        var f = CalendarMath.localFields(utcSeconds);
        return isoForFields(f[:year], f[:month], f[:day], f[:hour], f[:minute]);
    }

    function isoForFields(year as Lang.Number, month as Lang.Number, day as Lang.Number,
                          hour as Lang.Number, minute as Lang.Number) as Lang.String {
        return year.format("%04d") + "-" + month.format("%02d") + "-"
            + day.format("%02d") + "T" + hour.format("%02d") + ":"
            + minute.format("%02d");
    }

    function parseInsertion(value, nowUtc as Lang.Number) as Lang.Dictionary? {
        var fields = fieldsForIso(value);
        if (fields == null) { return null; }
        var currentYear = CalendarMath.localFields(nowUtc)[:year];
        if (fields[:year] < currentYear - 2 || fields[:year] > currentYear + 2) { return null; }
        var resolved = CalendarMath.wallToUtcUsingDevice(fields);
        if (resolved == null || resolved[:adjusted]) { return null; }
        if (!isoForUtc(resolved[:utc]).equals(value as Lang.String)) { return null; }
        if (resolved[:utc] > nowUtc + 60) { return null; }
        return resolved;
    }

    function fieldsForIso(value) as Lang.Dictionary? {
        if (!(value instanceof Lang.String)) { return null; }
        var text = value as Lang.String;
        if (text.length() != 16 || !text.substring(4, 5).equals("-")
            || !text.substring(7, 8).equals("-") || !text.substring(10, 11).equals("T")
            || !text.substring(13, 14).equals(":")) { return null; }
        try {
            var fields = {
                :year=>digits(text, 0, 4), :month=>digits(text, 5, 7),
                :day=>digits(text, 8, 10), :hour=>digits(text, 11, 13),
                :minute=>digits(text, 14, 16), :second=>0
            };
            return CalendarMath.validWall(fields) ? fields : null;
        } catch (ignored) { return null; }
    }

    function digits(text as Lang.String, start as Lang.Number, stop as Lang.Number) as Lang.Number {
        for (var i = start; i < stop; i += 1) {
            var c = text.substring(i, i + 1);
            if ("0123456789".find(c) == null) { return -1; }
        }
        var parsed = text.substring(start, stop).toNumber();
        return parsed == null ? -1 : parsed;
    }

    function minutesFromParts(hour as Lang.Number, minute as Lang.Number) as Lang.Number {
        return (hour * 60) + minute;
    }

    function partsFromMinutes(value as Lang.Number) as Lang.Array {
        return [value / 60, value % 60];
    }

    // The phone lists contain quarter-hours only. Watch values remain exact;
    // only the mirrored representation is rounded, including midnight wrap.
    function roundToQuarter(value as Lang.Number) as Lang.Number {
        return (((value + 7) / 15) * 15) % (24 * 60);
    }

    function validListMinutes(value) as Lang.Boolean {
        return value instanceof Lang.Number && value >= 0 && value < 24 * 60
            && value % 15 == 0;
    }

    function dateFields(value) as Lang.Dictionary? {
        if (!(value instanceof Lang.Number)) { return null; }
        try {
            var info = Gregorian.utcInfo(new Time.Moment(value as Lang.Number), Time.FORMAT_SHORT);
            var fields = {:year=>info.year, :month=>info.month, :day=>info.day,
                :hour=>0, :minute=>0, :second=>0};
            return CalendarMath.validWall(fields) ? fields : null;
        } catch (ignored) { return null; }
    }

    function validDateProperty(value, nowUtc as Lang.Number) as Lang.Boolean {
        var fields = dateFields(value);
        if (fields == null) { return false; }
        var currentYear = CalendarMath.localFields(nowUtc)[:year];
        return fields[:year] >= currentYear - 2 && fields[:year] <= currentYear + 2;
    }

    function isoForPropertyPair(dateValue, timeValue) as Lang.String? {
        var fields = dateFields(dateValue);
        if (fields == null || !validListMinutes(timeValue)) { return null; }
        var parts = partsFromMinutes(timeValue as Lang.Number);
        return isoForFields(fields[:year], fields[:month], fields[:day], parts[0], parts[1]);
    }

    function propertyPairForFields(fields as Lang.Dictionary) as Lang.Dictionary {
        var rawMinutes = minutesFromParts(fields[:hour], fields[:minute]);
        var rounded = ((rawMinutes + 7) / 15) * 15;
        var date = {:year=>fields[:year], :month=>fields[:month], :day=>fields[:day],
            :hour=>0, :minute=>0, :second=>0};
        if (rounded >= 24 * 60) {
            date = CalendarMath.dateShift(date, 1);
            rounded = 0;
        }
        var dateValue = CalendarMath.utc(date[:year], date[:month], date[:day], 0, 0, 0);
        return {:date=>dateValue, :time=>rounded,
            :iso=>isoForFields(date[:year], date[:month], date[:day], rounded / 60, rounded % 60)};
    }

    function propertyPairForUtc(utcSeconds as Lang.Number) as Lang.Dictionary {
        return propertyPairForFields(CalendarMath.localFields(utcSeconds));
    }

    function propertyPairForIso(value) as Lang.Dictionary? {
        var fields = fieldsForIso(value);
        return fields == null ? null : propertyPairForFields(fields as Lang.Dictionary);
    }

    function parseInsertionProperties(dateValue, timeValue,
                                      nowUtc as Lang.Number) as Lang.Dictionary? {
        if (!validDateProperty(dateValue, nowUtc) || !validListMinutes(timeValue)) { return null; }
        var fields = dateFields(dateValue) as Lang.Dictionary;
        var parts = partsFromMinutes(timeValue as Lang.Number);
        fields[:hour] = parts[0];
        fields[:minute] = parts[1];
        var resolved = CalendarMath.wallToUtcUsingDevice(fields);
        if (resolved == null || resolved[:adjusted] || resolved[:utc] > nowUtc + 60) { return null; }
        return resolved;
    }

    function isInsertionKey(key as Lang.String) as Lang.Boolean {
        return key.equals("insertionDate") || key.equals("insertionTime")
            || key.equals("insertionIso");
    }

    function validate(key as Lang.String, value, nowUtc as Lang.Number) as Lang.Boolean {
        if (key.equals("insertionDate")) { return validDateProperty(value, nowUtc); }
        if (key.equals("insertionTime") || key.equals("reminder1Minutes")
            || key.equals("reminder2Minutes")) { return validListMinutes(value); }
        if (key.equals("insertionIso")) {
            return value instanceof Lang.String && ((value as Lang.String).length() == 0
                || parseInsertion(value, nowUtc) != null);
        }
        if (key.equals("reminderHour") || key.equals("reminder2Hour")) {
            return numberIn(value, 0, 23);
        }
        if (key.equals("reminderMinute") || key.equals("reminder2Minute")) {
            return numberIn(value, 0, 59);
        }
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
            r[:overdueRepeatHours], r[:vibrationEnabled], r[:soundEnabled], 0];
    }

    function propertyConfigFromState(state as Lang.Dictionary) as Lang.Array {
        return normalizeConfigForProperties(configFromState(state));
    }

    function normalizeConfigForProperties(values as Lang.Array) as Lang.Array {
        var r1 = partsFromMinutes(roundToQuarter(minutesFromParts(values[0], values[1])));
        var r2 = partsFromMinutes(roundToQuarter(minutesFromParts(values[2], values[3])));
        var repeat = values[8] == 12 || values[8] == 24 ? 24 : values[8];
        return [r1[0], r1[1], r2[0], r2[1], values[4], values[5], values[6], values[7],
            repeat, values[9], values[10], 0];
    }

    function configFromProperties() as Lang.Array? {
        var reminder1 = Properties.getValue("reminder1Minutes");
        var reminder2 = Properties.getValue("reminder2Minutes");
        if (!validListMinutes(reminder1) || !validListMinutes(reminder2)) { return null; }
        var r1 = partsFromMinutes(reminder1 as Lang.Number);
        var r2 = partsFromMinutes(reminder2 as Lang.Number);
        var values = [r1[0], r1[1], r2[0], r2[1],
            Properties.getValue("reminder2Enabled"), Properties.getValue("dayBeforeEnabled"),
            Properties.getValue("daysIn"), Properties.getValue("daysOut"),
            Properties.getValue("overdueRepeatHours"), Properties.getValue("vibrationEnabled"),
            Properties.getValue("soundEnabled"), 0];
        if (values[8] == 12) { values[8] = 24; }
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

    function normalizedSnapshot(value) {
        if (!(value instanceof Lang.Array) || !ScheduleModel.validConfigArray(value)) { return value; }
        return normalizeConfigForProperties(value as Lang.Array);
    }

    // Runs once after an update. Legacy IDs remain declared so synchronized
    // v1.1 values are readable, but they are not exposed by settings.xml.
    function migrateLegacyProperties(state as Lang.Dictionary,
                                     nowUtc as Lang.Number) as Lang.Boolean {
        var version = Properties.getValue("settingsSchemaVersion");
        var reminders = state[:reminders] as Lang.Dictionary;
        var clockChanged = reminders[:clockFormat] != 0
            || Properties.getValue("clockFormat") != 0;
        reminders[:clockFormat] = 0;
        if (!(version instanceof Lang.Number) || version < PROPERTY_SCHEMA_VERSION) {
            if (reminders[:overdueRepeatHours] == 12 || reminders[:overdueRepeatHours] == 24) {
                reminders[:overdueRepeatHours] = 24;
            }
        }
        if (Properties.getValue("clockFormat") != 0) {
            Properties.setValue("clockFormat", 0);
        }
        if (version instanceof Lang.Number && version >= PROPERTY_SCHEMA_VERSION) {
            return clockChanged;
        }

        var sync = state[:settingsSync] as Lang.Dictionary;
        var pendingConfig = sync[:pendingConfigSnapshot] instanceof Lang.Array;
        var oldR1Hour = Properties.getValue("reminderHour");
        var oldR1Minute = Properties.getValue("reminderMinute");
        var oldR2Hour = Properties.getValue("reminder2Hour");
        var oldR2Minute = Properties.getValue("reminder2Minute");
        if (!pendingConfig && numberIn(oldR1Hour, 0, 23) && numberIn(oldR1Minute, 0, 59)) {
            reminders[:reminder1Hour] = oldR1Hour;
            reminders[:reminder1Minute] = oldR1Minute;
        }
        if (!pendingConfig && numberIn(oldR2Hour, 0, 23) && numberIn(oldR2Minute, 0, 59)) {
            reminders[:reminder2Hour] = oldR2Hour;
            reminders[:reminder2Minute] = oldR2Minute;
        }
        var propertyConfig = propertyConfigFromState(state);
        writeConfigProperties(propertyConfig);

        var oldIso = Properties.getValue("insertionIso");
        var pair = propertyPairForIso(oldIso);
        if (pair == null && state[:active] != null) {
            pair = propertyPairForUtc((state[:active] as Lang.Dictionary)[:insertionUtc]);
        }
        if (pair == null) {
            var today = CalendarMath.localFields(nowUtc);
            today[:hour] = reminders[:reminder1Hour];
            today[:minute] = reminders[:reminder1Minute];
            today[:second] = 0;
            pair = propertyPairForFields(today);
        }
        writeInsertionPair(pair as Lang.Dictionary);

        var lastSeen = propertyPairForIso(sync[:lastSeenInsertionIso]);
        var lastAccepted = propertyPairForIso(sync[:lastAcceptedInsertionIso]);
        if (lastSeen != null) { sync[:lastSeenInsertionIso] = lastSeen[:iso]; }
        else if (state[:active] != null || !(oldIso instanceof Lang.String)
            || (oldIso as Lang.String).length() == 0) { sync[:lastSeenInsertionIso] = pair[:iso]; }
        if (lastAccepted != null) { sync[:lastAcceptedInsertionIso] = lastAccepted[:iso]; }
        else { sync[:lastAcceptedInsertionIso] = sync[:lastSeenInsertionIso]; }
        sync[:configSnapshot] = normalizedSnapshot(sync[:configSnapshot]);
        sync[:pendingConfigSnapshot] = normalizedSnapshot(sync[:pendingConfigSnapshot]);
        Properties.setValue("settingsSchemaVersion", PROPERTY_SCHEMA_VERSION);
        return true;
    }

    // Returns only changes that require user review. Harmless configuration
    // values are applied immediately, as permitted by the settings contract.
    function observe(state as Lang.Dictionary, nowUtc as Lang.Number) as Lang.Dictionary? {
        migrateLegacyProperties(state, nowUtc);
        completePendingMirrors(state);
        var sync = state[:settingsSync] as Lang.Dictionary;
        var result = {};
        var dateValue = Properties.getValue("insertionDate");
        var timeValue = Properties.getValue("insertionTime");
        var pairIso = isoForPropertyPair(dateValue, timeValue);
        if (pairIso == null || !pairIso.equals(sync[:lastSeenInsertionIso] as Lang.String)) {
            var parsed = parseInsertionProperties(dateValue, timeValue, nowUtc);
            if (parsed == null) {
                sync[:pendingSettingsError] = "insertionDateTime";
                result[:invalid] = true;
            } else {
                result[:insertionUtc] = parsed[:utc];
                result[:insertionIso] = pairIso;
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
        r[:soundEnabled] = values[10]; r[:clockFormat] = 0;
    }

    function writeConfigProperties(values as Lang.Array) as Void {
        Properties.setValue("reminder1Minutes", minutesFromParts(values[0], values[1]));
        Properties.setValue("reminder2Minutes", minutesFromParts(values[2], values[3]));
        Properties.setValue("reminder2Enabled", values[4]);
        Properties.setValue("dayBeforeEnabled", values[5]);
        Properties.setValue("daysIn", values[6]);
        Properties.setValue("daysOut", values[7]);
        Properties.setValue("overdueRepeatHours", values[8]);
        Properties.setValue("vibrationEnabled", values[9]);
        Properties.setValue("soundEnabled", values[10]);
        Properties.setValue("clockFormat", 0);
    }

    function writeInsertionPair(pair as Lang.Dictionary) as Void {
        Properties.setValue("insertionDate", pair[:date]);
        Properties.setValue("insertionTime", pair[:time]);
    }

    function completePendingMirrors(state as Lang.Dictionary) as Void {
        migrateLegacyProperties(state, currentUtc());
        var sync = state[:settingsSync] as Lang.Dictionary;
        if (sync[:pendingMirrorIso] != null) {
            var pair = propertyPairForIso(sync[:pendingMirrorIso]);
            if (pair == null) { throw new Lang.InvalidValueException("invalid pending insertion mirror"); }
            writeInsertionPair(pair as Lang.Dictionary);
            sync[:lastSeenInsertionIso] = pair[:iso];
            sync[:lastAcceptedInsertionIso] = pair[:iso];
            sync[:pendingMirrorIso] = null;
        }
        if (sync[:pendingConfigSnapshot] instanceof Lang.Array) {
            var values = normalizeConfigForProperties(sync[:pendingConfigSnapshot] as Lang.Array);
            writeConfigProperties(values);
            sync[:configSnapshot] = values;
            sync[:pendingConfigSnapshot] = null;
        }
    }

    function defaultInsertionMirror(state as Lang.Dictionary) as Lang.String {
        var fields = CalendarMath.localFields(currentUtc());
        var reminders = state[:reminders] as Lang.Dictionary;
        fields[:hour] = reminders[:reminder1Hour];
        fields[:minute] = reminders[:reminder1Minute];
        fields[:second] = 0;
        return (propertyPairForFields(fields) as Lang.Dictionary)[:iso];
    }

    function stageMirrors(state as Lang.Dictionary) as Void {
        migrateLegacyProperties(state, currentUtc());
        var sync = state[:settingsSync] as Lang.Dictionary;
        var values = propertyConfigFromState(state);
        var properties = configFromProperties();
        if (properties == null || !arraysEqual(properties as Lang.Array, values)) {
            sync[:pendingConfigSnapshot] = values;
        } else {
            sync[:configSnapshot] = values;
        }
        var iso = state[:active] == null ? defaultInsertionMirror(state)
            : isoForUtc((state[:active] as Lang.Dictionary)[:insertionUtc]);
        var dateValue = Properties.getValue("insertionDate");
        var timeValue = Properties.getValue("insertionTime");
        var propertyIso = isoForPropertyPair(dateValue, timeValue);
        var mirrored = propertyPairForIso(iso) as Lang.Dictionary;
        if (propertyIso == null || !mirrored[:iso].equals(propertyIso as Lang.String)) {
            sync[:pendingMirrorIso] = iso;
        } else {
            sync[:lastSeenInsertionIso] = mirrored[:iso];
            sync[:lastAcceptedInsertionIso] = mirrored[:iso];
        }
    }

    // Synchronous helper retained for setup/tests. Production mutations stage
    // markers, save them, complete the property writes, then save the cleared
    // markers in RingTrackerApp.saveOrRecover().
    function mirrorAll(state as Lang.Dictionary) as Void {
        migrateLegacyProperties(state, currentUtc());
        var sync = state[:settingsSync] as Lang.Dictionary;
        sync[:pendingConfigSnapshot] = propertyConfigFromState(state);
        sync[:pendingMirrorIso] = state[:active] == null ? defaultInsertionMirror(state)
            : isoForUtc((state[:active] as Lang.Dictionary)[:insertionUtc]);
        completePendingMirrors(state);
    }
}
