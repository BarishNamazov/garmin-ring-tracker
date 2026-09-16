import Toybox.Math;
import Toybox.Lang;

// State transition and derivation logic. It is storage-agnostic and receives
// nowUtc explicitly so tests and debug scenarios never depend on wall time.
module ScheduleModel {
    const SCHEMA_VERSION = 3;
    const MAX_HISTORY = 24;
    const MAX_TEMP_INTERVALS = 32;
    const TEMP_LIMIT_SECONDS = 10800;

    function defaultRegimen() as Lang.Dictionary {
        return { :daysIn => 21, :daysOut => 7 };
    }

    function defaultReminders() as Lang.Dictionary {
        return {
            :reminder1Hour => 9,
            :reminder1Minute => 0,
            :reminder2Hour => 20,
            :reminder2Minute => 0,
            :reminder2Enabled => false,
            :dayBeforeEnabled => true,
            :overdueRepeatHours => 6,
            :vibrationEnabled => true,
            :soundEnabled => false,
            :clockFormat => 0
        };
    }

    function defaultLedger() as Lang.Dictionary {
        return {
            :cycleId => 0,
            :actionKey => "",
            :dayBeforeSent => false,
            :dayOf1Sent => false,
            :dayOf2Sent => false,
            :lastOverdueSlot => null,
            :lastTempOutSlot => null,
            :tempOutIdentity => null,
            :labelFourWeekSent => false,
            :ringFreeExceededSent => false
        };
    }

    function defaultState() as Lang.Dictionary {
        return {
            :schemaVersion => SCHEMA_VERSION,
            :nextCycleId => 1,
            :setupStep => 0,
            :active => null,
            :regimen => defaultRegimen(),
            :reminders => defaultReminders(),
            :reminderLedger => defaultLedger(),
            :history => [],
            :settingsSync => {
                :lastSeenInsertionIso => "",
                :lastAcceptedInsertionIso => "",
                :lastWatchScheduleEditUtc => 0,
                :lastSettingsObservationUtc => 0,
                :pendingMirrorIso => null,
                :pendingSettingsError => null,
                :configSnapshot => null,
                :pendingConfigSnapshot => null
            },
            :revision => 0,
            :migrationNoticePending => false
        };
    }

    function validRegimen(regimen) {
        return regimen instanceof Lang.Dictionary
            && regimen[:daysIn] instanceof Lang.Number
            && regimen[:daysOut] instanceof Lang.Number
            && regimen[:daysIn] >= 21 && regimen[:daysIn] <= 35
            && regimen[:daysOut] >= 0 && regimen[:daysOut] <= 7;
    }

    function newCycle(cycleId as Lang.Number, insertionUtc as Lang.Number, regimen as Lang.Dictionary) as Lang.Dictionary {
        var removal = CalendarMath.addLocalCalendarDays(insertionUtc, regimen[:daysIn]);
        var label = CalendarMath.addLocalCalendarDays(insertionUtc, 28);
        var wall = CalendarMath.localFields(insertionUtc);
        return {
            :cycleId => cycleId,
            :insertionUtc => insertionUtc,
            :insertionWall => wall,
            :insertionPlanUtc => null,
            :insertionDeltaSeconds => null,
            :removalUtc => null,
            :removalWall => null,
            :removeDueUtc => removal[:utc],
            :removalDeltaSeconds => null,
            :insertDueUtc => null,
            :labelFourWeekUtc => label[:utc],
            :ringFreeCeilingUtc => null,
            :dstAdjustment => (removal[:adjusted] || label[:adjusted]) ? "advancedToValidLocalTime" : null,
            :temporaryOut => [],
            :temporaryOutSummary => { :shortIntervalCount => 0, :shortIntervalSeconds => 0 }
        };
    }

    function tempOpen(active as Lang.Dictionary) as Lang.Dictionary? {
        var intervals = active[:temporaryOut] as Lang.Array;
        if (!(intervals instanceof Lang.Array) || intervals.size() == 0) { return null; }
        var last = intervals[intervals.size() - 1] as Lang.Dictionary;
        return last[:backInUtc] == null ? last : null;
    }

