import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/seller_products/domain/entities/product_status.dart';
import 'package:ohara/features/seller_products/presentation/providers/seller_products_providers.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/presentation/providers/store_ads_providers.dart';
import 'package:ohara/features/store_ads/presentation/widgets/ads_widgets.dart';
import 'package:ohara/features/store_ads/presentation/widgets/store_ads_labels.dart';

/// «حملة جديدة» — four choices and a price that answers each one at once.
///
/// The summary at the foot is the point of the screen: every change re-quotes
/// it, so she sees what the campaign costs, how much of it her credit covers,
/// how many women it will reach and how much of the slot she will hold —
/// before she has paid a lira.
class NewCampaignScreen extends ConsumerStatefulWidget {
  const NewCampaignScreen({super.key, this.suggestion});

  /// A smart pick she tapped in «مركز الإعلانات», pre-filling the campaign.
  final AdSuggestion? suggestion;

  @override
  ConsumerState<NewCampaignScreen> createState() => _NewCampaignScreenState();
}

class _NewCampaignScreenState extends ConsumerState<NewCampaignScreen> {
  @override
  void initState() {
    super.initState();
    final s = widget.suggestion;
    if (s != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(campaignComposerProvider.notifier)
            .choose(draft: s.toDraft(), title: s.title, image: s.imageUrl);
      });
    }
  }

  Future<void> _pickProduct() async {
    final picked = await DsBottomSheet.show<_Pick>(
      context,
      builder: (_) => const _ProductPicker(),
    );
    if (picked == null || !mounted) return;
    final current = ref.read(campaignComposerProvider).draft;
    ref
        .read(campaignComposerProvider.notifier)
        .choose(
          draft: (current ?? AdCampaignDraft(offerId: picked.offerId)).copyWith(
            offerId: picked.offerId,
          ),
          title: picked.title,
          image: picked.image,
        );
  }

  Future<void> _launch() async {
    final l10n = context.l10n;
    final failure = await ref.read(campaignComposerProvider.notifier).launch();
    if (!mounted) return;
    if (failure != null) {
      DsSnackbar.show(
        context,
        message: adFailureMessage(l10n, failure),
        type: DsSnackbarType.error,
      );
      return;
    }
    DsSnackbar.show(
      context,
      message: l10n.adsLaunched,
      type: DsSnackbarType.success,
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(campaignComposerProvider);
    final notifier = ref.read(campaignComposerProvider.notifier);
    final plans = ref.watch(adPlansProvider).value;
    final draft = state.draft;
    final gutter = atelierGutter(context);

    Widget step(String title, Widget child) => SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, DsSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AtelierHeading(title: title),
            DsGaps.vMd,
            child,
          ],
        ),
      ),
    );

    return OharaScrollPage(
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: Icons.rocket_launch_rounded,
          title: l10n.adsComposerTitle,
          showBack: true,
        ),
        DsGaps.sliverMd,
        step(
          l10n.adsStepProduct,
          _ProductRow(
            title: state.productTitle,
            image: state.productImage,
            onTap: _pickProduct,
          ),
        ),
        if (draft != null) ...[
          step(
            l10n.adsStepPlacement,
            _PlacementList(
              selected: draft.placement,
              plans: plans,
              onSelect: (placement) =>
                  notifier.update((d) => d.copyWith(placement: placement)),
            ),
          ),
          step(
            l10n.adsStepAudience,
            _AudiencePicker(
              audience: draft.audience,
              targeting: plans?.currentPlan?.targeting ?? AdTargeting.none,
              onChanged: (audience) =>
                  notifier.update((d) => d.copyWith(audience: audience)),
            ),
          ),
          step(
            l10n.adsStepDuration,
            _DurationPicker(
              days: draft.days,
              onChanged: (days) =>
                  notifier.update((d) => d.copyWith(days: days)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: _Summary(
                state: state,
                onLaunch: _launch,
                onUnlock: () => context.push(RoutePaths.sellerAdsPlans),
              ),
            ),
          ),
        ],
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The piece
// ---------------------------------------------------------------------------

class _Pick {
  const _Pick({required this.offerId, required this.title, this.image});

  final String offerId;
  final String title;
  final String? image;
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.title,
    required this.image,
    required this.onTap,
  });

  final String? title;
  final String? image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return SellerPanel(
      onTap: onTap,
      padding: DsSpacing.cardPaddingLg,
      child: Row(
        children: [
          if (title == null)
            Container(
              width: DsSizes.thumbSm,
              height: DsSizes.thumbSm,
              decoration: BoxDecoration(
                color: palette.primarySoft,
                borderRadius: DsRadius.borderMd,
              ),
              child: Icon(Icons.add_rounded, color: palette.primary),
            )
          else
            AdProductThumb(url: image),
          DsGaps.hMd,
          Expanded(
            child: Text(
              title ?? l10n.adsChooseProduct,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.dsText.cardTitle.tint(palette.ink),
            ),
          ),
          if (title != null)
            Text(
              l10n.adsChangeProduct,
              style: context.dsText.labelStrong.tint(palette.primary),
            ),
        ],
      ),
    );
  }
}

