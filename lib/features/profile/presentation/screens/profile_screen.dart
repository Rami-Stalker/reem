import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:reem/features/experience/presentation/screens/experience_surface_screen.dart';
import 'package:reem/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:reem/features/profile/presentation/providers/profile_provider.dart';
import 'package:reem/features/profile/presentation/widgets/profile_achievements.dart';
import 'package:reem/features/profile/presentation/widgets/profile_completion_card.dart';
import 'package:reem/features/profile/presentation/widgets/profile_cover.dart';
import 'package:reem/features/profile/presentation/widgets/profile_followed_stores.dart';
import 'package:reem/features/profile/presentation/widgets/profile_identity.dart';
import 'package:reem/features/profile/presentation/widgets/profile_loyalty_dashboard.dart';
import 'package:reem/features/profile/presentation/widgets/profile_menu.dart';
import 'package:reem/features/profile/presentation/widgets/profile_orders_overview.dart';
import 'package:reem/features/profile/presentation/widgets/profile_recently_viewed.dart';
import 'package:reem/features/profile/presentation/widgets/profile_referral_card.dart';
import 'package:reem/features/profile/presentation/widgets/profile_stats.dart';
import 'package:reem/features/profile/presentation/widgets/profile_wishlist_preview.dart';
import 'package:reem/features/seller_dashboard/presentation/screens/seller_profile_screen.dart';
import 'package:reem/features/user_profile/presentation/providers/user_profile_providers.dart';
import 'package:reem/features/user_profile/presentation/widgets/my_page_card.dart';
import 'package:reem/features/value/presentation/widgets/value_standing_card.dart';

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
      ref.read(userProfileNotifierProvider(null).notifier).refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider.select((s) => s.user));

    if (user == null) {
      return ReemScrollPage(
        slivers: [
          PremiumAppBar(title: context.l10n.profile),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _GuestProfileExperience(),
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
        const _Gap(DsSpacing.md),

        // «صفحتي»: her page as others see it, the switch that opens it, and
        // the way to publish. None of the three was reachable from here.
        _box(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            child: MyPageCard(),
          ),
        ),
        const _Gap(_gap),

        // Reem Value sits above the loyalty dashboard, because standing is what
        // she is on this platform and the points card below is what she is owed
        // by it. The order is the argument.
        _box(const ValueStandingCard()),
        const _Gap(_gap),

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

class _GuestProfileExperience extends StatelessWidget {
  const _GuestProfileExperience();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: DsSpacing.screenPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.person_outline_rounded, size: 58, color: c.primary),
          const SizedBox(height: DsSpacing.xl),
          Text(
            context.l10n.guestProfile,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: DsTypography.bold),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            context.l10n.guestBrowseBlurb,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.xl),
          SurfaceCard(
            child: Column(
              children: [
                _GuestBenefit(
                  icon: Icons.favorite_border_rounded,
                  title: context.l10n.saveYourProgress,
                  message:
                      context.l10n.savedProgressBlurb,
                ),
                SizedBox(height: DsSpacing.md),
                _GuestBenefit(
                  icon: Icons.auto_awesome_rounded,
                  title: context.l10n.personalRecommendations,
                  message:
                      context.l10n.personalRecommendationsBlurb,
                ),
                SizedBox(height: DsSpacing.md),
                _GuestBenefit(
                  icon: Icons.verified_user_outlined,
                  title: context.l10n.secureAccountControls,
                  message:
                      context.l10n.manageSecurityBlurb,
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.xl),
          PrimaryButton(
            label: context.l10n.signIn,
            icon: Icons.login_rounded,
            onPressed: () => context.push(RoutePaths.login),
          ),
          const SizedBox(height: DsSpacing.sm),
          SecondaryButton(
            label: context.l10n.createAccount,
            icon: Icons.person_add_alt_rounded,
            onPressed: () => context.push(RoutePaths.register),
          ),
        ],
      ),
    );
  }
}

class _GuestBenefit extends StatelessWidget {
  const _GuestBenefit({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: c.primary, size: 22),
        const SizedBox(width: DsSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.dsText.tileTitle.copyWith(
                  fontWeight: DsTypography.semiBold,
                ),
              ),
              DsGaps.vXxxs,
              Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
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
            style: context.dsText.tileTitle.displayFamily.bold.tint(c.onSurfaceVariant).copyWith(letterSpacing: 2),
          ),
          DsGaps.vXxxs,
          Text(
            context.l10n.appVersion('1.0.0'),
            style: context.dsText.caption.tint(c.onSurfaceVariant),
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