    function deriveStatus(nowUtc as Lang.Number, active as Lang.Dictionary?, regimen as Lang.Dictionary) as Lang.Dictionary {
        if (active == null) {
            return {
                :phase => :setup,
                :overdueKind => null,
                :temporaryOutOpen => false,
                :dayOfCycle => null,
                :nextAction => :setUp,
                :actionDueUtc => null,
                :nextActionUtc => null,
                :secondsRemaining => null,
                :displayDays => 0,
                :displayHours => 0,
                :ringFreeOverSevenDays => false,
                :ringInOverFourWeeks => false,
                :clockBeforeInsertion => false,
                :tempElapsed => null,
                :tempBoundary => null,
                :underlyingAction => :setUp,
                :underlyingActionUtc => null,
                :underlyingSecondsRemaining => null
            };
        }

        var removed = active[:removalUtc] != null;
        var deadline = removed ? active[:insertDueUtc] : active[:removeDueUtc];
        var action = removed ? :insert : (regimen[:daysOut] == 0 ? :replace : :remove);
        var underlyingDeadline = deadline;
        var underlyingAction = action;
        var phase = :ringIn;
        var overdueKind = null;
        if (removed) { phase = nowUtc < deadline ? :ringFree : :overdue; }
        else if (nowUtc >= deadline) { phase = :overdue; }
        if (phase == :overdue) { overdueKind = action; }

        var open = tempOpen(active);
        var tempElapsed = open == null ? null : (nowUtc - open[:outUtc] < 0 ? 0 : nowUtc - open[:outUtc]);
        var tempBoundary = null;
        if (tempElapsed != null) {
            tempBoundary = tempElapsed > TEMP_LIMIT_SECONDS ? :over : (tempElapsed == TEMP_LIMIT_SECONDS ? :at : :under);
            action = :ringBackIn;
            deadline = open[:outUtc] + TEMP_LIMIT_SECONDS;
        }

        var delta = deadline - nowUtc;
        var cd = CalendarMath.countdown(delta);
        return {
            :phase => phase,
            :overdueKind => overdueKind,
            :temporaryOutOpen => open != null,
            :dayOfCycle => CalendarMath.dayOfCycle(nowUtc, active[:insertionUtc]),
            :nextAction => action,
            :actionDueUtc => deadline,
            :nextActionUtc => deadline,
            :secondsRemaining => delta,
            :displayDays => cd[:days],
            :displayHours => cd[:hours],
            :ringFreeOverSevenDays => removed && active[:ringFreeCeilingUtc] != null && nowUtc > active[:ringFreeCeilingUtc],
            :ringInOverFourWeeks => !removed && nowUtc > active[:labelFourWeekUtc],
            :clockBeforeInsertion => nowUtc < active[:insertionUtc],
            :tempElapsed => tempElapsed,
            :tempBoundary => tempBoundary,
            :underlyingAction => underlyingAction,
            :underlyingActionUtc => underlyingDeadline,
            :underlyingSecondsRemaining => underlyingDeadline - nowUtc
        };
    }

    function phaseWeek(active as Lang.Dictionary, utcSeconds as Lang.Number) as Lang.Number? {
        var day = CalendarMath.dayOfCycle(utcSeconds, active[:insertionUtc]);
        if (day >= 1 && day <= 7) { return 1; }
        if (day <= 14) { return 2; }
        if (day <= 21) { return 3; }
        return null;
    }

    function recordRemoval(active as Lang.Dictionary, removalUtc as Lang.Number, regimen as Lang.Dictionary) as Lang.Boolean {
        if (!validRemovalEdit(active, removalUtc)) { return false; }
        var open = tempOpen(active);
        if (open != null) {
            open[:backInUtc] = removalUtc;
            open[:phaseWeekAtEnd] = phaseWeek(active, removalUtc);
            open[:thresholdCode] = thresholdCode(removalUtc - open[:outUtc]);
        }
        active[:removalUtc] = removalUtc;
        active[:removalWall] = CalendarMath.localFields(removalUtc);
        active[:removalDeltaSeconds] = removalUtc - active[:removeDueUtc];
        var insertion = CalendarMath.addLocalCalendarDays(removalUtc, regimen[:daysOut]);
        active[:insertDueUtc] = insertion[:utc];
        var ceiling = CalendarMath.addLocalCalendarDays(removalUtc, 7);
        active[:ringFreeCeilingUtc] = ceiling[:utc];
        active[:dstAdjustment] = (insertion[:adjusted] || ceiling[:adjusted])
            ? "advancedToValidLocalTime" : null;
        return true;
    }

    function recomputeForRegimen(active as Lang.Dictionary, regimen as Lang.Dictionary) as Lang.Boolean {
        var removal = CalendarMath.addLocalCalendarDays(active[:insertionUtc], regimen[:daysIn]);
        var label = CalendarMath.addLocalCalendarDays(active[:insertionUtc], 28);
        active[:removeDueUtc] = removal[:utc];
        active[:labelFourWeekUtc] = label[:utc];
        var adjusted = removal[:adjusted] || label[:adjusted];
        if (active[:removalUtc] == null) {
            active[:removalDeltaSeconds] = null;
            active[:insertDueUtc] = null;
            active[:ringFreeCeilingUtc] = null;
        } else {
            active[:removalDeltaSeconds] = active[:removalUtc] - active[:removeDueUtc];
            var insertion = CalendarMath.addLocalCalendarDays(active[:removalUtc], regimen[:daysOut]);
            var ceiling = CalendarMath.addLocalCalendarDays(active[:removalUtc], 7);
            active[:insertDueUtc] = insertion[:utc];
            active[:ringFreeCeilingUtc] = ceiling[:utc];
            adjusted = adjusted || insertion[:adjusted] || ceiling[:adjusted];
        }
        active[:dstAdjustment] = adjusted ? "advancedToValidLocalTime" : null;
        return adjusted;
    }

