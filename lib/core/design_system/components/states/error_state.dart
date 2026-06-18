import 'package:flutter/material.dart';

import '../../foundation/motion/animations/fade_animations.dart';
import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/tokens/ds_radius.dart';
import '../../foundation/tokens/ds_spacing.dart';
import '../../foundation/tokens/ds_typography.dart';
import '../buttons/button_sizes.dart';
import '../buttons/button_styles.dart';
import '../buttons/ds_button.dart';

/// A reassuring error state with a retry affordance.
class DsErrorState extends StatelessWidget {
  const DsErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'We couldn\'t load this right now. Please try again.',
    this.icon = Icons.sentiment_dissatisfied_rounded,
    this.retryLabel = 'Try again',
    this.onRetry,
  });

  /// Offline / no-connection variant.
  const DsErrorState.offline({
    super.key,
    this.title = 'No connection',
    this.message = 'Check your internet connection and try again.',
    this.icon = Icons.wifi_off_rounded,
    this.retryLabel = 'Retry',
    this.onRetry,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
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
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: DsTypography.bold),
              ),
              if (message != null) ...[
                const SizedBox(height: DsSpacing.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: c.onSurfaceVariant),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: DsSpacing.xl),
                DsButton(
                  label: retryLabel,
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
              label: 'Retry',
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
