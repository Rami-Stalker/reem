import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/referral.dart';
import '../providers/profile_overview_provider.dart';

/// The referral programme — share code, invited count and points earned, with
/// copy + share affordances.
class ProfileReferralCard extends ConsumerWidget {
  const ProfileReferralCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.isInitialLoading),
    );
    final referral = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.overview?.referral),
    );

    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 150, borderRadius: DsRadius.xxl)),
      );
    }
    if (referral == null) return const SizedBox.shrink();

    final c = context.dsColors;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: DsGradients.champagne,
                    borderRadius: DsRadius.borderLg,
                  ),
                  child: const Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invite friends, earn rewards',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: DsTypography.bold)),
                      const SizedBox(height: 2),
                      Text(referral.rewardHint,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            Row(
              children: [
                Expanded(child: _CodeBox(code: referral.code)),
                const SizedBox(width: DsSpacing.sm),
                DsButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  size: DsButtonSize.md,
                  variant: DsButtonVariant.accent,
                  isExpanded: false,
                  onPressed: () => _share(context, referral),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            Row(
              children: [
                _Stat(value: '${referral.invited}', label: 'Friends invited'),
                Container(
                    width: 1, height: 28, color: c.divider),
                _Stat(value: '${referral.earnedPoints}', label: 'Points earned'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _share(BuildContext context, Referral referral) {
    Clipboard.setData(ClipboardData(text: referral.code));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Invite code ${referral.code} copied — share it!'),
        ),
      );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Code copied to clipboard'),
            ),
          );
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: DsRadius.borderLg,
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontWeight: DsTypography.bold,
                  letterSpacing: 1,
                  color: c.onSurface,
                ),
              ),
            ),
            Icon(Icons.copy_rounded, size: 18, color: c.primary),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: DsTypography.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}
