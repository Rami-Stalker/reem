import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';

/// Three pulsing dots on the other side's edge of the conversation.
///
/// Its animation controller repeats for ever and was never disposed, so every
/// time the peer stopped typing the widget left the tree with a live ticker —
/// an assertion in debug builds, and a leaked animation in release ones.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg,
          vertical: DsSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          border: Border.all(color: colors.border),
          borderRadius: DsRadius.borderCard,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: controller,
              builder: (_, _) => Container(
                margin: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
                width: DsSpacing.sm,
                height: DsSpacing.sm,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(
                    alpha: .3 + ((controller.value + index * .2) % 1) * .7,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
