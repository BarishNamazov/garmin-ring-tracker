import Toybox.Application.Storage;
import Toybox.Lang;

// Foreground persistence uses compact positional records. Mirrors and history
// are staged before the canonical state, whose revision is the commit marker.
module RingStore {
    const STATE_KEY = "ringTrackerState";
    const GLANCE_KEY = "ringTrackerGlance";
    const BACKGROUND_KEY = "ringTrackerBackground";
    const RECOVERY_KEY = "ringTrackerRecovery";
    const MIRROR_ERROR_KEY = "ringTrackerMirrorError";
    const HISTORY_A0_KEY = "ringTrackerHistoryA0";
    const HISTORY_A1_KEY = "ringTrackerHistoryA1";
    const HISTORY_B0_KEY = "ringTrackerHistoryB0";
    const HISTORY_B1_KEY = "ringTrackerHistoryB1";
    const VALUE_BUDGET = 24576;

    var _lastSaveError = null;

    function lastSaveError() { return _lastSaveError; }

    function load() as Lang.Dictionary {
        var raw = Storage.getValue(STATE_KEY);
        if (raw == null) { return ScheduleModel.defaultState(); }

        try {
            if (!(raw instanceof Lang.Array) || (raw as Lang.Array).size() == 0) {
                return recover(raw, "invalid container");
            }
            var a = raw as Lang.Array;
            var version = a[0];
            if (version instanceof Lang.Number && version > ScheduleModel.SCHEMA_VERSION) {
                var future = ScheduleModel.defaultState();
                future[:readOnly] = true;
                return future;
            }
            var state;
            var migrated = false;
            if (version == 1) {
                state = migrateV2ToV3(migrateV1(a));
                migrated = true;
            } else if (version == 2) {
                state = decodeLegacyV2(a);
                if (a.size() >= 12 && a[10] > 0) {
                    state[:history] = loadLegacyHistory(a[9], a[10], a[11]);
                }
                state = migrateV2ToV3(state);
                migrated = true;
            } else if (version == ScheduleModel.SCHEMA_VERSION) {
                state = decodeState(a);
                if (a.size() >= 12 && a[10] > 0) {
                    state[:history] = loadHistory(a[9], a[10], a[11]);
                }
            } else {
                return recover(raw, "unknown schema");
            }
            if (!ScheduleModel.validState(state)) { return recover(raw, "invalid state"); }
            mergeBackgroundLedger(state);
            repairMirrors(state);
            if (migrated) { save(state); }
            return state;
        } catch (ex) {
            return recover(raw, "decode failed");
        }
    }

    function save(state as Lang.Dictionary) as Lang.Boolean {
        _lastSaveError = null;
        if (!ScheduleModel.validState(state)) {
            _lastSaveError = "validation";
            return false;
        }
        var revision = (state[:revision] as Lang.Number) + 1;
        var historyCount = (state[:history] as Lang.Array).size();
        var chunkCount = historyCount == 0 ? 0 : (historyCount == 1 ? 1 : 2);
        var canonical = encodeCanonical(state, revision, historyCount, chunkCount);
        while (!withinBudget(canonical)) {
            if (!compactOneActiveShort(state[:active])) {
                _lastSaveError = "size";
                return false;
            }
            canonical = encodeCanonical(state, revision, (state[:history] as Lang.Array).size(), 2);
        }
        var chunks = preparedHistoryChunks(state, revision);
        if (chunks == null) {
            _lastSaveError = "size";
            return false;
        }
        var glance = encodeGlance(state, revision);
        var background = encodeBackground(state, revision);
        if (!withinBudget(canonical) || !withinBudget(glance) || !withinBudget(background)) {
            _lastSaveError = "size";
            return false;
        }
        for (var c = 0; c < (chunks as Lang.Array).size(); c += 1) {
            if (!withinBudget((chunks as Lang.Array)[c])) { _lastSaveError = "size"; return false; }
        }
        try {
            var parity = revision % 2;
            Storage.setValue(historyKey(0, parity), (chunks as Lang.Array).size() > 0 ? (chunks as Lang.Array)[0] : [ScheduleModel.SCHEMA_VERSION, revision, []]);
            Storage.setValue(historyKey(1, parity), (chunks as Lang.Array).size() > 1 ? (chunks as Lang.Array)[1] : [ScheduleModel.SCHEMA_VERSION, revision, []]);
            Storage.setValue(GLANCE_KEY, glance);
            Storage.setValue(BACKGROUND_KEY, background);
            // Canonical state is deliberately last: reaching this write means
            // every record carrying its revision was already staged.
            Storage.setValue(STATE_KEY, canonical);
            state[:revision] = revision;
            return true;
        } catch (ex) {
            _lastSaveError = saveExceptionKind(ex);
            return false;
        }
    }

    function saveExceptionKind(ex) as Lang.String {
        return ex instanceof Lang.StorageFullException ? "storageFull" : "write";
    }

    function compactForStorage(state as Lang.Dictionary) as Lang.Boolean {
        // The canonical record excludes history, so it should already fit.
        // If a future field expansion crosses the budget, summarize eligible
        // active short intervals before refusing the write.
        while (!withinBudget(encodeCanonical(state, state[:revision],
                                              (state[:history] as Lang.Array).size(), 2))) {
            if (!compactOneActiveShort(state[:active])) { return false; }
        }
        return preparedHistoryChunks(state, state[:revision]) != null;
    }

    function preparedHistoryChunks(state as Lang.Dictionary, revision as Lang.Number) {
        // Encode once in the common path. If a value is too large, summarize
        // every legally compactable short interval in one pass and retry once;
        // repeatedly encoding a maximum state can trip the device watchdog.
        var chunks = encodeHistoryChunks(state[:history] as Lang.Array, revision);
        if (historyChunksFit(chunks)) { return chunks; }
        if (!compactAllHistoryShort(state)) { return null; }
        chunks = encodeHistoryChunks(state[:history] as Lang.Array, revision);
        return historyChunksFit(chunks) ? chunks : null;
    }

