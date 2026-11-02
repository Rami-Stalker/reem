import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/seller_store/domain/entities/seller_store.dart';
import 'package:ohara/features/seller_store/presentation/providers/seller_store_providers.dart';

/// A shop's terms at a glance on its page — returns, exchanges, where it
/// ships from and how fast — with the full policies a tap away.
class StoreInfoStrip extends ConsumerWidget {
  const StoreInfoStrip({super.key, required this.sellerId});

  final String sellerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(storeInfoProvider(sellerId)).value;
    if (info == null) return const SizedBox.shrink();
    final (policies, shipping) = info;
    final l10n = context.l10n;
    final chips = <(IconData, String)>[
      (
        Icons.assignment_return_outlined,
        l10n.storeInfoReturns(policies.platformReturnDays),
      ),
      (
        Icons.swap_horiz_rounded,
        policies.acceptsExchanges
            ? l10n.storeInfoExchanges
            : l10n.storeInfoNoExchanges,
      ),
      if (shipping.shipsFromGovernorate case final from?)
        (
          Icons.place_outlined,
          l10n.storeInfoShipsFrom(
            [from, ?shipping.shipsFromArea].join('، '),
          ),
        ),
      (
        Icons.schedule_rounded,
        l10n.storeInfoHandling(
          l10n.shippingHandlingDays(shipping.defaultHandlingDays),
        ),
      ),
      if (shipping.offersPickup && shipping.pickupAddress != null)
        (Icons.storefront_outlined, l10n.storeInfoPickup(shipping.pickupAddress!)),
    ];
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        DsSpacing.sm,
      ),
      child: Material(
        color: colors.surface,
        borderRadius: DsRadius.borderLg,
        child: InkWell(
          borderRadius: DsRadius.borderLg,
          onTap: () => _details(context, policies, shipping),
          child: Padding(
            padding: DsSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.policy_outlined, size: 18, color: colors.primary),
                    DsGaps.hXs,
                    Expanded(
                      child: Text(
                        l10n.storeInfoTitle,
                        style: context.dsText.labelStrong.tint(colors.onSurface),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
                DsGaps.vSm,
                Wrap(
                  spacing: DsSpacing.xs,
                  runSpacing: DsSpacing.xs,
                  children: [
                    for (final (icon, text) in chips)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.sm,
                          vertical: DsSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: DsRadius.borderFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: colors.onSurfaceVariant),
                            DsGaps.hXxs,
                            Flexible(
                              child: Text(
                                text,
                                style: context.dsText.caption.tint(
                                  colors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _details(
    BuildContext context,
    StorePolicies policies,
    ShippingSettings shipping,
  ) {
    final l10n = context.l10n;
    final rows = <(String, String)>[
      (
        l10n.storeInfoTitle,
        l10n.storePoliciesGuarantee(policies.platformReturnDays),
      ),
      if (policies.acceptsExchanges && policies.exchangeNote != null)
        (l10n.storePoliciesExchangeNote, policies.exchangeNote!),
      if (policies.returnNote != null)
        (l10n.storePoliciesReturnNote, policies.returnNote!),
      if (policies.careNote != null)
        (l10n.storePoliciesCareNote, policies.careNote!),
      if (policies.customOrderNote != null)
        (l10n.storePoliciesCustomNote, policies.customOrderNote!),
      if (shipping.offersPickup && shipping.pickupAddress != null)
        (
          l10n.shippingPickupTitle,
          [shipping.pickupAddress!, ?shipping.pickupHours].join('\n'),
        ),
      if (shipping.packagingNote != null)
        (l10n.shippingPackagingNote, shipping.packagingNote!),
    ];
    DsBottomSheet.show<void>(
      context,
      builder: (sheet) => DsSheetScaffold(
        title: l10n.storeInfoTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (title, body) in rows) ...[
              Text(
                title,
                style: context.dsText.labelStrong.tint(
                  context.dsColors.onSurface,
                ),
              ),
              DsGaps.vXxs,
              Text(
                body,
                style: context.dsText.body
                    .tint(context.dsColors.onSurfaceVariant)
                    .copyWith(height: 1.6),
              ),
              DsGaps.vMd,
            ],
          ],
        ),
      ),
    );
  }
}
