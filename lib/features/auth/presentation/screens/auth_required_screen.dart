import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_motion.dart';

class AuthRequiredScreen extends StatelessWidget {
  const AuthRequiredScreen({super.key, this.from});

  final String? from;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AuthStage(
      showBack: true,
      children: [
        const Spacer(),
        const AuthEmblem(icon: Icons.lock_person_rounded)
            .animate()
            .fadeIn(duration: 500.ms)
            .scale(
              begin: const Offset(0.85, 0.85),
              duration: 800.ms,
              curve: DsMotion.softSpring,
            ),
        AuthHeading(
          eyebrow: l10n.signInRequired,
          title: l10n.signInToContinue,
          subtitle: l10n.signUpBenefitsBlurb,
        ).authEnter(1),
        DsGaps.vXl,
        AuthPanel(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.xl,
            vertical: DsSpacing.lg,
          ),
          child: Column(
            children: [
              _Benefit(
                icon: Icons.shopping_bag_rounded,
                text: l10n.authBenefitCheckout,
              ),
              _Benefit(
                icon: Icons.chat_bubble_rounded,
                text: l10n.authBenefitChat,
              ),
              _Benefit(
                icon: Icons.favorite_rounded,
                text: l10n.authBenefitSaved,
              ),
            ],
          ),
        ).authEnter(2),
        DsGaps.vXl,
        PrimaryButton(
          label: l10n.signIn,
          icon: Icons.login_rounded,
          onPressed: () => context.push(_withFrom(RoutePaths.login)),
        ).authEnter(3),
        DsGaps.vSm,
        SecondaryButton(
          label: l10n.createAccount,
          icon: Icons.person_add_alt_rounded,
          onPressed: () => context.push(_withFrom(RoutePaths.register)),
        ).authEnter(4),
        DsGaps.vXs,
        Center(
          child: GhostButton(
            label: l10n.keepBrowsing,
            onPressed: () => context.go(RoutePaths.home),
          ),
        ).authEnter(5),
        const Spacer(flex: 2),
        DsGaps.vLg,
      ],
    );
  }

  String _withFrom(String path) {
    if (from == null || from!.isEmpty) return path;
    return '$path?from=${Uri.encodeComponent(from!)}';
  }
}

/// One thing an account unlocks: a blush medallion and a line.
class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
      child: Row(
        children: [
          Container(
            width: DsSizes.avatarSm,
            height: DsSizes.avatarSm,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primaryContainer, colors.secondaryContainer],
              ),
            ),
            child: Icon(icon, size: DsSizes.iconXs, color: colors.primary),
          ),
          DsGaps.hSm,
          Expanded(child: Text(text, style: context.dsText.bodyStrong)),
          Icon(
            Icons.check_rounded,
            size: DsSizes.iconXs,
            color: colors.success,
          ),
        ],
      ),
    );
  }
}