    function historyChunksFit(chunks as Lang.Array) as Lang.Boolean {
        if (chunks.size() > 2) { return false; }
        for (var i = 0; i < chunks.size(); i += 1) {
            if (!withinBudget(chunks[i])) { return false; }
        }
        return true;
    }

    function compactAllHistoryShort(state as Lang.Dictionary) as Lang.Boolean {
        var changed = false;
        var history = state[:history] as Lang.Array;
        for (var h = 0; h < history.size(); h += 1) {
            var cycle = history[h] as Lang.Dictionary;
            var intervals = cycle[:temporaryOut] as Lang.Array;
            var summary = cycle[:temporaryOutSummary] as Lang.Dictionary;
            var i = 0;
            while (i < intervals.size()) {
                var t = intervals[i] as Lang.Dictionary;
                if (t[:backInUtc] != null && t[:thresholdCode] instanceof Lang.String
                    && (t[:thresholdCode] as Lang.String).equals("under3h")) {
                    summary[:shortIntervalCount] += 1;
                    summary[:shortIntervalSeconds] += t[:backInUtc] - t[:outUtc];
                    intervals.remove(t);
                    changed = true;
                } else {
                    i += 1;
                }
            }
        }
        return changed;
    }

    function compactOneActiveShort(value) as Lang.Boolean {
        if (!(value instanceof Lang.Dictionary)) { return false; }
        var active = value as Lang.Dictionary;
        var intervals = active[:temporaryOut] as Lang.Array;
        var summary = active[:temporaryOutSummary] as Lang.Dictionary;
        for (var i = 0; i < intervals.size(); i += 1) {
            var t = intervals[i] as Lang.Dictionary;
            if (t[:backInUtc] != null && t[:thresholdCode] instanceof Lang.String
                && (t[:thresholdCode] as Lang.String).equals("under3h")) {
                summary[:shortIntervalCount] += 1;
                summary[:shortIntervalSeconds] += t[:backInUtc] - t[:outUtc];
                intervals.remove(t);
                return true;
            }
        }
        return false;
    }

    function compactOneHistoryShort(state as Lang.Dictionary) as Lang.Boolean {
        var history = state[:history] as Lang.Array;
        for (var h = 0; h < history.size(); h += 1) {
            var cycle = history[h] as Lang.Dictionary;
            var intervals = cycle[:temporaryOut] as Lang.Array;
            for (var i = 0; i < intervals.size(); i += 1) {
                var t = intervals[i] as Lang.Dictionary;
                if (t[:backInUtc] != null && t[:thresholdCode] instanceof Lang.String
                    && (t[:thresholdCode] as Lang.String).equals("under3h")) {
                    var summary = cycle[:temporaryOutSummary] as Lang.Dictionary;
                    summary[:shortIntervalCount] += 1;
                    summary[:shortIntervalSeconds] += t[:backInUtc] - t[:outUtc];
                    intervals.remove(t);
                    return true;
                }
            }
        }
        return false;
    }

    function withinBudget(value) as Lang.Boolean {
        return value.toString().length() < VALUE_BUDGET;
    }

    function stateSizeEstimate(state as Lang.Dictionary) as Lang.Number {
        return encodeCanonical(state, state[:revision], (state[:history] as Lang.Array).size(), 2).toString().length();
    }

    function historySizeEstimates(state as Lang.Dictionary) as Lang.Array {
        var chunks = encodeHistoryChunks(state[:history] as Lang.Array, state[:revision]);
        var result = [];
        for (var i = 0; i < chunks.size(); i += 1) { result.add(chunks[i].toString().length()); }
        return result;
    }

    function encodeHistoryChunks(history as Lang.Array, revision as Lang.Number) as Lang.Array {
        var midpoint = (history.size() + 1) / 2;
        var first = [];
        var second = [];
        for (var i = 0; i < history.size(); i += 1) {
            (i < midpoint ? first : second).add(encodeHistory(history[i] as Lang.Dictionary));
        }
        var chunks = [];
        if (first.size() > 0) { chunks.add([ScheduleModel.SCHEMA_VERSION, revision, first]); }
        if (second.size() > 0) { chunks.add([ScheduleModel.SCHEMA_VERSION, revision, second]); }
        return chunks;
    }

    function historyKey(chunk as Lang.Number, parity as Lang.Number) as Lang.String {
        if (chunk == 0) { return parity == 0 ? HISTORY_A0_KEY : HISTORY_A1_KEY; }
        return parity == 0 ? HISTORY_B0_KEY : HISTORY_B1_KEY;
    }

    function loadHistory(revision as Lang.Number, expectedCount as Lang.Number,
                         chunkCount as Lang.Number) as Lang.Array {
        if (expectedCount < 0 || expectedCount > ScheduleModel.MAX_HISTORY
            || chunkCount < 0 || chunkCount > 2) { throw new Lang.InvalidValueException("invalid history metadata"); }
        var result = [];
        var parity = revision % 2;
        for (var c = 0; c < chunkCount; c += 1) {
            var raw = Storage.getValue(historyKey(c, parity));
            if (!(raw instanceof Lang.Array)) { throw new Lang.InvalidValueException("missing history chunk"); }
            var a = raw as Lang.Array;
            if (a.size() != 3 || a[0] != ScheduleModel.SCHEMA_VERSION || a[1] != revision
                || !(a[2] instanceof Lang.Array)) { throw new Lang.InvalidValueException("invalid history chunk"); }
            var encoded = a[2] as Lang.Array;
            for (var i = 0; i < encoded.size(); i += 1) {
                result.add(decodeHistory(encoded[i] as Lang.Array));
            }
        }
        if (result.size() != expectedCount) { throw new Lang.InvalidValueException("history count mismatch"); }
        return result;
    }