    function startTemporaryOut(active as Lang.Dictionary, outUtc as Lang.Number) as Lang.Boolean {
        if (tempOpen(active) != null || outUtc < active[:insertionUtc] || active[:removalUtc] != null) { return false; }
        var intervals = active[:temporaryOut] as Lang.Array;
        if (intervals.size() >= MAX_TEMP_INTERVALS && !compactActiveIntervals(active, 1)) { return false; }
        intervals.add({
            :outUtc => outUtc,
            :backInUtc => null,
            :phaseWeekAtStart => phaseWeek(active, outUtc),
            :phaseWeekAtEnd => null,
            :thresholdCode => null
        });
        return true;
    }

    // Make room for a new real event without losing any exact/over-threshold
    // interval. Only the oldest closed under-three-hour records are folded
    // into the active-cycle summary.
    function compactActiveIntervals(active as Lang.Dictionary, slotsNeeded as Lang.Number) as Lang.Boolean {
        var intervals = active[:temporaryOut] as Lang.Array;
        var summary = active[:temporaryOutSummary] as Lang.Dictionary;
        while (intervals.size() + slotsNeeded > MAX_TEMP_INTERVALS) {
            var compactIndex = -1;
            for (var i = 0; i < intervals.size(); i += 1) {
                var interval = intervals[i] as Lang.Dictionary;
                if (interval[:backInUtc] != null && interval[:thresholdCode] instanceof Lang.String
                    && (interval[:thresholdCode] as Lang.String).equals("under3h")) {
                    compactIndex = i;
                    break;
                }
            }
            if (compactIndex < 0) { return false; }
            var removed = intervals[compactIndex] as Lang.Dictionary;
            summary[:shortIntervalCount] += 1;
            summary[:shortIntervalSeconds] += removed[:backInUtc] - removed[:outUtc];
            intervals.remove(removed);
        }
        return true;
    }

    function endTemporaryOut(active as Lang.Dictionary, backInUtc as Lang.Number) as Lang.Boolean {
        var open = tempOpen(active);
        if (open == null || backInUtc < open[:outUtc]) { return false; }
        open[:backInUtc] = backInUtc;
        open[:phaseWeekAtEnd] = phaseWeek(active, backInUtc);
        open[:thresholdCode] = thresholdCode(backInUtc - open[:outUtc]);
        return true;
    }

    function thresholdCode(seconds as Lang.Number) as Lang.String {
        if (seconds > TEMP_LIMIT_SECONDS) { return "over3h"; }
        if (seconds == TEMP_LIMIT_SECONDS) { return "at3h"; }
        return "under3h";
    }

    function archiveCycle(state as Lang.Dictionary, nextInsertionUtc as Lang.Number, reason as Lang.String) as Void {
        var active = state[:active] as Lang.Dictionary?;
        if (active == null) { return; }
        var history = state[:history] as Lang.Array<Lang.Dictionary>;
        var regimen = state[:regimen] as Lang.Dictionary;
        var compact = compactIntervals(active[:temporaryOut] as Lang.Array);
        var activeSummary = active[:temporaryOutSummary] as Lang.Dictionary;
        var expected = active[:removalUtc] == null ? active[:removeDueUtc] : active[:insertDueUtc];
        history.add({
            :cycleId => active[:cycleId],
            :insertionUtc => active[:insertionUtc],
            :insertionPlanUtc => active[:insertionPlanUtc],
            :insertionDeltaSeconds => active[:insertionDeltaSeconds],
            :removeDueUtc => active[:removeDueUtc],
            :removalUtc => active[:removalUtc],
            :removalDeltaSeconds => active[:removalDeltaSeconds],
            :insertDueUtc => active[:insertDueUtc],
            :nextInsertionUtc => nextInsertionUtc,
            :nextInsertionDeltaSeconds => nextInsertionUtc - expected,
            :closeReason => reason,
            :regimenDaysIn => regimen[:daysIn],
            :regimenDaysOut => regimen[:daysOut],
            :temporaryOut => compact[:retained],
            :temporaryOutSummary => {
                :shortIntervalCount => compact[:shortCount] + activeSummary[:shortIntervalCount],
                :shortIntervalSeconds => compact[:shortSeconds] + activeSummary[:shortIntervalSeconds]
            }
        });
        while (history.size() > MAX_HISTORY) { history.remove(history[0]); }
    }

