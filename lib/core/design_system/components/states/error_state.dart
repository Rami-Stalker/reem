import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/buttons/button_sizes.dart';
import 'package:reem/core/design_system/components/buttons/button_styles.dart';
import 'package:reem/core/design_system/components/buttons/ds_button.dart';
import 'package:reem/core/design_system/foundation/motion/animations/fade_animations.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/localization/readable_message.dart';

/// A reassuring error state with a retry affordance.
///
/// Copy is nullable and resolved from the locale in [build] — a `const`
/// default cannot reach `context.l10n`, so the previous English defaults were
/// unlocalisable.
class DsErrorState extends StatelessWidget {
  const DsErrorState({
    super.key,
    this.title,
    this.message,
    this.icon = Icons.sentiment_dissatisfied_rounded,
    this.retryLabel,
    this.onRetry,
  }) : isOffline = false;

  /// Offline / no-connection variant.
  const DsErrorState.offline({
    super.key,
    this.title,
    this.message,
    this.icon = Icons.wifi_off_rounded,
    this.retryLabel,
    this.onRetry,
  }) : isOffline = true;

  final String? title;
  final String? message;
  final IconData icon;
  final String? retryLabel;
  final bool isOffline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resolvedTitle =
        title ?? (isOffline ? l10n.noConnection : l10n.error);
    final resolvedRetry = retryLabel ?? l10n.retry;

    final c = context.dsColors;
    final theme = Theme.of(context);

    return Center(
      child: DsFadeAnimations.fadeIn(
        child: Padding(
          padding: const EdgeInsets.all(DsSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: c.errorContainer,
                  borderRadius: BorderRadius.circular(DsRadius.xxxl),
                ),
                child: Icon(icon, size: 44, color: c.error),
              ),
              const SizedBox(height: DsSpacing.lg),
              Text(
                resolvedTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: DsTypography.bold),
              ),
              if (message != null) ...[
                const SizedBox(height: DsSpacing.xs),
                Text(
                  readableMessage(l10n, message!),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: c.onSurfaceVariant),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: DsSpacing.xl),
                DsButton(
                  label: resolvedRetry,
                  icon: Icons.refresh_rounded,
                  variant: DsButtonVariant.secondary,
                  onPressed: onRetry,
                  isExpanded: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact inline error row (e.g. below a failed section, in a list).
class DsInlineError extends StatelessWidget {
  const DsInlineError({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.sm),
      decoration: BoxDecoration(
        color: c.errorContainer,
        borderRadius: DsRadius.borderMd,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: c.error, size: 20),
          const SizedBox(width: DsSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c.onSurface),
            ),
          ),
          if (onRetry != null)
            DsButton(
              label: context.l10n.retry,
              variant: DsButtonVariant.ghost,
              size: DsButtonSize.sm,
              onPressed: onRetry,
              isExpanded: false,
            ),
        ],
      ),
    );
  }
}