    function loadLegacyHistory(revision as Lang.Number, expectedCount as Lang.Number,
                               chunkCount as Lang.Number) as Lang.Array {
        if (expectedCount < 0 || expectedCount > ScheduleModel.MAX_HISTORY
            || chunkCount < 0 || chunkCount > 2) { throw new Lang.InvalidValueException("invalid legacy history metadata"); }
        var result = [];
        var parity = revision % 2;
        for (var c = 0; c < chunkCount; c += 1) {
            var raw = Storage.getValue(historyKey(c, parity));
            if (!(raw instanceof Lang.Array)) { throw new Lang.InvalidValueException("missing legacy history chunk"); }
            var a = raw as Lang.Array;
            if (a.size() != 3 || a[0] != 2 || a[1] != revision
                || !(a[2] instanceof Lang.Array)) { throw new Lang.InvalidValueException("invalid legacy history chunk"); }
            var encoded = a[2] as Lang.Array;
            for (var i = 0; i < encoded.size(); i += 1) {
                result.add(decodeLegacyHistory(encoded[i] as Lang.Array));
            }
        }
        if (result.size() != expectedCount) { throw new Lang.InvalidValueException("legacy history count mismatch"); }
        return result;
    }

    function loadGlance() as Lang.Dictionary {
        var raw = Storage.getValue(GLANCE_KEY);
        if (!(raw instanceof Lang.Array)) {
            return { :active => null, :regimen => ScheduleModel.defaultRegimen() };
        }
        try {
            var a = raw as Lang.Array;
            if (!validGlanceRaw(a)) { return { :active => null, :regimen => ScheduleModel.defaultRegimen() }; }
            var compact = a[2] as Lang.Array?;
            var intervals = [];
            if (compact != null && compact[6] != null) {
                intervals.add({ :outUtc => compact[6], :backInUtc => null });
            }
            return {
                :active => compact == null ? null : { :temporaryOut => intervals },
                :regimen => { :daysIn => a[3], :daysOut => a[4] }
            };
        } catch (ex) {
            return { :active => null, :regimen => ScheduleModel.defaultRegimen() };
        }
    }

    function loadBackground() as Lang.Dictionary {
        var raw = Storage.getValue(BACKGROUND_KEY);
        try {
            if (!(raw instanceof Lang.Array) || !validBackgroundRaw(raw as Lang.Array)) { return backgroundDefault(); }
            var a = raw as Lang.Array;
            var r = a[5] as Lang.Array;
            return {
                :active => a[2] == null ? null : decodeReducedActive(a[2] as Lang.Array),
                :regimen => { :daysIn => a[3], :daysOut => a[4] },
                :reminders => {
                    :reminder1Hour => r[0], :reminder1Minute => r[1],
                    :reminder2Hour => r[2], :reminder2Minute => r[3],
                    :reminder2Enabled => r[4], :dayBeforeEnabled => r[5],
                    :overdueRepeatHours => r[6], :vibrationEnabled => r[7],
                    :soundEnabled => r[8], :clockFormat => r[9]
                },
                :reminderLedger => decodeLedger(a[6] as Lang.Array)
            };
        } catch (ex) { return backgroundDefault(); }
    }

    function saveBackgroundLedger(state as Lang.Dictionary) as Lang.Boolean {
        try {
            var raw = Storage.getValue(BACKGROUND_KEY);
            if (!(raw instanceof Lang.Array) || !validBackgroundRaw(raw as Lang.Array)) { return false; }
            var a = raw as Lang.Array;
            a[6] = encodeLedger(state[:reminderLedger] as Lang.Dictionary);
            Storage.setValue(BACKGROUND_KEY, a);
            return true;
        } catch (ex) { return false; }
    }

    function backgroundDefault() as Lang.Dictionary {
        return {
            :active => null,
            :regimen => ScheduleModel.defaultRegimen(),
            :reminders => ScheduleModel.defaultReminders(),
            :reminderLedger => ScheduleModel.defaultLedger()
        };
    }

    function encodeGlance(state as Lang.Dictionary, revision as Lang.Number) as Lang.Array {
        var regimen = state[:regimen] as Lang.Dictionary;
        var compact = null;
        if (state[:active] != null) {
            var active = state[:active] as Lang.Dictionary;
            var open = ScheduleModel.tempOpen(active);
            var deadline = active[:removalUtc] == null ? active[:removeDueUtc] : active[:insertDueUtc];
            var cycleEnd = active[:removalUtc] == null
                ? CalendarMath.addLocalCalendarDays(active[:removeDueUtc], regimen[:daysOut])[:utc]
                : active[:insertDueUtc];
            compact = [active[:insertionUtc], active[:removalUtc], deadline,
                cycleEnd, active[:labelFourWeekUtc],
                active[:ringFreeCeilingUtc], open == null ? null : open[:outUtc]];
        }
        return [ScheduleModel.SCHEMA_VERSION, revision, compact, regimen[:daysIn], regimen[:daysOut]];
    }

    function encodeBackground(state as Lang.Dictionary, revision as Lang.Number) as Lang.Array {
        var regimen = state[:regimen] as Lang.Dictionary;
        var reminders = state[:reminders] as Lang.Dictionary;
        var reduced = null;
        if (state[:active] != null) {
            var active = state[:active] as Lang.Dictionary;
            var open = ScheduleModel.tempOpen(active);
            var action = active[:removalUtc] != null ? 1 : (regimen[:daysOut] == 0 ? 2 : 0);
            var deadline = active[:removalUtc] == null ? active[:removeDueUtc] : active[:insertDueUtc];
            reduced = [active[:cycleId], active[:insertionUtc], active[:removalUtc],
                active[:removeDueUtc], active[:insertDueUtc], active[:labelFourWeekUtc],
                active[:ringFreeCeilingUtc], open == null ? null : open[:outUtc], action, deadline];
        }
        return [ScheduleModel.SCHEMA_VERSION, revision, reduced, regimen[:daysIn], regimen[:daysOut],
            [reminders[:reminder1Hour], reminders[:reminder1Minute],
                reminders[:reminder2Hour], reminders[:reminder2Minute],
                reminders[:reminder2Enabled], reminders[:dayBeforeEnabled],
                reminders[:overdueRepeatHours], reminders[:vibrationEnabled],
                reminders[:soundEnabled], reminders[:clockFormat]],
            encodeLedger(state[:reminderLedger] as Lang.Dictionary)];
    }

