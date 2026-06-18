import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../../../../core/router/route_paths.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/seller_dashboard_provider.dart';

/// Seller command-centre app bar: store avatar, greeting, store score badge,
/// notifications shortcut, and a settings link. Pins to the top as a sliver.
class SellerHeaderSliver extends ConsumerWidget {
  const SellerHeaderSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    final state = ref.watch(sellerDashboardNotifierProvider);
    final c = context.dsColors;

    return SliverToBoxAdapter(
      child: Container(
        color: c.background,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            DsSpacing.lg,
            MediaQuery.paddingOf(context).top + DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.md,
          ),
          child: Row(
            children: [
              _StoreAvatar(
                logoUrl: state.data?.storeInfo.logoUrl,
                isLoading: state.isInitialLoading,
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: _Greeting(
                  name: user?.name ?? 'Seller',
                  storeScore: state.data?.storeInfo.storeScore,
                  isLoading: state.isInitialLoading,
                ),
              ),
              _HeaderActions(context: context),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 380.ms),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({this.logoUrl, required this.isLoading});

  final String? logoUrl;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    if (isLoading) {
      return DsShimmer(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.shimmerBase,
          ),
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: context.storyRingGradient,
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: logoUrl != null
            ? CachedNetworkImage(
                imageUrl: logoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(color: c.surfaceVariant),
                errorWidget: (_, _, _) => _Fallback(c: c),
              )
            : _Fallback(c: c),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.c});

  final DsColorScheme c;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: c.primaryContainer,
        child: Icon(Icons.storefront_rounded, color: c.primary, size: 24),
      );
}

class _Greeting extends StatelessWidget {
  const _Greeting({
    required this.name,
    this.storeScore,
    required this.isLoading,
  });

  final String name;
  final int? storeScore;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    if (isLoading) {
      return DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsSkeleton.line(width: 100),
            const SizedBox(height: 4),
            DsSkeleton.line(width: 140),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          timeGreeting,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: c.onSurfaceVariant),
        ),
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: DsTypography.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (storeScore != null) ...[
              const SizedBox(width: DsSpacing.xs),
              _ScoreBadge(score: storeScore!),
            ],
          ],
        ),
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 90
        ? const Color(0xFF3FA86F)
        : score >= 75
            ? const Color(0xFF5B8DEF)
            : const Color(0xFFE0A23C);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: DsRadius.borderFull,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: 10,
              fontWeight: DsTypography.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({required this.context});

  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    final c = ctx.dsColors;
    return Row(
      children: [
        IconButton(
          icon: Badge(
            isLabelVisible: true,
            label: const Text('3'),
            child: Icon(Icons.notifications_none_rounded,
                color: c.onSurface, size: 24),
          ),
          onPressed: () => ctx.push(RoutePaths.notifications),
          tooltip: 'Notifications',
        ),
        IconButton(
          icon: Icon(Icons.chat_bubble_outline_rounded,
              color: c.onSurface, size: 24),
          onPressed: () => ctx.push(RoutePaths.chats),
          tooltip: 'Messages',
        ),
      ],
    );
  }
}
