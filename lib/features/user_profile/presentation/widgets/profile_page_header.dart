import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/open_route.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/services/share_service.dart';
import 'package:ohara/features/chat/domain/entities/chat_start_request.dart';
import 'package:ohara/features/chat/presentation/widgets/message_seller_button.dart';
import 'package:ohara/features/social/presentation/open_stories.dart';
import 'package:ohara/features/social/presentation/providers/social_providers.dart';
import 'package:ohara/features/user_profile/domain/entities/user_profile.dart';
import 'package:ohara/features/user_profile/presentation/widgets/follow_button.dart';
import 'package:ohara/features/user_profile/presentation/widgets/seller_stats_card.dart';

/// The top of somebody's page — a shopper's or a boutique's: her portrait in
/// the arch, her name and role, her words, the counts, what a visitor can do,
/// and for a boutique its figures under the awning.
class ProfilePageHeader extends ConsumerWidget {
  const ProfilePageHeader({
    super.key,
    required this.profile,
    required this.isFollowLoading,
    required this.onToggleFollow,
  });

  final UserProfile profile;
  final bool isFollowLoading;
  final VoidCallback onToggleFollow;

  Future<void> _openStories(BuildContext context, WidgetRef ref) async {
    final groups = await ref.read(userStoriesProvider(profile.user.id).future);
    if (!context.mounted || groups.isEmpty) return;
    await openStoryGroups(context, groups);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = profile.user;
    final tone = profile.isSeller ? ProfileTone.boutique : ProfileTone.shopper;
    // The thread quickens only while there is a story this viewer may watch.
    final hasStory = profile.hasStory && profile.isReadable;
    final bio = user.bio?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileHero(
          name: user.name,
          imageUrl: user.imageUrl,
          tone: tone,
          hasStory: hasStory,
          onPortraitTap: hasStory ? () => _openStories(context, ref) : null,
          leading: ProfileCircleButton(
            icon: DsIcons.back,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => popOrHome(context),
          ),
          actions: [
            ProfileCircleButton(
              icon: Icons.ios_share_rounded,
              tooltip: l10n.contentShare,
              onPressed: () => ShareService.profile(
                context: context,
                userId: user.id,
                name: user.name,
                imageUrl: user.imageUrl,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: ProfileNameplate(
            name: user.name,
            username: user.username,
            tone: tone,
            isVerified: user.isVerified,
            verifiedLabel: l10n.verified,
            location: user.location,
            roleLabel: switch (user.role) {
              UserRole.admin => l10n.adminRoleAdmin,
              UserRole.seller => l10n.roleSeller,
              _ => l10n.roleBuyer,
            },
          ),
        ),
        if (bio != null && bio.isNotEmpty) ...[
          DsGaps.vXl,
          ProfileQuote(text: bio, tone: tone),
          DsGaps.vMd,
        ],
        DsGaps.vXl,
        ProfileArchStats(
          tone: tone,
          items: [
            ProfileStatItem(
              value: _compact(profile.postsCount),
              label: l10n.profilePosts,
            ),
            ProfileStatItem(
              value: _compact(user.followersCount),
              label: l10n.profileFollowers,
              onTap: () => context.push(RoutePaths.followersOf(user.id)),
            ),
            ProfileStatItem(
              value: _compact(user.followingCount),
              label: l10n.profileFollowing,
              onTap: () => context.push(RoutePaths.followingOf(user.id)),
            ),
          ],
        ),
        DsGaps.vXl,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: _Actions(
            profile: profile,
            isFollowLoading: isFollowLoading,
            onToggleFollow: onToggleFollow,
          ),
        ),
        if (profile.isSeller && profile.sellerStats != null) ...[
          DsGaps.vXl,
          SellerStatsCard(stats: profile.sellerStats!),
        ],
        DsGaps.vLg,
      ],
    );
  }

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

/// What she can do here: edit her own page (and run her shop), or follow and
/// write to somebody else's.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.profile,
    required this.isFollowLoading,
    required this.onToggleFollow,
  });

  final UserProfile profile;
  final bool isFollowLoading;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = profile.user;

    if (profile.isMe) {
      return Row(
        children: [
          Expanded(
            child: DsButton(
              label: l10n.profileEdit,
              icon: Icons.edit_rounded,
              variant: DsButtonVariant.tonal,
              size: DsButtonSize.md,
              onPressed: () => context.push(RoutePaths.editProfile),
            ),
          ),
          if (user.isSeller) ...[
            DsGaps.hSm,
            Expanded(
              child: DsButton(
                label: l10n.profileManageStore,
                icon: Icons.storefront_rounded,
                size: DsButtonSize.md,
                onPressed: () => context.push(RoutePaths.myProducts),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        // A closed page cannot be followed — the server refuses it — so the
        // button is not offered rather than offered and refused.
        if (profile.isReadable)
          Expanded(
            child: FollowButton(
              isFollowing: profile.isFollowing,
              isLoading: isFollowLoading,
              onPressed: onToggleFollow,
            ),
          ),
        // Only a boutique can be written to: the server refuses any pairing
        // that is not buyer↔seller.
        if (profile.isSeller) ...[
          if (profile.isReadable) DsGaps.hSm,
          Expanded(
            child: MessageSellerButton(
              label: l10n.messageSeller,
              request: ChatStartRequest.peer(peerId: user.id),
            ),
          ),
        ],
      ],
    );
  }
}

