import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/presentation/widgets/message_seller_button.dart';
import 'package:reem/features/user_profile/domain/entities/user_profile.dart';
import 'package:reem/features/user_profile/presentation/providers/user_profile_providers.dart';
import 'package:reem/features/user_profile/presentation/widgets/follow_button.dart';
import 'package:reem/features/user_profile/presentation/widgets/profile_stat_tile.dart';
import 'package:reem/features/user_profile/presentation/widgets/seller_stats_card.dart';

/// Social profile for any user. Pass [userId] = null to show the signed-in
/// user's own profile.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(userProfileNotifierProvider(userId));
    final notifier = ref.read(userProfileNotifierProvider(userId).notifier);
    final profile = state.profile;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(
          title: profile != null
              ? '@${profile.user.username}'
              : l10n.profileTitle,
          showBack: true,
        ),
        if (state.isLoading && profile == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (profile == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ErrorView(
              message: state.error ?? context.l10n.profileLoadFailed,
              onRetry: notifier.load,
            ),
          )
        else
          SliverToBoxAdapter(
            child: _ProfileBody(
              profile: profile,
              isFollowLoading: state.isFollowLoading,
              onToggleFollow: notifier.toggleFollow,
            ),
          ),
      ],
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.isFollowLoading,
    required this.onToggleFollow,
  });

  final UserProfile profile;
  final bool isFollowLoading;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final user = profile.user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.xxl,
      ),
      child: Column(
        children: [
          AppAvatar(
            radius: 50,
            imageUrl: user.imageUrl,
            heroTag: 'profile_${user.id}',
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: context.dsText.screenTitle.bold.tint(colors.onSurface),
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: DsSpacing.xs),
                Icon(Icons.verified_rounded, color: colors.primary, size: 20),
              ],
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          _RoleBadge(role: user.role),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.md),
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              style: context.dsText.body
                  .tint(colors.onSurfaceVariant)
                  .copyWith(height: 1.4),
            ),
          ],
          if (user.location != null && user.location!.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                DsGaps.hXxs,
                Text(
                  user.location!,
                  style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
                ),
              ],
            ),
          ],
          const SizedBox(height: DsSpacing.lg),
          _StatsRow(profile: profile),
          const SizedBox(height: DsSpacing.lg),
          if (profile.isMe) ...[
            SecondaryButton(
              label: context.l10n.profileEdit,
              onPressed: () => context.push(RoutePaths.editProfile),
            ),
            if (user.isSeller) ...[
              const SizedBox(height: DsSpacing.sm),
              PrimaryButton(
                label: context.l10n.profileManageStore,
                icon: Icons.storefront_outlined,
                onPressed: () => context.push(RoutePaths.myProducts),
              ),
            ],
          ] else ...[
            FollowButton(
              isFollowing: profile.isFollowing,
              isLoading: isFollowLoading,
              onPressed: onToggleFollow,
            ),
            // Only a boutique can be written to: the server refuses any
            // pairing that is not buyer↔seller, so offering this on a fellow
            // shopper's profile would be a button that always fails.
            if (profile.isSeller) ...[
              const SizedBox(height: DsSpacing.sm),
              MessageSellerButton(
                label: context.l10n.messageSeller,
                request: ChatStartRequest.peer(peerId: user.id),
              ),
            ],
          ],
          if (profile.isSeller && profile.sellerStats != null) ...[
            const SizedBox(height: DsSpacing.xl),
            SellerStatsCard(stats: profile.sellerStats!),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    Widget divider() => Container(width: 1, height: 28, color: colors.border);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProfileStatTile(
          value: '${profile.postsCount}',
          label: context.l10n.profilePosts,
        ),
        divider(),
        // Both counts open the list behind them — `ProfileStatTile` has taken
        // an `onTap` since it was written and nobody ever passed one.
        ProfileStatTile(
          value: _compact(profile.user.followersCount),
          label: context.l10n.profileFollowers,
          onTap: () =>
              context.push(RoutePaths.followersOf(profile.user.id)),
        ),
        divider(),
        ProfileStatTile(
          value: _compact(profile.user.followingCount),
          label: context.l10n.profileFollowing,
          onTap: () =>
              context.push(RoutePaths.followingOf(profile.user.id)),
        ),
      ],
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isSeller = role == UserRole.seller;
    final isAdmin = role == UserRole.admin;
    final color = isAdmin
        ? colors.error
        : isSeller
        ? colors.primary
        : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin
                ? Icons.shield_outlined
                : isSeller
                ? Icons.storefront_outlined
                : Icons.person_outline,
            size: 13,
            color: color,
          ),
          DsGaps.hXxs,
          Text(
            role.label,
            style: context.dsText.bodySmall.semibold.tint(color),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 40, color: colors.error),
          const SizedBox(height: DsSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.lg),
          SecondaryButton(label: context.l10n.retry, onPressed: onRetry),
        ],
      ),
    );
  }
}
