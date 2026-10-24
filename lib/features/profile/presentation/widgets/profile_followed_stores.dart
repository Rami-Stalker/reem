import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/profile/domain/entities/followed_store.dart';
import 'package:ohara/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_section_header.dart';

/// "Following" — a rail of the boutiques the customer follows, each with a
/// new-arrivals badge. Tapping opens the store profile.
class ProfileFollowedStores extends ConsumerWidget {
  const ProfileFollowedStores({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.isInitialLoading),
    );
    final stores = ref.watch(
      profileOverviewNotifierProvider.select(
        (s) => s.overview?.followedStores ?? const <FollowedStore>[],
      ),
    );

    if (!isLoading && stores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileSectionHeader(
          title: context.l10n.following,
          eyebrow: isLoading
              ? null
              : context.l10n.profileBoutiquesCount(stores.length),
        ),
        SizedBox(
          height: 96,
          child: isLoading
              ? _skeleton()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                  itemCount: stores.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: DsSpacing.md),
                  itemBuilder: (context, i) => _StoreAvatar(store: stores[i]),
                ),
        ),
      ],
    );
  }

  Widget _skeleton() {
    return DsShimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
        itemBuilder: (_, _) => const Column(
          children: [
            DsSkeleton.circle(size: 60),
            SizedBox(height: DsSpacing.xs),
            DsSkeleton.line(width: 44),
          ],
        ),
      ),
    );
  }
}

class _StoreAvatar extends StatelessWidget {
  const _StoreAvatar({required this.store});

  final FollowedStore store;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return GestureDetector(
      onTap: () => context.push(RoutePaths.userProfileOf(store.id)),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                DsAvatar(
                  imageUrl: store.logoUrl,
                  name: store.name,
                  size: 60,
                  hasRing: store.newCount > 0,
                ),
                if (store.newCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.xxs,
                        vertical: DsSpacing.xxxs,
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: c.primary,
                        borderRadius: DsRadius.borderFull,
                        border: Border.all(color: c.surface, width: 1.5),
                      ),
                      child: Text(
                        '${store.newCount}',
                        textAlign: TextAlign.center,
                        style: context.dsText.micro.bold.tint(c.onPrimary),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              store.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.dsText.caption.tint(c.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
