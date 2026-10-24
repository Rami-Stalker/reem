import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/discovery/domain/entities/product_collection.dart';
import 'package:ohara/features/home/presentation/providers/home_content_provider.dart';
import 'package:ohara/features/home/presentation/providers/home_provider.dart';
import 'package:ohara/features/home/presentation/widgets/living/home_aura.dart';
import 'package:ohara/features/home/presentation/widgets/living/live_countdown.dart';

/// One line of what is happening on Ohara right now.
///
/// A deal ticking down, the piece everyone is asking for, something that
/// just landed — each gets a few seconds, then the line turns over. A shelf
/// shows twelve things at once and she reads none; a ticker shows one, and
/// it moves, so she reads it.
class HomePulse extends ConsumerStatefulWidget {
  const HomePulse({super.key});

  @override
  ConsumerState<HomePulse> createState() => _HomePulseState();
}

class _HomePulseState extends ConsumerState<HomePulse> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3600), (_) {
      if (mounted) setState(() => _index++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final deals = ref.watch(
      homeContentNotifierProvider.select((s) => s.content?.flashDeals),
    );
    final trending = ref.watch(
      homeNotifierProvider.select(
        (s) => s.sectionOf(ProductCollection.trending).products,
      ),
    );
    final fresh = ref.watch(
      homeNotifierProvider.select(
        (s) => s.sectionOf(ProductCollection.newArrivals).products,
      ),
    );

    final now = DateTime.now();
    final beats = <_Beat>[
      for (final deal in (deals ?? const []).take(2))
        if (deal.endsAt != null && deal.endsAt!.isAfter(now))
          _Beat(
            productId: deal.product.id,
            icon: Icons.bolt_rounded,
            line: (left) => l10n.homePulseDeal(deal.product.title, left),
            endsAt: deal.endsAt,
          ),
      for (final product in trending.take(2))
        _Beat(
          productId: product.id,
          icon: Icons.local_fire_department_rounded,
          line: (_) => l10n.homePulseTrending(product.title),
        ),
      for (final product in fresh.take(2))
        _Beat(
          productId: product.id,
          icon: Icons.new_releases_outlined,
          line: (_) => l10n.homePulseNew(product.title),
        ),
    ];
    if (beats.isEmpty) return const SizedBox.shrink();

    final beat = beats[_index % beats.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: GestureDetector(
        onTap: () => context.push(RoutePaths.productDetailsOf(beat.productId)),
        child: Container(
          height: DsSizes.controlLg,
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: DsRadius.borderFull,
            border: Border.all(color: colors.border),
            boxShadow: context.shadowSoft,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.xs,
                  vertical: DsSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: colors.discount.withValues(alpha: 0.12),
                  borderRadius: DsRadius.borderFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulseDotIndicator(color: colors.discount),
                    DsGaps.hXxs,
                    Text(
                      l10n.homePulseLive,
                      style: context.dsText.captionStrong.tint(colors.discount),
                    ),
                  ],
                ),
              ),
              DsGaps.hSm,
              Expanded(
                child: AnimatedSwitcher(
                  duration: DsMotion.slow,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween(
                            begin: const Offset(0, 0.6),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: DsMotion.emphasized,
                            ),
                          ),
                      child: child,
                    ),
                  ),
                  child: Row(
                    key: ValueKey(_index % beats.length),
                    children: [
                      Icon(
                        beat.icon,
                        size: DsSizes.iconXs,
                        color: colors.primary,
                      ),
                      DsGaps.hXs,
                      Expanded(
                        child: beat.endsAt == null
                            ? _line(context, beat.line(''))
                            : LiveCountdown(
                                endsAt: beat.endsAt!,
                                builder: (context, left) =>
                                    _line(context, beat.line(left)),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              // Mirrors itself under RTL: it points the way the page reads.
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: DsSizes.iconXs,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String text) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.dsText.bodySmall.tabular.tint(context.dsColors.onSurface),
  );
}

class _Beat {
  const _Beat({
    required this.productId,
    required this.icon,
    required this.line,
    this.endsAt,
  });

  final String productId;
  final IconData icon;
  final String Function(String timeLeft) line;
  final DateTime? endsAt;
}
