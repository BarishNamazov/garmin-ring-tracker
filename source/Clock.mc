import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Time;

(:production, :background, :glance)
function currentUtc() {
    return Time.now().value();
}

// QA can seed Storage["debugNowUtc"] from the hidden Demo scenarios menu.
// This function is absent from release PRGs, not merely disabled at runtime.
(:debug, :background, :glance)
function currentUtc() {
    var overridden = Storage.getValue("debugNowUtc");
    return overridden instanceof Lang.Number ? overridden : Time.now().value();
}
