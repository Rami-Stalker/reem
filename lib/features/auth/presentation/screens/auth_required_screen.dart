import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';

class AuthRequiredScreen extends StatelessWidget {
  const AuthRequiredScreen({super.key, this.from});

  final String? from;

  @override
  Widget build(BuildContext context) {
    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.signInRequired, showBack: true),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: DsSpacing.screenPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_person_rounded,
                  size: 56,
                  color: context.dsColors.primary,
                ),
                const SizedBox(height: DsSpacing.xl),
                Text(
                  context.l10n.signInToContinue,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: DsTypography.bold,
                  ),
                ),
                const SizedBox(height: DsSpacing.sm),
                Text(
                  'Create a secure account to checkout, message sellers, save your progress, and manage your profile across devices.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.dsColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: DsSpacing.xl),
                PrimaryButton(
                  label: context.l10n.signIn,
                  icon: Icons.login_rounded,
                  onPressed: () => context.push(_withFrom(RoutePaths.login)),
                ),
                const SizedBox(height: DsSpacing.sm),
                SecondaryButton(
                  label: context.l10n.createAccount,
                  icon: Icons.person_add_alt_rounded,
                  onPressed: () => context.push(_withFrom(RoutePaths.register)),
                ),
                const SizedBox(height: DsSpacing.sm),
                GhostButton(
                  label: context.l10n.keepBrowsing,
                  onPressed: () => context.go(RoutePaths.home),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _withFrom(String path) {
    if (from == null || from!.isEmpty) return path;
    return '$path?from=${Uri.encodeComponent(from!)}';
  }
}
