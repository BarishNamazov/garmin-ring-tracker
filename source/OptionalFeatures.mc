import Toybox.Lang;

// Release counterparts for optional QA hooks. Their names and behavior are
// neutral, and the debug implementation file is physically excluded.
(:production)
function openOptionalMenu(id) as Lang.Boolean { return false; }

(:production)
function optionalActionMessage(action as Lang.Symbol, fallback as Lang.String) as Lang.String { return fallback; }

(:production)
function optionalSeedState(action as Lang.Symbol, data, nowUtc as Lang.Number) as Lang.Dictionary? { return null; }

(:production)
function isFreshOptionalSeed(action as Lang.Symbol, data) as Lang.Boolean { return false; }

(:production)
function isTransientOptionalSeed(action as Lang.Symbol, data) as Lang.Boolean { return false; }

(:production)
function previewOptionalNotification(data, state as Lang.Dictionary, nowUtc as Lang.Number) as Void { }

(:production)
function afterOptionalSeed(action as Lang.Symbol, data) as Void { }

(:production, :background)
function reportOptionalServiceMemory() as Void { }

(:production, :background)
function showOptionalNotification(title as Lang.String, subtitle as Lang.String, options) as Void {
    Toybox.Notifications.showNotification(title, subtitle, options);
}

(:production, :background)
function reportOptionalServiceResult(kind, notificationShown as Lang.Boolean,
                                     ledgerSaved as Lang.Boolean, caught as Lang.Boolean) as Void { }

(:production)
function pickerUses24Hour(reminders as Lang.Dictionary) as Lang.Boolean {
    return Toybox.System.getDeviceSettings().is24Hour;
}
