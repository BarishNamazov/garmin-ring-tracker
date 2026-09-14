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

(:production, :background)
function reportOptionalServiceMemory() as Void { }
