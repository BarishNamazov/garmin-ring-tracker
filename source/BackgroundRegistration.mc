import Toybox.Background;
import Toybox.Lang;
import Toybox.Time;

(:background)
module BackgroundRegistration {
    const INTERVAL = 3600;

    function needed(registered) as Lang.Boolean {
        return !(registered instanceof Time.Duration)
            || (registered as Time.Duration).value() != INTERVAL;
    }

    function ensureHourly() as Lang.Boolean {
        try {
            if (needed(Background.getTemporalEventRegisteredTime())) {
                Background.registerForTemporalEvent(new Time.Duration(INTERVAL));
            }
            return true;
        } catch (ignored) { return false; }
    }
}