    // Closed cycles retain every boundary/over-boundary interval and the eight
    // most recent short intervals. Older short intervals become an aggregate,
    // keeping the persisted document comfortably below Storage's value limit.
    function compactIntervals(intervals as Lang.Array) as Lang.Dictionary {
        var shortTotal = 0;
        for (var i = 0; i < intervals.size(); i += 1) {
            var candidate = intervals[i] as Lang.Dictionary;
            if (candidate[:backInUtc] != null && candidate[:thresholdCode].equals("under3h")) {
                shortTotal += 1;
            }
        }
        var summarizeBefore = shortTotal > 8 ? shortTotal - 8 : 0;
        var shortSeen = 0;
        var summarizedCount = 0;
        var summarizedSeconds = 0;
        var retained = [];
        for (var j = 0; j < intervals.size(); j += 1) {
            var interval = intervals[j] as Lang.Dictionary;
            var isShort = interval[:backInUtc] != null && interval[:thresholdCode].equals("under3h");
            if (isShort && shortSeen < summarizeBefore) {
                summarizedCount += 1;
                summarizedSeconds += interval[:backInUtc] - interval[:outUtc];
            } else {
                retained.add(interval);
            }
            if (isShort) { shortSeen += 1; }
        }
        return { :retained => retained, :shortCount => summarizedCount, :shortSeconds => summarizedSeconds };
    }

    function insertOrReplace(state as Lang.Dictionary, insertionUtc as Lang.Number) as Lang.Dictionary {
        var insertionPlan = null;
        if (state[:active] != null) {
            var previous = state[:active] as Lang.Dictionary;
            var open = tempOpen(previous);
            if (open != null && insertionUtc >= open[:outUtc]) {
                endTemporaryOut(previous, insertionUtc);
            }
            insertionPlan = previous[:removalUtc] == null
                ? previous[:removeDueUtc] : previous[:insertDueUtc];
            archiveCycle(state, insertionUtc, "replaced");
        }
        var id = state[:nextCycleId];
        state[:nextCycleId] = id + 1;
        state[:active] = newCycle(id, insertionUtc, state[:regimen] as Lang.Dictionary);
        var created = state[:active] as Lang.Dictionary;
        created[:insertionPlanUtc] = insertionPlan;
        created[:insertionDeltaSeconds] = insertionPlan == null
            ? null : insertionUtc - (insertionPlan as Lang.Number);
        var ledger = defaultLedger();
        ledger[:cycleId] = id;
        state[:reminderLedger] = ledger;
        state[:setupStep] = 3;
        return created;
    }

    function validInsertionEdit(active as Lang.Dictionary, insertionUtc as Lang.Number) as Lang.Boolean {
        if (active[:removalUtc] != null && insertionUtc > active[:removalUtc]) { return false; }
        var intervals = active[:temporaryOut] as Lang.Array;
        for (var i = 0; i < intervals.size(); i += 1) {
            var interval = intervals[i] as Lang.Dictionary;
            if (insertionUtc > interval[:outUtc]) { return false; }
            if (interval[:backInUtc] != null && insertionUtc > interval[:backInUtc]) { return false; }
        }
        return true;
    }

    function validRemovalEdit(active as Lang.Dictionary, removalUtc as Lang.Number) as Lang.Boolean {
        if (removalUtc < active[:insertionUtc]) { return false; }
        var intervals = active[:temporaryOut] as Lang.Array;
        for (var i = 0; i < intervals.size(); i += 1) {
            var interval = intervals[i] as Lang.Dictionary;
            if (interval[:outUtc] > removalUtc) { return false; }
            if (interval[:backInUtc] != null && interval[:backInUtc] > removalUtc) { return false; }
        }
        return true;
    }

    function validReplacementTime(active as Lang.Dictionary, insertionUtc as Lang.Number) as Lang.Boolean {
        if (insertionUtc < active[:insertionUtc]
            || (active[:removalUtc] != null && insertionUtc < active[:removalUtc])) { return false; }
        var intervals = active[:temporaryOut] as Lang.Array;
        for (var i = 0; i < intervals.size(); i += 1) {
            var interval = intervals[i] as Lang.Dictionary;
            if (insertionUtc < interval[:outUtc]
                || (interval[:backInUtc] != null && insertionUtc < interval[:backInUtc])) { return false; }
        }
        return true;
    }

