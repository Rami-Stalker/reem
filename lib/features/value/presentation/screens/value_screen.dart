import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/value/domain/entities/value_standing.dart';
import 'package:reem/features/value/presentation/providers/value_providers.dart';
import 'package:reem/features/value/presentation/widgets/value_pillars.dart';

/// مكانتي بريم — her standing.
///
/// The screen is ordered as an argument. Where she stands comes first, then the
/// six dimensions it is built from, then what it opens, then what she actually
/// did, and only at the bottom the rules. A points screen puts the balance at
/// the top and the redemption catalogue underneath; this one puts *why* between
/// them, because the why is the product.
class ValueScreen extends ConsumerWidget {
  const ValueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final standingAsync = ref.watch(valueStandingProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const ReemAppBar(title: 'مكانتي بريم'),
      body: standingAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: 'ما قدرنا نجيب مكانتك.',
          onRetry: () => ref.invalidate(valueStandingProvider),
        ),
        data: (standing) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(valueStandingProvider),
          child: ListView(
            padding: const EdgeInsets.all(DsSpacing.md),
            children: [
              _StandingHero(standing: standing),
              const SizedBox(height: DsSpacing.lg),

              _Section(
                title: 'من وين إجت مكانتك',
                subtitle:
                    'مكانتك مبنية على ست جهات، مو على المصروف لحاله.',
                child: ValuePillarBars(pillars: standing.pillars),
              ),

              if (standing.advice.isNotEmpty && standing.nextTier != null)
                _Section(
                  title: 'شو بيقرّبك من ${standing.nextTier!.name}',
                  child: ValueAdviceList(advice: standing.advice),
                ),

              _Section(
                title: 'شو بتفتحلك مكانتك',
                child: _Benefits(standing: standing),
              ),

              if (standing.recent.isNotEmpty)
                _Section(
                  title: 'آخر الأشياء يلي حسبناها',
                  child: _RecentEvents(events: standing.recent),
                ),

              const _RulesLink(),
              const SizedBox(height: DsSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _StandingHero extends StatelessWidget {
  const _StandingHero({required this.standing});

  final ValueStanding standing;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final tier = standing.tier;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tier?.name ?? 'لسا بالبداية', style: context.dsText.hero),
          if (tier?.blurb != null) ...[
            DsGaps.vXxxs,
            Text(tier!.blurb!, style: context.dsText.bodyMuted),
          ],

          const SizedBox(height: DsSpacing.md),
          ValueHistoryLine(history: standing.history),

          if (standing.nextTier != null) ...[
            const SizedBox(height: DsSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(DsRadius.pill),
              child: LinearProgressIndicator(
                value: standing.progressToNext,
                minHeight: 8,
                backgroundColor: colors.surfaceVariant,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              'الدرجة الجاي: ${standing.nextTier!.name}',
              style: context.dsText.caption,
            ),
          ],

          if (standing.peakScore > standing.score) ...[
            const SizedBox(height: DsSpacing.sm),
            // The high-water mark. Shown only when she is below it, because
            // that is the moment it means something: a quiet season is not a
            // record wiped.
            Text(
              'أعلى مكانة وصلتيها لهلق محفوظة عنا.',
              style: context.dsText.caption.tint(colors.onSurfaceVariant),
            ),
          ],

          if (standing.tierHeldUntil != null &&
              standing.tierHeldUntil!.isAfter(DateTime.now())) ...[
            const SizedBox(height: DsSpacing.sm),
            // Told, rather than silently protected and later surprised.
            Text(
              'درجتك محفوظة إلك حتى لو هدأ نشاطك شوي.',
              style: context.dsText.caption.tint(colors.success),
            ),
          ],

          if (standing.frozen) ...[
            const SizedBox(height: DsSpacing.sm),
            Text(
              'مكانتك موقوفة مؤقتًا للمراجعة — ما ضاع منها شي.',
              style: context.dsText.caption.tint(colors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _Benefits extends ConsumerWidget {
  const _Benefits({required this.standing});

  final ValueStanding standing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Open first, then locked. Locked ones stay on the screen because they
        // are the argument for taking part — a programme that shows a woman
        // only what she already has cannot tell her what standing is for.
        for (final benefit in standing.unlockedBenefits)
          _BenefitTile(benefit: benefit, onClaim: () => _claim(context, ref, benefit)),
        for (final benefit in standing.lockedBenefits)
          _BenefitTile(benefit: benefit),
      ],
    );
  }

  Future<void> _claim(
    BuildContext context,
    WidgetRef ref,
    ValueBenefit benefit,
  ) async {
    final result = await ref.read(valueActionsProvider).claim(benefit.key);
    if (!context.mounted) return;
    result.when(
      success: (_) => DsSnackbar.show(context, message: 'صارت إلك.'),
      error: (failure) =>
          DsSnackbar.show(context, message: failure.message, type: DsSnackbarType.error),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({required this.benefit, this.onClaim});

  final ValueBenefit benefit;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final open = benefit.available;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xs),
      child: SurfaceCard(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              open ? _iconFor(benefit.kind) : Icons.lock_outline_rounded,
              size: 20,
              color: open ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    benefit.title,
                    style: open
                        ? context.dsText.cardTitle
                        : context.dsText.cardTitle.tint(colors.onSurfaceVariant),
                  ),
                  if (benefit.description != null)
                    Text(benefit.description!, style: context.dsText.caption),
                  if (!benefit.unlocked && benefit.requiresTier != null) ...[
                    DsGaps.vXxs,
                    Text(
                      'بتنفتح مع درجة أعلى',
                      style: context.dsText.micro.tint(colors.primary),
                    ),
                  ],
                  if (benefit.blockedBy == 'quota') ...[
                    DsGaps.vXxs,
                    Text('أخدتيها هالفترة', style: context.dsText.micro),
                  ],
                  if (benefit.blockedBy == 'budget') ...[
                    DsGaps.vXxs,
                    Text('خلصت هالفترة', style: context.dsText.micro),
                  ],
                ],
              ),
            ),
            if (benefit.isClaimable && onClaim != null)
              DsButton(
                label: 'خديها',
                size: DsButtonSize.sm,
                isExpanded: false,
                onPressed: onClaim,
              )
            else if (open && benefit.grant == null)
              // Standing benefits are not claimed. Saying "مفعّلة" rather than
              // offering a button is the difference between a status and a
              // voucher.
              Text('مفعّلة', style: context.dsText.micro.tint(colors.success)),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String kind) => switch (kind) {
        'EARLY_ACCESS' => Icons.schedule_rounded,
        'EXCLUSIVE_PRODUCT' => Icons.diamond_outlined,
        'PRIORITY_SUPPORT' => Icons.support_agent_rounded,
        'PRIORITY_DELIVERY' => Icons.local_shipping_rounded,
        'ENHANCED_RETURNS' => Icons.assignment_return_rounded,
        'GIFT' => Icons.card_giftcard_rounded,
        _ => Icons.auto_awesome_rounded,
      };
}

class _RecentEvents extends StatelessWidget {
  const _RecentEvents({required this.events});

  final List<ValueEvent> events;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Column(
      children: [
        for (final event in events.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  event.isReversed
                      ? Icons.remove_circle_outline_rounded
                      : event.isPositive
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                  size: 16,
                  color: event.isReversed
                      ? colors.onSurfaceVariant
                      : event.isPositive
                          ? colors.success
                          : colors.warning,
                ),
                const SizedBox(width: DsSpacing.xs),
                Expanded(
                  child: Text(
                    event.label,
                    style: event.isReversed
                        ? context.dsText.body.tint(colors.onSurfaceVariant)
                        : context.dsText.body,
                  ),
                ),
                Text(event.pillarLabel, style: context.dsText.micro),
              ],
            ),
          ),
      ],
    );
  }
}

