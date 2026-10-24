import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';

/// The other side is writing: three dots rising and falling in turn, inside a
/// bubble shaped like theirs.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        label: context.l10n.chatTyping,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: (isDark ? colors.surfaceElevated : colors.surface)
                .withValues(alpha: 0.92),
            shape: SilkBubbleBorder(
              mine: false,
              side: BorderSide(color: colors.border.withValues(alpha: 0.8)),
            ),
            shadows: context.shadowXs,
          ),
          child: const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              DsSpacing.lg + SilkBubbleBorder.tailWidth,
              DsSpacing.md,
              DsSpacing.lg,
              DsSpacing.md,
            ),
            child: WaveDots(),
          ),
        ),
      ),
    );
  }
}
