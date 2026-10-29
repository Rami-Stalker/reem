import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/presentation/providers/store_ads_providers.dart';
import 'package:ohara/features/store_ads/presentation/widgets/store_ads_labels.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// «باقات الإعلان» — four plans side by side, so she can see exactly what
/// paying more buys before she pays anything.
class AdPlansScreen extends ConsumerWidget {
  const AdPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final plans = ref.watch(adPlansProvider);
    final gutter = atelierGutter(context);

    return OharaScrollPage(
      onRefresh: () async => ref.invalidate(adPlansProvider),
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.workspace_premium_rounded,
          title: l10n.adsPlansTitle,
          subtitle: l10n.adsPlansSubtitle,
          showBack: true,
        ),
        DsGaps.sliverMd,
        ...plans.when(
          loading: () => [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: const DsShimmer(
                  child: DsSkeleton.box(height: 320, borderRadius: DsRadius.xl),
                ),
              ),
            ),
          ],
          error: (error, _) => [
            SliverToBoxAdapter(
              child: DsErrorState(
                message: error is Failure
                    ? error.displayMessage
                    : l10n.adsFailed,
                onRetry: () => ref.invalidate(adPlansProvider),
              ),
            ),
          ],
          data: (view) => [
            if (view.queuedTier != null && view.queuedStartsAt != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, DsSpacing.md),
                  child: Text(
                    l10n.adsPlanQueued(
                      view.queuedTier!.label(l10n),
                      DateFormat.yMMMd(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(view.queuedStartsAt!),
                    ),
                    style: context.dsText.bodySmall.tint(context.atelier.muted),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              sliver: SliverList.separated(
                // Highest first: the page opens on what is possible.
                itemCount: view.plans.length,
                separatorBuilder: (_, _) => DsGaps.vLg,
                itemBuilder: (context, index) {
                  final plan = view.plans[view.plans.length - 1 - index];
                  return DsStaggerAnimations.item(
                    index: index,
                    child: _PlanCard(plan: plan, view: view),
                  );
                },
              ),
            ),
          ],
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard({required this.plan, required this.view});

  final AdPlan plan;
  final AdPlansView view;

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _busy = false;

  AdPlan get plan => widget.plan;
  AdCurrentPlan get current => widget.view.current;

  bool get _isCurrent => plan.tier == current.tier;
  bool get _isRecommended => widget.view.recommendation?.tier == plan.tier;

  Future<void> _buy() async {
    final l10n = context.l10n;
    final confirmed = await DsBottomSheet.show<bool>(
      context,
      builder: (sheetContext) => DsSheetScaffold(
        title: l10n.adsPlanConfirmTitle(plan.tier.label(l10n)),
        subtitle: l10n.adsPlanConfirmBody(formatSyp(plan.price)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (current.tier.isPaid && plan.tier > current.tier) ...[
              Text(
                l10n.adsPlanConfirmUpgradeNote,
                style: context.dsText.bodySmall.tint(context.atelier.muted),
              ),
              DsGaps.vMd,
            ],
            DsButton(
              label: l10n.adsConfirm,
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            DsGaps.vSm,
            DsButton(
              label: l10n.cancel,
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final failure = await ref
        .read(storeAdsActionsProvider)
        .subscribe(plan.tier);
    if (!mounted) return;
    setState(() => _busy = false);
    DsSnackbar.show(
      context,
      message: failure == null
          ? l10n.adsPlanSubscribed(plan.tier.label(l10n))
          : adFailureMessage(l10n, failure),
      type: failure == null ? DsSnackbarType.success : DsSnackbarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final text = context.dsText;
    final jewel = plan.tier.jewel;
    final ink = jewel?.ink ?? palette.ink;

    final header = Container(
      padding: DsSpacing.cardPaddingLg,
      decoration: BoxDecoration(
        gradient: jewel?.gradient,
        color: jewel == null ? palette.primarySoft : null,
      ),
      child: Row(
        children: [
          Icon(
            jewel?.icon ?? Icons.storefront_outlined,
            size: DsSizes.iconLg,
            color: ink,
          ),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.tier.label(l10n), style: text.screenTitle.tint(ink)),
                Text(
                  plan.price == 0
                      ? l10n.adsPlanFreeLabel
                      : l10n.adsPlanPerMonth(formatSyp(plan.price)),
                  style: text.bodyStrong.tint(ink),
                ),
              ],
            ),
          ),
          if (_isCurrent)
            _Flag(label: l10n.adsPlanCurrent, ink: ink)
          else if (_isRecommended)
            _Flag(label: l10n.adsPlanRecommendedChip, ink: ink),
        ],
      ),
    );

    final perks = _perks(l10n);
    final action = _action(l10n);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXl,
        border: Border.all(
          color: _isRecommended || _isCurrent ? palette.gold : palette.line,
          width: _isRecommended || _isCurrent
              ? DsStrokes.medium
              : DsStrokes.thin,
        ),
        boxShadow: palette.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Padding(
            padding: DsSpacing.cardPaddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isRecommended &&
                    widget.view.recommendation!.saving > 0) ...[
                  Text(
                    l10n.adsPlanSaving(
                      formatSyp(widget.view.recommendation!.saving),
                    ),
                    style: text.bodyStrong.tint(palette.positive),
                  ),
                  DsGaps.vMd,
                ],
                for (final perk in perks) ...[
                  _Perk(icon: perk.$1, label: perk.$2, highlight: perk.$3),
                  DsGaps.vSm,
                ],
                if (action != null) ...[
                  DsGaps.vSm,
                  DsButton(
                    label: action,
                    icon: Icons.workspace_premium_rounded,
                    variant: _isRecommended
                        ? DsButtonVariant.primary
                        : DsButtonVariant.secondary,
                    isLoading: _busy,
                    onPressed: _busy ? null : _buy,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _action(AppLocalizations l10n) {
    if (plan.tier == AdTier.free) return null;
    if (_isCurrent) return l10n.adsPlanRenew;
    return l10n.adsPlanChoose(plan.tier.label(l10n));
  }

  List<(IconData, String, bool)> _perks(AppLocalizations l10n) {
    final placements = plan.placements
        .map((p) => p.label(l10n))
        .join(l10n.adsListSeparator);
    return [
      if (plan.credit > 0)
        (
          Icons.savings_rounded,
          l10n.adsPlanCredit(formatSyp(plan.credit)),
          plan.bonusCredit > 0,
        ),
      if (plan.bonusCredit > 0)
        (
          Icons.card_giftcard_rounded,
          l10n.adsPlanBonus(formatSyp(plan.bonusCredit)),
          true,
        ),
      if (plan.discountPercent > 0)
        (
          Icons.percent_rounded,
          l10n.adsPlanDiscount(plan.discountPercent.round()),
          false,
        ),
      (
        Icons.campaign_rounded,
        l10n.adsPlanCampaigns(plan.maxActiveCampaigns),
        false,
      ),
      if (plan.servingWeight > 1)
        (
          Icons.trending_up_rounded,
          l10n.adsPlanWeight(plan.servingWeight),
          true,
        ),
      (
        Icons.my_location_rounded,
        switch (plan.targeting) {
          AdTargeting.none => l10n.adsPlanTargetingNone,
          AdTargeting.location => l10n.adsPlanTargetingLocation,
          AdTargeting.full => l10n.adsPlanTargetingFull,
        },
        plan.targeting == AdTargeting.full,
      ),
      (Icons.place_outlined, l10n.adsPlanPlacements(placements), false),
      if (plan.notifiesFollowers)
        (Icons.notifications_active_outlined, l10n.adsPlanFollowers, false),
      if (plan.featuredStore)
        (Icons.storefront_rounded, l10n.adsPlanFeatured, true),
    ];
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.label, required this.ink});

  final String label;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: DsSpacing.badgePadding,
    decoration: BoxDecoration(
      borderRadius: DsRadius.borderFull,
      border: Border.all(color: ink),
    ),
    child: Text(label, style: context.dsText.badge.tint(ink)),
  );
}

class _Perk extends StatelessWidget {
  const _Perk({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: DsSizes.iconSm,
          color: highlight ? palette.gold : palette.primary,
        ),
        DsGaps.hSm,
        Expanded(
          child: Text(
            label,
            style: (highlight ? context.dsText.bodyStrong : context.dsText.body)
                .tint(palette.ink),
          ),
        ),
      ],
    );
  }
}
