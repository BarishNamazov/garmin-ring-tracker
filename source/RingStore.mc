import Toybox.Application.Storage;
import Toybox.Lang;

// The in-memory domain model deliberately uses Symbol keys for readable,
// type-safe access. Connect IQ Storage does not support Symbol values, so the
// persistence boundary encodes the model as versioned, positional arrays.
(:background, :glance)
module RingStore {
    const STATE_KEY = "ringTrackerState";
    const GLANCE_KEY = "ringTrackerGlance";
    const BACKGROUND_KEY = "ringTrackerBackground";
    const RECOVERY_KEY = "ringTrackerRecovery";

    function load() as Lang.Dictionary {
        var raw = Storage.getValue(STATE_KEY);
        if (raw == null) { return ScheduleModel.defaultState(); }

        try {
            if (!(raw instanceof Lang.Array) || raw.size() == 0) {
                return recover(raw, "invalid container");
            }
            var version = raw[0];
            if (version instanceof Lang.Number && version > ScheduleModel.SCHEMA_VERSION) {
                var future = ScheduleModel.defaultState();
                future[:readOnly] = true;
                return future;
            }
            var state = decodeState(raw as Lang.Array);
            if (!ScheduleModel.validState(state)) { return recover(raw, "invalid state"); }
            mergeBackgroundLedger(state);
            return state;
        } catch (ex) {
            return recover(raw, "decode failed");
        }
    }

    function save(state as Lang.Dictionary) as Lang.Boolean {
        try {
            Storage.setValue(STATE_KEY, encodeState(state));
            Storage.setValue(GLANCE_KEY, encodeGlance(state));
            Storage.setValue(BACKGROUND_KEY, encodeBackground(state));
            return true;
        } catch (ex) {
            return false;
        }
    }

    function loadGlance() as Lang.Dictionary {
        var raw = Storage.getValue(GLANCE_KEY);
        if (!(raw instanceof Lang.Array)) {
            return { :active => null, :regimen => ScheduleModel.defaultRegimen() };
        }
        try {
            var a = raw as Lang.Array;
            if (a[0] != ScheduleModel.SCHEMA_VERSION) {
                return { :active => null, :regimen => ScheduleModel.defaultRegimen() };
            }
            return {
                :active => a[1] == null ? null : decodeActive(a[1] as Lang.Array),
                :regimen => { :daysIn => a[2], :daysOut => a[3] }
            };
        } catch (ex) {
            return { :active => null, :regimen => ScheduleModel.defaultRegimen() };
        }
    }

    // Background reminders need only active schedule/configuration and the
    // delivery ledger. Never decode archived history in the 64 KiB service VM.
    function loadBackground() as Lang.Dictionary {
        var raw = Storage.getValue(BACKGROUND_KEY);
        try {
            if (!(raw instanceof Lang.Array)) { return backgroundDefault(); }
            var a = raw as Lang.Array;
            if (a.size() < 6 || a[0] != ScheduleModel.SCHEMA_VERSION) { return backgroundDefault(); }
            var reminders = a[4] as Lang.Array;
            return {
                :active => a[1] == null ? null : decodeActive(a[1] as Lang.Array),
                :regimen => { :daysIn => a[2], :daysOut => a[3] },
                :reminders => {
                    :localHour => reminders[0], :localMinute => reminders[1],
                    :overdueRepeatHours => reminders[2], :vibrationEnabled => reminders[3],
                    :soundEnabled => reminders[4], :clockFormat => reminders[5]
                },
                :reminderLedger => decodeLedger(a[5] as Lang.Array)
            };
        } catch (ex) {
            return backgroundDefault();
        }
    }

    // Update only the small background mirror. The full state/history document
    // is never loaded in the background VM; foreground load merges this ledger.
    function saveBackgroundLedger(state as Lang.Dictionary) as Lang.Boolean {
        try {
            var raw = Storage.getValue(BACKGROUND_KEY);
            if (!(raw instanceof Lang.Array)) { return false; }
            var a = raw as Lang.Array;
            if (a.size() < 6 || a[0] != ScheduleModel.SCHEMA_VERSION) { return false; }
            a[5] = encodeLedger(state[:reminderLedger] as Lang.Dictionary);
            Storage.setValue(BACKGROUND_KEY, a);
            return true;
        } catch (ex) {
            return false;
        }
    }

    function backgroundDefault() as Lang.Dictionary {
        return {
            :active => null,
            :regimen => ScheduleModel.defaultRegimen(),
            :reminders => ScheduleModel.defaultReminders(),
            :reminderLedger => ScheduleModel.defaultLedger()
        };
    }

    function encodeGlance(state as Lang.Dictionary) as Lang.Array {
        var regimen = state[:regimen] as Lang.Dictionary;
        return [ScheduleModel.SCHEMA_VERSION,
            state[:active] == null ? null : encodeReducedActive(state[:active] as Lang.Dictionary),
            regimen[:daysIn], regimen[:daysOut]];
    }

