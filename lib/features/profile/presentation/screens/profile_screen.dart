import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/experience/role_experience.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:ohara/features/experience/presentation/screens/experience_surface_screen.dart';
import 'package:ohara/features/highlights/presentation/widgets/highlights_rail.dart';
import 'package:ohara/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:ohara/features/profile/presentation/providers/profile_provider.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_achievements.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_completion_card.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_followed_stores.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_header.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_loyalty_dashboard.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_menu.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_orders_overview.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_recently_viewed.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_referral_card.dart';
import 'package:ohara/features/profile/presentation/widgets/profile_wishlist_preview.dart';
import 'package:ohara/features/seller_dashboard/presentation/screens/seller_profile_screen.dart';
import 'package:ohara/features/user_profile/presentation/providers/user_profile_providers.dart';
import 'package:ohara/features/user_profile/presentation/widgets/my_page_card.dart';
import 'package:ohara/features/value/presentation/widgets/value_standing_card.dart';

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

    if (user == null) return const _GuestProfileExperience();

    final savedCount = ref.watch(
      favoritesNotifierProvider.select((s) => s.favorites.length),
    );

    return OharaScrollPage(
      onRefresh: _refresh,
      slivers: [
        SliverToBoxAdapter(
          child: ProfileHeader(user: user, savedCount: savedCount),
        ),
        const _Gap(DsSpacing.xl),

        _box(const ProfileCompletionCard()),
        const _Gap(DsSpacing.lg),

        // «الأبرز» — her own rail, with the invitation to start one. Above
        // «صفحتي» on purpose: what she keeps is the first thing another woman
        // sees on her page, so it should be the first thing she manages.
        const SliverToBoxAdapter(child: HighlightsRail()),
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

        // Ohara Value sits above the loyalty dashboard, because standing is what
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
        DsGaps.sliverBottomSafe,
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

/// Her profile before she has one: the same stage as the way in, saying what
/// an account keeps for her and offering the two doors.
class _GuestProfileExperience extends StatelessWidget {
  const _GuestProfileExperience();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AuthStage(
      children: [
        const Spacer(),
        const AuthEmblem(icon: Icons.person_rounded),
        AuthHeading(title: l10n.guestProfile, subtitle: l10n.guestBrowseBlurb),
        DsGaps.vXl,
        AuthPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.xl,
            vertical: DsSpacing.lg,
          ),
          child: Column(
            children: [
              _GuestBenefit(
                icon: Icons.favorite_rounded,
                title: l10n.saveYourProgress,
                message: l10n.savedProgressBlurb,
              ),
              DsGaps.vMd,
              _GuestBenefit(
                icon: Icons.auto_awesome_rounded,
                title: l10n.personalRecommendations,
                message: l10n.personalRecommendationsBlurb,
              ),
              DsGaps.vMd,
              _GuestBenefit(
                icon: Icons.verified_user_rounded,
                title: l10n.secureAccountControls,
                message: l10n.manageSecurityBlurb,
              ),
            ],
          ),
        ),
        DsGaps.vXl,
        PrimaryButton(
          label: l10n.signIn,
          icon: Icons.login_rounded,
          onPressed: () => context.push(RoutePaths.login),
        ),
        DsGaps.vSm,
        SecondaryButton(
          label: l10n.createAccount,
          icon: Icons.person_add_alt_rounded,
          onPressed: () => context.push(RoutePaths.register),
        ),
        const Spacer(flex: 2),
        // Room for the floating tab bar, which sits over the foot of a tab.
        SizedBox(
          height: MediaQuery.paddingOf(context).bottom + DsSpacing.massive,
        ),
      ],
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
        Container(
          width: DsSizes.avatarSm,
          height: DsSizes.avatarSm,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.primaryContainer, c.secondaryContainer],
            ),
          ),
          child: Icon(icon, size: DsSizes.iconXs, color: c.primary),
        ),
        DsGaps.hSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.dsText.bodyStrong),
              DsGaps.vXxxs,
              Text(message, style: context.dsText.caption),
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
            style: context.dsText.tileTitle.displayFamily.bold
                .tint(c.onSurfaceVariant)
                .copyWith(letterSpacing: 2),
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
