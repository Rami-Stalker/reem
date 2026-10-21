import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_decode.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/social/domain/entities/content_analytics.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';

/// What a boutique can see about its own content, and about the women carrying
/// its products around.
///
/// Three questions, in the order she asks them: what is worth making more of,
/// how far has it travelled, and who is doing the travelling. The last one is
/// the point of the whole reshare feature on her side — and it is where the
/// privacy rule shows: a woman whose page is open is named, and one whose page
/// is closed is counted.
class ContentStudioScreen extends ConsumerWidget {
  const ContentStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formats = ref.watch(contentFormatPerformanceProvider);
    final reshares = ref.watch(reshareSummaryProvider);
    final promoters = ref.watch(promotersProvider);

    return ReemScrollPage(
      background: const SellerAtelierBackground(),
      onRefresh: () async {
        ref.invalidate(contentFormatPerformanceProvider);
        ref.invalidate(reshareSummaryProvider);
        ref.invalidate(promotersProvider);
      },
      slivers: [
        PremiumAppBar(
          title: context.l10n.studioTitle,
          subtitle: context.l10n.studioSubtitle,
          showBack: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.gutter),
          sliver: SliverList.list(
            children: [
              // ── What is worth making more of ──────────────────────────
              ReemSectionHeader(title: context.l10n.studioFormats),
              DsGaps.vSm,
              formats.when(
                loading: () => const DsLoadingIndicator(),
                error: (error, _) => DsInlineError(message: '$error'),
                data: (rows) => rows.isEmpty
                    ? DsEmptyState(
                        icon: Icons.insights_outlined,
                        title: context.l10n.studioFormatsEmpty,
                      )
                    : Column(
                        children: [
                          for (final row in rows)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: DsSpacing.sm,
                              ),
                              child: _FormatRow(row: row),
                            ),
                        ],
                      ),
              ),

              // ── How far it travelled ──────────────────────────────────
              DsGaps.vXl,
              ReemSectionHeader(title: context.l10n.studioReach),
              DsGaps.vSm,
              reshares.when(
                loading: () => const DsLoadingIndicator(),
                error: (error, _) => DsInlineError(message: '$error'),
                data: (summary) => _ReachPanel(summary: summary),
              ),

              // ── Who is doing the travelling ───────────────────────────
              DsGaps.vXl,
              ReemSectionHeader(title: context.l10n.studioPromoters),
              DsGaps.vXxs,
              Text(
                context.l10n.studioPromotersHelp,
                style: context.dsText.caption.tint(
                  context.dsColors.onSurfaceVariant,
                ),
              ),
              DsGaps.vSm,
              promoters.when(
                loading: () => const DsLoadingIndicator(),
                error: (error, _) => DsInlineError(message: '$error'),
                data: (page) => page.items.isEmpty
                    ? DsEmptyState(
                        icon: Icons.groups_outlined,
                        title: context.l10n.studioPromotersEmpty,
                        message: context.l10n.studioPromotersEmptyBody,
                      )
                    : Column(
                        children: [
                          for (final promoter in page.items)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: DsSpacing.sm,
                              ),
                              child: _PromoterRow(promoter: promoter),
                            ),
                        ],
                      ),
              ),
              DsGaps.bottomSafe,
            ],
          ),
        ),
      ],
    );
  }
}

class _FormatRow extends StatelessWidget {
  const _FormatRow({required this.row});

  final ContentFormatPerformance row;

  String _label(BuildContext context) => switch (row.format) {
    'reel' => context.l10n.reelsTitle,
    'story' => context.l10n.studioFormatStory,
    'product_post' => context.l10n.studioFormatPost,
    _ => row.format,
  };