    function rebuildForInsertion(active as Lang.Dictionary, insertionUtc as Lang.Number,
                                 regimen as Lang.Dictionary) as Lang.Dictionary? {
        if (!validInsertionEdit(active, insertionUtc)) { return null; }
        var rebuilt = newCycle(active[:cycleId], insertionUtc, regimen);
        rebuilt[:insertionPlanUtc] = active[:insertionPlanUtc];
        rebuilt[:insertionDeltaSeconds] = active[:insertionPlanUtc] == null
            ? null : insertionUtc - active[:insertionPlanUtc];
        rebuilt[:removalUtc] = active[:removalUtc];
        rebuilt[:removalWall] = active[:removalWall];
        rebuilt[:temporaryOut] = active[:temporaryOut];
        rebuilt[:temporaryOutSummary] = active[:temporaryOutSummary];
        if (active[:removalUtc] != null) {
            rebuilt[:removalDeltaSeconds] = active[:removalUtc] - rebuilt[:removeDueUtc];
            var insertion = CalendarMath.addLocalCalendarDays(active[:removalUtc], regimen[:daysOut]);
            rebuilt[:insertDueUtc] = insertion[:utc];
            var ceiling = CalendarMath.addLocalCalendarDays(active[:removalUtc], 7);
            rebuilt[:ringFreeCeilingUtc] = ceiling[:utc];
            if (insertion[:adjusted] || ceiling[:adjusted]) {
                rebuilt[:dstAdjustment] = "advancedToValidLocalTime";
            }
        }
        return rebuilt;
    }

    // Future rows are derived on demand. Actual events remain authoritative
    // for the current row and every later row follows the latest actual anchor.
    function projectUpcoming(active as Lang.Dictionary, regimen as Lang.Dictionary,
                             count as Lang.Number, nowUtc as Lang.Number) as Lang.Array {
        var rows = [];
        if (count <= 0) { return rows; }
        var currentOut = active[:removalUtc] == null ? active[:removeDueUtc] : active[:removalUtc];
        rows.add({ :cycleId=>active[:cycleId], :inUtc=>active[:insertionUtc],
            :outUtc=>currentOut, :inActual=>true,
            :outActual=>active[:removalUtc] != null, :isCurrent=>true,
            :ifDoneToday=>false });
        var actionDue = active[:removalUtc] == null ? active[:removeDueUtc] : active[:insertDueUtc];
        var overdueAnchor = actionDue < nowUtc;
        var nextIn;
        if (active[:removalUtc] != null) {
            nextIn = overdueAnchor ? nowUtc : active[:insertDueUtc];
        } else {
            var removalAnchor = overdueAnchor ? nowUtc : active[:removeDueUtc];
            nextIn = CalendarMath.addLocalCalendarDays(removalAnchor, regimen[:daysOut])[:utc];
        }
        for (var i = 1; i < count; i += 1) {
            var nextOut = CalendarMath.addLocalCalendarDays(nextIn, regimen[:daysIn])[:utc];
            rows.add({ :cycleId=>active[:cycleId] + i, :inUtc=>nextIn,
                :outUtc=>nextOut, :inActual=>false, :outActual=>false, :isCurrent=>false,
                :ifDoneToday=>overdueAnchor });
            nextIn = CalendarMath.addLocalCalendarDays(nextOut, regimen[:daysOut])[:utc];
        }
        return rows;
    }

    function validNotificationData(value, activeCycleId as Lang.Number) as Lang.Boolean {
        if (!(value instanceof Lang.Array) || (value as Lang.Array).size() != 2) { return false; }
        var data = value as Lang.Array;
        return data[0] instanceof Lang.Number && data[0] == activeCycleId
            && data[1] instanceof Lang.Number && data[1] >= 0 && data[1] <= 5;
    }

    function temporaryGuidance(interval as Lang.Dictionary) as Lang.Array<Lang.Symbol> {
        var start = interval[:phaseWeekAtStart];
        var stop = interval[:phaseWeekAtEnd];
        if (interval[:backInUtc] == null) {
            if (start == 1 || start == 2) { return [:week12]; }
            if (start == 3) { return [:week3]; }
            return [:outside];
        }
        var result = [] as Lang.Array<Lang.Symbol>;
        if (start == 1 || start == 2 || stop == 1 || stop == 2) { result.add(:week12); }
        if (start == 3 || stop == 3) { result.add(:week3); }
        if (start == null || stop == null) { result.add(:outside); }
        if (result.size() == 0) { result.add(:unknown); }
        return result;
    }

