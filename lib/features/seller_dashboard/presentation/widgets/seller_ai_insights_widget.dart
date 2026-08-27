import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../domain/entities/seller_misc.dart';
import '../providers/seller_dashboard_provider.dart';

class SellerAiInsightsWidget extends ConsumerWidget {
  const SellerAiInsightsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final theme = Theme.of(context);

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 220, borderRadius: DsRadius.xxl)),
      );
    }

    final insights = state.data?.aiInsights ?? [];
    if (insights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: context.primaryGradient,
                  borderRadius: DsRadius.borderSm,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 14, color: Colors.white),
              ),
              const SizedBox(width: DsSpacing.xs),
              Text(
                context.l10n.sellerInsights,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: DsTypography.bold),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          ...insights.asMap().entries.map((e) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: e.key < insights.length - 1 ? DsSpacing.sm : 0),
              child: _InsightCard(insight: e.value)
                  .animate(delay: (e.key * 80).ms)
                  .fadeIn(duration: 320.ms)
                  .slideX(begin: 0.04, end: 0, duration: 320.ms),
            );
          }),
        ],
      ),
    );
  }
}

class _InsightCard extends StatefulWidget {
  const _InsightCard({required this.insight});

  final SellerAiInsight insight;

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final insight = widget.insight;
    final color = insight.kindColor;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: DsRadius.borderLg,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(DsSpacing.xs),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: DsRadius.borderSm,
                  ),
                  child: Icon(insight.kindIcon, size: 16, color: color),
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: DsTypography.bold,
                          color: c.onSurface,
                        ),
                      ),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _expanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: Text(
                          insight.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: c.onSurfaceVariant),
                        ),
                        secondChild: Text(
                          insight.body,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: c.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: c.onSurfaceVariant,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: DsSpacing.sm),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: Text(insight.action),
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.sm, vertical: DsSpacing.xxs),
                  textStyle: const TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.labelSmall,
                    fontWeight: DsTypography.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
