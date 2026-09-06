import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';

class SettingsProfileHeader extends ConsumerWidget {
  const SettingsProfileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final auth = ref.watch(authNotifierProvider);
    final user = auth.user;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.huge, bottom: DsSpacing.lg),
      child: Column(
        children: [
          AppAvatar(radius: 58, imageUrl: user?.imageUrl, name: user?.name)
              .animate()
              .scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: DsSpacing.md),
          DsGradientText(
            user?.name ?? context.l10n.guestShopper,
            style: context.dsText.pageTitle.bold,
          ),
          DsGaps.vXxs,
          Text(
            // Her phone is the identity she signed up with, so it comes first;
            // an email is optional and often absent.
            user?.phone ?? user?.email ?? context.l10n.browsingWithoutAccount,
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
