import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/value_objects/money_format.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/presentation/providers/store_ads_providers.dart';
import 'package:ohara/features/store_ads/presentation/widgets/ads_widgets.dart';
import 'package:ohara/features/store_ads/presentation/widgets/store_ads_labels.dart';

/// «مركز الإعلانات» — a boutique's whole advertising life on one page.
///
/// Read top to bottom the way she would use it: what her plan gives her right
/// now, how her adverts are doing, which of her pieces are worth promoting
/// next (and why), and the campaigns she is running.
class AdsCenterScreen extends ConsumerWidget {
  const AdsCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plans = ref.watch(adPlansProvider);
    final gutter = atelierGutter(context);

    Future<void> refresh() async {
      ref.read(storeAdsActionsProvider).refresh();
      await ref
          .read(adPlansProvider.future)
          .catchError((_) => const AdPlansView());
    }

    Widget padded(Widget child) => SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: child,
      ),
    );

    return OharaScrollPage(
      onRefresh: refresh,
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.campaign_rounded,
          title: l10n.adsCenterTitle,
          subtitle: l10n.adsCenterSubtitle,
          showBack: true,
        ),
        DsGaps.sliverMd,
        padded(
          plans.when(
            loading: () => const DsShimmer(
              child: DsSkeleton.box(height: 220, borderRadius: DsRadius.xxl),
            ),
            error: (error, _) => DsErrorState(
              message: error is Failure ? error.displayMessage : l10n.adsFailed,
              onRetry: () => ref.invalidate(adPlansProvider),
            ),
            data: (view) => _PlanHero(view: view),
          ),
        ),
        DsGaps.sliverLg,
        padded(
          DsButton(
            label: l10n.adsNewCampaign,
            icon: Icons.add_rounded,
            onPressed: () => context.push(RoutePaths.sellerAdsNew),
          ),
        ),
        DsGaps.sliverXxl,
        padded(const _Performance()),
        DsGaps.sliverXxl,
        const SliverToBoxAdapter(child: _Suggestions()),
        DsGaps.sliverXxl,
        padded(AtelierHeading(title: l10n.adsCampaignsTitle)),
        DsGaps.sliverMd,
        const _Campaigns(),
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The plan
// ---------------------------------------------------------------------------

class _PlanHero extends StatelessWidget {
  const _PlanHero({required this.view});

  final AdPlansView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.dsText;
    final current = view.current;
    final jewel = current.tier.jewel;
    final days = current.daysLeft(DateTime.now());
    final rec = view.recommendation;

