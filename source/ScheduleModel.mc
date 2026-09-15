import Toybox.Math;
import Toybox.Lang;

// State transition and derivation logic. It is storage-agnostic and receives
// nowUtc explicitly so tests and debug scenarios never depend on wall time.
module ScheduleModel {
    const SCHEMA_VERSION = 1;
    const MAX_HISTORY = 24;
    const MAX_TEMP_INTERVALS = 32;
    const TEMP_LIMIT_SECONDS = 10800;

    function defaultRegimen() as Lang.Dictionary {
        return { :daysIn => 21, :daysOut => 7 };
    }

    function defaultReminders() as Lang.Dictionary {
        return {
            :localHour => 9,
            :localMinute => 0,
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
            :dayOfSent => false,
            :lastOverdueSlot => null,
            :lastTempOutSlot => null,
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
                :configSnapshot => null
            }
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
        var insertion = CalendarMath.addLocalCalendarDays(insertionUtc, regimen[:daysIn] + regimen[:daysOut]);
        var label = regimen[:daysIn] + regimen[:daysOut] == 28
            ? insertion : CalendarMath.addLocalCalendarDays(insertionUtc, 28);
        var wall = CalendarMath.localFields(insertionUtc);
        return {
            :cycleId => cycleId,
            :insertionUtc => insertionUtc,
            :insertionWall => wall,
            :removalUtc => null,
            :removalWall => null,
            :scheduledRemovalUtc => removal[:utc],
            :scheduledInsertionUtc => insertion[:utc],
            :labelFourWeekUtc => label[:utc],
            :ringFreeCeilingUtc => null,
            :plannedOverrideUtc => null,
            :dstAdjustment => (removal[:adjusted] || insertion[:adjusted] || label[:adjusted]) ? "advancedToValidLocalTime" : null,
            :temporaryOut => []
        };
    }

    function tempOpen(active as Lang.Dictionary) as Lang.Dictionary? {
        var intervals = active[:temporaryOut] as Lang.Array;
        if (!(intervals instanceof Lang.Array) || intervals.size() == 0) { return null; }
        var last = intervals[intervals.size() - 1] as Lang.Dictionary;
        return last[:backInUtc] == null ? last : null;
    }

    function nextInsertUtc(active as Lang.Dictionary, regimen as Lang.Dictionary) as Lang.Number {
        if (active[:removalUtc] == null) { return active[:scheduledInsertionUtc]; }
        if (regimen[:daysOut] == 0) { return active[:removalUtc]; }
        var actualPlan = CalendarMath.addLocalCalendarDays(active[:removalUtc], regimen[:daysOut])[:utc];
        var deadline = active[:scheduledInsertionUtc] < actualPlan ? active[:scheduledInsertionUtc] : actualPlan;
        deadline = deadline < active[:ringFreeCeilingUtc] ? deadline : active[:ringFreeCeilingUtc];
        if (active[:plannedOverrideUtc] != null) {
            deadline = active[:plannedOverrideUtc] < active[:ringFreeCeilingUtc] ? active[:plannedOverrideUtc] : active[:ringFreeCeilingUtc];
        }
        return deadline;
    }

