import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/app/bootstrap.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_names.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:ohara/features/settings/presentation/widgets/help_sheet.dart';
import 'package:ohara/features/settings/presentation/widgets/settings_category_card.dart';

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

    final user = auth.user;
    final locale = AppBootstrap.localeController;
    final theme = AppBootstrap.themeController;
    final gutter = vanityGutter(context);

    return ListenableBuilder(
      listenable: Listenable.merge([locale, theme]),
      builder: (context, _) => OharaScrollPage(
        slivers: [
          // Her mirror: the page that is about her shows her in the glass.
          VanityAppBar(
            title: user?.name ?? l10n.guestShopper,
            // Her phone is the identity she signed up with, so it comes first;
            // an email is optional and often absent.
            // The isolates keep «+963…» reading left to right inside Arabic.
            subtitle: user?.phone != null
                ? '\u2066${user!.phone}\u2069'
                : user?.email ?? l10n.browsingWithoutAccount,
            collapsedTitle: l10n.settings,
            reflection: Center(
              child: AppAvatar(
                radius: 36,
                imageUrl: user?.imageUrl,
                name: user?.name,
                heroTag: null,
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(gutter, DsSpacing.xl, gutter, 140),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // The drawers: the four places she opens most. Rewards and
                // coupons are account balances, so they ask the same way every
                // other account row on this screen asks — a sheet where she
                // is, rather than a redirect after the tap has already failed.
                VanityDrawers(
                  items: [
                    VanityDrawerItem(
                      icon: Icons.shopping_bag_outlined,
                      label: l10n.orders,
                      onTap: () => protectedPushNamed(
                        RouteNames.orders,
                        RoutePaths.orders,
                        l10n.signInToInteract,
                      ),
                    ),
                    VanityDrawerItem(
                      icon: Icons.favorite_border,
                      label: l10n.wishlist,
                      onTap: () => context.push(RoutePaths.favorites),
                    ),
                    VanityDrawerItem(
                      icon: Icons.stars_rounded,
                      label: l10n.rewards,
                      onTap: () => protectedPushNamed(
                        RouteNames.rewards,
                        RoutePaths.rewards,
                        l10n.rewards,
                      ),
                    ),
                    VanityDrawerItem(
                      icon: Icons.local_offer_outlined,
                      label: l10n.coupons,
                      onTap: () => protectedPushNamed(
                        RouteNames.coupons,
                        RoutePaths.coupons,
                        l10n.coupons,
                      ),
                    ),
                  ],
                ),
                DsGaps.vXxl,
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
                    // «توثيق الحساب» — the badge beside her name. Above the
                    // seller application on purpose: it is the one every account
                    // can ask for, and the two are different questions.
                    SettingsItemData(
                      icon: Icons.verified_user_outlined,
                      title: l10n.accountVerification,
                      onTap: () => protectedPushNamed(
                        RouteNames.accountVerification,
                        RoutePaths.accountVerification,
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
                  ],
                ),
                DsGaps.vXl,
                SettingsCategoryCard(
                  title: l10n.preferences,
                  items: [
                    SettingsItemData(
                      icon: Icons.notifications_none,
                      title: l10n.notifications,
                      onTap: () => protectedPushNamed(
                        RouteNames.notificationPreferences,
                        RoutePaths.notificationPreferences,
                        l10n.notifications,
                      ),
                    ),
                    SettingsItemData(
                      icon: Icons.palette_outlined,
                      title: l10n.appearance,
                      value: switch (theme.mode) {
                        DsAppThemeMode.light => l10n.themeLight,
                        DsAppThemeMode.dark => l10n.themeDark,
                        DsAppThemeMode.system => l10n.themeSystem,
                      },
                      onTap: () => context.pushNamed(RouteNames.appearance),
                    ),
                    SettingsItemData(
                      icon: Icons.language_rounded,
                      title: l10n.language,
                      value: locale.followsSystem
                          ? l10n.systemLanguage
                          : locale.isArabic
                          ? l10n.ar
                          : l10n.en,
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
                DsGaps.vXl,
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
                      color: isSignedIn ? context.boutique.critical : null,
                      onTap: () async {
                        if (isSignedIn) {
                          await ref
                              .read(authNotifierProvider.notifier)
                              .logout();
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
      ),
    );
  }
}