    function encodeBackground(state as Lang.Dictionary) as Lang.Array {
        var regimen = state[:regimen] as Lang.Dictionary;
        var reminders = state[:reminders] as Lang.Dictionary;
        return [ScheduleModel.SCHEMA_VERSION,
            state[:active] == null ? null : encodeReducedActive(state[:active] as Lang.Dictionary),
            regimen[:daysIn], regimen[:daysOut],
            [reminders[:localHour], reminders[:localMinute], reminders[:overdueRepeatHours],
                reminders[:vibrationEnabled], reminders[:soundEnabled], reminders[:clockFormat]],
            encodeLedger(state[:reminderLedger] as Lang.Dictionary)];
    }

    function mergeBackgroundLedger(state as Lang.Dictionary) as Void {
        try {
            var raw = Storage.getValue(BACKGROUND_KEY);
            if (!(raw instanceof Lang.Array)) { return; }
            var a = raw as Lang.Array;
            if (a.size() < 6 || a[0] != ScheduleModel.SCHEMA_VERSION) { return; }
            var stored = decodeLedger(a[5] as Lang.Array);
            var active = state[:active] as Lang.Dictionary?;
            if (active != null && stored[:cycleId] == active[:cycleId]) {
                state[:reminderLedger] = stored;
            }
        } catch (ignored) {
        }
    }

    function stateSizeEstimate(state as Lang.Dictionary) as Lang.Number {
        return encodeState(state).toString().length();
    }

    function recover(raw, reason as Lang.String) as Lang.Dictionary {
        try {
            var sample = raw == null ? "null" : raw.toString();
            if (sample.length() > 256) { sample = sample.substring(0, 256); }
            Storage.setValue(RECOVERY_KEY, reason + ": " + sample);
            Storage.deleteValue(STATE_KEY);
            Storage.deleteValue(GLANCE_KEY);
            Storage.deleteValue(BACKGROUND_KEY);
        } catch (ignored) {
        }
        var fresh = ScheduleModel.defaultState();
        fresh[:loadError] = "recovered";
        return fresh;
    }

    function encodeState(s as Lang.Dictionary) as Lang.Array {
        var regimen = s[:regimen] as Lang.Dictionary;
        var reminders = s[:reminders] as Lang.Dictionary;
        var ledger = s[:reminderLedger] as Lang.Dictionary;
        var sync = s[:settingsSync] as Lang.Dictionary;
        var encodedHistory = [];
        var history = s[:history] as Lang.Array;
        for (var i = 0; i < history.size(); i += 1) {
            encodedHistory.add(encodeHistory(history[i] as Lang.Dictionary));
        }
        return [
            ScheduleModel.SCHEMA_VERSION,
            s[:nextCycleId],
            s[:setupStep],
            s[:active] == null ? null : encodeActive(s[:active] as Lang.Dictionary),
            [regimen[:daysIn], regimen[:daysOut]],
            [reminders[:localHour], reminders[:localMinute], reminders[:overdueRepeatHours],
                reminders[:vibrationEnabled], reminders[:soundEnabled], reminders[:clockFormat]],
            encodeLedger(ledger),
            encodedHistory,
            [sync[:lastSeenInsertionIso], sync[:lastAcceptedInsertionIso],
                sync[:lastWatchScheduleEditUtc], sync[:lastSettingsObservationUtc],
                sync[:pendingMirrorIso], sync[:pendingSettingsError], sync[:configSnapshot]]
        ];
    }

    function decodeState(a as Lang.Array) as Lang.Dictionary {
        var regimen = a[4] as Lang.Array;
        var reminders = a[5] as Lang.Array;
        var ledger = a[6] as Lang.Array;
        var sync = a[8] as Lang.Array;
        var decodedHistory = [];
        var history = a[7] as Lang.Array;
        for (var i = 0; i < history.size(); i += 1) {
            decodedHistory.add(decodeHistory(history[i] as Lang.Array));
        }
        return {
            :schemaVersion => a[0],
            :nextCycleId => a[1],
            :setupStep => a[2],
            :active => a[3] == null ? null : decodeActive(a[3] as Lang.Array),
            :regimen => { :daysIn => regimen[0], :daysOut => regimen[1] },
            :reminders => {
                :localHour => reminders[0], :localMinute => reminders[1],
                :overdueRepeatHours => reminders[2], :vibrationEnabled => reminders[3],
                :soundEnabled => reminders[4], :clockFormat => reminders[5]
            },
            :reminderLedger => decodeLedger(ledger),
            :history => decodedHistory,
            :settingsSync => {
                :lastSeenInsertionIso => sync[0], :lastAcceptedInsertionIso => sync[1],
                :lastWatchScheduleEditUtc => sync[2], :lastSettingsObservationUtc => sync[3],
                :pendingMirrorIso => sync[4], :pendingSettingsError => sync[5],
                :configSnapshot => sync.size() > 6 ? sync[6] : null
            }
        };
    }

