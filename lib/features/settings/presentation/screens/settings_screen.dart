import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_names.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:reem/features/settings/presentation/widgets/help_sheet.dart';
import 'package:reem/features/settings/presentation/widgets/settings_category_card.dart';
import 'package:reem/features/settings/presentation/widgets/settings_profile_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final auth = ref.watch(authNotifierProvider);
    final isSignedIn = auth.isAuthenticated;
    Future<void> protectedPush(String route, String title) async {
      final ok = await requireAuthenticatedUser(
        context,
        ref,
        title: title,
        message: l10n.signInToManageSecurely,
        from: route,
      );
      if (ok && context.mounted) {
        unawaited(context.push(route));
      }
    }

    Future<void> protectedPushNamed(
      String name,
      String path,
      String title,
    ) async {
      final ok = await requireAuthenticatedUser(
        context,
        ref,
        title: title,
        message: l10n.signInToManageSecurely,
        from: path,
      );
      if (ok && context.mounted) {
        unawaited(context.pushNamed(name));
      }
    }

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: l10n.settings),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.sm,
            DsSpacing.lg,
            140,
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
                    title: l10n.accountSettings,
                    onTap: () => protectedPushNamed(
                      RouteNames.accountSettings,
                      RoutePaths.accountSettings,
                      l10n.signInToInteract,
                    ),
                  ),
                  SettingsItemData(
                    icon: Icons.security_outlined,
                    title: l10n.securityTitle,
                    onTap: () => protectedPushNamed(
                      RouteNames.securitySettings,
                      RoutePaths.securitySettings,
                      l10n.signInToInteract,
                    ),
                  ),
                  SettingsItemData(
                    icon: Icons.devices_outlined,
                    title: l10n.devices,
                    onTap: () => protectedPushNamed(
                      RouteNames.deviceManagement,
                      RoutePaths.deviceManagement,
                      l10n.signInToInteract,
                    ),
                  ),
                  SettingsItemData(
                    icon: Icons.storefront_outlined,
                    title: l10n.sellerVerification,
                    onTap: () => protectedPushNamed(
                      RouteNames.sellerVerification,
                      RoutePaths.sellerVerification,
                      l10n.signInToInteract,
                    ),
                  ),
                  SettingsItemData(
                    icon: Icons.badge_outlined,
                    title: l10n.editProfile,
                    onTap: () => protectedPushNamed(
                      RouteNames.editProfile,
                      RoutePaths.editProfile,
                      l10n.signInToInteract,
                    ),
                  ),
                  SettingsItemData(
                    icon: Icons.favorite_border,
                    title: l10n.wishlist,
                    onTap: () => context.go(RoutePaths.favorites),
                  ),
                  SettingsItemData(
                    icon: Icons.shopping_bag_outlined,
                    title: l10n.orders,
                    onTap: () => protectedPushNamed(
                      RouteNames.orders,
                      RoutePaths.orders,
                      l10n.signInToInteract,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.lg),
              SettingsCategoryCard(
                title: l10n.rewardsAndOffers,
                items: [
                  // Account balances, so they ask the same way every other
                  // account row on this screen asks — a sheet where she is,
                  // rather than a redirect after the tap has already failed.
                  SettingsItemData(
                    icon: Icons.stars_rounded,
                    title: l10n.rewards,
                    onTap: () => protectedPushNamed(
                      RouteNames.rewards,
                      RoutePaths.rewards,
                      l10n.rewards,
                    ),
                  ),
                  SettingsItemData(
                    icon: Icons.local_offer_outlined,
                    title: l10n.coupons,
                    onTap: () => protectedPushNamed(
                      RouteNames.coupons,
                      RoutePaths.coupons,
                      l10n.coupons,
                    ),
                  ),
                  SettingsItemData(
                    icon: Icons.notifications_none,
                    title: l10n.notifications,
                    onTap: () => protectedPushNamed(
                      RouteNames.notificationPreferences,
                      RoutePaths.notificationPreferences,
                      l10n.notifications,
                    ),
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
                    onTap: () => protectedPush(
                      RoutePaths.addresses,
                      l10n.signInToInteract,
                    ),
                  ),
                  SettingsItemData(
                    icon: Icons.credit_card_outlined,
                    title: l10n.paymentMethods,
                    onTap: () => protectedPush(
                      RoutePaths.paymentMethods,
                      l10n.signInToInteract,
                    ),
                  ),
                  SettingsItemData(
                    icon: Icons.admin_panel_settings_outlined,
                    title: l10n.adminPanel,
                    onTap: auth.user?.isAdmin == true
                        ? () => context.pushNamed(RouteNames.adminDashboard)
                        : null,
                  ),
                  // A rider's own round. The only door to it used to be inside
                  // the seller menu, so a courier — an ordinary account with a
                  // `Courier` row, never a seller — could not reach the screen
                  // built for her at all.
                  if (auth.user?.isCourier == true)
                    SettingsItemData(
                      icon: Icons.delivery_dining_outlined,
                      title: l10n.courierDay,
                      onTap: () => context.push(RoutePaths.courierDay),
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
                    onTap: () => showHelpSheet(context),
                  ),
                  // Not behind `protectedPush`: the terms are readable without
                  // an account, on the server and here. Asking a woman to sign
                  // in to read what she agreed to would be the opposite of the
                  // point.
                  SettingsItemData(
                    icon: Icons.policy_outlined,
                    title: l10n.policiesTitle,
                    onTap: () => context.push(RoutePaths.policies),
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
