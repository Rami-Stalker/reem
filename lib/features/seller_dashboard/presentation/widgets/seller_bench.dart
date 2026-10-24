import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_decode.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_chart_data.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_dashboard_data.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_orders_summary.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_format.dart';
import 'package:reem/features/seller_dashboard/presentation/widgets/seller_labels.dart';

/// The pieces of the seller's home, **the workbench**, in the order her day
/// goes: how the shop is doing and the month's goal ([BenchHero]); the one
/// thing to do first and the few after it ([BenchNextStitch]); the order
/// seam ([BenchSeam]); her tools ([BenchTools]); what is on the rail
/// ([BenchRail]); and the sales pattern ([BenchPattern]).
///
/// Each one reads the dashboard state itself and renders nothing until the
/// store has loaded, so the screen is only a list of sections.

double benchGutter(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600 ? DsSpacing.md : DsSpacing.xl;

// ---------------------------------------------------------------------------
// The hero
// ---------------------------------------------------------------------------

class BenchHero extends ConsumerWidget {
  const BenchHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final data = state.data;
    if (data == null) {
      return state.isInitialLoading
          ? const DsShimmer(
              child: DsSkeleton.box(height: 220, borderRadius: DsRadius.xxl),
            )
          : const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? l10n.sellerBenchGreetingMorning
        : l10n.sellerBenchGreetingEvening;
    final compact = MediaQuery.sizeOf(context).width < 600;
    final revenue = data.revenue;
    final goal = data.goals.isEmpty ? null : data.goals.first;
    final progress = goal == null || goal.target <= 0
        ? 0.0
        : (goal.current / goal.target).clamp(0.0, 1.0);
    final rising = revenue.todayTrend >= 0;

    final takings = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.sellerBenchTodayTakings,
          style: context.dsText.labelMedium.tint(DsColors.onMediaMuted),
        ),
        DsGaps.vXxs,
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            revenue.today.sypFull,
            style: context.dsText.hero.displayFamily.bold.tint(
              DsColors.gold200,
            ),
          ),
        ),
        DsGaps.vXs,
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: DsSpacing.pillPadding,
              decoration: BoxDecoration(
                color: DsColors.mediaPlate,
                borderRadius: DsRadius.borderPill,
                border: Border.all(color: DsColors.onMediaFaint),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    rising
                        ? Icons.north_east_rounded
                        : Icons.south_east_rounded,
                    size: DsSizes.iconXxs,
                    color: rising ? DsColors.gold200 : DsColors.coral300,
                  ),
                  DsGaps.hXxs,
                  Text(
                    formatTrend(revenue.todayTrend),
                    textDirection: TextDirection.ltr,
                    style: context.dsText.captionStrong.tint(DsColors.onMedia),
                  ),
                ],
              ),
            ),
            Text(
              l10n.sellerVsPrior,
              style: context.dsText.caption.tint(DsColors.onMediaMuted),
            ),
          ],
        ),
        DsGaps.vLg,
        Wrap(
          spacing: DsSpacing.xl,
          runSpacing: DsSpacing.sm,
          children: [
            _HeroFigure(
              label: l10n.periodWeek,
              value: revenue.thisWeek.sypCompact,
            ),
            _HeroFigure(
              label: l10n.periodMonth,
              value: revenue.thisMonth.sypCompact,
            ),
          ],
        ),
      ],
    );

    final spool = goal == null
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThreadSpool(
                progress: progress,
                width: compact ? 52 : 64,
                semanticLabel: '${goal.label} ${(progress * 100).round()}%',
              ),
              DsGaps.vSm,
              Text(
                '${(progress * 100).round()}%',
                style: context.dsText.metricSmall.displayFamily.tint(
                  DsColors.gold100,
                ),
              ),
              SizedBox(
                width: compact ? 92 : 112,
                child: Text(
                  progress >= 1 ? l10n.sellerBenchGoalReached : goal.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.caption.tint(DsColors.onMediaMuted),
                ),
              ),
            ],
          );

    return AtelierHero(
      padding: compact ? DsSpacing.paddingLg : DsSpacing.paddingXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MaterialLocalizations.of(context).formatFullDate(now),
            style: context.dsText.overline.tint(DsColors.onMediaMuted),
          ),
          DsGaps.vXs,
          Text(
            l10n.sellerBenchGreetingNamed(greeting, data.storeInfo.name),
            style:
                (compact
                        ? context.dsText.screenTitle
                        : context.dsText.pageTitle)
                    .displayFamily
                    .bold
                    .tint(DsColors.onMedia),
          ),
          DsGaps.vLg,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: takings),
              if (spool != null) ...[DsGaps.hMd, spool],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  const _HeroFigure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.dsText.caption.tint(DsColors.onMediaMuted)),
        Text(
          value,
          style: context.dsText.bodyLarge.bold.tint(DsColors.onMedia),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The next stitch
// ---------------------------------------------------------------------------

/// One thing on her list today.
@immutable
class _Stitch {
  const _Stitch({
    required this.title,
    required this.hint,
    required this.icon,
    required this.tone,
    this.action,
    this.route,
  });

  final String title;
  final String hint;
  final IconData icon;
  final DsTone tone;
  final String? action;
  final String? route;
}

/// What to do first, and what after it.
///
/// Ordered by what costs her most to leave: a new order cools by the hour,
/// a ready parcel misses today's courier, a sold-out piece drops out of
/// search; then the tasks the server already ranked. Only the first is drawn
/// large, because a list of equals is how the old page made her read
/// everything to find anything.
class BenchNextStitch extends ConsumerWidget {
  const BenchNextStitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sellerDashboardNotifierProvider).data;
    if (data == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final palette = context.atelier;
    final stitches = _stitchesFor(context, data);

    if (stitches.isEmpty) {
      return StitchedCard(
        accent: palette.positive,
        child: Row(
          children: [
            Icon(
              Icons.spa_outlined,
              size: DsSizes.iconLg,
              color: palette.positive,
            ),
            DsGaps.hMd,
            Expanded(
              child: Text(
                l10n.sellerBenchCalm,
                style: context.dsText.bodyLarge.tint(palette.ink),
              ),
            ),
          ],
        ),
      );
    }

    final first = stitches.first;
    final rest = stitches.skip(1).take(4).toList(growable: false);
    final accent = context.toneColor(first.tone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StitchedCard(
          accent: accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: DsSpacing.pillPadding,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: DsRadius.borderPill,
                    ),
                    child: Text(
                      l10n.sellerBenchStartHere,
                      style: context.dsText.captionStrong.tint(accent),
                    ),
                  ),
                  const Spacer(),
                  Icon(first.icon, color: accent, size: DsSizes.iconMd),
                ],
              ),
              DsGaps.vMd,
              Text(
                first.title,
                style: context.dsText.screenTitle.bold.tint(palette.ink),
              ),
              DsGaps.vXs,
              Text(first.hint, style: context.dsText.body.tint(palette.muted)),
              if (first.route != null && first.action != null) ...[
                DsGaps.vLg,
                // The button's frame fills whatever width it is offered, so
                // it is offered only its own.
                IntrinsicWidth(
                  child: PrimaryButton(
                    label: first.action!,
                    isExpanded: false,
                    onPressed: () => context.push(first.route!),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (rest.isNotEmpty) ...[
          DsGaps.vLg,
          Text(
            l10n.sellerBenchThen,
            style: context.dsText.overline.tint(palette.muted),
          ),
          DsGaps.vXs,
          for (final (i, stitch) in rest.indexed)
            _ThenRow(stitch: stitch, last: i == rest.length - 1),
        ],
      ],
    );
  }

  List<_Stitch> _stitchesFor(BuildContext context, SellerDashboardData data) {
    final l10n = context.l10n;
    final orders = data.orders;
    final soldOut = data.lowStock.where((item) => item.isOutOfStock).toList();
    final tasks = [...data.pendingTasks]
      ..sort((a, b) => a.priority.index.compareTo(b.priority.index));

    return [
      if (orders.newOrders > 0)
        _Stitch(
          title: l10n.sellerBenchNewOrders(orders.newOrders),
          hint: l10n.sellerBenchNewOrdersHint,
          icon: Icons.receipt_long_rounded,
          tone: DsTone.critical,
          action: l10n.sellerBenchOpenOrders,
          route: RoutePaths.sellerOrders,
        ),
      if (orders.readyForShipment > 0)
        _Stitch(
          title: l10n.sellerBenchReadyOrders(orders.readyForShipment),
          hint: l10n.sellerBenchReadyOrdersHint,
          icon: Icons.local_shipping_rounded,
          tone: DsTone.caution,
          action: l10n.sellerBenchOpenOrders,
          route: RoutePaths.sellerOrders,
        ),
      for (final item in soldOut.take(2))
        _Stitch(
          title: l10n.sellerBenchSoldOut(item.title),
          hint: l10n.sellerBenchSoldOutHint,
          icon: Icons.inventory_2_rounded,
          tone: DsTone.caution,
          action: l10n.sellerBenchOpenProducts,
          route: RoutePaths.myProducts,
        ),
      for (final task in tasks)
        _Stitch(
          title: task.title,
          hint: task.subtitle,
          icon: task.icon,
          tone: task.priorityTone,
        ),
    ];
  }
}