class _ProductPicker extends ConsumerWidget {
  const _ProductPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final products = ref.watch(myProductsNotifierProvider);
    final live = products.products
        .where((p) => p.status == ProductStatus.active && p.stock > 0)
        .toList();

    return DsSheetScaffold(
      title: l10n.adsPickProductTitle,
      child: products.isLoading && live.isEmpty
          ? const Padding(
              padding: DsSpacing.paddingXl,
              child: DsLoadingIndicator(),
            )
          : live.isEmpty
          ? DsEmptyState(
              icon: Icons.inventory_2_outlined,
              title: l10n.adsNoProducts,
            )
          : Column(
              children: [
                for (final p in live)
                  InkWell(
                    borderRadius: DsRadius.borderMd,
                    onTap: () => Navigator.of(context).pop(
                      _Pick(
                        offerId: p.id,
                        title: p.title,
                        image: p.media.isEmpty ? null : p.media.first.url,
                      ),
                    ),
                    child: Padding(
                      padding: DsSpacing.listRowPadding,
                      child: Row(
                        children: [
                          AdProductThumb(
                            url: p.media.isEmpty ? null : p.media.first.url,
                          ),
                          DsGaps.hMd,
                          Expanded(
                            child: Text(
                              p.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.dsText.body.tint(palette.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placement
// ---------------------------------------------------------------------------

class _PlacementList extends StatelessWidget {
  const _PlacementList({
    required this.selected,
    required this.plans,
    required this.onSelect,
  });

  final AdPlacement selected;
  final AdPlansView? plans;
  final ValueChanged<AdPlacement> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final placement in AdPlacement.values) ...[
          _PlacementOption(
            placement: placement,
            selected: selected == placement,
            lockedTier: plans == null || plans!.allows(placement)
                ? null
                : placement.minimumTier,
            onTap: () => onSelect(placement),
          ),
          DsGaps.vSm,
        ],
      ],
    );
  }
}

class _PlacementOption extends StatelessWidget {
  const _PlacementOption({
    required this.placement,
    required this.selected,
    required this.lockedTier,
    required this.onTap,
  });

  final AdPlacement placement;
  final bool selected;
  final AdTier? lockedTier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final text = context.dsText;
    final jewel = lockedTier?.jewel;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.borderLg,
        child: AnimatedContainer(
          duration: DsReducedMotion.duration(DsMotion.fast),
          padding: DsSpacing.cardPaddingLg,
          decoration: BoxDecoration(
            color: selected ? palette.primarySoft : palette.surface,
            borderRadius: DsRadius.borderLg,
            border: Border.all(
              color: selected ? palette.primary : palette.line,
              width: selected ? DsStrokes.medium : DsStrokes.thin,
            ),
          ),
          child: Row(
            children: [
              Icon(
                placement.icon,
                size: DsSizes.iconMd,
                color: selected ? palette.primary : palette.muted,
              ),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      placement.label(l10n),
                      style: text.bodyStrong.tint(palette.ink),
                    ),
                    DsGaps.vXxs,
                    Text(
                      placement.hint(l10n),
                      style: text.caption.tint(palette.muted),
                    ),
                  ],
                ),
              ),
              if (jewel != null) ...[
                DsGaps.hSm,
                AdLockTag(
                  tier: jewel,
                  label: l10n.adsLockedNeeds(lockedTier!.label(l10n)),
                ),
              ] else if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: DsSizes.iconMd,
                  color: palette.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Audience
// ---------------------------------------------------------------------------

class _AudiencePicker extends ConsumerWidget {
  const _AudiencePicker({
    required this.audience,
    required this.targeting,
    required this.onChanged,
  });

  final AdAudience audience;
  final AdTargeting targeting;
  final ValueChanged<AdAudience> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final text = context.dsText;
    final governorates = ref.watch(adGovernoratesProvider).value ?? const [];

    Widget choice(bool targeted, String title, String hint, IconData icon) {
      final selected = audience.targeted == targeted;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: InkWell(
            borderRadius: DsRadius.borderLg,
            onTap: () => onChanged(audience.copyWith(targeted: targeted)),
            child: AnimatedContainer(
              duration: DsReducedMotion.duration(DsMotion.fast),
              padding: DsSpacing.cardPadding,
              decoration: BoxDecoration(
                color: selected ? palette.primarySoft : palette.surface,
                borderRadius: DsRadius.borderLg,
                border: Border.all(
                  color: selected ? palette.primary : palette.line,
                  width: selected ? DsStrokes.medium : DsStrokes.thin,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: selected ? palette.primary : palette.muted),
                  DsGaps.vXs,
                  Text(title, style: text.bodyStrong.tint(palette.ink)),
                  DsGaps.vXxs,
                  Text(hint, style: text.caption.tint(palette.muted)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final groupsLocked = targeting != AdTargeting.full;
    final locationLocked = targeting == AdTargeting.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              choice(
                false,
                l10n.adsAudienceEveryone,
                l10n.adsAudienceEveryoneHint,
                Icons.public_rounded,
              ),
              DsGaps.hSm,
              choice(
                true,
                l10n.adsAudienceTargeted,
                l10n.adsAudienceTargetedHint,
                Icons.center_focus_strong_rounded,
              ),
            ],
          ),
        ),
        if (audience.targeted) ...[
          DsGaps.vLg,
          _GroupTitle(
            label: l10n.adsTargetGroups,
            lockedTier: groupsLocked ? AdTier.gold : null,
          ),
          DsGaps.vSm,
          Wrap(
            spacing: DsSpacing.xs,
            runSpacing: DsSpacing.xs,
            children: [
              DsChip(
                label: l10n.adsTargetFollowers,
                icon: Icons.favorite_border_rounded,
                selected: audience.followers,
                onTap: () => onChanged(
                  audience.copyWith(followers: !audience.followers),
                ),
              ),
              DsChip(
                label: l10n.adsTargetPastBuyers,
                icon: Icons.shopping_bag_outlined,
                selected: audience.pastBuyers,
                onTap: () => onChanged(
                  audience.copyWith(pastBuyers: !audience.pastBuyers),
                ),
              ),
              DsChip(
                label: l10n.adsTargetInterested,
                icon: Icons.interests_outlined,
                selected: audience.interested,
                onTap: () => onChanged(
                  audience.copyWith(interested: !audience.interested),
                ),
              ),
              DsChip(
                label: l10n.adsTargetNewShoppers,
                icon: Icons.fiber_new_outlined,
                selected: audience.newShoppers,
                onTap: () => onChanged(
                  audience.copyWith(newShoppers: !audience.newShoppers),
                ),
              ),
            ],
          ),
          if (governorates.isNotEmpty) ...[
            DsGaps.vLg,
            _GroupTitle(
              label: l10n.adsTargetGovernorates,
              lockedTier: locationLocked ? AdTier.silver : null,
            ),
            DsGaps.vSm,
            Wrap(
              spacing: DsSpacing.xs,
              runSpacing: DsSpacing.xs,
              children: [
                for (final g in governorates)
                  DsChip(
                    label: g.name,
                    count: g.shoppers,
                    selected: audience.governorates.contains(g.name),
                    onTap: () {
                      final next = [...audience.governorates];
                      next.contains(g.name)
                          ? next.remove(g.name)
                          : next.add(g.name);
                      onChanged(audience.copyWith(governorates: next));
                    },
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.label, required this.lockedTier});

  final String label;
  final AdTier? lockedTier;

  @override
  Widget build(BuildContext context) {
    final jewel = lockedTier?.jewel;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.dsText.labelStrong.tint(context.atelier.ink),
          ),
        ),
        if (jewel != null)
          AdLockTag(
            tier: jewel,
            label: context.l10n.adsLockedNeeds(lockedTier!.label(context.l10n)),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Duration
// ---------------------------------------------------------------------------

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  static const _quick = [3, 7, 14, 30];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            for (final d in _quick)
              DsChip(
                label: l10n.adsDays(d),
                selected: days == d,
                onTap: () => onChanged(d),
              ),
          ],
        ),
        DsGaps.vSm,
        Row(
          children: [
            Expanded(
              child: Slider(
                value: days.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                activeColor: palette.primary,
                inactiveColor: palette.primarySoft,
                label: l10n.adsDays(days),
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
            Text(
              l10n.adsDays(days),
              style: context.dsText.bodyStrong.tint(palette.ink),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The summary
// ---------------------------------------------------------------------------

class _Summary extends StatelessWidget {
  const _Summary({
    required this.state,
    required this.onLaunch,
    required this.onUnlock,
  });

  final CampaignComposerState state;
  final VoidCallback onLaunch;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final text = context.dsText;
    final quote = state.quote;

    if (quote == null) {
      return SellerPanel(
        padding: DsSpacing.cardPaddingLg,
        child: state.quoteFailure != null
            ? Text(l10n.adsQuoteFailed, style: text.body.tint(palette.critical))
            : const DsShimmer(
                child: DsSkeleton.box(height: 160, borderRadius: DsRadius.lg),
              ),
      );
    }

    final p = quote.price;
    final tier = quote.requiredTier;

    return AnimatedOpacity(
      opacity: state.isQuoting ? 0.6 : 1,
      duration: DsReducedMotion.duration(DsMotion.fast),
      child: SellerPanel(
        padding: DsSpacing.cardPaddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Reach.
            Row(
              children: [
                Icon(Icons.groups_rounded, color: palette.primary),
                DsGaps.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.adsReachTitle,
                        style: text.caption.tint(palette.muted),
                      ),
                      Text(
                        l10n.adsReachValue(quote.reach),
                        style: text.metricSmall.tint(palette.ink),
                      ),
                    ],
                  ),
                ),
                Text(
                  l10n.adsReachShare((quote.reachShare * 100).round()),
                  style: text.captionStrong.tint(palette.primary),
                ),
              ],
            ),
            DsGaps.vSm,
            ClipRRect(
              borderRadius: DsRadius.borderFull,
              child: LinearProgressIndicator(
                value: quote.reachShare,
                minHeight: DsSpacing.xs,
                color: palette.primary,
                backgroundColor: palette.primarySoft,
              ),
            ),
            DsGaps.vLg,
            // Share of voice.
            Row(
              children: [
                Icon(Icons.pie_chart_outline_rounded, color: palette.gold),
                DsGaps.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.adsShareOfVoice,
                        style: text.caption.tint(palette.muted),
                      ),
                      Text(
                        quote.competingCampaigns == 0
                            ? l10n.adsShareAlone
                            : l10n.adsShareOfVoiceHint(
                                quote.competingCampaigns,
                              ),
                        style: text.caption.tint(palette.ink),
                      ),
                    ],
                  ),
                ),
                Text(
                  l10n.adsPercent((quote.shareOfVoice * 100).round()),
                  style: text.metricSmall.tint(palette.gold),
                ),
              ],
            ),
            if (quote.feedPost != null) ...[
              DsGaps.vLg,
              Text(
                l10n.adsFeedPostPinned,
                style: text.caption.tint(palette.muted),
              ),
              DsGaps.vXs,
              Row(
                children: [
                  AdProductThumb(url: quote.feedPost!.imageUrl),
                  DsGaps.hSm,
                  Expanded(
                    child: Text(
                      quote.feedPost!.title ?? state.productTitle ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.body.tint(palette.ink),
                    ),
                  ),
                ],
              ),
            ],
            Divider(color: palette.line, height: DsSpacing.xxl),
            // Price, line by line.
            _PriceLine(
              label: l10n.adsPriceLine(l10n.adsDays(p.days)),
              value: formatSyp(p.listPrice),
            ),
            if (p.discount > 0)
              _PriceLine(
                label: l10n.adsPriceDiscount(quote.tier.label(l10n)),
                value: l10n.adsMinus(formatSyp(p.discount)),
                color: palette.positive,
              ),
            if (p.creditApplied > 0)
              _PriceLine(
                label: l10n.adsPriceCredit,
                value: l10n.adsMinus(formatSyp(p.creditApplied)),
                color: palette.positive,
              ),
            DsGaps.vXs,
            _PriceLine(
              label: l10n.adsPriceToPay,
              value: formatSyp(p.toPay),
              strong: true,
            ),
            DsGaps.vLg,
            if (quote.needsFeedPost) ...[
              Text(
                l10n.adsFeedPostMissing,
                style: text.bodySmall.tint(palette.caution),
              ),
              DsGaps.vSm,
              DsButton(
                label: l10n.adsCreatePost,
                icon: Icons.add_photo_alternate_outlined,
                variant: DsButtonVariant.secondary,
                onPressed: () => context.push(RoutePaths.addPost),
              ),
            ] else if (!quote.allowed && tier != null)
              DsButton(
                label: l10n.adsUnlockWith(tier.label(l10n)),
                icon: Icons.lock_open_rounded,
                onPressed: onUnlock,
              )
            else
              DsButton(
                label: p.toPay == 0
                    ? l10n.adsLaunchFree
                    : l10n.adsLaunch(formatSyp(p.toPay)),
                icon: Icons.rocket_launch_rounded,
                isLoading: state.isLaunching,
                onPressed: state.canLaunch ? onLaunch : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.value,
    this.color,
    this.strong = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final style = strong ? context.dsText.bodyStrong : context.dsText.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style.tint(palette.muted))),
          Text(value, style: style.tint(color ?? palette.ink)),
        ],
      ),
    );
  }
}
