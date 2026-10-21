import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/features/profile/domain/entities/referral.dart';
import 'package:reem/features/profile/presentation/providers/profile_overview_provider.dart';

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
                      color: DsColors.onMedia, size: 22),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.inviteFriends,
                          style: context.dsText.tileTitle
                              .copyWith(fontWeight: DsTypography.bold)),
                      DsGaps.vXxxs,
                      Text(referral.rewardHint,
                          style: context.dsText.cardSubtitle
                              .copyWith(color: c.onSurfaceVariant)),
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
                  label: context.l10n.a11yShare,
                  icon: Icons.ios_share_rounded,
                  size: DsButtonSize.md,
                  variant: DsButtonVariant.accent,
                  isExpanded: false,
                  onPressed: () => unawaited(_share(context, referral)),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            Row(
              children: [
                _Stat(value: '${referral.invited}', label: context.l10n.friendsInvited),
                Container(
                    width: 1, height: 28, color: c.divider),
                _Stat(value: '${referral.earnedPoints}', label: context.l10n.pointsEarned),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the share sheet with her invite, rather than quietly copying it.
  ///
  /// The button said «مشاركة», carried the share glyph, and put the code on
  /// the clipboard — so the invite went nowhere unless she then found
  /// somewhere to paste it herself. It goes through `ShareService` now, like
  /// every other share in the app, and the code is still copied so a paste
  /// works too.
  Future<void> _share(BuildContext context, Referral referral) async {
    await Clipboard.setData(ClipboardData(text: referral.code));
    if (!context.mounted) return;
    await ShareService.referral(
      context: context,
      code: referral.code,
      hint: referral.rewardHint,
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
        DsSnackbar.show(
          context,
          message: context.l10n.codeCopied,
          type: DsSnackbarType.success,
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
                style: context.dsText.body.bold.tint(c.onSurface).copyWith(letterSpacing: 1),
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
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: context.dsText.cardTitle
                  .copyWith(fontWeight: DsTypography.bold)),
          DsGaps.vXxxs,
          Text(label,
              style: context.dsText.caption
                  .copyWith(color: c.onSurfaceVariant)),
        ],
      ),
    );
  }
}
