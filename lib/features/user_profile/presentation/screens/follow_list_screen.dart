import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/user_profile/presentation/providers/user_profile_providers.dart';

/// Which side of a follow the list is showing.
enum FollowListKind {
  /// The accounts this person follows.
  following,

  /// The accounts following them.
  followers,
}

/// Who follows whom — the list behind the numbers on a profile.
///
/// `GET /users/:id/followers` and `/following` have existed since the profile
/// was built and nothing in the app ever called them: the profile showed three
/// counts and none of them could be opened, which is what made the strip read
/// as decoration. Tapping a count opens this.
class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, required this.userId, required this.kind});

  final String userId;
  final FollowListKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(followListProvider((userId: userId, kind: kind)));
    final title = kind == FollowListKind.following
        ? l10n.following
        : l10n.followers;

    return ReemScrollPage(
      onRefresh: () async =>
          ref.invalidate(followListProvider((userId: userId, kind: kind))),
      slivers: [
        PremiumAppBar(title: title, showBack: true),
        async.when(
          loading: () => const SliverToBoxAdapter(child: _Skeleton()),
          error: (error, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: DsErrorState(
              message: error.toString(),
              onRetry: () => ref.invalidate(
                followListProvider((userId: userId, kind: kind)),
              ),
            ),
          ),
          data: (people) => people.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: DsEmptyState(
                    icon: Icons.people_outline_rounded,
                    title: title,
                    message: kind == FollowListKind.following
                        ? l10n.followListEmptyFollowing
                        : l10n.followListEmptyFollowers,
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    DsSpacing.lg,
                    DsSpacing.sm,
                    DsSpacing.lg,
                    DsSpacing.xxl,
                  ),
                  sliver: SliverList.separated(
                    itemCount: people.length,
                    separatorBuilder: (_, _) => const SizedBox(
                      height: DsSpacing.sm,
                    ),
                    itemBuilder: (context, index) =>
                        _PersonRow(person: people[index]),
                  ),
                ),
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person});

  final User person;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return CustomerPanel(
      onTap: () => context.push(RoutePaths.userProfileOf(person.id)),
      child: Row(
        children: [
          DsAvatar(imageUrl: person.imageUrl, name: person.name, size: 48),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.tileTitle.semibold.tint(
                          c.onSurface,
                        ),
                      ),
                    ),
                    if (person.isVerified) ...[
                      DsGaps.hXxs,
                      Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: c.secondary,
                      ),
                    ],
                  ],
                ),
                if (person.username.isNotEmpty) ...[
                  DsGaps.vXxxs,
                  Text(
                    '@${person.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.tint(c.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: c.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: DsShimmer(
        child: Column(
          children: [
            for (var i = 0; i < 6; i++) ...[
              const DsSkeleton.box(height: 72, borderRadius: DsRadius.xl),
              const SizedBox(height: DsSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }
}
