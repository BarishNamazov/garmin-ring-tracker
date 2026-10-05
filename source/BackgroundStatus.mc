import Toybox.Application.Storage;
import Toybox.Lang;

// Independent of the schedule schema, revisions, and reminder ledger.
// [version, checkUtc, outcome, stage, kind, alertUtc, alertKind]
(:background)
module BackgroundStatus {
    const KEY = "ringTrackerBackgroundStatus";
    const TEST_KEY = "ringTrackerTestAlert";
    const NOT_CHECKED = 0;
    const NO_ACTIVE = 1;
    const MIRROR_INVALID = 2;
    const CANONICAL_MISMATCH = 3;
    const NOTHING_DUE = 4;
    const ALERT_SHOWN = 5;
    const FAILED = 6;
    const NONE = 0;
    const LOAD = 1;
    const EVALUATE = 2;
    const NOTIFY = 3;
    const SAVE = 4;
    // 0..5 match reminder kinds; 6 distinguishes Reminder 2; 7 is a test.
    const REMINDER_2 = 6;
    const TEST = 7;

    function empty() as Lang.Array { return [1, null, NOT_CHECKED, NONE, null, null, null]; }

    function valid(raw) as Lang.Boolean {
        if (!(raw instanceof Lang.Array)) { return false; }
        var a = raw as Lang.Array;
        if (a.size() != 7 || a[0] != 1 || !utcOrNull(a[1])
            || !range(a[2], 0, FAILED) || !range(a[3], 0, SAVE)
            || !(a[4] == null || range(a[4], 0, TEST))
            || !utcOrNull(a[5]) || !(a[6] == null || range(a[6], 0, TEST))) { return false; }
        if ((a[5] == null) != (a[6] == null)) { return false; }
        if ((a[1] == null) != (a[2] == NOT_CHECKED)) { return false; }
        if ((a[3] != NONE) != (a[2] == FAILED)) { return false; }
        if (a[2] == ALERT_SHOWN && (a[4] == null || a[5] != a[1] || a[6] != a[4])) { return false; }
        return true;
    }

    function range(value, low as Lang.Number, high as Lang.Number) as Lang.Boolean {
        return value instanceof Lang.Number && value >= low && value <= high;
    }

    function utcOrNull(value) as Lang.Boolean {
        return value == null || range(value, 0, 2147483647);
    }

    function decode(raw) as Lang.Array {
        if (!valid(raw)) { return empty(); }
        var a = raw as Lang.Array;
        return [1, a[1], a[2], a[3], a[4], a[5], a[6]];
    }

    function encode(status as Lang.Array) as Lang.Array { return decode(status); }

    function load() as Lang.Array {
        try { return decode(Storage.getValue(KEY)); }
        catch (ignored) { return empty(); }
    }

    function begin(nowUtc as Lang.Number) as Lang.Array {
        var previous = load();
        return [1, nowUtc, NO_ACTIVE, NONE, null, previous[5], previous[6]];
    }

    function shown(status as Lang.Array, kind as Lang.Number) as Void {
        status[2] = ALERT_SHOWN;
        alertReturned(status, kind);
    }

    function alertReturned(status as Lang.Array, kind as Lang.Number) as Void {
        status[4] = kind;
        status[5] = status[1];
        status[6] = kind;
    }

    function failed(status as Lang.Array, stage as Lang.Number) as Void {
        status[2] = FAILED;
        status[3] = stage;
    }

    function save(status as Lang.Array) as Void { Storage.setValue(KEY, encode(status)); }

    function queueTest() as Void { Storage.setValue(TEST_KEY, true); }

    function consumeTest() as Lang.Boolean {
        var raw = Storage.getValue(TEST_KEY);
        if (raw == null) { return false; }
        // Delete before attempting notification, including a failed attempt.
        Storage.deleteValue(TEST_KEY);
        return raw == true;
    }
}
