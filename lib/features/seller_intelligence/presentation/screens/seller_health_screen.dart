import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/seller_intelligence/domain/entities/intelligence.dart';
import 'package:ohara/features/seller_intelligence/presentation/providers/intelligence_providers.dart';
import 'package:ohara/features/seller_intelligence/presentation/widgets/intelligence_pieces.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// صحّة المتجر — the eight things a buyer actually feels.
///
/// The page is arranged as an argument rather than a dashboard. The score
/// first, with its band said in words; then **what to do**, because a health
/// score she cannot move is just a grade; then the eight dimensions with the
/// evidence behind each; and the raw counts last, for when she wants to check
/// the working.
///
/// The design decision that shapes everything here is that a dimension with
/// too little evidence is shown *greyed and uncounted* rather than hidden or
/// scored. A new seller sees exactly what will be measured and that none of it
/// is being held against her yet — which is the difference between a system
/// that recruits sellers and one that frightens them.
class SellerHealthScreen extends ConsumerWidget {
  const SellerHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.atelier;
    final async = ref.watch(sellerHealthProvider);

    return OharaScrollPage(
      onRefresh: () async {
        ref
          ..invalidate(sellerHealthProvider)
          ..invalidate(sellerHealthHistoryProvider)
          ..invalidate(decliningListingsProvider);
      },
      background: const SellerAtelierBackground(),
      backgroundColor: palette.background,
      slivers: [
        PremiumAppBar(title: context.l10n.siShopHealth),
        ...async.when(
          loading: () => [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: Center(child: DsLoadingIndicator()),
              ),
            ),
          ],
          error: (_, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
                child: DsErrorState(
                  message: context.l10n.siHealthFailed,
                  onRetry: () => ref.invalidate(sellerHealthProvider),
                ),
              ),
            ),
          ],
          data: (health) => _body(context, ref, health),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xxl)),
      ],
    );
  }

  List<Widget> _body(BuildContext context, WidgetRef ref, SellerHealth health) {
    final measured = health.dimensions.where((d) => d.counted).toList();
    final waiting = health.dimensions.where((d) => !d.counted).toList();

    return [
      SliverToBoxAdapter(child: _Header(health: health)),

      if (health.advice.isNotEmpty) ...[
        SectionTitle(
          title: context.l10n.siWhatRaisesHealth,
          subtitle: context.l10n.siWhatRaisesHealthSubtitle,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            child: SellerPanel(
              child: Column(
                children: [
                  for (final advice in health.advice)
                    AdviceTile(advice: advice),
                ],
              ),
            ),
          ),
        ),
      ],

      ..._declining(context, ref),

      if (measured.isNotEmpty) ...[
        SectionTitle(title: context.l10n.siMetrics),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            child: SellerPanel(
              child: Column(
                children: [
                  for (final dimension in measured)
                    _DimensionRow(dimension: dimension),
                ],
              ),
            ),
          ),
        ),
      ],

      if (waiting.isNotEmpty) ...[
        SectionTitle(
          title: context.l10n.siNotEnoughYet,
          // The sentence that makes the whole evidence rule legible.
          subtitle: context.l10n.siNotEnoughYetBody,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            child: SellerPanel(
              child: Column(
                children: [
                  for (final dimension in waiting)
                    _DimensionRow(dimension: dimension),
                ],
              ),
            ),
          ),
        ),
      ],

      SliverToBoxAdapter(child: _Facts(health: health)),
    ];
  }

  /// شو تراجع — listings that were selling and stopped.
  ///
  /// It sits directly under the advice because it answers a different
  /// question with the same urgency: health says how good the shop is, this
  /// says what *changed*. Telling a seller to improve her photographs when a
  /// competitor undercut her by a third costs her a week.
  ///
  /// Nothing is drawn when there is nothing to say. A supplementary section
  /// that renders an empty card teaches her to scroll past it, and the day it
  /// has something she will scroll past that too.
  List<Widget> _declining(BuildContext context, WidgetRef ref) {
    final async = ref.watch(decliningListingsProvider);

    return async.when(
      // Silent: the page's subject is the health score, and a spinner for an
      // adjunct section makes the whole screen feel slower than it is.
      loading: () => const <Widget>[],
      error: (_, _) => [
        SectionTitle(title: context.l10n.siWhatSlipped),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            child: SellerPanel(
              child: Text(
                context.l10n.siSlippedFailed,
                style: context.dsText.caption.tint(context.atelier.muted),
              ),
            ),
          ),
        ),
      ],
      data: (rows) => rows.isEmpty
          ? const <Widget>[]
          : [
              SectionTitle(
                title: context.l10n.siWhatSlipped,
                subtitle: context.l10n.siWhatSlippedSubtitle,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.lg,
                  ),
                  child: SellerPanel(
                    child: Column(
                      children: [
                        for (final row in rows) _DecliningTile(row: row),
                      ],
                    ),
                  ),
                ),
              ),
            ],
    );
  }
}

/// One declining listing: what fell, by how much, and the single named cause.
///
/// The runner-up cause is shown as context underneath rather than beside the
/// first, because two instructions of equal weight is how a seller ends up
/// following neither.
class _DecliningTile extends StatelessWidget {
  const _DecliningTile({required this.row});

