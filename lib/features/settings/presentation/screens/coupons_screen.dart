import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/value_objects/money_format.dart';
import 'package:ohara/features/cart/presentation/providers/cart_providers.dart';
import 'package:ohara/features/checkout/presentation/providers/applied_coupon_provider.dart';
import 'package:ohara/features/settings/domain/entities/coupon_entity.dart';
import 'package:ohara/features/settings/presentation/providers/coupon_apply_provider.dart';
import 'package:ohara/features/settings/presentation/providers/coupons_provider.dart';

/// Her coupons.
///
/// This screen used to list four invented codes — `SUMMER20`, `GLOW15`,
/// `FREESHIP`, `VIP25` — in English, priced in dollars, on a platform that
/// charges in Syrian pounds. Tapping one copied it, and checkout then refused
/// it, because no such coupon has ever existed. The server has answered
/// `GET /coupons` with her real, unexpired, still-redeemable offers the whole
/// time; the data layer to read it was already written and simply never
/// called.
///
/// Applying happens here rather than only at checkout because this is where
/// she is looking at the offer. The eligibility answer belongs next to the
/// choice: «حد أدنى ٥٠٬٠٠٠ ل.س» said now is a basket she can still add to,
/// said at checkout it is an order that fails at the end.
class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupons = ref.watch(couponsProvider);
    final applied = ref.watch(appliedCouponProvider);
    final cart = ref.watch(cartNotifierProvider).cart;

    // A discount was quoted against one subtotal; once the basket moves, the
    // figure on screen is a promise the order will not keep.
    ref.listen(
      cartNotifierProvider.select((state) => state.cart.summary.subtotal),
      (_, subtotal) => ref
          .read(appliedCouponProvider.notifier)
          .invalidateForBasket(subtotal),
    );

    return OharaScrollPage(
      slivers: [
        VanityAppBar(
          title: context.l10n.settingsCoupons,
          showBack: true,
          icon: Icons.local_offer_outlined,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              OharaSectionHeader(
                title: context.l10n.settingsYourOffers,
                subtitle: context.l10n.settingsYourOffersSubtitle,
              ),
              const SizedBox(height: DsSpacing.lg),

              if (applied != null) ...[
                _AppliedBanner(
                  code: applied.code,
                  discount: applied.discount.format(),
                  onRemove: () =>
                      ref.read(appliedCouponProvider.notifier).clear(),
                  onCheckout: () => context.push(RoutePaths.checkout),
                ),
                const SizedBox(height: DsSpacing.lg),
              ] else if (!cart.isEmpty) ...[
                _BasketHint(subtotal: cart.summary.subtotal?.format()),
                const SizedBox(height: DsSpacing.lg),
              ],

              coupons.when(
                loading: () => const _CouponsSkeleton(),
                error: (_, _) => _CouponsFailed(
                  onRetry: () => ref.invalidate(couponsProvider),
                ),
                data: (list) {
                  final redeemable = list
                      .where((coupon) => coupon.isRedeemable)
                      .toList();
                  if (redeemable.isEmpty) return const _NoCoupons();
                  return Column(
                    children: [
                      for (var i = 0; i < redeemable.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: DsSpacing.md),
                          child: _CouponTicket(
                            coupon: redeemable[i],
                            index: i,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _CouponTicket extends ConsumerWidget {
  const _CouponTicket({required this.coupon, required this.index});

  final CouponEntity coupon;
  final int index;

  /// «خصم ٢٠٪» or «خصم ٥٬٠٠٠ ل.س», from what the coupon actually is.
  String _headline(BuildContext context) => switch (coupon.kind) {
    CouponKind.percent => context.l10n.settingsCouponPercentOff(
      coupon.discountPercent.toStringAsFixed(0),
    ),
    CouponKind.fixed => context.l10n.settingsCouponAmountOff(
      (coupon.amountOff ?? 0).sypFull,
    ),
    CouponKind.unknown => coupon.title,
  };

  /// The conditions, in the order they matter to her: the floor she has to
  /// reach, how long she has, and whether it is nearly spent.
  List<String> _conditions(BuildContext context) {
    final parts = <String>[];

    final minimum = coupon.minOrderAmount;
    if (minimum != null && minimum > 0) {
      parts.add(context.l10n.settingsCouponMinimum(minimum.sypFull));
    }

    final days = coupon.expiresAt.difference(DateTime.now()).inDays;
    parts.add(
      days <= 0
          ? context.l10n.settingsCouponEndsToday
          : context.l10n.settingsCouponDaysLeft(days),
    );

    final remaining = coupon.remainingUses;
    if (remaining != null && remaining <= 3) {
      parts.add(
        remaining == 1
            ? context.l10n.settingsCouponLastUse
            : context.l10n.settingsCouponUsesLeft(remaining),
      );
    }

    return parts;
  }

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(couponApplyProvider.notifier)
        .apply(coupon.code);
    if (!context.mounted) return;

    if (result.didApply) {
      DsSnackbar.show(
        context,
        message: context.l10n.settingsCouponApplied(
          coupon.code,
          result.discount!.format(),
        ),
        type: DsSnackbarType.success,
      );
      return;
    }

    final message = switch (result.issue) {
      CouponApplyIssue.emptyBasket => context.l10n.settingsCouponEmptyBag,
      CouponApplyIssue.unknownSubtotal =>
        context.l10n.settingsCouponTwoCurrencies,
      null => result.serverMessage ?? context.l10n.settingsCouponApplyFailed,
    };
    DsSnackbar.show(context, message: message, type: DsSnackbarType.error);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final pending = ref.watch(couponApplyProvider);
    final applied = ref.watch(appliedCouponProvider);

    final isPending = pending == coupon.code;
    final isApplied = applied?.code == coupon.code;
    // One at a time: two in flight would race to be the applied one.
    final isBusy = pending != null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxl,
        gradient: index.isEven ? context.primaryGradient : DsGradients.rewards,
        boxShadow: context.luxuryShadow,
        border: isApplied
            ? Border.all(color: colors.onPrimary.withValues(alpha: 0.85), width: 2)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(DsSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    coupon.isUserSpecific
                        ? Icons.card_giftcard_rounded
                        : Icons.local_offer_rounded,
                    color: colors.onPrimary,
                  ),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.code,
                        style: context.dsText.sectionTitle.bold.tint(colors.onPrimary).copyWith(letterSpacing: 2),
                      ),
                      Text(
                        _headline(context),
                        style: context.dsText.body.semibold.tint(colors.onPrimary.withValues(alpha: 0.92)),
                      ),
                      DsGaps.vXxxs,
                      Text(
                        _conditions(context).join(' · '),
                        style: context.dsText.caption.tint(colors.onPrimary.withValues(alpha: 0.75)),
                      ),
                      if (coupon.isUserSpecific) ...[
                        DsGaps.vXs,
                        _Chip(
                          label: context.l10n.settingsCouponJustForYou,
                          color: colors.onPrimary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            Divider(
              height: 1,
              color: colors.onPrimary.withValues(alpha: 0.25),
            ),
            const SizedBox(height: DsSpacing.sm),
            Row(
              children: [
                _TicketAction(
                  icon: Icons.copy_rounded,
                  label: context.l10n.settingsCouponCopyCode,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: coupon.code));
                    if (!context.mounted) return;
                    DsSnackbar.show(
                      context,
                      message: context.l10n.settingsCouponCopied(coupon.code),
                      type: DsSnackbarType.success,
                    );
                  },
                ),
                const Spacer(),
                if (isApplied)
                  _TicketAction(
                    icon: Icons.check_circle_rounded,
                    label: context.l10n.settingsCouponAppliedBadge,
                    onTap: () =>
                        ref.read(appliedCouponProvider.notifier).clear(),
                    emphasised: true,
                  )
                else if (isPending)
                  DsLoadingIndicator.inline(color: colors.onPrimary)
                else
                  _TicketAction(
                    icon: Icons.shopping_bag_outlined,
                    label: context.l10n.settingsCouponApplyToBag,
                    onTap: isBusy ? null : () => _apply(context, ref),
                    emphasised: true,
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (80 * index).ms).slideX(begin: 0.08);
  }
}

/// What is currently applied, and the way straight to paying with it.
class _AppliedBanner extends StatelessWidget {
  const _AppliedBanner({
    required this.code,
    required this.discount,
    required this.onRemove,
    required this.onCheckout,
  });

  final String code;
  final String discount;
  final VoidCallback onRemove;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.10),
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: colors.success.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: colors.success, size: 20),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.settingsCouponAppliedSaving(code, discount),
                  style: context.dsText.body.semibold.tint(colors.onSurface),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, color: colors.onSurfaceVariant),
                tooltip: context.l10n.settingsRemove,
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          PrimaryButton(
            label: context.l10n.settingsContinueToCheckout,
            onPressed: onCheckout,
          ),
        ],
      ),
    );
  }
}