class _ThenRow extends StatelessWidget {
  const _ThenRow({required this.stitch, required this.last});

  final _Stitch stitch;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final tone = context.toneColor(stitch.tone);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
      child: Row(
        children: [
          Container(
            width: DsSizes.controlSm,
            height: DsSizes.controlSm,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone.withValues(alpha: 0.12),
            ),
            child: Icon(stitch.icon, size: DsSizes.iconXs, color: tone),
          ),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stitch.title,
                  style: context.dsText.bodyStrong.tint(palette.ink),
                ),
                if (stitch.hint.isNotEmpty)
                  Text(
                    stitch.hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.tint(palette.muted),
                  ),
              ],
            ),
          ),
          if (stitch.route != null)
            Icon(
              Icons.chevron_right_rounded,
              color: palette.muted,
            ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: palette.line)),
      ),
      child: stitch.route == null
          ? row
          : InkWell(onTap: () => context.push(stitch.route!), child: row),
    );
  }
}

// ---------------------------------------------------------------------------
// The seam
// ---------------------------------------------------------------------------

class BenchSeam extends ConsumerWidget {
  const BenchSeam({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sellerDashboardNotifierProvider).data;
    if (data == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final palette = context.atelier;
    final orders = data.orders;

    const flow = [
      SellerOrderStatus.newOrders,
      SellerOrderStatus.processing,
      SellerOrderStatus.readyForShipment,
      SellerOrderStatus.delivered,
    ];

    return _BenchPanel(
      title: l10n.sellerBenchSeamTitle,
      caption: l10n.sellerBenchSeamCaption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OrderSeam(
            onTap: (_) => context.push(RoutePaths.sellerOrders),
            stations: [
              for (final status in flow)
                SeamStation(
                  label: status.labelOf(l10n),
                  count: formatCount(status.countOf(orders)),
                  icon: status.icon,
                  // Delivered is history, not work.
                  lit:
                      status != SellerOrderStatus.delivered &&
                      status.countOf(orders) > 0,
                ),
            ],
          ),
          DsGaps.vMd,
          Text(
            '${formatCount(orders.cancelled)} '
            '${SellerOrderStatus.cancelled.labelOf(l10n)} · '
            '${formatCount(orders.returned)} '
            '${SellerOrderStatus.returned.labelOf(l10n)}',
            textAlign: TextAlign.center,
            style: context.dsText.caption.tint(palette.muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The tools
// ---------------------------------------------------------------------------

class BenchTools extends StatelessWidget {
  const BenchTools({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final tools = [
      (
        Icons.add_box_outlined,
        l10n.sellerAddProduct,
        RoutePaths.productForm,
        palette.series[0],
      ),
      (
        Icons.receipt_long_outlined,
        l10n.sellerManageOrders,
        RoutePaths.sellerOrders,
        palette.series[1],
      ),
      (
        Icons.inventory_2_outlined,
        l10n.myProducts,
        RoutePaths.myProducts,
        palette.series[3],
      ),
      (
        Icons.assignment_return_outlined,
        l10n.sellerReturnsTitle,
        RoutePaths.sellerReturns,
        palette.series[2],
      ),
      (
        Icons.campaign_outlined,
        l10n.sellerAnnouncement,
        RoutePaths.addPost,
        palette.series[4],
      ),
      (
        Icons.bar_chart_rounded,
        l10n.sellerAnalytics,
        RoutePaths.sellerAnalytics,
        palette.primary,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AtelierHeading(title: l10n.sellerBenchToolsTitle),
        DsGaps.vLg,
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560 ? 6 : 3;
            final width = constraints.maxWidth / columns;
            return Wrap(
              runSpacing: DsSpacing.lg,
              children: [
                for (final tool in tools)
                  SizedBox(
                    width: width,
                    child: SewingButton(
                      icon: tool.$1,
                      label: tool.$2,
                      color: tool.$4,
                      onTap: () => context.push(tool.$3),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The rail
// ---------------------------------------------------------------------------

class BenchRail extends ConsumerWidget {
  const BenchRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sellerDashboardNotifierProvider).data;
    if (data == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final palette = context.atelier;

    // Best sellers first, then whatever is running out that is not already
    // hanging there — one rail, so «what sells» and «what is nearly gone»
    // are read side by side, which is how she restocks.
    // The two lists come from different queries and can name the same piece
    // under different ids, so a piece is matched by its name as well.
    final shown = {
      for (final p in data.topProducts) ...[p.id, p.title.trim()],
    };
    final pieces = <Widget>[
      for (final product in data.topProducts)
        HangingPiece(
          image: _PieceImage(url: product.imageUrl),
          title: product.title,
          tag: product.isOutOfStock
              ? l10n.sellerBenchTagOut
              : product.isLowStock
              ? l10n.sellerBenchTagLeft(formatCount(product.stock))
              : l10n.sellerBenchTagSold(formatCount(product.unitsSold)),
          tagColor: product.isOutOfStock || product.isLowStock
              ? palette.critical
              : null,
          onTap: () => context.push(RoutePaths.myProducts),
        ),
      for (final item in data.lowStock)
        if (!shown.contains(item.id) && !shown.contains(item.title.trim()))
          HangingPiece(
            image: _PieceImage(url: item.imageUrl),
            title: item.title,
            tag: item.isOutOfStock
                ? l10n.sellerBenchTagOut
                : l10n.sellerBenchTagLeft(formatCount(item.stock)),
            tagColor: palette.critical,
            onTap: () => context.push(RoutePaths.myProducts),
          ),
    ];
    if (pieces.isEmpty) return const SizedBox.shrink();

    final gutter = benchGutter(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: AtelierHeading(
            title: l10n.sellerBenchRailTitle,
            caption: l10n.sellerBenchRailCaption,
            trailing: TextButton(
              onPressed: () => context.push(RoutePaths.myProducts),
              child: Text(
                l10n.myProducts,
                style: context.dsText.labelStrong.tint(palette.primary),
              ),
            ),
          ),
        ),
        DsGaps.vLg,
        HangerRail(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          children: pieces,
        ),
      ],
    );
  }
}

class _PieceImage extends StatelessWidget {
  const _PieceImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.primarySoft, palette.goldSoft],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.checkroom_rounded,
          size: DsSizes.iconXl,
          color: palette.primary.withValues(alpha: 0.6),
        ),
      ),
    );
    if (url.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: MediaVariants.thumb(url),
      fit: BoxFit.cover,
      memCacheWidth: MediaDecode.widthFor(context, 136),
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

// ---------------------------------------------------------------------------
// The pattern
// ---------------------------------------------------------------------------

class BenchPattern extends ConsumerWidget {
  const BenchPattern({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final data = state.data;
    if (data == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final period = state.selectedChartPeriod;
    final points = data.charts[period]?.revenuePoints ?? const [];

    return _BenchPanel(
      title: l10n.sellerBenchPatternTitle,
      caption: l10n.sellerBenchPatternCaption,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PeriodBeads(
            selected: period,
            onSelected: ref
                .read(sellerDashboardNotifierProvider.notifier)
                .setChartPeriod,
          ),
          DsGaps.vLg,
          ThreadChart(
            values: [for (final p in points) p.value],
            labels: [for (final p in points) p.label],
            semanticLabel: l10n.sellerBenchPatternSemantics,
          ),
        ],
      ),
    );
  }
}

class _PeriodBeads extends StatelessWidget {
  const _PeriodBeads({required this.selected, required this.onSelected});

  final ChartPeriod selected;
  final ValueChanged<ChartPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final period in ChartPeriod.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpacing.xs),
              child: ChoiceChip(
                label: Text(period.labelOf(l10n)),
                selected: period == selected,
                showCheckmark: false,
                selectedColor: palette.primary,
                backgroundColor: palette.surface,
                side: BorderSide(
                  color: period == selected ? palette.primary : palette.line,
                ),
                labelStyle: context.dsText.labelLarge.tint(
                  period == selected ? palette.onPrimary : palette.ink,
                ),
                onSelected: (_) => onSelected(period),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

/// A panel on the bench: the atelier's surface with its heading on top.
class _BenchPanel extends StatelessWidget {
  const _BenchPanel({required this.title, required this.child, this.caption});

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Container(
      padding: DsSpacing.paddingXl,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: palette.line),
        boxShadow: palette.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AtelierHeading(title: title, caption: caption),
          DsGaps.vLg,
          child,
        ],
      ),
    );
  }
}
