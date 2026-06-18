import 'package:flutter/material.dart';

import '../../foundation/motion/animations/fade_animations.dart';
import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/tokens/ds_radius.dart';
import '../../foundation/tokens/ds_spacing.dart';
import '../../foundation/tokens/ds_typography.dart';
import '../buttons/button_styles.dart';
import '../buttons/ds_button.dart';

/// A graceful empty state — soft icon medallion, friendly copy and an optional
/// call to action. Use the named constructors for common scenarios.
class DsEmptyState extends StatelessWidget {
  const DsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
  });

  /// Empty shopping bag / cart.
  const DsEmptyState.cart({
    super.key,
    this.title = 'Your bag is empty',
    this.message = 'Discover beautiful pieces made just for you.',
    this.actionLabel = 'Start shopping',
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
  }) : icon = Icons.shopping_bag_outlined;

  /// No favorites yet.
  const DsEmptyState.favorites({
    super.key,
    this.title = 'No favorites yet',
    this.message = 'Tap the heart on anything you love to save it here.',
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
  }) : icon = Icons.favorite_border_rounded;

  /// Empty search results.
  const DsEmptyState.search({
    super.key,
    this.title = 'No results found',
    this.message = 'Try a different search or adjust your filters.',
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
  }) : icon = Icons.search_off_rounded;

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Optional custom illustration shown instead of the icon medallion.
  final Widget? illustration;

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
              illustration ??
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: c.primaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(DsRadius.xxxl),
                    ),
                    child: Icon(icon, size: 48, color: c.primary),
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
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: DsSpacing.xl),
                DsButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  isExpanded: false,
                ),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: DsSpacing.xs),
                DsButton(
                  label: secondaryActionLabel!,
                  variant: DsButtonVariant.ghost,
                  onPressed: onSecondaryAction,
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