    function validGlanceRaw(a as Lang.Array) as Lang.Boolean {
        if (a.size() != 5 || a[0] != ScheduleModel.SCHEMA_VERSION
            || !(a[1] instanceof Lang.Number) || a[1] < 0
            || !ScheduleModel.numberBetween(a[3], 21, 35)
            || !ScheduleModel.numberBetween(a[4], 0, 7)) { return false; }
        if (a[2] == null) { return true; }
        if (!(a[2] instanceof Lang.Array) || (a[2] as Lang.Array).size() != 7) { return false; }
        var active = a[2] as Lang.Array;
        return active[0] instanceof Lang.Number && (active[1] == null || active[1] instanceof Lang.Number)
            && active[2] instanceof Lang.Number && active[3] instanceof Lang.Number
            && active[4] instanceof Lang.Number && (active[5] == null || active[5] instanceof Lang.Number)
            && (active[6] == null || active[6] instanceof Lang.Number);
    }

    function validBackgroundRaw(a as Lang.Array) as Lang.Boolean {
        if (a.size() != 7 || a[0] != ScheduleModel.SCHEMA_VERSION
            || !(a[1] instanceof Lang.Number) || a[1] < 0
            || !ScheduleModel.numberBetween(a[3], 21, 35)
            || !ScheduleModel.numberBetween(a[4], 0, 7)
            || !(a[5] instanceof Lang.Array) || (a[5] as Lang.Array).size() != 10
            || !(a[6] instanceof Lang.Array)
            || ((a[6] as Lang.Array).size() != 9 && (a[6] as Lang.Array).size() != 10)) { return false; }
        var r = a[5] as Lang.Array;
        var reminder = { :reminder1Hour=>r[0], :reminder1Minute=>r[1],
            :reminder2Hour=>r[2], :reminder2Minute=>r[3],
            :reminder2Enabled=>r[4], :dayBeforeEnabled=>r[5],
            :overdueRepeatHours=>r[6], :vibrationEnabled=>r[7],
            :soundEnabled=>r[8], :clockFormat=>r[9] };
        if (!ScheduleModel.validReminders(reminder)
            || !ScheduleModel.validLedger(decodeLedger(a[6] as Lang.Array))) { return false; }
        if (a[2] == null) { return true; }
        if (!(a[2] instanceof Lang.Array) || (a[2] as Lang.Array).size() != 10) { return false; }
        var active = a[2] as Lang.Array;
        if (!(ScheduleModel.numberBetween(active[0], 1, 2147483647)
            && active[1] instanceof Lang.Number && (active[2] == null || active[2] instanceof Lang.Number)
            && active[3] instanceof Lang.Number && (active[4] == null || active[4] instanceof Lang.Number)
            && active[5] instanceof Lang.Number && (active[6] == null || active[6] instanceof Lang.Number)
            && (active[7] == null || active[7] instanceof Lang.Number)
            && ScheduleModel.numberBetween(active[8], 0, 2) && active[9] instanceof Lang.Number)) { return false; }
        if (active[2] == null) {
            return active[4] == null && active[6] == null && active[9] == active[3]
                && active[8] == (a[4] == 0 ? 2 : 0);
        }
        return active[4] instanceof Lang.Number && active[6] instanceof Lang.Number
            && active[7] == null && active[8] == 1 && active[9] == active[4];
    }

    function canonicalRevision() as Lang.Number? {
        try {
            var raw = Storage.getValue(STATE_KEY);
            if (raw instanceof Lang.Array && (raw as Lang.Array).size() >= 10
                && (raw as Lang.Array)[0] == ScheduleModel.SCHEMA_VERSION
                && (raw as Lang.Array)[9] instanceof Lang.Number) { return (raw as Lang.Array)[9]; }
        } catch (ignored) { }
        return null;
    }

    function repairMirrors(state as Lang.Dictionary) as Void {
        var revision = state[:revision] as Lang.Number;
        try {
            var glance = Storage.getValue(GLANCE_KEY);
            if (!(glance instanceof Lang.Array) || !validGlanceRaw(glance as Lang.Array)
                || (glance as Lang.Array)[1] != revision) {
                Storage.setValue(GLANCE_KEY, encodeGlance(state, revision));
            }
            var background = Storage.getValue(BACKGROUND_KEY);
            if (!(background instanceof Lang.Array) || !validBackgroundRaw(background as Lang.Array)
                || (background as Lang.Array)[1] != revision) {
                Storage.setValue(BACKGROUND_KEY, encodeBackground(state, revision));
            }
            Storage.deleteValue(MIRROR_ERROR_KEY);
        } catch (ignored) { }
    }

    function mergeBackgroundLedger(state as Lang.Dictionary) as Void {
        try {
            var raw = Storage.getValue(BACKGROUND_KEY);
            if (!(raw instanceof Lang.Array) || !validBackgroundRaw(raw as Lang.Array)) { return; }
            var a = raw as Lang.Array;
            if (a[1] != state[:revision]) { return; }
            var stored = decodeLedger(a[6] as Lang.Array);
            var active = state[:active] as Lang.Dictionary?;
            if (active != null && stored[:cycleId] == active[:cycleId]) {
                state[:reminderLedger] = stored;
            }
        } catch (ignored) { }
    }

    function recover(raw, reason as Lang.String) as Lang.Dictionary {
        try {
            var sample = raw == null ? "null" : raw.toString();
            if (sample.length() > 256) { sample = sample.substring(0, 256); }
            Storage.setValue(RECOVERY_KEY, reason + ": " + sample);
            Storage.deleteValue(STATE_KEY);
            Storage.deleteValue(GLANCE_KEY);
            Storage.deleteValue(BACKGROUND_KEY);
        } catch (ignored) { }
        var fresh = ScheduleModel.defaultState();
        fresh[:loadError] = "recovered";
        return fresh;
    }

