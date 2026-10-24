/// The Ohara Trend Engine, as the app sees it.
///
/// One thing shapes every type behind this barrel: **a score always arrives
/// with its evidence.** The server sends the number, the nine components it
/// was made of, the raw window figures underneath those, and a confidence
/// saying how much of it to believe — and none of it is flattened to the
/// headline. A seller who is told her product scores 63 is entitled to ask
/// why, and the answer has to be on the device already.
///
/// Nothing here computes a trend. The client renders what the nightly pipeline
/// decided; it does not get a second opinion.
///
/// The types live in three files split along the layers of the engine itself —
/// scores, insights, and the dashboards built on both — so no consumer has to
/// know which one a type came from.
library;

export 'package:ohara/features/trends/domain/entities/trend_insight.dart';
export 'package:ohara/features/trends/domain/entities/trend_overview.dart';
export 'package:ohara/features/trends/domain/entities/trend_score.dart';
