import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/experience/role_experience.dart';
import '../../../../core/router/route_paths.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../experience/presentation/providers/role_experience_provider.dart';
import '../../../experience/presentation/screens/experience_surface_screen.dart';
import '../../../seller_dashboard/presentation/screens/seller_profile_screen.dart';
import '../providers/profile_overview_provider.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_achievements.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/profile_cover.dart';
import '../widgets/profile_followed_stores.dart';
import '../widgets/profile_identity.dart';
import '../widgets/profile_loyalty_dashboard.dart';
import '../widgets/profile_menu.dart';
import '../widgets/profile_orders_overview.dart';
import '../widgets/profile_recently_viewed.dart';
import '../widgets/profile_referral_card.dart';
import '../widgets/profile_stats.dart';
import '../widgets/profile_wishlist_preview.dart';

/// Role-aware profile dispatcher — renders [SellerProfileScreen] for sellers
/// and the buyer profile hub for customers.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(
      roleExperienceProvider.select((experience) => experience.role),
    );
    return switch (role) {
      ExperienceRole.seller => const SellerProfileScreen(),
      ExperienceRole.admin => const ExperienceSurfaceScreen(
        surface: ExperienceSurface.settings,
      ),
      ExperienceRole.buyer => const _BuyerProfileScreen(),
    };
  }
}

/// The buyer's profile centre — identity, loyalty, orders, achievements,
/// wishlist, referral and account menu.
class _BuyerProfileScreen extends ConsumerStatefulWidget {
  const _BuyerProfileScreen();

  @override
  ConsumerState<_BuyerProfileScreen> createState() =>
      _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends ConsumerState<_BuyerProfileScreen> {
  static const double _gap = DsSpacing.xl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final favorites = ref.read(favoritesNotifierProvider);
      if (favorites.favorites.isEmpty && !favorites.isLoading) {
        ref.read(favoritesNotifierProvider.notifier).load();
      }
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(profileOverviewNotifierProvider.notifier).refresh(),
      ref.read(favoritesNotifierProvider.notifier).load(),
      ref.read(authNotifierProvider.notifier).refreshUser(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider.select((s) => s.user));

    if (user == null) {
      return ReemScrollPage(
        slivers: [
          const PremiumAppBar(title: 'Profile'),
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsEmptyState(
              icon: Icons.person_outline_rounded,
              title: 'Sign in to Reem',
              message: 'Access your profile, orders and saved pieces.',
              actionLabel: 'Sign in',
              onAction: () => context.push(RoutePaths.login),
            ),
          ),
        ],
      );
    }

    final savedCount = ref.watch(
      favoritesNotifierProvider.select((s) => s.favorites.length),
    );

    return ReemScrollPage(
      onRefresh: _refresh,
      slivers: [
        ProfileCover(user: user),

        SliverToBoxAdapter(child: ProfileIdentity(user: user)),
        const _Gap(DsSpacing.lg),

        _box(const ProfileCompletionCard()),
        const _Gap(DsSpacing.md),

        SliverToBoxAdapter(
          child: ProfileStats(user: user, savedCount: savedCount),
        ),

        _box(const ProfileLoyaltyDashboard()),
        const _Gap(_gap),

        _box(const ProfileOrdersOverview()),
        const _Gap(_gap),

        _box(const ProfileAchievements()),
        const _Gap(_gap),

        _box(const ProfileWishlistPreview()),
        const _Gap(_gap),

        _box(const ProfileRecentlyViewed()),
        const _Gap(_gap),

        _box(const ProfileFollowedStores()),
        const _Gap(_gap),

        _box(const ProfileReferralCard()),
        const _Gap(_gap),

        _box(const ProfileMenu()),

        const _Gap(DsSpacing.xl),
        const SliverToBoxAdapter(child: _VersionFooter()),
        const _Gap(140),
      ],
    );
  }

  static Widget _box(Widget child) {
    return SliverToBoxAdapter(
      child: child
          .animate()
          .fadeIn(duration: 420.ms, curve: Curves.easeOut)
          .slideY(
            begin: 0.05,
            end: 0,
            duration: 420.ms,
            curve: Curves.easeOutCubic,
          ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Center(
      child: Column(
        children: [
          Text(
            'REEM',
            style: TextStyle(
              fontFamily: DsTypography.fontFamilyDisplay,
              fontFamilyFallback: DsTypography.displayFallback,
              fontSize: DsTypography.titleSmall,
              fontWeight: DsTypography.bold,
              color: c.onSurfaceVariant,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Version 1.0.0',
            style: TextStyle(
              fontSize: DsTypography.labelSmall,
              color: c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap(this.height);

  final double height;

  @override
  Widget build(BuildContext context) =>
      SliverToBoxAdapter(child: SizedBox(height: height));
}