  final DecliningListing row;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.bodyStrong.tint(palette.ink),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: palette.critical.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(DsRadius.pill),
                ),
                child: Text(
                  '${row.ordersBefore} ← ${row.ordersNow}',
                  style: context.dsText.micro.tint(palette.critical),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            row.diagnosis.title,
            style: context.dsText.caption.tint(palette.ink),
          ),
          DsGaps.vXxxs,
          Text(
            row.diagnosis.action,
            style: context.dsText.caption.tint(palette.muted),
          ),
          if (row.diagnosis.also case final also?) ...[
            DsGaps.vXxxs,
            Text(
              also,
              style: context.dsText.micro.tint(palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.health});

  final SellerHealth health;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        0,
      ),
      child: SellerPanel(
        padding: const EdgeInsets.all(DsSpacing.lg),
        child: Column(
          children: [
            Row(
              children: [
                IntelligenceDial(
                  score: health.score,
                  confidence: health.confidence,
                  size: 92,
                  provisional: health.isProvisional,
                ),
                const SizedBox(width: DsSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        health.bandLabel,
                        style: context.dsText.sectionTitle.tint(palette.ink),
                      ),
                      DsGaps.vXxs,
                      Text(
                        health.isProvisional
                            // Said plainly. A provisional score that looked
                            // like a verdict would be the cruellest possible
                            // first impression for a new shop.
                            ? context.l10n.siHealthTooFewOrders
                            : context.l10n.siHealthWindow(health.windowDays),
                        style: context.dsText.caption.tint(palette.muted),
                      ),
                      if (!health.isProvisional && health.momentum != 0) ...[
                        const SizedBox(height: DsSpacing.xs),
                        Row(
                          children: [
                            Icon(
                              health.momentum > 0
                                  ? Icons.north_rounded
                                  : Icons.south_rounded,
                              size: 14,
                              color: health.momentum > 0
                                  ? palette.positive
                                  : palette.caution,
                            ),
                            DsGaps.hXxxs,
                            Text(
                              context.l10n.siMomentum(
                                health.momentum.abs().round(),
                              ),
                              style: context.dsText.caption.tint(
                                health.momentum > 0
                                    ? palette.positive
                                    : palette.caution,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.dimension});

  final HealthDimension dimension;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MeasureBar(
            label: dimension.label,
            score: dimension.score,
            weight: dimension.counted ? dimension.weight : null,
            provisional: !dimension.counted,
            trailing: _trailing(context, dimension),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              dimension.counted
                  ? dimension.blurb
                  : dimension.score == null
                  ? context.l10n.siDimensionUnmeasured(dimension.blurb)
                  // The honest middle case: we did measure it, there just is
                  // not enough of it to hold her to.
                  : context.l10n.siDimensionTooFew(
                      dimension.blurb,
                      dimension.sample,
                    ),
              style: context.dsText.micro.tint(palette.muted),
            ),
          ),
        ],
      ),
    );
  }

  /// The measured figure in its own units, because "16.5" means nothing
  /// without knowing it is hours.
  String? _trailing(BuildContext context, HealthDimension d) {
    final value = d.value;
    if (value == null) return null;
    return switch (d.key) {
      'prepSpeed' || 'shipSpeed' || 'responsiveness' =>
        value >= 48
            ? context.l10n.siDays((value / 24).round())
            : context.l10n.siHours(value.round()),
      'satisfaction' => context.l10n.siOutOfFive(value.toStringAsFixed(1)),
      'reliability' || 'returns' || 'cancellation' => '${value.round()}%',
      _ => null,
    };
  }
}

/// The counts the score came from.
///
/// Collapsed by default: most days she wants the conclusion, but a seller who
/// disagrees with a number should be able to see exactly what was counted
/// rather than being asked to take it on trust.
class _Facts extends StatefulWidget {
  const _Facts({required this.health});

  final SellerHealth health;

  @override
  State<_Facts> createState() => _FactsState();
}

class _FactsState extends State<_Facts> {
  bool _open = false;

  static Map<String, String> _labels(AppLocalizations l10n) => {
    'accepted_orders': l10n.siFactAccepted,
    'delivered_orders': l10n.siFactDelivered,
    'cancelled_by_seller': l10n.siFactCancelledBySeller,
    'cancelled_by_others': l10n.siFactCancelledByOthers,
    'returned_orders': l10n.siFactReturned,
    'prep_hours': l10n.siFactPrepHours,
    'ship_hours': l10n.siFactShipHours,
    'response_hours': l10n.siFactResponseHours,
    'average_rating': l10n.siFactRating,
    'review_count': l10n.siFactReviewCount,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final facts = widget.health.facts;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.lg,
        DsSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _open = !_open),
            icon: Icon(
              _open
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
            ),
            label: Text(
              _open ? context.l10n.siHideNumbers : context.l10n.siShowNumbers,
            ),
          ),
          if (_open)
            SellerPanel(
              child: Column(
                children: [
                  for (final entry in _labels(context.l10n).entries)
                    if (facts.containsKey(entry.key))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.value,
                                style: context.dsText.caption.tint(
                                  palette.muted,
                                ),
                              ),
                            ),
                            Text(
                              facts[entry.key] == null
                                  ? '—'
                                  : _format(facts[entry.key]!),
                              style: context.dsText.caption.semibold.tint(
                                palette.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _format(num value) =>
      value is int || value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}
