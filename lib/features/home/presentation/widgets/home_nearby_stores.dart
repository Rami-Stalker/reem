import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/home/domain/entities/nearby_store.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';

/// "Boutiques near you" -- the shops trading in her governorate, her own city
/// first.
///
/// This section did not work, and could not have. It opened with a card asking
/// her to "enable location", which set a boolean in this widget and nothing
/// else: no permission was requested, no coordinate was ever read, and the
/// list behind it was hard-coded empty on the server. Tapping the button
/// replaced the card with nothing at all.
///
/// It is answered from data the platform actually holds now -- the governorate
/// on her delivery address, matched against where each boutique trades -- so
/// there is no toggle, and nothing to enable. Where she has saved no address,
/// or no boutique trades near her, the section simply is not there.
class HomeNearbyStores extends ConsumerWidget {
  const HomeNearbyStores({super.key});

  static const double _railHeight = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stores = ref.watch(
      homeContentNotifierProvider.select(
        (s) => s.content?.nearbyStores ?? const <NearbyStore>[],
      ),
    );

    if (stores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          eyebrow: context.l10n.homeNearbyEyebrow,
          title: context.l10n.homeNearbyStores,
          subtitle: context.l10n.homeNearbySubtitle,
        ),
        SizedBox(
          height: _railHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            itemCount: stores.length,
            separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
            itemBuilder: (context, i) => _NearbyCard(store: stores[i]),
          ),
        ),
      ],
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.store});

  final NearbyStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () => context.push(RoutePaths.userProfileOf(store.id)),
      child: Container(
        width: 248,
        padding: const EdgeInsets.all(DsSpacing.sm),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: DsRadius.borderXl,
          border: Border.all(color: c.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            DsAvatar(imageUrl: store.logoUrl, name: store.name, size: 48),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    store.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.labelLarge.tint(c.onSurface),
                  ),
                  DsGaps.vXxxs,
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 12, color: c.primary),
                      DsGaps.hXxxs,
                      Flexible(
                        child: Text(
                          store.area,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.caption.tint(
                            c.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (store.rating != null) ...[
                        const SizedBox(width: DsSpacing.xs),
                        Icon(Icons.star_rounded, size: 12, color: c.rating),
                        DsGaps.hXxxs,
                        Text(
                          store.rating!.toStringAsFixed(1),
                          style: context.dsText.caption.tint(
                            c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  DsGaps.vXxs,
                  Text(
                    store.sameCity
                        ? l10n.homeNearbyInYourCity
                        : l10n.homeNearbyInGovernorate,
                    style: context.dsText.caption.bold.tint(
                      store.sameCity ? c.success : c.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
