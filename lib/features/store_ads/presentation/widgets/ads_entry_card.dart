import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/store_ads/presentation/providers/store_ads_providers.dart';
import 'package:ohara/features/store_ads/presentation/widgets/store_ads_labels.dart';

/// The way into «مركز الإعلانات» from her dashboard: her plan's jewel, the
/// credit she has left to spend, and one tap to promote something.
class AdsEntryCard extends ConsumerWidget {
  const AdsEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.atelier;
    final text = context.dsText;
    final view = ref.watch(adPlansProvider).value;
    final current = view?.current;
    final jewel = current?.tier.jewel;

    return SellerPanel(
      onTap: () => context.push(RoutePaths.sellerAds),
      padding: DsSpacing.cardPaddingLg,
      child: Row(
        children: [
          Container(
            width: DsSizes.avatarLg,
            height: DsSizes.avatarLg,
            decoration: BoxDecoration(
              gradient: jewel?.gradient ?? palette.goldGradient,
              borderRadius: DsRadius.borderLg,
            ),
            child: Icon(
              Icons.campaign_rounded,
              color: jewel?.ink ?? DsColors.onGold,
            ),
          ),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.adsCenterTitle,
                        style: text.cardTitle.tint(palette.ink),
                      ),
                    ),
                    if (jewel != null) ...[
                      DsGaps.hXs,
                      DsTierBadge(
                        tier: jewel,
                        label: current!.tier.label(l10n),
                      ),
                    ],
                  ],
                ),
                DsGaps.vXxs,
                Text(
                  current != null && current.tier.isPaid
                      ? l10n.adsCreditLeft(formatSyp(current.creditRemaining))
                      : l10n.adsEntryBody,
                  style: text.caption.tint(palette.muted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: palette.muted),
        ],
      ),
    );
  }
}
