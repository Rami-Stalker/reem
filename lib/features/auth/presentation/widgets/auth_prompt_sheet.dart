import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';

Future<bool> requireAuthenticatedUser(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
  String? from,
}) async {
  if (ref.read(authNotifierProvider).isAuthenticated) return true;
  await showAuthPrompt(context, title: title, message: message, from: from);
  return false;
}

Future<void> showAuthPrompt(
  BuildContext context, {
  required String title,
  required String message,
  String? from,
}) {
  return DsBottomSheet.show<void>(
    context,
    builder: (sheetContext) => DsSheetScaffold(
      title: title,
      subtitle: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BenefitRow(
            icon: Icons.shopping_bag_outlined,
            title: context.l10n.checkoutSafely,
            subtitle: context.l10n.checkoutSafelyBlurb,
          ),
          _BenefitRow(
            icon: Icons.favorite_border_rounded,
            title: context.l10n.saveYourProgress,
            subtitle: context.l10n.syncBlurb,
          ),
          _BenefitRow(
            icon: Icons.devices_rounded,
            title: context.l10n.useEveryDevice,
            subtitle: context.l10n.useEveryDeviceBlurb,
          ),
          const SizedBox(height: DsSpacing.lg),
          PrimaryButton(
            label: context.l10n.signIn,
            icon: Icons.login_rounded,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              context.push(_withFrom(RoutePaths.login, from));
            },
          ),
          const SizedBox(height: DsSpacing.sm),
          SecondaryButton(
            label: context.l10n.createAccount,
            icon: Icons.person_add_alt_rounded,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              context.push(_withFrom(RoutePaths.register, from));
            },
          ),
        ],
      ),
    ),
  );
}

String _withFrom(String path, String? from) {
  if (from == null || from.isEmpty) return path;
  return '$path?from=${Uri.encodeComponent(from)}';
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(DsRadius.md),
            ),
            child: Icon(icon, color: c.primary, size: 21),
          ),
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
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