    function validState(state) as Lang.Boolean {
        if (!(state instanceof Lang.Dictionary) || state[:schemaVersion] != SCHEMA_VERSION) { return false; }
        if (!validRegimen(state[:regimen])) { return false; }
        if (!(state[:nextCycleId] instanceof Lang.Number) || state[:nextCycleId] < 1
            || !(state[:setupStep] instanceof Lang.Number) || state[:setupStep] < 0 || state[:setupStep] > 3
            || !(state[:revision] instanceof Lang.Number) || state[:revision] < 0
            || !(state[:migrationNoticePending] instanceof Lang.Boolean)
            || !validReminders(state[:reminders]) || !validLedger(state[:reminderLedger])
            || !validSettingsSync(state[:settingsSync])) { return false; }
        if (!(state[:history] instanceof Lang.Array) || state[:history].size() > MAX_HISTORY) { return false; }
        var history = state[:history] as Lang.Array;
        var largestId = 0;
        var seenIds = {};
        for (var h = 0; h < history.size(); h += 1) {
            if (!validHistory(history[h])) { return false; }
            var historyId = (history[h] as Lang.Dictionary)[:cycleId];
            if (seenIds[historyId] == true) { return false; }
            seenIds[historyId] = true;
            if (historyId > largestId) { largestId = historyId; }
        }
        var active = state[:active];
        if (active != null) {
            if (!validActive(active, state[:regimen] as Lang.Dictionary)) { return false; }
            var activeId = (active as Lang.Dictionary)[:cycleId];
            if (activeId > largestId) { largestId = activeId; }
            if (seenIds[activeId] == true) { return false; }
        }
        return state[:nextCycleId] > largestId;
    }

    function validReminders(value) as Lang.Boolean {
        if (!(value instanceof Lang.Dictionary)) { return false; }
        var r = value as Lang.Dictionary;
        return numberBetween(r[:reminder1Hour], 0, 23)
            && numberBetween(r[:reminder1Minute], 0, 59)
            && numberBetween(r[:reminder2Hour], 0, 23)
            && numberBetween(r[:reminder2Minute], 0, 59)
            && r[:reminder2Enabled] instanceof Lang.Boolean
            && r[:dayBeforeEnabled] instanceof Lang.Boolean
            && (r[:overdueRepeatHours] == 1 || r[:overdueRepeatHours] == 3
                || r[:overdueRepeatHours] == 6 || r[:overdueRepeatHours] == 12
                || r[:overdueRepeatHours] == 24)
            && r[:vibrationEnabled] instanceof Lang.Boolean
            && r[:soundEnabled] instanceof Lang.Boolean
            && (r[:clockFormat] == 0 || r[:clockFormat] == 12 || r[:clockFormat] == 24);
    }

    function validLedger(value) as Lang.Boolean {
        if (!(value instanceof Lang.Dictionary)) { return false; }
        var l = value as Lang.Dictionary;
        return numberBetween(l[:cycleId], 0, 2147483647)
            && l[:actionKey] instanceof Lang.String && (l[:actionKey] as Lang.String).length() <= 64
            && l[:dayBeforeSent] instanceof Lang.Boolean
            && l[:dayOf1Sent] instanceof Lang.Boolean && l[:dayOf2Sent] instanceof Lang.Boolean
            && nullableNonnegative(l[:lastOverdueSlot]) && nullableNonnegative(l[:lastTempOutSlot])
            && nullableNonnegative(l[:tempOutIdentity])
            && (l[:lastTempOutSlot] == null || l[:tempOutIdentity] != null)
            && l[:labelFourWeekSent] instanceof Lang.Boolean
            && l[:ringFreeExceededSent] instanceof Lang.Boolean;
    }

    function validSettingsSync(value) as Lang.Boolean {
        if (!(value instanceof Lang.Dictionary)) { return false; }
        var s = value as Lang.Dictionary;
        if (!boundedString(s[:lastSeenInsertionIso], 32)
            || !boundedString(s[:lastAcceptedInsertionIso], 32)
            || !numberBetween(s[:lastWatchScheduleEditUtc], 0, 2147483647)
            || !numberBetween(s[:lastSettingsObservationUtc], 0, 2147483647)
            || !nullableBoundedString(s[:pendingMirrorIso], 32)
            || !nullableBoundedString(s[:pendingSettingsError], 64)) { return false; }
        if (s[:configSnapshot] != null && !validConfigArray(s[:configSnapshot])) { return false; }
        return s[:pendingConfigSnapshot] == null || validConfigArray(s[:pendingConfigSnapshot]);
    }