    function encodeLedger(ledger as Lang.Dictionary) as Lang.Array {
        return [ledger[:cycleId], ledger[:actionKey], ledger[:dayBeforeSent], ledger[:dayOfSent],
            ledger[:lastOverdueSlot], ledger[:lastTempOutSlot], ledger[:labelFourWeekSent],
            ledger[:ringFreeExceededSent]];
    }

    function decodeLedger(ledger as Lang.Array) as Lang.Dictionary {
        return {
            :cycleId => ledger[0], :actionKey => ledger[1], :dayBeforeSent => ledger[2],
            :dayOfSent => ledger[3], :lastOverdueSlot => ledger[4],
            :lastTempOutSlot => ledger[5], :labelFourWeekSent => ledger[6],
            :ringFreeExceededSent => ledger[7]
        };
    }

    function encodeWall(wall) {
        if (wall == null) { return null; }
        var fields = wall as Lang.Dictionary;
        return [fields[:year], fields[:month], fields[:day], fields[:hour], fields[:minute], fields[:second]];
    }

    function decodeWall(a) {
        if (a == null) { return null; }
        var fields = a as Lang.Array;
        return { :year => fields[0], :month => fields[1], :day => fields[2], :hour => fields[3], :minute => fields[4], :second => fields[5] };
    }

    function encodeActive(a as Lang.Dictionary) as Lang.Array {
        return [a[:cycleId], a[:insertionUtc], encodeWall(a[:insertionWall]),
            a[:removalUtc], encodeWall(a[:removalWall]), a[:scheduledRemovalUtc],
            a[:scheduledInsertionUtc], a[:labelFourWeekUtc], a[:ringFreeCeilingUtc],
            a[:plannedOverrideUtc], a[:dstAdjustment], encodeIntervals(a[:temporaryOut] as Lang.Array)];
    }

    // Glance and reminders only need the currently open temporary interval.
    // Closed intervals remain in the full state for history and medical copy.
    function encodeReducedActive(a as Lang.Dictionary) as Lang.Array {
        var encoded = encodeActive(a);
        var intervals = a[:temporaryOut] as Lang.Array;
        var reduced = [];
        if (intervals.size() > 0) {
            var last = intervals[intervals.size() - 1] as Lang.Dictionary;
            if (last[:backInUtc] == null) {
                reduced.add([last[:outUtc], last[:backInUtc], last[:phaseWeekAtStart],
                    last[:phaseWeekAtEnd], last[:thresholdCode]]);
            }
        }
        encoded[11] = reduced;
        return encoded;
    }

    function decodeActive(a as Lang.Array) as Lang.Dictionary {
        return {
            :cycleId => a[0], :insertionUtc => a[1], :insertionWall => decodeWall(a[2]),
            :removalUtc => a[3], :removalWall => decodeWall(a[4]),
            :scheduledRemovalUtc => a[5], :scheduledInsertionUtc => a[6],
            :labelFourWeekUtc => a[7], :ringFreeCeilingUtc => a[8],
            :plannedOverrideUtc => a[9], :dstAdjustment => a[10],
            :temporaryOut => decodeIntervals(a[11] as Lang.Array)
        };
    }

    function encodeIntervals(intervals as Lang.Array) as Lang.Array {
        var encoded = [];
        for (var i = 0; i < intervals.size(); i += 1) {
            var t = intervals[i] as Lang.Dictionary;
            encoded.add([t[:outUtc], t[:backInUtc], t[:phaseWeekAtStart],
                t[:phaseWeekAtEnd], t[:thresholdCode]]);
        }
        return encoded;
    }

    function decodeIntervals(intervals as Lang.Array) as Lang.Array {
        var decoded = [];
        for (var i = 0; i < intervals.size(); i += 1) {
            var t = intervals[i] as Lang.Array;
            decoded.add({ :outUtc => t[0], :backInUtc => t[1],
                :phaseWeekAtStart => t[2], :phaseWeekAtEnd => t[3], :thresholdCode => t[4] });
        }
        return decoded;
    }

    function encodeHistory(h as Lang.Dictionary) as Lang.Array {
        var summary = h[:temporaryOutSummary] as Lang.Dictionary;
        return [h[:cycleId], h[:insertionUtc], h[:removalUtc], h[:nextInsertionUtc],
            h[:closeReason], h[:regimenDaysIn], h[:regimenDaysOut],
            encodeIntervals(h[:temporaryOut] as Lang.Array),
            [summary[:shortIntervalCount], summary[:shortIntervalSeconds]]];
    }

    function decodeHistory(h as Lang.Array) as Lang.Dictionary {
        var summary = h[8] as Lang.Array;
        return {
            :cycleId => h[0], :insertionUtc => h[1], :removalUtc => h[2],
            :nextInsertionUtc => h[3], :closeReason => h[4],
            :regimenDaysIn => h[5], :regimenDaysOut => h[6],
            :temporaryOut => decodeIntervals(h[7] as Lang.Array),
            :temporaryOutSummary => { :shortIntervalCount => summary[0], :shortIntervalSeconds => summary[1] }
        };
    }
}
