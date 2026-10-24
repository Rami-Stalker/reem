import 'package:flutter/material.dart';

import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The words «تقييمات من بمقاسي» draws with, in one place, so a fit is called
/// the same thing on the card, the summary and the composer.
abstract final class FitLabels {
  static String fit(AppLocalizations l10n, ReviewFit fit) => switch (fit) {
    ReviewFit.runsSmall => l10n.fitRunsSmall,
    ReviewFit.trueToSize => l10n.fitTrueToSize,
    ReviewFit.runsLarge => l10n.fitRunsLarge,
  };

  static IconData icon(ReviewFit fit) => switch (fit) {
    ReviewFit.runsSmall => Icons.compress_rounded,
    ReviewFit.trueToSize => Icons.check_circle_outline_rounded,
    ReviewFit.runsLarge => Icons.expand_rounded,
  };

  /// The summary's one sentence, when there is a verdict.
  static String verdict(AppLocalizations l10n, ReviewFit fit) => switch (fit) {
    ReviewFit.runsSmall => l10n.fitVerdictSmall,
    ReviewFit.trueToSize => l10n.fitVerdictTrue,
    ReviewFit.runsLarge => l10n.fitVerdictLarge,
  };
}
