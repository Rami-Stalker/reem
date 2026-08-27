import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/home/domain/entities/nearby_store.dart';
import 'package:reem/features/home/presentation/providers/home_content_provider.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';

/// "Boutiques near you" — gated behind location. Until the customer opts in we
/// show a soft permission card; once enabled, a rail of nearby stores with
/// distance and open/closed status.
class HomeNearbyStores extends ConsumerStatefulWidget {
  const HomeNearbyStores({super.key});

  @override
  ConsumerState<HomeNearbyStores> createState() => _HomeNearbyStoresState();
}

class _HomeNearbyStoresState extends ConsumerState<HomeNearbyStores> {
  bool _locationEnabled = false;

  @override
  Widget build(BuildContext context) {
    final stores = ref.watch(
      homeContentNotifierProvider
          .select((s) => s.content?.nearbyStores ?? const <NearbyStore>[]),
    );

    if (!_locationEnabled) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: _LocationPrompt(
          onEnable: () => setState(() => _locationEnabled = true),
        ),
      );
    }

    if (stores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          eyebrow: context.l10n.homeNearbyEyebrow,
          title: context.l10n.homeNearbyStores,
        ),
        SizedBox(
          height: 92,
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

class _LocationPrompt extends StatelessWidget {
  const _LocationPrompt({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: context.primaryGradient,
              borderRadius: DsRadius.borderLg,
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.homeNearbyPromptTitle,
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.bold,
                    fontSize: DsTypography.labelLarge,
                    color: c.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.homeNearbyPromptBody,
                  style: TextStyle(
                      fontSize: DsTypography.labelSmall,
                      color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          DsButton(
            label: context.l10n.enable,
            size: DsButtonSize.sm,
            variant: DsButtonVariant.tonal,
            isExpanded: false,
            onPressed: onEnable,
          ),
        ],
      ),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.store});

  final NearbyStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
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
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.semiBold,
                    fontSize: DsTypography.labelLarge,
                    color: c.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.near_me_rounded, size: 12, color: c.primary),
                    const SizedBox(width: 2),
                    Text('${store.distanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                            fontSize: DsTypography.labelSmall,
                            color: c.onSurfaceVariant)),
                    const SizedBox(width: DsSpacing.xs),
                    Icon(Icons.star_rounded, size: 12, color: c.rating),
                    const SizedBox(width: 2),
                    Text(store.rating.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: DsTypography.labelSmall,
                            color: c.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  store.isOpen ? context.l10n.openNow : context.l10n.closedNow,
                  style: TextStyle(
                    fontSize: DsTypography.labelSmall,
                    fontWeight: DsTypography.bold,
                    color: store.isOpen ? c.success : c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
