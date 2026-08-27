import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/entities/user.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/user_profile_providers.dart';
import '../widgets/follow_button.dart';
import '../widgets/profile_stat_tile.dart';
import '../widgets/seller_stats_card.dart';

/// Social profile for any user. Pass [userId] = null to show the signed-in
/// user's own profile.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userProfileNotifierProvider(userId));
    final notifier = ref.read(userProfileNotifierProvider(userId).notifier);
    final profile = state.profile;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(
          title: profile != null ? '@${profile.user.username}' : 'Profile',
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
              message: state.error ?? 'Could not load profile',
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
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.headlineSmall,
                    fontWeight: DsTypography.bold,
                    color: colors.onSurface,
                  ),
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
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
          if (user.location != null && user.location!.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.place_outlined,
                    size: 16, color: colors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  user.location!,
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.bodySmall,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: DsSpacing.lg),
          _StatsRow(profile: profile),
          const SizedBox(height: DsSpacing.lg),
          if (profile.isMe) ...[
            SecondaryButton(
              label: 'Edit profile',
              onPressed: () => context.push(RoutePaths.editProfile),
            ),
            if (user.isSeller) ...[
              const SizedBox(height: DsSpacing.sm),
              PrimaryButton(
                label: 'Manage store',
                icon: Icons.storefront_outlined,
                onPressed: () => context.push(RoutePaths.myProducts),
              ),
            ],
          ] else
            FollowButton(
              isFollowing: profile.isFollowing,
              isLoading: isFollowLoading,
              onPressed: onToggleFollow,
            ),
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
        ProfileStatTile(value: '${profile.postsCount}', label: 'Posts'),
        divider(),
        ProfileStatTile(
          value: _compact(profile.user.followersCount),
          label: 'Followers',
        ),
        divider(),
        ProfileStatTile(
          value: _compact(profile.user.followingCount),
          label: 'Following',
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
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: 3),
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
          const SizedBox(width: 4),
          Text(
            role.label,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: DsTypography.bodySmall,
              fontWeight: DsTypography.semiBold,
              color: color,
            ),
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
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.lg),
          SecondaryButton(
            label: 'Retry',
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
