import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/checkout/presentation/order_labels.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/presentation/providers/store_ads_providers.dart';
import 'package:ohara/features/store_ads/presentation/widgets/store_ads_labels.dart';

/// The icon a payment method is recognised by.
IconData adPaymentIcon(String method) => switch (method) {
  adPayFromEarnings => Icons.account_balance_wallet_rounded,
  'sham_cash' || 'syriatel_cash' || 'mtn_cash' => Icons.phone_iphone_rounded,
  'bank_transfer' => Icons.account_balance_rounded,
  'hawala' => Icons.storefront_rounded,
  _ => Icons.payments_rounded,
};

/// «كيف تدفعين؟» — her earnings, at once, or a transfer the way she sends any
/// money: Sham Cash, Syriatel Cash, MTN Cash, a bank transfer, a hawala.
///
/// Returns [adPayFromEarnings] or the chosen method's wire name.
class AdPaymentMethodSheet extends ConsumerWidget {
  const AdPaymentMethodSheet({
    super.key,
    required this.plan,
    this.isUpgrade = false,
  });

  final AdPlan plan;
  final bool isUpgrade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final text = context.dsText;
    final options = ref.watch(adPaymentOptionsProvider);

    return DsSheetScaffold(
      title: l10n.adsPlanConfirmTitle(plan.tier.label(l10n)),
      subtitle: l10n.adsPlanConfirmBody(formatSyp(plan.price)),
      child: options.when(
        loading: () => const Padding(
          padding: DsSpacing.paddingXl,
          child: DsLoadingIndicator(),
        ),
        error: (_, _) =>
            Text(l10n.adsFailed, style: text.body.tint(palette.critical)),
        data: (o) {
          final canUseEarnings = o.earningsBalance >= plan.price;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isUpgrade) ...[
                Text(
                  l10n.adsPlanConfirmUpgradeNote,
                  style: text.bodySmall.tint(palette.muted),
                ),
                DsGaps.vMd,
              ],
              Text(l10n.adsPayHow, style: text.labelStrong.tint(palette.ink)),
              DsGaps.vSm,
              _MethodTile(
                icon: adPaymentIcon(adPayFromEarnings),
                title: l10n.adsPayFromEarnings,
                subtitle: canUseEarnings
                    ? l10n.adsPayEarningsBalance(formatSyp(o.earningsBalance))
                    : l10n.adsPayEarningsShort(formatSyp(o.earningsBalance)),
                badge: canUseEarnings ? l10n.adsPayInstant : null,
                enabled: canUseEarnings,
                onTap: () => Navigator.of(context).pop(adPayFromEarnings),
              ),
              for (final m in o.transferMethods) ...[
                DsGaps.vSm,
                _MethodTile(
                  icon: adPaymentIcon(m.method),
                  title: l10n.paymentMethodName(m.method),
                  subtitle: l10n.adsPayTransferHint,
                  onTap: () => Navigator.of(context).pop(m.method),
                ),
              ],
              if (o.transferMethods.isEmpty && !canUseEarnings) ...[
                DsGaps.vMd,
                Text(
                  l10n.adsPayNoMethods,
                  style: text.bodySmall.tint(palette.caution),
                ),
              ],
              DsGaps.vMd,
              DsButton(
                label: l10n.cancel,
                variant: DsButtonVariant.ghost,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final text = context.dsText;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SellerPanel(
        onTap: enabled ? onTap : null,
        padding: DsSpacing.cardPadding,
        child: Row(
          children: [
            Container(
              width: DsSizes.avatarMd,
              height: DsSizes.avatarMd,
              decoration: BoxDecoration(
                color: palette.primarySoft,
                borderRadius: DsRadius.borderMd,
              ),
              child: Icon(icon, color: palette.primary),
            ),
            DsGaps.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.bodyStrong.tint(palette.ink)),
                  DsGaps.vXxs,
                  Text(subtitle, style: text.caption.tint(palette.muted)),
                ],
              ),
            ),
            if (badge != null)
              DsBadge(label: badge!, tone: DsBadgeTone.success),
          ],
        ),
      ),
    );
  }
}

/// A plan paid by transfer that is still waiting — on her, on finance, or
/// sent back with a reason. Kept in front of her until it is settled.
class AdPendingPaymentBanner extends ConsumerWidget {
  const AdPendingPaymentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchase = ref.watch(adPlansProvider).value?.pendingPurchase;
    if (purchase == null || !purchase.status.isOpen) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final tier = purchase.tier.label(l10n);
    final (tone, icon, message) = switch (purchase.status) {
      AdPurchaseStatus.awaitingReview => (
        DsTone.info,
        Icons.hourglass_top_rounded,
        l10n.adsPaymentBannerReview(tier),
      ),
      AdPurchaseStatus.rejected => (
        DsTone.critical,
        Icons.error_outline_rounded,
        l10n.adsPaymentBannerRejected(tier),
      ),
      _ => (
        DsTone.caution,
        Icons.payments_rounded,
        l10n.adsPaymentBannerAwaiting(tier),
      ),
    };
    final color = context.toneColor(tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: Material(
        color: context.toneContainer(tone),
        borderRadius: DsRadius.borderLg,
        child: InkWell(
          borderRadius: DsRadius.borderLg,
          onTap: () => context.push(RoutePaths.sellerAdsPayment),
          child: Padding(
            padding: DsSpacing.cardPadding,
            child: Row(
              children: [
                Icon(icon, color: color),
                DsGaps.hSm,
                Expanded(
                  child: Text(
                    message,
                    style: context.dsText.bodySmall.semibold.tint(color),
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of every buy button until her store is approved.
class AdStoreNotVerifiedCard extends ConsumerWidget {
  const AdStoreNotVerifiedCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = ref.watch(adPlansProvider).value?.storeVerified ?? true;
    if (verified) return const SizedBox.shrink();
    final l10n = context.l10n;
    final color = context.toneColor(DsTone.caution);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: Container(
        padding: DsSpacing.cardPaddingLg,
        decoration: BoxDecoration(
          color: context.toneContainer(DsTone.caution),
          borderRadius: DsRadius.borderLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, color: color),
                DsGaps.hSm,
                Expanded(
                  child: Text(
                    l10n.adsNotVerifiedTitle,
                    style: context.dsText.bodyStrong.tint(color),
                  ),
                ),
              ],
            ),
            DsGaps.vXs,
            Text(
              l10n.adsNotVerifiedBody,
              style: context.dsText.bodySmall.tint(color),
            ),
            DsGaps.vMd,
            DsButton(
              label: l10n.adsNotVerifiedAction,
              icon: Icons.arrow_back_rounded,
              variant: DsButtonVariant.secondary,
              size: DsButtonSize.md,
              onPressed: () => context.push(RoutePaths.sellerVerification),
            ),
          ],
        ),
      ),
    );
  }
}