/// The rules, published.
///
/// A programme whose rules are secret is one nobody can trust or plan around,
/// so the whole earning table is one tap away from the standing it produced.
class _RulesLink extends ConsumerWidget {
  const _RulesLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      icon: const Icon(Icons.help_outline_rounded, size: 18),
      label: const Text('كيف بتنبنى المكانة؟'),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => const _RulesSheet(),
      ),
    );
  }
}

class _RulesSheet extends ConsumerWidget {
  const _RulesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(valueRulesProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (context, controller) => rulesAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => const DsErrorState(message: 'ما قدرنا نجيب القواعد.'),
        data: (rules) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(DsSpacing.lg),
          children: [
            Text('كيف بتنبنى مكانتك', style: context.dsText.sectionTitle),
            const SizedBox(height: DsSpacing.xs),
            Text(
              'مكانتك ما بتنشرى. الشرا جهة وحدة من ست، وإلها سقف — '
              'يعني حدا بس بيشتري ما بيوصل لأعلى الدرجات.',
              style: context.dsText.bodyMuted,
            ),
            const SizedBox(height: DsSpacing.md),
            for (final rule in rules)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rule.label, style: context.dsText.labelStrong),
                    Text(rule.evidence, style: context.dsText.caption),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.dsText.sectionTitle),
          if (subtitle != null) ...[
            DsGaps.vXxxs,
            Text(subtitle!, style: context.dsText.sectionSubtitle),
          ],
          const SizedBox(height: DsSpacing.sm),
          child,
        ],
      ),
    );
  }
}
