import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/seller_intelligence/domain/entities/intelligence.dart';
import 'package:reem/features/seller_intelligence/presentation/providers/intelligence_providers.dart';
import 'package:reem/features/seller_intelligence/presentation/widgets/intelligence_pieces.dart';

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

    return ReemScrollPage(
      onRefresh: () async {
        ref
          ..invalidate(sellerHealthProvider)
          ..invalidate(sellerHealthHistoryProvider)
          ..invalidate(decliningListingsProvider);
      },
      background: const SellerAtelierBackground(),
      backgroundColor: palette.background,
      slivers: [
        const PremiumAppBar(title: 'صحّة المتجر'),
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
                  message: 'ما قدرنا نحسب صحّة المتجر.',
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
        const SectionTitle(
          title: 'شو بيرفع صحّتك',
          subtitle: 'مرتّبة حسب أكبر أثر',
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
        const SectionTitle(title: 'المقاييس'),
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
        const SectionTitle(
          title: 'لسا ما عندنا كفاية',
          // The sentence that makes the whole evidence rule legible.
          subtitle: 'هي المقاييس ما بتأثر على صحّتك لحد ما يصير عندنا بيانات كافية',
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
        const SectionTitle(title: 'شو تراجع'),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            child: SellerPanel(
              child: Text(
                'ما قدرنا نقرأ المنتجات المتراجعة هلق.',
                style: context.dsText.caption.tint(context.atelier.muted),
              ),
            ),
          ),
        ),
      ],
      data: (rows) => rows.isEmpty
          ? const <Widget>[]
          : [
              const SectionTitle(
                title: 'شو تراجع',
                subtitle: 'كانت تبيع وخفّت — وسبب واحد لكل وحدة',
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
                            ? 'لسا ما عندنا طلبات كفاية لنحكم. كل طلب بتخلّصيه بيوضّح الصورة.'
                            : 'محسوبة على آخر ${health.windowDays} يوم من طلباتك.',
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
                              '${health.momentum.abs().round()} نقطة عن الشهر الماضي',
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
            trailing: _trailing(dimension),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              dimension.counted
                  ? dimension.blurb
                  : dimension.score == null
                  ? '${dimension.blurb} — ما صار عندنا شي نقيسه بعد.'
                  // The honest middle case: we did measure it, there just is
                  // not enough of it to hold her to.
                  : '${dimension.blurb} — قسناها على ${dimension.sample} بس لسا قليلة لتتحسب.',
              style: context.dsText.micro.tint(palette.muted),
            ),
          ),
        ],
      ),
    );
  }

  /// The measured figure in its own units, because "16.5" means nothing
  /// without knowing it is hours.
  String? _trailing(HealthDimension d) {
    final value = d.value;
    if (value == null) return null;
    return switch (d.key) {
      'prepSpeed' || 'shipSpeed' || 'responsiveness' =>
        value >= 48 ? '${(value / 24).round()} يوم' : '${value.round()} ساعة',
      'satisfaction' => '${value.toStringAsFixed(1)} من ٥',
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

  static const _labels = <String, String>{
    'accepted_orders': 'طلبات قبلتيها وخلصت',
    'delivered_orders': 'طلبات وصلت',
    'cancelled_by_seller': 'ألغيتيها',
    'cancelled_by_others': 'انلغت من الزبونة',
    'returned_orders': 'رجعت',
    'prep_hours': 'وسطي التجهيز (ساعة)',
    'ship_hours': 'وسطي الشحن (ساعة)',
    'response_hours': 'وسطي الردّ (ساعة)',
    'average_rating': 'تقييم المتجر',
    'review_count': 'عدد التقييمات',
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
            label: Text(_open ? 'خبّي الأرقام' : 'شوفي الأرقام يلي انحسبت'),
          ),
          if (_open)
            SellerPanel(
              child: Column(
                children: [
                  for (final entry in _labels.entries)
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