    function encodeCanonical(s as Lang.Dictionary, revision as Lang.Number,
                             historyCount as Lang.Number, chunkCount as Lang.Number) as Lang.Array {
        var regimen = s[:regimen] as Lang.Dictionary;
        var reminders = s[:reminders] as Lang.Dictionary;
        var sync = s[:settingsSync] as Lang.Dictionary;
        return [
            ScheduleModel.SCHEMA_VERSION, s[:nextCycleId], s[:setupStep],
            s[:active] == null ? null : encodeActive(s[:active] as Lang.Dictionary),
            [regimen[:daysIn], regimen[:daysOut]],
            encodeReminders(reminders),
            encodeLedger(s[:reminderLedger] as Lang.Dictionary), [],
            [sync[:lastSeenInsertionIso], sync[:lastAcceptedInsertionIso],
                sync[:lastWatchScheduleEditUtc], sync[:lastSettingsObservationUtc],
                sync[:pendingMirrorIso], sync[:pendingSettingsError], sync[:configSnapshot],
                sync[:pendingConfigSnapshot]],
            revision, historyCount, chunkCount, s[:migrationNoticePending]
        ];
    }

    function encodeState(s as Lang.Dictionary) as Lang.Array {
        var regimen = s[:regimen] as Lang.Dictionary;
        var reminders = s[:reminders] as Lang.Dictionary;
        var sync = s[:settingsSync] as Lang.Dictionary;
        var encodedHistory = [];
        var history = s[:history] as Lang.Array;
        for (var i = 0; i < history.size(); i += 1) {
            encodedHistory.add(encodeHistory(history[i] as Lang.Dictionary));
        }
        return [
            ScheduleModel.SCHEMA_VERSION, s[:nextCycleId], s[:setupStep],
            s[:active] == null ? null : encodeActive(s[:active] as Lang.Dictionary),
            [regimen[:daysIn], regimen[:daysOut]],
            encodeReminders(reminders),
            encodeLedger(s[:reminderLedger] as Lang.Dictionary), encodedHistory,
            [sync[:lastSeenInsertionIso], sync[:lastAcceptedInsertionIso],
                sync[:lastWatchScheduleEditUtc], sync[:lastSettingsObservationUtc],
                sync[:pendingMirrorIso], sync[:pendingSettingsError], sync[:configSnapshot],
                sync[:pendingConfigSnapshot]],
            s[:revision], 0, 0, s[:migrationNoticePending]
        ];
    }

    function decodeState(a as Lang.Array) as Lang.Dictionary {
        if (a.size() < 13 || !(a[4] instanceof Lang.Array) || !(a[5] instanceof Lang.Array)
            || !(a[6] instanceof Lang.Array) || !(a[7] instanceof Lang.Array)
            || !(a[8] instanceof Lang.Array)) { throw new Lang.InvalidValueException("invalid state shape"); }
        var regimen = a[4] as Lang.Array;
        var reminders = a[5] as Lang.Array;
        var sync = a[8] as Lang.Array;
        if (regimen.size() != 2 || reminders.size() != 10 || sync.size() != 8) {
            throw new Lang.InvalidValueException("invalid state fields");
        }
        var decodedHistory = [];
        var history = a[7] as Lang.Array;
        for (var i = 0; i < history.size(); i += 1) {
            decodedHistory.add(decodeHistory(history[i] as Lang.Array));
        }
        return {
            :schemaVersion => ScheduleModel.SCHEMA_VERSION,
            :nextCycleId => a[1], :setupStep => a[2],
            :active => a[3] == null ? null : decodeActive(a[3] as Lang.Array),
            :regimen => { :daysIn => regimen[0], :daysOut => regimen[1] },
            :reminders => decodeReminders(reminders),
            :reminderLedger => decodeLedger(a[6] as Lang.Array),
            :history => decodedHistory,
            :settingsSync => {
                :lastSeenInsertionIso => sync[0], :lastAcceptedInsertionIso => sync[1],
                :lastWatchScheduleEditUtc => sync[2], :lastSettingsObservationUtc => sync[3],
                :pendingMirrorIso => sync[4], :pendingSettingsError => sync[5],
                :configSnapshot => sync[6],
                :pendingConfigSnapshot => sync.size() > 7 ? sync[7] : null
            },
            :revision => a[9],
            :migrationNoticePending => a[12]
        };
    }

    // Schema 1 was the pre-revision form of schema 2. Decode it into the
    // legacy dictionary first so both legacy paths share one v3 migration.
    function migrateV1(a as Lang.Array) as Lang.Dictionary {
        if (a.size() < 9) { throw new Lang.InvalidValueException("invalid v1 state"); }
        var copy = [];
        copy.add(2);
        for (var i = 1; i < a.size(); i += 1) { copy.add(a[i]); }
        copy.add(0);
        return decodeLegacyV2(copy);
    }

    function decodeLegacyV2(a as Lang.Array) as Lang.Dictionary {
        if (a.size() < 10 || !(a[4] instanceof Lang.Array) || !(a[5] instanceof Lang.Array)
            || !(a[6] instanceof Lang.Array) || !(a[7] instanceof Lang.Array)
            || !(a[8] instanceof Lang.Array)) { throw new Lang.InvalidValueException("invalid v2 state shape"); }
        var regimen = a[4] as Lang.Array;
        var reminders = a[5] as Lang.Array;
        var sync = a[8] as Lang.Array;
        if (regimen.size() != 2 || reminders.size() != 6 || sync.size() < 7) {
            throw new Lang.InvalidValueException("invalid v2 state fields");
        }
        var decodedHistory = [];
        var history = a[7] as Lang.Array;
        for (var i = 0; i < history.size(); i += 1) {
            decodedHistory.add(decodeLegacyHistory(history[i] as Lang.Array));
        }
        return {
            :schemaVersion=>2, :nextCycleId=>a[1], :setupStep=>a[2],
            :active=>a[3] == null ? null : decodeLegacyActive(a[3] as Lang.Array),
            :regimen=>{:daysIn=>regimen[0], :daysOut=>regimen[1]},
            :reminders=>{:localHour=>reminders[0], :localMinute=>reminders[1],
                :overdueRepeatHours=>reminders[2], :vibrationEnabled=>reminders[3],
                :soundEnabled=>reminders[4], :clockFormat=>reminders[5]},
            :reminderLedger=>decodeLegacyLedger(a[6] as Lang.Array),
            :history=>decodedHistory,
            :settingsSync=>{:lastSeenInsertionIso=>sync[0], :lastAcceptedInsertionIso=>sync[1],
                :lastWatchScheduleEditUtc=>sync[2], :lastSettingsObservationUtc=>sync[3],
                :pendingMirrorIso=>sync[4], :pendingSettingsError=>sync[5],
                :configSnapshot=>sync[6], :pendingConfigSnapshot=>sync.size() > 7 ? sync[7] : null},
            :revision=>a[9]
        };
    }