    return AtelierHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adsYourPlan,
                      style: text.overline.tint(DsColors.onMediaMuted),
                    ),
                    DsGaps.vXs,
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            current.tier.label(l10n),
                            style: text.pageTitle.tint(DsColors.onMedia),
                          ),
                        ),
                        if (jewel != null) ...[
                          DsGaps.hXs,
                          DsTierBadge.compact(
                            tier: jewel,
                            label: l10n.storeTierBadge(
                              current.tier.label(l10n),
                            ),
                          ),
                        ],
                      ],
                    ),
                    DsGaps.vXs,
                    Text(
                      l10n.adsActiveOf(
                        current.activeCampaigns,
                        current.maxActiveCampaigns,
                      ),
                      style: text.caption.tint(DsColors.onMediaMuted),
                    ),
                    if (days != null) ...[
                      DsGaps.vXxs,
                      Text(
                        l10n.adsPlanEndsIn(days),
                        style: text.caption.tint(DsColors.onMediaMuted),
                      ),
                    ],
                  ],
                ),
              ),
              if (current.tier.isPaid)
                Column(
                  children: [
                    ArchGauge(
                      progress: current.creditProgress,
                      width: DsSizes.iconXxl,
                      semanticLabel: l10n.adsCreditLeft(
                        formatSyp(current.creditRemaining),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (current.tier.isPaid) ...[
            DsGaps.vMd,
            Text(
              l10n.adsCreditLeft(formatSyp(current.creditRemaining)),
              style: text.bodyStrong.tint(DsColors.onMedia),
            ),
          ],
          if (rec != null) ...[
            DsGaps.vMd,
            Container(
              padding: DsSpacing.cardPadding,
              decoration: BoxDecoration(
                color: DsColors.onMedia.withValues(alpha: 0.12),
                borderRadius: DsRadius.borderLg,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    size: DsSizes.iconSm,
                    color: DsColors.onMedia,
                  ),
                  DsGaps.hXs,
                  Expanded(
                    child: Text(
                      rec.reason == AdRecommendationReason.wouldHaveSaved
                          ? l10n.adsRecommendSaving(
                              rec.tier.label(l10n),
                              formatSyp(rec.saving),
                            )
                          : l10n.adsPlanStartHint,
                      style: text.caption.tint(DsColors.onMedia),
                    ),
                  ),
                ],
              ),
            ),
          ],
          DsGaps.vLg,
          DsButton(
            label: current.tier == AdTier.diamond
                ? l10n.adsSeePlans
                : l10n.adsUpgrade,
            icon: Icons.workspace_premium_rounded,
            variant: DsButtonVariant.tonal,
            size: DsButtonSize.md,
            onPressed: () => context.push(RoutePaths.sellerAdsPlans),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Performance
// ---------------------------------------------------------------------------

class _Performance extends ConsumerWidget {
  const _Performance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final overview = ref.watch(adsOverviewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AtelierHeading(
          title: l10n.adsPerformance,
          caption: l10n.adsPerformanceCaption,
        ),
        DsGaps.vMd,
        overview.when(
          loading: () => const DsShimmer(
            child: DsSkeleton.box(height: 180, borderRadius: DsRadius.lg),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (o) {
            final tiles = [
              AdMetricTile(
                icon: Icons.payments_outlined,
                value: formatSyp(o.spend),
                label: l10n.adsMetricSpend,
              ),
              AdMetricTile(
                icon: Icons.groups_rounded,
                value: formatCount(o.reach),
                label: l10n.adsMetricReach,
                accent: palette.series[1],
              ),
              AdMetricTile(
                icon: Icons.touch_app_outlined,
                value: formatCount(o.clicks),
                label: l10n.adsMetricClicks,
                accent: palette.series[2],
              ),
              AdMetricTile(
                icon: Icons.shopping_bag_outlined,
                value: formatCount(o.attributedOrders),
                label: l10n.adsMetricOrders,
                accent: palette.positive,
              ),
              AdMetricTile(
                icon: Icons.trending_up_rounded,
                value: formatSyp(o.attributedRevenue),
                label: l10n.adsMetricRevenue,
                accent: palette.gold,
              ),
              AdMetricTile(
                icon: Icons.auto_graph_rounded,
                value: o.returnOnAdSpend == null
                    ? l10n.adsNotYet
                    : l10n.adsRoasValue(o.returnOnAdSpend!.toStringAsFixed(1)),
                label: l10n.adsMetricRoas,
                accent: palette.series[3],
              ),
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 520 ? 3 : 2;
                    final width =
                        (constraints.maxWidth - DsSpacing.sm * (columns - 1)) /
                        columns;
                    return Wrap(
                      spacing: DsSpacing.sm,
                      runSpacing: DsSpacing.sm,
                      children: [
                        for (final tile in tiles)
                          SizedBox(width: width, child: tile),
                      ],
                    );
                  },
                ),
                DsGaps.vMd,
                _InsightLine(insight: o.insight),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({required this.insight});

  final AdInsight insight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (tone, icon, message) = switch (insight) {
      AdInsight.aboveAverage => (
        DsTone.positive,
        Icons.rocket_launch_rounded,
        l10n.adsInsightAbove,
      ),
      AdInsight.average => (
        DsTone.info,
        Icons.balance_rounded,
        l10n.adsInsightAverage,
      ),
      AdInsight.belowAverage => (
        DsTone.caution,
        Icons.lightbulb_outline_rounded,
        l10n.adsInsightBelow,
      ),
      AdInsight.notEnoughData => (
        DsTone.neutral,
        Icons.hourglass_empty_rounded,
        l10n.adsInsightNoData,
      ),
    };
    return Container(
      padding: DsSpacing.cardPadding,
      decoration: BoxDecoration(
        color: context.toneContainer(tone),
        borderRadius: DsRadius.borderLg,
      ),
      child: Row(
        children: [
          Icon(icon, size: DsSizes.iconSm, color: context.toneColor(tone)),
          DsGaps.hXs,
          Expanded(
            child: Text(
              message,
              style: context.dsText.bodySmall.tint(context.toneColor(tone)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Smart picks
// ---------------------------------------------------------------------------

class _Suggestions extends ConsumerWidget {
  const _Suggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final suggestions = ref.watch(adSuggestionsProvider).value ?? const [];
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final gutter = atelierGutter(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: AtelierHeading(
            title: l10n.adsSuggestionsTitle,
            caption: l10n.adsSuggestionsCaption,
          ),
        ),
        DsGaps.vLg,
        DisplayShelf(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          children: [
            for (final s in suggestions)
              ShelfPiece(
                image: AdProductThumb(
                  url: s.imageUrl,
                  size: DsSizes.railCardWidth,
                ),
                title: s.title,
                tag: s.reason.label(l10n),
                tagColor: s.reason == AdSuggestionReason.bestSeller
                    ? palette.positive
                    : null,
                onTap: () => context.push(RoutePaths.sellerAdsNew, extra: s),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Campaigns
// ---------------------------------------------------------------------------

class _Campaigns extends ConsumerWidget {
  const _Campaigns();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final campaigns = ref.watch(adCampaignsProvider);
    final gutter = atelierGutter(context);

    return campaigns.when(
      loading: () => SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: const DsShimmer(
            child: DsSkeleton.box(height: 140, borderRadius: DsRadius.lg),
          ),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: DsErrorState(
          message: error is Failure ? error.displayMessage : l10n.adsFailed,
          onRetry: () => ref.invalidate(adCampaignsProvider),
        ),
      ),
      data: (rows) => rows.isEmpty
          ? SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: DsEmptyState(
                  icon: Icons.campaign_outlined,
                  title: l10n.adsNoCampaigns,
                  message: l10n.adsNoCampaignsBody,
                ),
              ),
            )
          : SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverList.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => DsGaps.vMd,
                itemBuilder: (context, index) =>
                    _CampaignCard(campaign: rows[index]),
              ),
            ),
    );
  }
}

class _CampaignCard extends ConsumerStatefulWidget {
  const _CampaignCard({required this.campaign});

  final AdCampaign campaign;

  @override
  ConsumerState<_CampaignCard> createState() => _CampaignCardState();
}

class _CampaignCardState extends ConsumerState<_CampaignCard> {
  bool _busy = false;

  Future<void> _set(AdCampaignStatus status) async {
    setState(() => _busy = true);
    final failure = await ref
        .read(storeAdsActionsProvider)
        .setStatus(widget.campaign, status);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      DsSnackbar.show(
        context,
        message: adFailureMessage(context.l10n, failure),
        type: DsSnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    final l10n = context.l10n;
    final palette = context.atelier;
    final text = context.dsText;

    return SellerPanel(
      padding: DsSpacing.cardPaddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AdProductThumb(url: c.productImage),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.productTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.cardTitle.tint(palette.ink),
                    ),
                    DsGaps.vXxs,
                    Row(
                      children: [
                        Icon(
                          c.placement.icon,
                          size: DsSizes.iconXs,
                          color: palette.muted,
                        ),
                        DsGaps.hXxs,
                        Flexible(
                          child: Text(
                            l10n.adsCampaignWhere(
                              c.placement.label(l10n),
                              c.audience.isEffectivelyTargeted
                                  ? l10n.adsAudienceTargeted
                                  : l10n.adsAudienceEveryone,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.caption.tint(palette.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AdStatusPill(label: c.statusLabel(l10n), tone: c.statusTone),
            ],
          ),
          DsGaps.vMd,
          ClipRRect(
            borderRadius: DsRadius.borderFull,
            child: LinearProgressIndicator(
              value: c.progress(DateTime.now()),
              minHeight: DsSpacing.xxs,
              color: palette.primary,
              backgroundColor: palette.primarySoft,
            ),
          ),
          DsGaps.vMd,
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.adsCampaignStats(
                    formatCount(c.impressions),
                    formatCount(c.clicks),
                  ),
                  style: text.caption.tint(palette.ink),
                ),
              ),
              Text(
                l10n.adsCampaignReachOrders(
                  formatCount(c.reach),
                  formatCount(c.attributedOrders),
                ),
                style: text.captionStrong.tint(palette.positive),
              ),
            ],
          ),
          if (c.attributedRevenue > 0) ...[
            DsGaps.vXxs,
            Text(
              l10n.adsCampaignRevenue(c.attributedRevenue.toDouble().sypFull),
              style: text.caption.tint(palette.muted),
            ),
          ],
          if (c.canPause || c.canResume) ...[
            DsGaps.vMd,
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: DsButton(
                label: c.canPause ? l10n.adsPause : l10n.adsResume,
                icon: c.canPause
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                variant: DsButtonVariant.secondary,
                size: DsButtonSize.sm,
                isExpanded: false,
                isLoading: _busy,
                onPressed: _busy
                    ? null
                    : () => _set(
                        c.canPause
                            ? AdCampaignStatus.paused
                            : AdCampaignStatus.active,
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
