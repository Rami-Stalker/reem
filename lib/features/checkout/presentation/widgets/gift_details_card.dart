import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/checkout/domain/entities/order.dart';

/// «إرسال كهدية» on an order, seen from either side.
///
/// For the buyer it says who the gift is going to and what the card reads.
/// For the boutique ([forSeller]) it is a packing note: wrap it, put this
/// card in, leave the prices out, and collect nothing at the door.
class GiftDetailsCard extends StatelessWidget {
  const GiftDetailsCard({
    super.key,
    required this.gift,
    this.recipientName,
    this.forSeller = false,
  });

  final OrderGift gift;
  final String? recipientName;
  final bool forSeller;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final from = gift.isAnonymous
        ? l10n.giftCardAnonymous
        : l10n.giftCardFrom(gift.fromName!);

    final notes = forSeller
        ? <(IconData, String)>[
            (
              Icons.redeem_rounded,
              gift.wrap ? l10n.giftSellerWrap : l10n.giftSellerNoWrap,
            ),
            if (gift.hidePrices)
              (Icons.money_off_rounded, l10n.giftSellerHidePrices),
            (Icons.verified_rounded, l10n.giftSellerPaid),
          ]
        : <(IconData, String)>[
            if (recipientName != null)
              (Icons.person_pin_circle_outlined, l10n.giftSentTo(recipientName!)),
            if (gift.wrap) (Icons.redeem_rounded, l10n.giftWrap),
            if (gift.hidePrices)
              (Icons.money_off_rounded, l10n.giftHidePrices),
          ];

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXl,
        color: colors.primaryContainer.withValues(alpha: 0.55),
        border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded, color: colors.primary),
              DsGaps.hSm,
              Expanded(
                child: Text(
                  forSeller ? l10n.giftSellerTitle : l10n.giftOrderTitle,
                  style: context.dsText.tileTitle.bold.tint(colors.onSurface),
                ),
              ),
            ],
          ),
          DsGaps.vSm,
          for (final (icon, text) in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: colors.onSurfaceVariant),
                  DsGaps.hXs,
                  Expanded(
                    child: Text(
                      text,
                      style: context.dsText.bodySmall.tint(colors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          if (gift.message != null || forSeller) ...[
            DsGaps.vSm,
            // The card itself, as it will read inside the box.
            Container(
              padding: const EdgeInsets.all(DsSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: DsRadius.borderLg,
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (forSeller)
                    Text(
                      l10n.giftSellerCard,
                      style: context.dsText.caption.tint(
                        colors.onSurfaceVariant,
                      ),
                    ),
                  if (gift.message != null)
                    Text(
                      gift.message!,
                      style: context.dsText.body
                          .tint(colors.onSurface)
                          .copyWith(height: 1.6),
                    ),
                  DsGaps.vXs,
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      from,
                      style: context.dsText.labelStrong.tint(colors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