    function migrateV2ToV3(legacy as Lang.Dictionary) as Lang.Dictionary {
        var state = ScheduleModel.defaultState();
        state[:nextCycleId] = legacy[:nextCycleId];
        state[:setupStep] = legacy[:setupStep];
        state[:regimen] = legacy[:regimen];
        state[:revision] = legacy[:revision];
        state[:migrationNoticePending] = true;
        var oldR = legacy[:reminders] as Lang.Dictionary;
        state[:reminders] = {
            :reminder1Hour=>oldR[:localHour], :reminder1Minute=>oldR[:localMinute],
            :reminder2Hour=>20, :reminder2Minute=>0, :reminder2Enabled=>false,
            :dayBeforeEnabled=>true, :overdueRepeatHours=>oldR[:overdueRepeatHours],
            :vibrationEnabled=>oldR[:vibrationEnabled], :soundEnabled=>oldR[:soundEnabled],
            :clockFormat=>oldR[:clockFormat]
        };
        var oldSync = legacy[:settingsSync] as Lang.Dictionary;
        state[:settingsSync] = {
            :lastSeenInsertionIso=>oldSync[:lastSeenInsertionIso],
            :lastAcceptedInsertionIso=>oldSync[:lastAcceptedInsertionIso],
            :lastWatchScheduleEditUtc=>oldSync[:lastWatchScheduleEditUtc],
            :lastSettingsObservationUtc=>oldSync[:lastSettingsObservationUtc],
            :pendingMirrorIso=>oldSync[:pendingMirrorIso],
            :pendingSettingsError=>oldSync[:pendingSettingsError],
            :configSnapshot=>migrateConfig(oldSync[:configSnapshot]),
            :pendingConfigSnapshot=>migrateConfig(oldSync[:pendingConfigSnapshot])
        };

        var oldHistory = legacy[:history] as Lang.Array;
        var history = [];
        for (var h = 0; h < oldHistory.size(); h += 1) {
            history.add(migrateHistory(oldHistory[h] as Lang.Dictionary));
        }
        state[:history] = history;
        var oldActive = legacy[:active] as Lang.Dictionary?;
        if (oldActive != null) { state[:active] = migrateActive(oldActive, state[:regimen] as Lang.Dictionary); }

        // Stitch retained insertions only across an observed contiguous close.
        for (var i = 1; i < history.size(); i += 1) {
            stitchInsertion(history[i - 1] as Lang.Dictionary, history[i] as Lang.Dictionary);
        }
        if (history.size() > 0 && state[:active] != null) {
            stitchInsertion(history[history.size() - 1] as Lang.Dictionary,
                state[:active] as Lang.Dictionary);
        }

        var oldLedger = legacy[:reminderLedger] as Lang.Dictionary;
        var ledger = ScheduleModel.defaultLedger();
        ledger[:cycleId] = oldLedger[:cycleId];
        ledger[:dayBeforeSent] = oldLedger[:dayBeforeSent];
        ledger[:dayOf1Sent] = oldLedger[:dayOfSent];
        ledger[:dayOf2Sent] = oldLedger[:dayOfSent];
        ledger[:lastOverdueSlot] = oldLedger[:lastOverdueSlot];
        ledger[:labelFourWeekSent] = oldLedger[:labelFourWeekSent];
        ledger[:ringFreeExceededSent] = oldLedger[:ringFreeExceededSent];
        if (state[:active] != null) {
            var open = ScheduleModel.tempOpen(state[:active] as Lang.Dictionary);
            if (open != null && oldLedger[:lastTempOutSlot] != null) {
                ledger[:lastTempOutSlot] = oldLedger[:lastTempOutSlot];
                ledger[:tempOutIdentity] = (open as Lang.Dictionary)[:outUtc];
            }
            var status = ScheduleModel.deriveStatus((state[:active] as Lang.Dictionary)[:insertionUtc],
                state[:active] as Lang.Dictionary, state[:regimen] as Lang.Dictionary);
            var newKey = ReminderPolicy.actionKey(status);
            ledger[:actionKey] = newKey;
            if (!(oldLedger[:actionKey] as Lang.String).equals(newKey)) {
                ledger[:dayBeforeSent] = false; ledger[:dayOf1Sent] = false;
                ledger[:dayOf2Sent] = false; ledger[:lastOverdueSlot] = null;
            }
        }
        state[:reminderLedger] = ledger;
        return state;
    }

    function migrateConfig(value) {
        if (value == null) { return null; }
        if (!(value instanceof Lang.Array) || (value as Lang.Array).size() != 8) {
            throw new Lang.InvalidValueException("invalid v2 config");
        }
        var a = value as Lang.Array;
        return [a[0], a[1], 20, 0, false, true, a[2], a[3], a[4], a[5], a[6], a[7]];
    }

