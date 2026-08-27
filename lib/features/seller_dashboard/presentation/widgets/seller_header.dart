import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../providers/seller_dashboard_provider.dart';

/// The command centre's app bar: the store's mark, its name, its health score,
/// and the two inboxes a seller checks first.
///
/// Pinned and frosted like the buyer's, but in the atelier palette — plum and
/// champagne over the theme's own ground, so it survives dark mode instead of
/// staying stubbornly white.
class SellerHeaderSliver extends ConsumerWidget {
  const SellerHeaderSliver({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.atelier;
    final state = ref.watch(sellerDashboardNotifierProvider);
    final store = state.data?.storeInfo;

    return SliverAppBar(
      pinned: true,
      floating: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      titleSpacing: DsSpacing.lg,
      toolbarHeight: 74,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: DsBlur.medium,
            sigmaY: DsBlur.medium,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.background.withValues(alpha: 0.98),
                  palette.background.withValues(alpha: 0.62),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          _StoreMark(
            logoUrl: store?.logoUrl,
            isLoading: state.isInitialLoading,
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: _Identity(
              storeName: store?.name,
              storeScore: store?.storeScore,
              isVerified: store?.isVerified ?? false,
              isLoading: state.isInitialLoading,
            ),
          ),
        ],
      ),
      actions: const [_HeaderActions()],
    );
  }
}

class _StoreMark extends StatelessWidget {
  const _StoreMark({this.logoUrl, required this.isLoading});

  final String? logoUrl;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    if (isLoading) {
      return DsShimmer(
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.dsColors.shimmerBase,
          ),
        ),
      );
    }

    final url = logoUrl ?? '';
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: palette.goldGradient,
      ),
      child: ClipOval(
        child: url.isEmpty
            ? _Fallback(palette: palette)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    ColoredBox(color: context.dsColors.shimmerBase),
                errorWidget: (_, _, _) => _Fallback(palette: palette),
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.palette});

  final SellerAtelierPalette palette;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: palette.primarySoft,
    child: Icon(
      Icons.storefront_rounded,
      color: palette.primary,
      size: 22,
    ),
  );
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.storeName,
    required this.storeScore,
    required this.isVerified,
    required this.isLoading,
  });

  final String? storeName;
  final int? storeScore;
  final bool isVerified;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;

    if (isLoading) {
      return DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            DsSkeleton.line(width: 92),
            SizedBox(height: 5),
            DsSkeleton.line(width: 150),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                gradient: palette.goldGradient,
                borderRadius: DsRadius.borderPill,
              ),
            ),
            const SizedBox(width: DsSpacing.xxs),
            Flexible(
              child: Text(
                l10n.sellerCommandCentre.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsTypography.overline(palette.gold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Row(
          children: [
            Flexible(
              child: Text(
                storeName ?? l10n.sellerDashboard,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.ink,
                  fontFamily: DsTypography.fontFamilyDisplay,
                  fontFamilyFallback: DsTypography.displayFallback,
                  fontSize: DsTypography.titleMedium,
                  fontWeight: DsTypography.bold,
                  height: 1.2,
                ),
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: DsSpacing.xxs),
              Icon(
                Icons.verified_rounded,
                size: 14,
                color: context.dsColors.secondary,
              ),
            ],
            if (storeScore != null) ...[
              const SizedBox(width: DsSpacing.xs),
              _ScoreChip(score: storeScore!),
            ],
          ],
        ),
      ],
    );
  }
}

/// The store health score, coloured by band.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final color = switch (score) {
      >= 90 => palette.positive,
      >= 75 => palette.primary,
      >= 60 => palette.caution,
      _ => palette.critical,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.speed_rounded, size: 11, color: color),
          const SizedBox(width: 2),
          Text(
            '$score',
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: 10,
              fontWeight: DsTypography.bold,
              color: color,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  const _HeaderActions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: DsSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderButton(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: l10n.messages,
            onTap: () => context.push(RoutePaths.chats),
          ),
          const SizedBox(width: DsSpacing.xs),
          _HeaderButton(
            icon: Icons.notifications_none_rounded,
            tooltip: l10n.notifications,
            hasDot: true,
            onTap: () => context.push(RoutePaths.notifications),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.hasDot = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.raised.withValues(alpha: 0.8),
                shape: BoxShape.circle,
                border: Border.all(color: palette.line),
              ),
              child: Icon(icon, size: 19, color: palette.ink),
            ),
            if (hasDot)
              PositionedDirectional(
                top: 9,
                end: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: palette.critical,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.raised, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
