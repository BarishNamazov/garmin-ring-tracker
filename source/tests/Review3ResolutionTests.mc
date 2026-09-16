import Toybox.Lang;
import Toybox.Test;

(:test)
function review3TemporaryOutIdentitySurvivesReboot(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    state[:setupStep] = 3;
    var regimen = state[:regimen] as Lang.Dictionary;
    var reminders = state[:reminders] as Lang.Dictionary;
    var active = ScheduleModel.insertOrReplace(state, testWall(2026, 9, 1, 9, 0));
    var firstOut = active[:insertionUtc] + 3600;
    Test.assert(ScheduleModel.startTemporaryOut(active, firstOut));
    var first = ReminderPolicy.evaluate(firstOut + 10801, active, regimen, reminders,
        state[:reminderLedger] as Lang.Dictionary);
    ReminderPolicy.markSent(state[:reminderLedger] as Lang.Dictionary, first);
    Test.assertEqual(firstOut, (state[:reminderLedger] as Lang.Dictionary)[:tempOutIdentity]);

    var restored = RingStore.decodeState(RingStore.encodeState(state));
    var restoredActive = restored[:active] as Lang.Dictionary;
    Test.assert(ScheduleModel.endTemporaryOut(restoredActive, firstOut + 10900));
    var secondOut = firstOut + 20000;
    Test.assert(ScheduleModel.startTemporaryOut(restoredActive, secondOut));
    var second = ReminderPolicy.evaluate(secondOut + 10801, restoredActive,
        restored[:regimen] as Lang.Dictionary, restored[:reminders] as Lang.Dictionary,
        restored[:reminderLedger] as Lang.Dictionary);
    Test.assertEqual(:tempOver3h, second[:kind]);
    Test.assertEqual(0, second[:slot]);
    Test.assertEqual(secondOut, second[:tempOutIdentity]);
    return true;
}

(:test)
function review3TemporaryOutIntervalsKeepForegroundBackgroundParity(logger as Test.Logger) as Boolean {
    var state = ScheduleModel.defaultState();
    state[:setupStep] = 3;
    var regimen = state[:regimen] as Lang.Dictionary;
    var reminders = state[:reminders] as Lang.Dictionary;
    var active = ScheduleModel.insertOrReplace(state, testWall(2026, 9, 1, 9, 0));
    var firstOut = active[:insertionUtc] + 3600;
    Test.assert(ScheduleModel.startTemporaryOut(active, firstOut));
    var first = ReminderPolicy.evaluate(firstOut + 10801, active, regimen, reminders,
        state[:reminderLedger] as Lang.Dictionary);
    ReminderPolicy.markSent(state[:reminderLedger] as Lang.Dictionary, first);
    Test.assert(ScheduleModel.endTemporaryOut(active, firstOut + 10900));
    var secondOut = firstOut + 20000;
    Test.assert(ScheduleModel.startTemporaryOut(active, secondOut));

    var foreground = ReminderPolicy.evaluate(secondOut + 10801, active, regimen, reminders,
        state[:reminderLedger] as Lang.Dictionary);
    var compact = RingStore.encodeBackground(state, 0);
    var background = BackgroundRuntime.evaluate(secondOut + 10801, compact);
    Test.assertEqual(:tempOver3h, foreground[:kind]);
    Test.assertEqual(1, background[0]);
    Test.assertEqual(foreground[:slot], background[2]);
    ReminderPolicy.markSent(state[:reminderLedger] as Lang.Dictionary, foreground);
    BackgroundRuntime.markSent(compact, background);
    Test.assertEqual(secondOut, (state[:reminderLedger] as Lang.Dictionary)[:tempOutIdentity]);
    Test.assertEqual(secondOut, (compact[6] as Lang.Array)[9]);
    return true;
}

(:test)
function review3OldSchema3LedgerDropsAmbiguousTemporarySlot(logger as Test.Logger) as Boolean {
    var old = [1, "remove:123", false, false, false, null, 4, false, false];
    var decoded = RingStore.decodeLedger(old);
    Test.assert(decoded[:lastTempOutSlot] == null);
    Test.assert(decoded[:tempOutIdentity] == null);
    Test.assert(ScheduleModel.validLedger(decoded));
    var encoded = RingStore.encodeLedger(decoded);
    Test.assertEqual(10, encoded.size());
    Test.assert(encoded[6] == null && encoded[9] == null);
    return true;
}
