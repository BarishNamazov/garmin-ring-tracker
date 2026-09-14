import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Notifications;
import Toybox.System;
import Toybox.Time;

// This class and every domain/storage dependency it reaches are scoped for the
// 64 KiB background process. It has no reference to a view or UI delegate.
(:background)
class RingServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        try {
            var state = RingStore.loadBackground();
            var active = state[:active] as Lang.Dictionary?;
            if (active != null) {
                var nowUtc = Time.now().value();
                var selected = ReminderPolicy.evaluate(nowUtc, active,
                    state[:regimen] as Lang.Dictionary,
                    state[:reminders] as Lang.Dictionary,
                    state[:reminderLedger] as Lang.Dictionary);
                if (selected != null) {
                    var status = ScheduleModel.deriveStatus(nowUtc, active,
                        state[:regimen] as Lang.Dictionary);
                    var ids = notificationIds(selected[:kind] as Lang.Symbol, status[:nextAction] as Lang.Symbol);
                    var options = {
                        :body => ids[2],
                        :icon => Rez.Drawables.NotificationIcon,
                        :data => [active[:cycleId], selected[:kind].toString()],
                        :dismissPrevious => true
                    };
                    Notifications.showNotification(ids[0], ids[1], options);
                    ReminderPolicy.markSent(state[:reminderLedger] as Lang.Dictionary, selected);
                    RingStore.saveBackgroundLedger(state);
                }
            }
        } catch (ignored) {
            // A later hourly evaluation retries. Do not mark unsent work done.
        }
        reportOptionalServiceMemory();
        Background.exit(null);
    }

    function notificationIds(kind as Lang.Symbol, action as Lang.Symbol) as Lang.Array {
        var title = Rez.Strings.NotificationTitle;
        var subtitle = action == :remove ? Rez.Strings.NotificationRemove
            : (action == :replace ? Rez.Strings.NotificationReplace : Rez.Strings.NotificationInsert);
        var body = Rez.Strings.NotificationScheduled;
        if (kind == :dayBefore) {
            subtitle = action == :remove ? Rez.Strings.NotificationRemoveTomorrow : Rez.Strings.NotificationInsertTomorrow;
        } else if (kind == :dayOf) {
            subtitle = action == :remove ? Rez.Strings.NotificationRemoveToday : Rez.Strings.NotificationInsertToday;
        } else if (kind == :overdue) {
            title = Rez.Strings.NotificationOverdueTitle;
        } else if (kind == :tempOver3h) {
            title = Rez.Strings.NotificationWarningTitle;
            subtitle = Rez.Strings.NotificationTemp;
            body = Rez.Strings.NotificationLabelInfo;
        } else if (kind == :ringFreeExceeded) {
            title = Rez.Strings.NotificationWarningTitle;
            subtitle = Rez.Strings.NotificationFree;
            body = Rez.Strings.NotificationLabelInfo;
        } else if (kind == :beyondFourWeeks) {
            title = Rez.Strings.NotificationWarningTitle;
            subtitle = Rez.Strings.NotificationFourWeeks;
            body = Rez.Strings.NotificationLabelInfo;
        }
        return [title, subtitle, body];
    }
}
