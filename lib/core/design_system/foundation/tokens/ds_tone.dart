import 'package:flutter/widgets.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';

/// The meaning a status carries, independent of what colour draws it.
///
/// Domain entities used to answer "what colour is a grade of 82?" with a
/// `const Color(0xFF5B8DEF)` — a presentation decision frozen into the domain
/// layer, duplicated across two entity files, and unable to follow the theme.
/// They now answer with a [DsTone], and the widget resolves it.
enum DsTone {
  /// Healthy, delivered, on target.
  positive,

  /// Informational, in progress, neutral-good.
  info,

  /// Needs attention soon.
  caution,

  /// Failed, cancelled, overdue.
  critical,

  /// Brand-secondary — a state that is neither good nor bad, just distinct.
  accent,

  /// A returned or reversed flow.
  reversal,

  /// No signal.
  neutral,
}

extension DsToneContext on BuildContext {
  /// The foreground colour for a tone.
  Color toneColor(DsTone tone) {
    final c = dsColors;
    return switch (tone) {
      DsTone.positive => c.success,
      DsTone.info => c.info,
      DsTone.caution => c.warning,
      DsTone.critical => c.error,
      DsTone.accent => c.secondary,
      DsTone.reversal => c.discount,
      DsTone.neutral => c.onSurfaceVariant,
    };
  }

  /// The tinted fill that goes behind [toneColor] — a chip, a status pill, a
  /// medallion behind an icon.
  Color toneContainer(DsTone tone) {
    final c = dsColors;
    return switch (tone) {
      DsTone.positive => c.successContainer,
      DsTone.info => c.infoContainer,
      DsTone.caution => c.warningContainer,
      DsTone.critical => c.errorContainer,
      DsTone.accent => c.secondaryContainer,
      DsTone.reversal => c.errorContainer,
      DsTone.neutral => c.surfaceVariant,
    };
  }
}
