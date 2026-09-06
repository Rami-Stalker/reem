import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/ai_stylist/domain/entities/style_brief.dart';

/// What the stylist understood, shown back to her.
///
/// This is the feature's honesty surface. A shopping assistant that quietly
/// misreads "٥٠٠ ألف" as five hundred returns nonsense and leaves her guessing
/// why; one that shows «حتى 500 ألف ل.س» above the results lets her catch it in
/// a glance and correct it in one sentence.
class StylistBriefBar extends StatelessWidget {
  const StylistBriefBar({super.key, required this.brief, this.onEdit});

  final StyleBrief brief;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    if (brief.chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Icon(Icons.tune_rounded, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: DsSpacing.xs),
          Expanded(
            child: SizedBox(
              height: 26,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: brief.chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xxs),
                itemBuilder: (context, index) => _Chip(
                  label: brief.chips[index].label,
                ),
              ),
            ),
          ),
          if (onEdit != null)
            InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(DsRadius.pill),
              child: Padding(
                padding: const EdgeInsets.all(DsSpacing.xxs),
                child: Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: colors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.xs,
          vertical: DsSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: colors.secondaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(DsRadius.pill),
        ),
        child: Text(
          label,
          style: context.dsText.caption.tint(colors.onSecondaryContainer),
        ),
      ),
    );
  }
}

/// The three dots while a turn is in flight.
///
/// Shown instead of a spinner because the wait is a *reply* being written, and
/// a spinner reads as the app being stuck.
class StylistTypingIndicator extends StatefulWidget {
  const StylistTypingIndicator({super.key});

  @override
  State<StylistTypingIndicator> createState() => _StylistTypingIndicatorState();
}

class _StylistTypingIndicatorState extends State<StylistTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.sm,
          vertical: DsSpacing.xs + DsSpacing.xxxs,
        ),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          border: Border.all(color: colors.border),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(DsRadius.lg),
            topRight: Radius.circular(DsRadius.lg),
            bottomRight: Radius.circular(DsRadius.lg),
            bottomLeft: Radius.circular(DsRadius.xs),
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                // Each dot leads the one before it by a third of a cycle.
                final phase = (_controller.value + index / 3) % 1;
                final scale = 0.6 + 0.4 * (1 - (phase * 2 - 1).abs());
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxxs),
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