    function migrateActive(old as Lang.Dictionary, regimen as Lang.Dictionary) as Lang.Dictionary {
        var active = ScheduleModel.newCycle(old[:cycleId], old[:insertionUtc], regimen);
        active[:insertionWall] = old[:insertionWall];
        active[:removeDueUtc] = old[:scheduledRemovalUtc];
        active[:removalUtc] = old[:removalUtc]; active[:removalWall] = old[:removalWall];
        active[:temporaryOut] = old[:temporaryOut]; active[:temporaryOutSummary] = old[:temporaryOutSummary];
        active[:dstAdjustment] = old[:dstAdjustment];
        if (old[:removalUtc] != null) {
            active[:removalDeltaSeconds] = old[:removalUtc] - active[:removeDueUtc];
            active[:insertDueUtc] = CalendarMath.addLocalCalendarDays(old[:removalUtc], regimen[:daysOut])[:utc];
            active[:ringFreeCeilingUtc] = CalendarMath.addLocalCalendarDays(old[:removalUtc], 7)[:utc];
        }
        return active;
    }

    function migrateHistory(old as Lang.Dictionary) as Lang.Dictionary {
        var removeDue = CalendarMath.addLocalCalendarDays(old[:insertionUtc], old[:regimenDaysIn])[:utc];
        var insertDue = old[:removalUtc] == null ? null
            : CalendarMath.addLocalCalendarDays(old[:removalUtc], old[:regimenDaysOut])[:utc];
        var expected = old[:removalUtc] == null ? removeDue : insertDue;
        return {:cycleId=>old[:cycleId], :insertionUtc=>old[:insertionUtc],
            :insertionPlanUtc=>null, :insertionDeltaSeconds=>null,
            :removeDueUtc=>removeDue, :removalUtc=>old[:removalUtc],
            :removalDeltaSeconds=>old[:removalUtc] == null ? null : old[:removalUtc] - removeDue,
            :insertDueUtc=>insertDue, :nextInsertionUtc=>old[:nextInsertionUtc],
            :nextInsertionDeltaSeconds=>old[:nextInsertionUtc] == null ? null : old[:nextInsertionUtc] - expected,
            :closeReason=>old[:closeReason], :regimenDaysIn=>old[:regimenDaysIn],
            :regimenDaysOut=>old[:regimenDaysOut], :temporaryOut=>old[:temporaryOut],
            :temporaryOutSummary=>old[:temporaryOutSummary]};
    }

    function stitchInsertion(previous as Lang.Dictionary, current as Lang.Dictionary) as Void {
        if (previous[:nextInsertionUtc] == current[:insertionUtc]) {
            var due = previous[:removalUtc] == null ? previous[:removeDueUtc] : previous[:insertDueUtc];
            current[:insertionPlanUtc] = due;
            current[:insertionDeltaSeconds] = current[:insertionUtc] - due;
        }
    }

    function encodeLedger(l as Lang.Dictionary) as Lang.Array {
        return [l[:cycleId], l[:actionKey], l[:dayBeforeSent], l[:dayOf1Sent], l[:dayOf2Sent],
            l[:lastOverdueSlot], l[:lastTempOutSlot], l[:labelFourWeekSent],
            l[:ringFreeExceededSent], l[:tempOutIdentity]];
    }

    function decodeLedger(a as Lang.Array) as Lang.Dictionary {
        if (a.size() != 9 && a.size() != 10) { throw new Lang.InvalidValueException("invalid ledger"); }
        return { :cycleId=>a[0], :actionKey=>a[1], :dayBeforeSent=>a[2],
            :dayOf1Sent=>a[3], :dayOf2Sent=>a[4], :lastOverdueSlot=>a[5],
            :lastTempOutSlot=>a.size() == 10 ? a[6] : null,
            :labelFourWeekSent=>a[7], :ringFreeExceededSent=>a[8],
            :tempOutIdentity=>a.size() == 10 ? a[9] : null };
    }

    function decodeLegacyLedger(a as Lang.Array) as Lang.Dictionary {
        if (a.size() != 8) { throw new Lang.InvalidValueException("invalid legacy ledger"); }
        return {:cycleId=>a[0], :actionKey=>a[1], :dayBeforeSent=>a[2], :dayOfSent=>a[3],
            :lastOverdueSlot=>a[4], :lastTempOutSlot=>a[5],
            :labelFourWeekSent=>a[6], :ringFreeExceededSent=>a[7]};
    }

    function encodeReminders(r as Lang.Dictionary) as Lang.Array {
        return [r[:reminder1Hour], r[:reminder1Minute], r[:reminder2Hour],
            r[:reminder2Minute], r[:reminder2Enabled], r[:dayBeforeEnabled],
            r[:overdueRepeatHours], r[:vibrationEnabled], r[:soundEnabled], r[:clockFormat]];
    }

    function decodeReminders(a as Lang.Array) as Lang.Dictionary {
        return {:reminder1Hour=>a[0], :reminder1Minute=>a[1],
            :reminder2Hour=>a[2], :reminder2Minute=>a[3], :reminder2Enabled=>a[4],
            :dayBeforeEnabled=>a[5], :overdueRepeatHours=>a[6],
            :vibrationEnabled=>a[7], :soundEnabled=>a[8], :clockFormat=>a[9]};
    }

    function encodeWall(value) {
        if (value == null) { return null; }
        var w = value as Lang.Dictionary;
        return [w[:year], w[:month], w[:day], w[:hour], w[:minute], w[:second]];
    }

    function decodeWall(value) {
        if (value == null) { return null; }
        if (!(value instanceof Lang.Array) || (value as Lang.Array).size() != 6) {
            throw new Lang.InvalidValueException("invalid wall tuple");
        }
        var a = value as Lang.Array;
        return { :year=>a[0], :month=>a[1], :day=>a[2], :hour=>a[3], :minute=>a[4], :second=>a[5] };
    }

    function encodeActive(a as Lang.Dictionary) as Lang.Array {
        var summary = a[:temporaryOutSummary] as Lang.Dictionary;
        return [a[:cycleId], a[:insertionUtc], encodeWall(a[:insertionWall]),
            a[:insertionPlanUtc], a[:insertionDeltaSeconds], a[:removalUtc],
            encodeWall(a[:removalWall]), a[:removeDueUtc], a[:removalDeltaSeconds],
            a[:insertDueUtc], a[:labelFourWeekUtc], a[:ringFreeCeilingUtc],
            a[:dstAdjustment], encodeIntervals(a[:temporaryOut] as Lang.Array),
            [summary[:shortIntervalCount], summary[:shortIntervalSeconds]]];
    }

