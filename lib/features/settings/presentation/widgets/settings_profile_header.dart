import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/shared/wedgets/app/app_avatar.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/design_system/design_system.dart';

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
          AppAvatar(radius: 58).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: DsSpacing.md),
          DsGradientText(
            user?.name ?? (auth.isGuest ? 'Guest shopper' : 'Reem'),
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: 28,
              fontWeight: DsTypography.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? user?.phone ?? 'Browsing without an account',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