    function validConfigArray(value) as Lang.Boolean {
        if (!(value instanceof Lang.Array) || (value as Lang.Array).size() != 12) { return false; }
        var a = value as Lang.Array;
        return numberBetween(a[0], 0, 23) && numberBetween(a[1], 0, 59)
            && numberBetween(a[2], 0, 23) && numberBetween(a[3], 0, 59)
            && a[4] instanceof Lang.Boolean && a[5] instanceof Lang.Boolean
            && numberBetween(a[6], 21, 35) && numberBetween(a[7], 0, 7)
            && (a[8] == 1 || a[8] == 3 || a[8] == 6 || a[8] == 12 || a[8] == 24)
            && a[9] instanceof Lang.Boolean && a[10] instanceof Lang.Boolean
            && (a[11] == 0 || a[11] == 12 || a[11] == 24);
    }

    function validActive(value, regimen as Lang.Dictionary) as Lang.Boolean {
        if (!(value instanceof Lang.Dictionary)) { return false; }
        var a = value as Lang.Dictionary;
        if (!numberBetween(a[:cycleId], 1, 2147483647)
            || !(a[:insertionUtc] instanceof Lang.Number) || !validWall(a[:insertionWall])
            || !nullableNumber(a[:insertionPlanUtc]) || !nullableNumber(a[:insertionDeltaSeconds])
            || !(a[:removeDueUtc] instanceof Lang.Number)
            || !(a[:labelFourWeekUtc] instanceof Lang.Number)
            || a[:removeDueUtc] < a[:insertionUtc]
            || a[:labelFourWeekUtc] < a[:insertionUtc]
            || (a[:dstAdjustment] != null && (!(a[:dstAdjustment] instanceof Lang.String)
                || !(a[:dstAdjustment] as Lang.String).equals("advancedToValidLocalTime")))
            || !(a[:temporaryOut] instanceof Lang.Array)
            || (a[:temporaryOut] as Lang.Array).size() > MAX_TEMP_INTERVALS
            || !validSummary(a[:temporaryOutSummary])) { return false; }
        if ((a[:insertionPlanUtc] == null) != (a[:insertionDeltaSeconds] == null)
            || (a[:insertionPlanUtc] != null
                && a[:insertionDeltaSeconds] != a[:insertionUtc] - a[:insertionPlanUtc])) { return false; }
        if (!CalendarMath.isExactLocalCalendarAddition(a[:insertionUtc], regimen[:daysIn], a[:removeDueUtc])
            || !CalendarMath.isExactLocalCalendarAddition(a[:insertionUtc], 28, a[:labelFourWeekUtc])) { return false; }
        var removed = a[:removalUtc];
        if (removed == null) {
            if (a[:removalWall] != null || a[:ringFreeCeilingUtc] != null
                || a[:removalDeltaSeconds] != null || a[:insertDueUtc] != null) { return false; }
        } else if (!(removed instanceof Lang.Number) || removed < a[:insertionUtc]
            || !validWall(a[:removalWall]) || !(a[:ringFreeCeilingUtc] instanceof Lang.Number)
            || !(a[:insertDueUtc] instanceof Lang.Number) || !(a[:removalDeltaSeconds] instanceof Lang.Number)) {
            return false;
        } else {
            if (a[:removalDeltaSeconds] != removed - a[:removeDueUtc]
                || !CalendarMath.isExactLocalCalendarAddition(removed, regimen[:daysOut], a[:insertDueUtc])
                || !CalendarMath.isExactLocalCalendarAddition(removed, 7, a[:ringFreeCeilingUtc])) { return false; }
        }
        var intervals = a[:temporaryOut] as Lang.Array;
        var previousEnd = a[:insertionUtc];
        for (var i = 0; i < intervals.size(); i += 1) {
            if (!validInterval(intervals[i], a[:insertionUtc], removed, previousEnd, i == intervals.size() - 1)) { return false; }
            var interval = intervals[i] as Lang.Dictionary;
            previousEnd = interval[:backInUtc] == null ? interval[:outUtc] : interval[:backInUtc];
        }
        return true;
    }

