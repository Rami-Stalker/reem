import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/router/route_paths.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/settings_category_card.dart';
import '../widgets/settings_profile_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final auth = ref.watch(authNotifierProvider);
    final isSignedIn = auth.isAuthenticated;
    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: l10n.settings),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg, DsSpacing.sm, DsSpacing.lg, 140,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SettingsProfileHeader(),
              const SizedBox(height: DsSpacing.xl),
              SettingsCategoryCard(
                title: l10n.account,
                items: [
                  SettingsItemData(
                    icon: Icons.person_outline,
                    title: 'Account settings',
                    onTap: () => isSignedIn
                        ? context.pushNamed(RouteNames.accountSettings)
                        : context.go(RoutePaths.login),
                  ),
                  SettingsItemData(
                    icon: Icons.security_outlined,
                    title: 'Security',
                    onTap: () => isSignedIn
                        ? context.pushNamed(RouteNames.securitySettings)
                        : context.go(RoutePaths.login),
                  ),
                  SettingsItemData(
                    icon: Icons.devices_outlined,
                    title: 'Devices',
                    onTap: () => isSignedIn
                        ? context.pushNamed(RouteNames.deviceManagement)
                        : context.go(RoutePaths.login),
                  ),
                  SettingsItemData(
                    icon: Icons.storefront_outlined,
                    title: 'Seller verification',
                    onTap: () => isSignedIn
                        ? context.pushNamed(RouteNames.sellerVerification)
                        : context.go(RoutePaths.login),
                  ),
                  SettingsItemData(
                    icon: Icons.badge_outlined,
                    title: l10n.editProfile,
                    onTap: () => isSignedIn
                        ? context.pushNamed(RouteNames.editProfile)
                        : context.go(RoutePaths.login),
                  ),
                  SettingsItemData(
                    icon: Icons.favorite_border,
                    title: l10n.wishlist,
                    onTap: () => context.go(RoutePaths.favorites),
                  ),
                  SettingsItemData(
                    icon: Icons.shopping_bag_outlined,
                    title: l10n.orders,
                    onTap: () => context.pushNamed(RouteNames.orders),
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.lg),
              SettingsCategoryCard(
                title: l10n.rewardsAndOffers,
                items: [
                  SettingsItemData(
                    icon: Icons.stars_rounded,
                    title: l10n.rewards,
                    onTap: () => context.pushNamed(RouteNames.rewards),
                  ),
                  SettingsItemData(
                    icon: Icons.local_offer_outlined,
                    title: l10n.coupons,
                    onTap: () => context.pushNamed(RouteNames.coupons),
                  ),
                  SettingsItemData(
                    icon: Icons.notifications_none,
                    title: l10n.notifications,
                    onTap: () => context.pushNamed(RouteNames.notifications),
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.lg),
              SettingsCategoryCard(
                title: l10n.preferences,
                items: [
                  SettingsItemData(
                    icon: Icons.palette_outlined,
                    title: l10n.appearance,
                    onTap: () => context.pushNamed(RouteNames.appearance),
                  ),
                  SettingsItemData(
                    icon: Icons.language_rounded,
                    title: l10n.language,
                    onTap: () => context.pushNamed(RouteNames.language),
                  ),
                  SettingsItemData(
                    icon: Icons.location_on_outlined,
                    title: l10n.addresses,
                    onTap: () => context.pushNamed(RouteNames.addresses),
                  ),
                  SettingsItemData(
                    icon: Icons.credit_card_outlined,
                    title: l10n.paymentMethods,
                    onTap: () => context.pushNamed(RouteNames.paymentMethods),
                  ),
                  SettingsItemData(
                    icon: Icons.admin_panel_settings_outlined,
                    title: l10n.adminPanel,
                    onTap: auth.user?.isAdmin == true
                        ? () => context.pushNamed(RouteNames.adminDashboard)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.lg),
              SettingsCategoryCard(
                title: l10n.support,
                items: [
                  SettingsItemData(
                    icon: Icons.help_outline,
                    title: l10n.helpCenter,
                    onTap: () {},
                  ),
                  SettingsItemData(
                    icon: Icons.logout,
                    title: isSignedIn ? l10n.signOut : l10n.signIn,
                    onTap: () async {
                      if (isSignedIn) {
                        await ref.read(authNotifierProvider.notifier).logout();
                        if (context.mounted) {
                          context.go(RoutePaths.login);
                        }
                      } else {
                        context.go(RoutePaths.login);
                      }
                    },
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
