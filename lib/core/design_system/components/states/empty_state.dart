import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/buttons/button_styles.dart';
import 'package:reem/core/design_system/components/buttons/ds_button.dart';
import 'package:reem/core/design_system/foundation/motion/animations/fade_animations.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';
import 'package:reem/core/localization/l10n_extension.dart';

/// The scenario an empty state describes, so its copy can be resolved from
/// the current locale rather than frozen at construction.
enum DsEmptyStateKind { custom, cart, favorites, search }

/// A graceful empty state — soft icon medallion, friendly copy and an optional
/// call to action. Use the named constructors for common scenarios.
///
/// Copy is nullable and defaults are resolved in [build] from [kind]. They used
/// to be `const` English strings in the constructor, which made this component
/// structurally impossible to localise: a `const` default cannot read
/// `context.l10n`, so every empty state in the app was English in Arabic.
class DsEmptyState extends StatelessWidget {
  const DsEmptyState({
    super.key,
    required this.icon,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
    this.kind = DsEmptyStateKind.custom,
  });

  /// Empty shopping bag / cart.
  const DsEmptyState.cart({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
  })  : icon = Icons.shopping_bag_outlined,
        kind = DsEmptyStateKind.cart;

  /// No favourites yet.
  const DsEmptyState.favorites({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
  })  : icon = Icons.favorite_border_rounded,
        kind = DsEmptyStateKind.favorites;

  /// Empty search results.
  const DsEmptyState.search({
    super.key,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.illustration,
  })  : icon = Icons.search_off_rounded,
        kind = DsEmptyStateKind.search;

  final IconData icon;
  final DsEmptyStateKind kind;
  final String? title;
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
    final l10n = context.l10n;

    final resolvedTitle = title ??
        switch (kind) {
          DsEmptyStateKind.cart => l10n.emptyCart,
          DsEmptyStateKind.favorites => l10n.emptyWishlist,
          DsEmptyStateKind.search => l10n.emptyFeed,
          DsEmptyStateKind.custom => '',
        };
    final resolvedAction = actionLabel ??
        (kind == DsEmptyStateKind.cart ? l10n.emptyCartAction : null);

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
                resolvedTitle,
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
              if (resolvedAction != null && onAction != null) ...[
                const SizedBox(height: DsSpacing.xl),
                DsButton(
                  label: resolvedAction,
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
