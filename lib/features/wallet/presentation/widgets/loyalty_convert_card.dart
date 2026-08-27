import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../rewards/presentation/providers/rewards_hub_provider.dart';
import '../providers/wallet_provider.dart';

/// Q43 — turning loyalty points into spendable credit.
///
/// The rate is printed rather than hidden behind the button: «كل ١٠ نقاط =
/// ٥٬٠٠٠ ل.س». The stepper only offers multiples of ten, so the rule is
/// something she meets in the interface rather than in a rejected request.
class LoyaltyConvertCard extends ConsumerStatefulWidget {
  const LoyaltyConvertCard({super.key});

  @override
  ConsumerState<LoyaltyConvertCard> createState() => _LoyaltyConvertCardState();
}

class _LoyaltyConvertCardState extends ConsumerState<LoyaltyConvertCard> {
  int _points = WalletNotifier.pointsStep;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;

    // The rewards hub is where the app already keeps her points balance.
    final available = ref.watch(
      rewardsHubNotifierProvider.select((s) => s.hub?.points ?? 0),
    );
    final isConverting = ref.watch(
      walletNotifierProvider.select((s) => s.isConverting),
    );

    // Nothing to offer until she has at least one full conversion's worth.
    if (available < WalletNotifier.pointsStep) {
      return const SizedBox.shrink();
    }

    final maxConvertible =
        (available ~/ WalletNotifier.pointsStep) * WalletNotifier.pointsStep;
    final selected = _points.clamp(WalletNotifier.pointsStep, maxConvertible);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: DsRadius.borderCard,
          border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: colors.accent),
                const SizedBox(width: DsSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.loyaltyPoints,
                    style: TextStyle(
                      fontFamily: DsTypography.fontFamily,
                      fontSize: DsTypography.titleSmall,
                      fontWeight: DsTypography.bold,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                Text(
                  l10n.loyaltyPointsCount(available),
                  style: TextStyle(
                    fontSize: DsTypography.labelMedium,
                    fontWeight: DsTypography.semiBold,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              l10n.loyaltyConvertHint,
              style: TextStyle(
                fontSize: DsTypography.labelSmall,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: DsSpacing.md),

            Row(
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  onTap: selected > WalletNotifier.pointsStep
                      ? () => setState(
                          () => _points = selected - WalletNotifier.pointsStep,
                        )
                      : null,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      l10n.loyaltyPointsCount(selected),
                      style: TextStyle(
                        fontFamily: DsTypography.fontFamily,
                        fontSize: DsTypography.bodyLarge,
                        fontWeight: DsTypography.bold,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  onTap: selected < maxConvertible
                      ? () => setState(
                          () => _points = selected + WalletNotifier.pointsStep,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),

            DsButton(
              label: l10n.loyaltyConvert,
              isLoading: isConverting,
              onPressed: () => ref
                  .read(walletNotifierProvider.notifier)
                  .convertPoints(selected),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DsRadius.full),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? colors.primaryContainer : colors.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? colors.onPrimaryContainer : colors.disabled,
          ),
        ),
      ),
    );
  }
}