    function decodeActive(a as Lang.Array) as Lang.Dictionary {
        if (a.size() != 15 || !(a[13] instanceof Lang.Array)
            || !(a[14] instanceof Lang.Array) || (a[14] as Lang.Array).size() != 2) {
            throw new Lang.InvalidValueException("invalid active record");
        }
        var summary = a[14] as Lang.Array;
        return {
            :cycleId=>a[0], :insertionUtc=>a[1], :insertionWall=>decodeWall(a[2]),
            :insertionPlanUtc=>a[3], :insertionDeltaSeconds=>a[4],
            :removalUtc=>a[5], :removalWall=>decodeWall(a[6]), :removeDueUtc=>a[7],
            :removalDeltaSeconds=>a[8], :insertDueUtc=>a[9],
            :labelFourWeekUtc=>a[10], :ringFreeCeilingUtc=>a[11], :dstAdjustment=>a[12],
            :temporaryOut=>decodeIntervals(a[13] as Lang.Array),
            :temporaryOutSummary=>{:shortIntervalCount=>summary[0], :shortIntervalSeconds=>summary[1]}
        };
    }

    function decodeLegacyActive(a as Lang.Array) as Lang.Dictionary {
        if (a.size() < 12 || !(a[11] instanceof Lang.Array)) {
            throw new Lang.InvalidValueException("invalid legacy active record");
        }
        var summary = a.size() > 13 && a[13] instanceof Lang.Array ? a[13] as Lang.Array : [0, 0];
        return {:cycleId=>a[0], :insertionUtc=>a[1], :insertionWall=>decodeWall(a[2]),
            :removalUtc=>a[3], :removalWall=>decodeWall(a[4]),
            :scheduledRemovalUtc=>a[5], :scheduledInsertionUtc=>a[6],
            :labelFourWeekUtc=>a[7], :ringFreeCeilingUtc=>a[8],
            :plannedOverrideUtc=>a[9], :dstAdjustment=>a[10],
            :temporaryOut=>decodeIntervals(a[11] as Lang.Array),
            :finalInsertionUtc=>a.size() > 12 ? a[12] : null,
            :temporaryOutSummary=>{:shortIntervalCount=>summary[0], :shortIntervalSeconds=>summary[1]}};
    }

    function decodeReducedActive(a as Lang.Array) as Lang.Dictionary {
        var intervals = [];
        if (a[7] != null) { intervals.add({:outUtc=>a[7], :backInUtc=>null}); }
        return {:cycleId=>a[0], :insertionUtc=>a[1], :removalUtc=>a[2],
            :removeDueUtc=>a[3], :insertDueUtc=>a[4], :labelFourWeekUtc=>a[5],
            :ringFreeCeilingUtc=>a[6], :temporaryOut=>intervals};
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
            if (!(intervals[i] instanceof Lang.Array) || (intervals[i] as Lang.Array).size() != 5) {
                throw new Lang.InvalidValueException("invalid interval");
            }
            var t = intervals[i] as Lang.Array;
            decoded.add({:outUtc=>t[0], :backInUtc=>t[1], :phaseWeekAtStart=>t[2],
                :phaseWeekAtEnd=>t[3], :thresholdCode=>t[4]});
        }
        return decoded;
    }

    function encodeHistory(h as Lang.Dictionary) as Lang.Array {
        var summary = h[:temporaryOutSummary] as Lang.Dictionary;
        return [h[:cycleId], h[:insertionUtc], h[:insertionPlanUtc],
            h[:insertionDeltaSeconds], h[:removeDueUtc], h[:removalUtc],
            h[:removalDeltaSeconds], h[:insertDueUtc], h[:nextInsertionUtc],
            h[:nextInsertionDeltaSeconds], h[:closeReason], h[:regimenDaysIn], h[:regimenDaysOut],
            encodeIntervals(h[:temporaryOut] as Lang.Array),
            [summary[:shortIntervalCount], summary[:shortIntervalSeconds]]];
    }

    function decodeHistory(h as Lang.Array) as Lang.Dictionary {
        if (h.size() != 15 || !(h[13] instanceof Lang.Array) || !(h[14] instanceof Lang.Array)
            || (h[14] as Lang.Array).size() != 2) { throw new Lang.InvalidValueException("invalid history record"); }
        var summary = h[14] as Lang.Array;
        return {:cycleId=>h[0], :insertionUtc=>h[1], :insertionPlanUtc=>h[2],
            :insertionDeltaSeconds=>h[3], :removeDueUtc=>h[4], :removalUtc=>h[5],
            :removalDeltaSeconds=>h[6], :insertDueUtc=>h[7], :nextInsertionUtc=>h[8],
            :nextInsertionDeltaSeconds=>h[9], :closeReason=>h[10], :regimenDaysIn=>h[11],
            :regimenDaysOut=>h[12], :temporaryOut=>decodeIntervals(h[13] as Lang.Array),
            :temporaryOutSummary=>{:shortIntervalCount=>summary[0], :shortIntervalSeconds=>summary[1]}};
    }

    function decodeLegacyHistory(h as Lang.Array) as Lang.Dictionary {
        if (h.size() != 9 || !(h[7] instanceof Lang.Array) || !(h[8] instanceof Lang.Array)
            || (h[8] as Lang.Array).size() != 2) {
            throw new Lang.InvalidValueException("invalid legacy history record");
        }
        var summary = h[8] as Lang.Array;
        return {:cycleId=>h[0], :insertionUtc=>h[1], :removalUtc=>h[2],
            :nextInsertionUtc=>h[3], :closeReason=>h[4], :regimenDaysIn=>h[5],
            :regimenDaysOut=>h[6], :temporaryOut=>decodeIntervals(h[7] as Lang.Array),
            :temporaryOutSummary=>{:shortIntervalCount=>summary[0], :shortIntervalSeconds=>summary[1]}};
    }
}