  @override
  Widget build(BuildContext context) {
    final a = context.atelier;
    return SellerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_label(context), style: context.dsText.cardTitle),
              ),
              Text(
                context.l10n.studioPublishedCount(row.published),
                style: context.dsText.caption.tint(a.muted),
              ),
            ],
          ),
          DsGaps.vSm,
          Wrap(
            spacing: DsSpacing.lg,
            runSpacing: DsSpacing.sm,
            children: [
              _Metric(label: context.l10n.studioViews, value: row.views),
              _Metric(label: context.l10n.a11yLike, value: row.likes),
              _Metric(label: context.l10n.comments, value: row.comments),
              _Metric(label: context.l10n.studioSaves, value: row.saves),
              _Metric(
                label: context.l10n.studioProductClicks,
                value: row.productClicks,
              ),
            ],
          ),
          if (row.views > 0) ...[
            DsGaps.vSm,
            // The number that separates a social app from a commerce one:
            // whether being watched turns into being opened.
            Text(
              context.l10n.studioClickThrough(
                (row.clickThrough * 100).toStringAsFixed(1),
              ),
              style: context.dsText.caption.tint(a.gold),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value', style: context.dsText.metric),
        Text(
          label,
          style: context.dsText.micro.tint(context.atelier.muted),
        ),
      ],
    );
  }
}

class _ReachPanel extends StatelessWidget {
  const _ReachPanel({required this.summary});

  final ReshareSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) {
      return DsEmptyState(
        icon: Icons.share_outlined,
        title: context.l10n.studioReachEmpty,
        message: context.l10n.studioReachEmptyBody,
      );
    }

    return SellerPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: context.l10n.studioReshares,
                  value: summary.totalReshares,
                ),
              ),
              Expanded(
                child: _Metric(
                  // Distinct women, not reshares. One enthusiast adding nine
                  // posts is one promoter, and saying nine would tell her
                  // something untrue about her reach.
                  label: context.l10n.studioPromotersCount,
                  value: summary.promoters,
                ),
              ),
            ],
          ),
          if (summary.topProducts.isNotEmpty) ...[
            DsGaps.vLg,
            Text(
              context.l10n.studioTopProducts,
              style: context.dsText.labelLarge,
            ),
            DsGaps.vSm,
            for (final product in summary.topProducts.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        product.title ?? product.productId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.body,
                      ),
                    ),
                    Text(
                      '${product.reshares}',
                      style: context.dsText.caption,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PromoterRow extends StatelessWidget {
  const _PromoterRow({required this.promoter});

  final ContentPromoter promoter;

  @override
  Widget build(BuildContext context) {
    final a = context.atelier;
    final user = promoter.user;

    return SellerPanel(
      child: Row(
        children: [
          if (user != null)
            DsAvatar(
              imageUrl: user.imageUrl,
              name: user.name,
              size: DsSizes.avatarSm,
            )
          else
            // A woman whose page is closed. She is counted and never named —
            // the server does not send her name at all, so there is nothing
            // here to leak.
            CircleAvatar(
              radius: DsSizes.avatarSm / 2,
              backgroundColor: a.line,
              child: Icon(
                Icons.person_outline_rounded,
                size: DsSizes.iconSm,
                color: a.muted,
              ),
            ),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? context.l10n.studioPromoterAnonymous,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.tileTitle,
                ),
                Text(
                  context.l10n.studioPromoterSummary(
                    promoter.reshares,
                    promoter.products,
                  ),
                  style: context.dsText.micro.tint(a.muted),
                ),
              ],
            ),
          ),
          Text(
            formatRelativeTime(context.l10n, promoter.lastAt),
            style: context.dsText.micro.tint(a.muted),
          ),
          if (user != null)
            DsIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: context.l10n.viewProfile,
              onPressed: () =>
                  context.push(RoutePaths.userProfileOf(user.id)),
            ),
        ],
      ),
    );
  }
}

/// A tile for one of her pieces, used by the reach panel's top-content list.
class ContentThumb extends StatelessWidget {
  const ContentThumb({super.key, required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return SizedBox(
      width: DsSizes.thumbMd,
      height: DsSizes.thumbMd,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DsRadius.sm),
        child: url == null || url.isEmpty
            ? const DsMediaFallback()
            : CachedNetworkImage(
                imageUrl: MediaVariants.thumb(url),
                memCacheWidth: MediaDecode.widthFor(context, DsSizes.thumbMd),
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const DsMediaFallback(),
              ),
      ),
    );
  }
}
