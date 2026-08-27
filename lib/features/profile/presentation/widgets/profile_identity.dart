import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/entities/user.dart';

/// Identity block beneath the cover: name + verification, @username, phone and
/// the primary edit / share / settings actions.
class ProfileIdentity extends StatelessWidget {
  const ProfileIdentity({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(DsSpacing.lg, DsSpacing.md, DsSpacing.lg, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: DsGradientText(
                  user.name,
                  style: (theme.textTheme.headlineMedium ?? const TextStyle())
                      .copyWith(fontWeight: DsTypography.bold),
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: DsSpacing.xs),
                Icon(Icons.verified_rounded, color: c.secondary, size: 22),
              ],
            ],
          ),
          const SizedBox(height: DsSpacing.xxs),
          Text('@${user.username}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: DsSpacing.xs),
          // Verification + phone chips.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: DsSpacing.xs,
            runSpacing: DsSpacing.xs,
            children: [
              _Pill(
                icon: user.isVerified
                    ? Icons.verified_user_rounded
                    : Icons.gpp_maybe_outlined,
                label: user.isVerified ? context.l10n.verified : context.l10n.unverified,
                tone: user.isVerified ? c.success : c.warning,
              ),
              if (user.phone.isNotEmpty)
                _Pill(icon: Icons.phone_iphone_rounded, label: user.phone),
              if (user.location != null && user.location!.isNotEmpty)
                _Pill(icon: Icons.location_on_outlined, label: user.location!),
            ],
          ),
          const SizedBox(height: DsSpacing.lg),
          Row(
            children: [
              Expanded(
                child: DsButton(
                  label: context.l10n.editProfile,
                  icon: Icons.edit_outlined,
                  variant: DsButtonVariant.tonal,
                  size: DsButtonSize.md,
                  onPressed: () => context.push(RoutePaths.editProfile),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              DsIconButton(
                icon: Icons.ios_share_rounded,
                variant: DsIconButtonVariant.surface,
                onPressed: () {},
              ),
              const SizedBox(width: DsSpacing.xs),
              DsIconButton(
                icon: Icons.settings_outlined,
                variant: DsIconButtonVariant.surface,
                onPressed: () => context.push(RoutePaths.settings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.tone});

  final IconData icon;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final color = tone ?? c.onSurfaceVariant;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: 5),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: DsRadius.borderFull,
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: DsSpacing.xxs),
          Text(
            label,
            style: TextStyle(
              fontSize: DsTypography.labelSmall,
              fontWeight: DsTypography.semiBold,
              color: c.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