    function deriveStatus(nowUtc as Lang.Number, active as Lang.Dictionary?, regimen as Lang.Dictionary) as Lang.Dictionary {
        if (active == null) {
            return {
                :phase => :setup,
                :overdueKind => null,
                :temporaryOutOpen => false,
                :dayOfCycle => null,
                :nextAction => :setUp,
                :nextActionUtc => null,
                :secondsRemaining => null,
                :displayDays => 0,
                :displayHours => 0,
                :ringFreeLimitExceeded => false,
                :beyondLabelFourWeeks => false,
                :clockBeforeInsertion => false,
                :tempElapsed => null,
                :tempBoundary => null
            };
        }

        var removed = active[:removalUtc] != null;
        var deadline = removed ? nextInsertUtc(active, regimen) : active[:scheduledRemovalUtc];
        var action = removed ? :insert : (regimen[:daysOut] == 0 ? :replace : :remove);
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
            :nextActionUtc => deadline,
            :secondsRemaining => delta,
            :displayDays => cd[:days],
            :displayHours => cd[:hours],
            :ringFreeLimitExceeded => removed && active[:ringFreeCeilingUtc] != null && nowUtc > active[:ringFreeCeilingUtc],
            :beyondLabelFourWeeks => !removed && nowUtc > active[:labelFourWeekUtc],
            :clockBeforeInsertion => nowUtc < active[:insertionUtc],
            :tempElapsed => tempElapsed,
            :tempBoundary => tempBoundary
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
        if (removalUtc < active[:insertionUtc]) { return false; }
        var open = tempOpen(active);
        if (open != null) {
            open[:backInUtc] = removalUtc;
            open[:phaseWeekAtEnd] = phaseWeek(active, removalUtc);
            open[:thresholdCode] = thresholdCode(removalUtc - open[:outUtc]);
        }
        active[:removalUtc] = removalUtc;
        active[:removalWall] = CalendarMath.localFields(removalUtc);
        var ceiling = CalendarMath.addLocalCalendarDays(removalUtc, 7);
        active[:ringFreeCeilingUtc] = ceiling[:utc];
        active[:dstAdjustment] = ceiling[:adjusted] ? "advancedToValidLocalTime" : null;
        return true;
    }

    function startTemporaryOut(active as Lang.Dictionary, outUtc as Lang.Number) as Lang.Boolean {
        if (tempOpen(active) != null || outUtc < active[:insertionUtc] || active[:removalUtc] != null) { return false; }
        var intervals = active[:temporaryOut] as Lang.Array;
        if (intervals.size() >= MAX_TEMP_INTERVALS) { return false; }
        intervals.add({
            :outUtc => outUtc,
            :backInUtc => null,
            :phaseWeekAtStart => phaseWeek(active, outUtc),
            :phaseWeekAtEnd => null,
            :thresholdCode => null
        });
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
        history.add({
            :cycleId => active[:cycleId],
            :insertionUtc => active[:insertionUtc],
            :removalUtc => active[:removalUtc],
            :nextInsertionUtc => nextInsertionUtc,
            :closeReason => reason,
            :regimenDaysIn => regimen[:daysIn],
            :regimenDaysOut => regimen[:daysOut],
            :temporaryOut => compact[:retained],
            :temporaryOutSummary => {
                :shortIntervalCount => compact[:shortCount],
                :shortIntervalSeconds => compact[:shortSeconds]
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
        if (state[:active] != null) { archiveCycle(state, insertionUtc, "replaced"); }
        var id = state[:nextCycleId];
        state[:nextCycleId] = id + 1;
        state[:active] = newCycle(id, insertionUtc, state[:regimen] as Lang.Dictionary);
        var ledger = defaultLedger();
        ledger[:cycleId] = id;
        state[:reminderLedger] = ledger;
        state[:setupStep] = 3;
        return state[:active];
    }

    function validState(state) as Lang.Boolean {
        if (!(state instanceof Lang.Dictionary) || state[:schemaVersion] != SCHEMA_VERSION) { return false; }
        if (!validRegimen(state[:regimen])) { return false; }
        if (!(state[:history] instanceof Lang.Array) || state[:history].size() > MAX_HISTORY) { return false; }
        var active = state[:active];
        if (active == null) { return true; }
        return active instanceof Lang.Dictionary
            && active[:cycleId] instanceof Lang.Number
            && active[:insertionUtc] instanceof Lang.Number
            && active[:scheduledRemovalUtc] instanceof Lang.Number
            && active[:scheduledInsertionUtc] instanceof Lang.Number
            && active[:labelFourWeekUtc] instanceof Lang.Number
            && active[:temporaryOut] instanceof Lang.Array
            && active[:temporaryOut].size() <= MAX_TEMP_INTERVALS;
    }
}
