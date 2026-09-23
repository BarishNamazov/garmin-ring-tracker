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
function uxDGlanceDaysMatchMainCountdown(logger as Test.Logger) as Boolean {
    var glance = new RingGlanceView();
    var remaining = [86400, 86401, (2 * 86400) - 1, 2 * 86400,
        12 * 86400, (12 * 86400) + (6 * 3600), (13 * 86400) - 1,
        13 * 86400];
    var expectedDays = [1, 1, 1, 2, 12, 12, 12, 13];
    for (var i = 0; i < remaining.size(); i += 1) {
        var days = expectedDays[i];
        var expected = days.toString() + (days == 1 ? " day" : " days");
        Test.assertEqual(expected, glance.durationText(remaining[i]));
        var mainGroups = Ui.mainCountdownGroups(remaining[i]);
        var mainDays = mainGroups[0] as Lang.Array;
        Test.assertEqual(days.toString(), mainDays[0]);
    }
    return true;
}

(:test)
function uxDGlanceTemporaryCopyShowsWindowDirection(logger as Test.Logger) as Boolean {
    var glance = new RingGlanceView();
    Test.assertEqual("2 h 50 min", glance.temporaryText((2 * 3600) + (50 * 60)));
    Test.assertEqual("10 min over", glance.temporaryText(-10 * 60));
    return true;
}

(:test)
function uxDGlanceLatenessMatchesSharedRule(logger as Test.Logger) as Boolean {
    Test.assertEqual("29h", Lateness.compact(29 * 3600));
    Test.assertEqual("47h", Lateness.compact(47 * 3600));
    Test.assertEqual("2d", Lateness.compact(48 * 3600));
    Test.assertEqual("2d", Lateness.compact(71 * 3600));
    return true;
}

(:test)
function uxDReminderTwoDiffersForEveryAction(logger as Test.Logger) as Boolean {
    var service = new RingServiceDelegate();
    var due = testWall(2026, 9, 15, 17, 26);
    var expected = ["Remove ring today", "Insert ring today", "Replace today"];
    for (var action = 0; action < 3; action += 1) {
        var copy = service.notificationIds(4, action, due, 12, due - 60, 2);
        Test.assertEqual(expected[action], copy[0]);
        Test.assertEqual("Due today · 5:26 PM", copy[1]);
        Test.assertEqual("Tap to log", copy[2]);
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
        "Put ring back", "Insert now", "Replace now"];
    for (var i = 0; i < cases.size(); i += 1) {
        var title = (cases[i] as Lang.Array)[0] as Lang.String;
        Test.assertEqual(expected[i], title);
        Test.assert(title.length() <= 15);
        for (var digit = 0; digit < 10; digit += 1) {
            Test.assert(title.find(digit.toString()) == null);
        }
    }
    return true;
}

(:test)
function uxDNotificationsUseConsistentHintsAndLateness(logger as Test.Logger) as Boolean {
    var due = testWall(2026, 9, 15, 17, 26);
    var service = new RingServiceDelegate();
    var overdue = service.notificationIds(3, 0, due, 12,
        due + (29 * 3600), 0);
    Test.assertEqual("29h late · due Tue 15 Sep", overdue[1]);
    Test.assertEqual("Tap to log", overdue[2]);
    var twoDays = service.notificationIds(3, 1, due, 12,
        due + (48 * 3600), 0);
    Test.assertEqual("2d late · due Tue 15 Sep", twoDays[1]);
    var temporary = service.notificationIds(1, 0, due, 12, due + 11400, 0);
    Test.assertEqual("Backup advised", temporary[2]);
    var free = service.notificationIds(0, 1, due, 12, due + (29 * 3600), 0);
    Test.assertEqual("Ring-free 8 days · 29h late", free[1]);
    Test.assertEqual("Backup advised", free[2]);
    var worn = service.notificationIds(2, 2, due, 12, due + (6 * 86400), 0);
    Test.assertEqual("Ring in 34 days · 6d late", worn[1]);
    Test.assertEqual("Backup advised", worn[2]);
    return true;
}
