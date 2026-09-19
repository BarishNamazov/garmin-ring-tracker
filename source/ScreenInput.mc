import Toybox.Lang;
import Toybox.WatchUi;

// BehaviorDelegate consumes mapped gestures BEFORE onTap/onSwipe. These custom
// screens need coordinates (notably picker arrows and confirmation buttons),
// so dispatch physical keys explicitly and let touch reach its own handlers.
// Native Garmin menus and confirmations retain their native delegates.
class ScreenInputDelegate extends WatchUi.InputDelegate {
    function initialize() { InputDelegate.initialize(); }

    function onKey(event as WatchUi.KeyEvent) as Lang.Boolean {
        return handleKey(event.getKey());
    }

    function handleKey(key as Lang.Number) as Lang.Boolean {
        if (key == WatchUi.KEY_ENTER) { return onSelect(); }
        if (key == WatchUi.KEY_ESC) { return onBack(); }
        if (key == WatchUi.KEY_UP) { return onPreviousPage(); }
        if (key == WatchUi.KEY_DOWN) { return onNextPage(); }
        return false;
    }

    function onSelect() as Lang.Boolean { return false; }
    function onBack() as Lang.Boolean { return false; }
    function onPreviousPage() as Lang.Boolean { return false; }
    function onNextPage() as Lang.Boolean { return false; }

    function onTap(event as WatchUi.ClickEvent) as Lang.Boolean { return onSelect(); }
    function onSwipe(event as WatchUi.SwipeEvent) as Lang.Boolean {
        if (event.getDirection() == WatchUi.SWIPE_RIGHT) { return onBack(); }
        if (event.getDirection() == WatchUi.SWIPE_UP) { return onNextPage(); }
        if (event.getDirection() == WatchUi.SWIPE_DOWN) { return onPreviousPage(); }
        return false;
    }
}