/// The basket the offers will be measured against.
///
/// Shown so «حد أدنى ٥٠٬٠٠٠» has something to be compared with on the same
/// screen, instead of sending her to the cart to find out what she has.
class _BasketHint extends StatelessWidget {
  const _BasketHint({required this.subtotal});

  final String? subtotal;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    if (subtotal == null) return const SizedBox.shrink();

    return Row(
      children: [
        Icon(
          Icons.shopping_bag_outlined,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: DsSpacing.sm),
        Text(
          context.l10n.settingsBagNow(subtotal!),
          style: context.dsText.caption.tint(colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: DsSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: DsRadius.borderFull,
      ),
      child: Text(
        label,
        style: context.dsText.caption.semibold.tint(color),
      ),
    );
  }
}

class _TicketAction extends StatelessWidget {
  const _TicketAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasised = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final tint = colors.onPrimary.withValues(alpha: onTap == null ? 0.45 : 1);

    return InkWell(
      onTap: onTap,
      borderRadius: DsRadius.borderFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: DsSpacing.xs),
        decoration: emphasised
            ? BoxDecoration(
                color: colors.onPrimary.withValues(alpha: 0.18),
                borderRadius: DsRadius.borderFull,
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: tint),
            DsGaps.hXs,
            Text(
              label,
              style: context.dsText.caption.semibold.tint(tint),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCoupons extends StatelessWidget {
  const _NoCoupons();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
      child: Column(
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 48,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            context.l10n.settingsNoCoupons,
            style: context.dsText.tileTitle.semibold.tint(colors.onSurface),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            context.l10n.settingsNoCouponsBody,
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CouponsFailed extends StatelessWidget {
  const _CouponsFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 44,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            context.l10n.settingsCouponsFailed,
            style: context.dsText.body.tint(colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.md),
          SecondaryButton(label: context.l10n.retry, onPressed: onRetry),
        ],
      ),
    );
  }
}

class _CouponsSkeleton extends StatelessWidget {
  const _CouponsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          const DsShimmer(child: DsSkeleton.box(height: 132)),
          const SizedBox(height: DsSpacing.md),
        ],
      ],
    );
  }
}
