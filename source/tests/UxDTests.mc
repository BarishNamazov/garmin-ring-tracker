import Toybox.Lang;
import Toybox.Test;

(:test)
function uxDGlanceUsesLongReadableUnits(logger as Test.Logger) as Boolean {
    var glance = new RingGlanceView();
    Test.assertEqual("17 days", glance.durationText(17 * 86400));
    Test.assertEqual("1 day", glance.durationText(86400));
    Test.assertEqual("2 h 50 min", glance.durationText((2 * 3600) + (50 * 60)));
    Test.assertEqual("45 min", glance.durationText(45 * 60));
    return true;
}

(:test)
function uxDGlanceTemporaryCopyShowsWindowDirection(logger as Test.Logger) as Boolean {
    var glance = new RingGlanceView();
    Test.assertEqual("2 h 50 min left", glance.temporaryText((2 * 3600) + (50 * 60)));
    Test.assertEqual("10 min over", glance.temporaryText(-10 * 60));
    return true;
}

(:test)
function uxDReminderTwoDiffersForEveryAction(logger as Test.Logger) as Boolean {
    var service = new RingServiceDelegate();
    var due = testWall(2026, 9, 15, 17, 26);
    var expected = ["Still in — remove", "Still out — insert", "Still in — replace"];
    for (var action = 0; action < 3; action += 1) {
        var copy = service.notificationIds(4, action, due, 12, due - 60, 2);
        Test.assertEqual(expected[action], copy[0]);
        Test.assertEqual("Due 5:26 PM today", copy[1]);
        Test.assert(copy[2] != null);
    }
    return true;
}

(:test)
function uxDNotificationTitlesAreVerbFirstAndNumberFree(logger as Test.Logger) as Boolean {
    var service = new RingServiceDelegate();
    var due = testWall(2026, 9, 15, 17, 26);
    var cases = [
        service.notificationIds(5, 0, due, 12, due - 86400, 0),
        service.notificationIds(4, 0, due, 12, due - 60, 1),
        service.notificationIds(3, 0, due, 12, due + 100800, 0),
        service.notificationIds(1, 0, due, 12, due + 11400, 0),
        service.notificationIds(0, 1, due, 12, due + 86400, 0),
        service.notificationIds(2, 0, due, 12, due + 86400, 0)
    ];
    var expected = ["Remove tomorrow", "Remove ring", "Remove now",
        "Put ring back", "Insert ring", "Replace ring"];
    for (var i = 0; i < cases.size(); i += 1) {
        Test.assertEqual(expected[i], (cases[i] as Lang.Array)[0]);
        Test.assert(((cases[i] as Lang.Array)[0] as Lang.String).find("1") == null);
    }
    return true;
}