    function validHistory(value) as Lang.Boolean {
        if (!(value instanceof Lang.Dictionary)) { return false; }
        var h = value as Lang.Dictionary;
        if (!numberBetween(h[:cycleId], 1, 2147483647)
            || !(h[:insertionUtc] instanceof Lang.Number)
            || !nullableNumber(h[:insertionPlanUtc]) || !nullableNumber(h[:insertionDeltaSeconds])
            || !(h[:removeDueUtc] instanceof Lang.Number)
            || (h[:removalUtc] != null && (!(h[:removalUtc] instanceof Lang.Number) || h[:removalUtc] < h[:insertionUtc]))
            || !nullableNumber(h[:removalDeltaSeconds]) || !nullableNumber(h[:insertDueUtc])
            || (h[:nextInsertionUtc] != null && (!(h[:nextInsertionUtc] instanceof Lang.Number) || h[:nextInsertionUtc] < h[:insertionUtc]))
            || !nullableNumber(h[:nextInsertionDeltaSeconds])
            || !(h[:closeReason] instanceof Lang.String) || !(h[:closeReason] as Lang.String).equals("replaced")
            || !numberBetween(h[:regimenDaysIn], 21, 35) || !numberBetween(h[:regimenDaysOut], 0, 7)
            || !(h[:temporaryOut] instanceof Lang.Array) || !validSummary(h[:temporaryOutSummary])) { return false; }
        if ((h[:insertionPlanUtc] == null) != (h[:insertionDeltaSeconds] == null)
            || (h[:insertionPlanUtc] != null
                && h[:insertionDeltaSeconds] != h[:insertionUtc] - h[:insertionPlanUtc])) { return false; }
        if (!CalendarMath.isExactLocalCalendarAddition(h[:insertionUtc], h[:regimenDaysIn], h[:removeDueUtc])) { return false; }
        if (h[:removalUtc] == null) {
            if (h[:removalDeltaSeconds] != null || h[:insertDueUtc] != null) { return false; }
        } else {
            if (h[:removalDeltaSeconds] != h[:removalUtc] - h[:removeDueUtc]
                || !CalendarMath.isExactLocalCalendarAddition(h[:removalUtc], h[:regimenDaysOut], h[:insertDueUtc])) { return false; }
        }
        var expectedNext = h[:removalUtc] == null ? h[:removeDueUtc] : h[:insertDueUtc];
        if ((h[:nextInsertionUtc] == null) != (h[:nextInsertionDeltaSeconds] == null)
            || (h[:nextInsertionUtc] != null
                && h[:nextInsertionDeltaSeconds] != h[:nextInsertionUtc] - expectedNext)) { return false; }
        var intervals = h[:temporaryOut] as Lang.Array;
        if (intervals.size() > MAX_TEMP_INTERVALS) { return false; }
        var previousEnd = h[:insertionUtc];
        for (var i = 0; i < intervals.size(); i += 1) {
            if (!validInterval(intervals[i], h[:insertionUtc], h[:removalUtc], previousEnd, false)) { return false; }
            previousEnd = (intervals[i] as Lang.Dictionary)[:backInUtc];
        }
        return true;
    }

    function validInterval(value, insertionUtc, removalUtc, previousEnd, mayBeOpen as Lang.Boolean) as Lang.Boolean {
        if (!(value instanceof Lang.Dictionary)) { return false; }
        var t = value as Lang.Dictionary;
        if (!(t[:outUtc] instanceof Lang.Number) || t[:outUtc] < insertionUtc || t[:outUtc] < previousEnd
            || !validWeek(t[:phaseWeekAtStart]) || !validWeek(t[:phaseWeekAtEnd])) { return false; }
        if (removalUtc != null && t[:outUtc] > removalUtc) { return false; }
        if (t[:backInUtc] == null) {
            return mayBeOpen && removalUtc == null && t[:phaseWeekAtEnd] == null && t[:thresholdCode] == null;
        }
        if (!(t[:backInUtc] instanceof Lang.Number) || t[:backInUtc] < t[:outUtc]
            || (removalUtc != null && t[:backInUtc] > removalUtc)) { return false; }
        var expected = thresholdCode(t[:backInUtc] - t[:outUtc]);
        return t[:thresholdCode] instanceof Lang.String
            && (t[:thresholdCode] as Lang.String).equals(expected);
    }

    function validSummary(value) as Lang.Boolean {
        return value instanceof Lang.Dictionary
            && numberBetween(value[:shortIntervalCount], 0, 2147483647)
            && numberBetween(value[:shortIntervalSeconds], 0, 2147483647);
    }

    function validWall(value) as Lang.Boolean {
        return value instanceof Lang.Dictionary && CalendarMath.validWall(value as Lang.Dictionary);
    }

    function validWeek(value) as Lang.Boolean {
        return value == null || value == 1 || value == 2 || value == 3;
    }

    function numberBetween(value, low as Lang.Number, high as Lang.Number) as Lang.Boolean {
        return value instanceof Lang.Number && value >= low && value <= high;
    }

    function nullableNonnegative(value) as Lang.Boolean {
        return value == null || (value instanceof Lang.Number && value >= 0);
    }

    function nullableNumber(value) as Lang.Boolean {
        return value == null || value instanceof Lang.Number;
    }

    function boundedString(value, maxLength as Lang.Number) as Lang.Boolean {
        return value instanceof Lang.String && (value as Lang.String).length() <= maxLength;
    }

    function nullableBoundedString(value, maxLength as Lang.Number) as Lang.Boolean {
        return value == null || boundedString(value, maxLength);
    }
}
