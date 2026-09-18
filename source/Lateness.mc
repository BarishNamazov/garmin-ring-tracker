import Toybox.Lang;

// Shared lateness copy for foreground, glance, and background personalities.
// Keep this module independent of UI and calendar code so constrained
// processes can reuse it without pulling in either dependency graph.
(:glance, :background)
module Lateness {
    const SECONDS_PER_MINUTE = 60;
    const SECONDS_PER_HOUR = 3600;
    const SECONDS_PER_DAY = 86400;
    const HOURS_TO_DAYS = 48;

    function parts(seconds as Lang.Number) as Lang.Array<Lang.String> {
        var value = seconds.abs();
        if (value >= HOURS_TO_DAYS * SECONDS_PER_HOUR) {
            return [((value / SECONDS_PER_DAY).toNumber()).toString(), "d"];
        }
        if (value >= SECONDS_PER_HOUR) {
            return [((value / SECONDS_PER_HOUR).toNumber()).toString(), "h"];
        }
        var minutes = (value / SECONDS_PER_MINUTE).toNumber();
        if (minutes < 1) { minutes = 1; }
        return [minutes.toString(), "m"];
    }

    function format(seconds as Lang.Number) as Lang.String {
        return compact(seconds) + " late";
    }

    function compact(seconds as Lang.Number) as Lang.String {
        var value = parts(seconds);
        return value[0] + value[1];
    }
}
