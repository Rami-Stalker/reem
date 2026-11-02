import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:ohara/features/ai_stylist/presentation/widgets/stylist_aura.dart';

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

    return AnimatedSize(
      duration: DsDurations.normal,
      curve: DsCurves.emphasized,
      alignment: Alignment.topCenter,
      child: brief.chips.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.sm,
                DsSpacing.xs,
                DsSpacing.sm,
                DsSpacing.none,
              ),
              child: StylistPanel(
                radius: DsRadius.pill,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DsSpacing.sm,
                  DsSpacing.xxs,
                  DsSpacing.xxs,
                  DsSpacing.xxs,
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 14, color: colors.primary),
                    DsGaps.hXxs,
                    Text(
                      context.l10n.stylistUnderstood,
                      style: context.dsText.caption.semibold.tint(colors.onSurface),
                    ),
                    DsGaps.hXs,
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: brief.chips.length,
                          separatorBuilder: (_, _) => DsGaps.hXxs,
                          itemBuilder: (context, index) => StylistAppear(
                            index: index,
                            offset: 6,
                            child: _Chip(label: brief.chips[index].label),
                          ),
                        ),
                      ),
                    ),
                    if (onEdit != null)
                      IconButton(
                        onPressed: onEdit,
                        visualDensity: VisualDensity.compact,
                        tooltip: context.l10n.stylistMyPreferences,
                        icon: Icon(Icons.tune_rounded, size: 17, color: colors.primary),
                      ),
                  ],
                ),
              ),
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
          vertical: DsSpacing.xxxs,
        ),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(DsRadius.pill),
          border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
        ),
        child: Text(
          label,
          style: context.dsText.caption.medium.tint(colors.onPrimaryContainer),
        ),
      ),
    );
  }
}

/// The wait while a turn is in flight.
///
/// Ohara's orb quickens beside a bubble of rising dots and a line saying what
/// she is doing — a reply being put together reads as care, where a spinner
/// reads as the app being stuck.
class StylistTypingIndicator extends StatefulWidget {
  const StylistTypingIndicator({super.key});

  @override
  State<StylistTypingIndicator> createState() => _StylistTypingIndicatorState();
}

class _StylistTypingIndicatorState extends State<StylistTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void initState() {
    super.initState();
    if (!DsReducedMotion.isEnabled) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final boutique = context.boutique;

    return StylistAppear(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const OharaOrb(size: 30, thinking: true),
            DsGaps.hXs,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.md,
                vertical: DsSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceElevated.withValues(alpha: 0.92),
                border: Border.all(color: colors.border.withValues(alpha: 0.7)),
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(DsRadius.xl),
                  topEnd: Radius.circular(DsRadius.xl),
                  bottomEnd: Radius.circular(DsRadius.xl),
                  bottomStart: Radius.circular(DsRadius.xs),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          // Each dot trails the one before by a fifth of a cycle.
                          final phase = (_controller.value - index * 0.2) % 1;
                          final lift = math.max(0.0, math.sin(phase * math.pi * 2));
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DsSpacing.xxxs,
                            ),
                            child: Transform.translate(
                              offset: Offset(0, -4 * lift),
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color.lerp(colors.primary, boutique.gold, index / 2)!
                                      .withValues(alpha: 0.55 + 0.45 * lift),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  DsGaps.hXs,
                  Text(
                    context.l10n.stylistThinking,
                    style: context.dsText.caption.tint(colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
