import Toybox.Background;
import Toybox.Lang;
import Toybox.Notifications;
import Toybox.System;

// This class and every domain/storage dependency it reaches are scoped for the
// 64 KiB background process. It has no reference to a view or UI delegate.
(:background)
class RingServiceDelegate extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        try {
            var state = BackgroundRuntime.load();
            if (state != null) {
                var active = state[1] as Lang.Array?;
                var selected = BackgroundRuntime.evaluate(currentUtc(), state);
                if (selected != null) {
                    var ids = notificationIds(selected[0], selected[1]);
                    var options = {
                        :body => ids[2],
                        :icon => Rez.Drawables.NotificationIcon,
                        :data => [active[0], selected[0]],
                        :dismissPrevious => true
                    };
                    Notifications.showNotification(ids[0], ids[1], options);
                    BackgroundRuntime.markSent(state, selected);
                    BackgroundRuntime.save(state);
                }
            }
        } catch (ignored) {
            // A later hourly evaluation retries. Do not mark unsent work done.
        }
        reportOptionalServiceMemory();
        Background.exit(null);
    }

    function notificationIds(kind as Lang.Number, action as Lang.Number) as Lang.Array {
        var title = Rez.Strings.NotificationTitle;
        var subtitle = action == 0 ? Rez.Strings.NotificationRemove
            : (action == 2 ? Rez.Strings.NotificationReplace : Rez.Strings.NotificationInsert);
        var body = Rez.Strings.NotificationScheduled;
        if (kind == 5) {
            subtitle = action == 0 ? Rez.Strings.NotificationRemoveTomorrow : Rez.Strings.NotificationInsertTomorrow;
        } else if (kind == 4) {
            subtitle = action == 0 ? Rez.Strings.NotificationRemoveToday : Rez.Strings.NotificationInsertToday;
        } else if (kind == 3) {
            title = Rez.Strings.NotificationOverdueTitle;
        } else if (kind == 1) {
            title = Rez.Strings.NotificationWarningTitle;
            subtitle = Rez.Strings.NotificationTemp;
            body = Rez.Strings.NotificationLabelInfo;
        } else if (kind == 0) {
            title = Rez.Strings.NotificationWarningTitle;
            subtitle = Rez.Strings.NotificationFree;
            body = Rez.Strings.NotificationLabelInfo;
        } else if (kind == 2) {
            title = Rez.Strings.NotificationWarningTitle;
            subtitle = Rez.Strings.NotificationFourWeeks;
            body = Rez.Strings.NotificationLabelInfo;
        }
        return [title, subtitle, body];
    }
}
