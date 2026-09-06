/// Damascus wall-clock time.
///
/// Every "good morning" on this app is a claim about *her* morning, not the
/// handset's. A phone left on a European timezone — or one whose owner travels,
/// or a demo device nobody ever set — greeted a Damascus shopper with «مساء
/// الخير» over her breakfast. The greeting is about Syria, so it reads Syria's
/// clock.
///
/// Syria abolished daylight saving in October 2022 and has stood on UTC+03:00
/// year round since, so the offset is a constant rather than a rule table. If
/// that ever changes, this one place changes with it.
library;

/// Syria's standard offset from UTC, fixed since 2022.
const Duration damascusOffset = Duration(hours: 3);

/// Now, as the clock on a wall in Damascus reads it.
///
/// Returned as a UTC-flagged `DateTime` whose fields already carry the offset —
/// only its calendar fields (`hour`, `weekday`, …) are meaningful, which is all
/// a greeting ever asks for.
DateTime damascusNow({DateTime? clock}) =>
    (clock ?? DateTime.now()).toUtc().add(damascusOffset);
