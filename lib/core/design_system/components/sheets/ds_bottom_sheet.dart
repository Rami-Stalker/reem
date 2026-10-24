import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/buttons/ds_icon_button.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_constraints.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_platform.dart';

/// One entry in a [DsBottomSheet.choose] menu.
class DsSheetChoice<T> {
  const DsSheetChoice({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;
}

/// Helpers for presenting Reem-styled modal bottom sheets.
///
/// Visuals (shape, drag handle, barrier, elevation) come from the global
/// bottom-sheet theme; these helpers add safe sizing and ergonomics.
abstract final class DsBottomSheet {
  /// Show arbitrary content. Wrap it in a [DsSheetScaffold] for a titled sheet.
  ///
  /// **On the root navigator.** The buyer's shell sets `extendBody: true` and
  /// floats its navigation bar over the page, so a sheet raised on the tab's
  /// own navigator was laid out *behind* that bar: the last lines of the help
  /// and about sheets sat under the glass rail and could not be read or
  /// scrolled to. Presenting above the shell puts the whole sheet on screen,
  /// bar included, which is also what a modal is supposed to mean.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: true,
      constraints: const BoxConstraints(
        maxWidth: DsConstraints.maxContentWidth,
      ),
      builder: builder,
    );
  }

  /// Convenience for a titled sheet around [child].
  static Future<T?> showTitled<T>(
    BuildContext context, {
    required String title,
    required Widget child,
    String? subtitle,
    bool showClose = true,
    bool scrollable = true,
  }) {
    return show<T>(
      context,
      builder: (_) => DsSheetScaffold(
        title: title,
        subtitle: subtitle,
        showClose: showClose,
        scrollable: scrollable,
        child: child,
      ),
    );
  }

  /// A plain "which one?" menu — the sheet whose whole content is a short list
  /// of choices.
  ///
  /// This is the one sheet shape the two platforms genuinely disagree about.
  /// iOS answers a question like *camera or gallery?* with an action sheet
  /// that rises from the bottom with a separated Cancel below it, and a
  /// Material list inside a rounded card reads as a port there. Android
  /// answers it with exactly that Material list. Sheets that carry real
  /// content — a form, an explanation, a comment thread — stay Material on
  /// both, because those are the app's own furniture rather than a system
  /// idiom.
  static Future<T?> choose<T>(
    BuildContext context, {
    required List<DsSheetChoice<T>> choices,
    String? title,
    String? message,
    String? cancelLabel,
  }) {
    final cancelText = cancelLabel ?? context.l10n.cancel;

    if (AppPlatform.isApple) {
      return showCupertinoModalPopup<T>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => CupertinoActionSheet(
          title: title == null ? null : Text(title),
          message: message == null ? null : Text(message),
          actions: [
            for (final choice in choices)
              CupertinoActionSheetAction(
                isDestructiveAction: choice.destructive,
                onPressed: () => Navigator.of(ctx).pop(choice.value),
                child: Text(choice.label),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(cancelText),
          ),
        ),
      );
    }

    return show<T>(
      context,
      builder: (ctx) => DsSheetScaffold(
        title: title,
        subtitle: message,
        scrollable: false,
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.sm,
          0,
          DsSpacing.sm,
          DsSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in choices)
              _ChoiceRow<T>(
                choice: choice,
                onTap: () => Navigator.of(ctx).pop(choice.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({required this.choice, required this.onTap});

  final DsSheetChoice<T> choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final tint = choice.destructive ? c.error : c.primary;

    return ListTile(
      onTap: onTap,
      minTileHeight: DsSizes.minTouchTarget,
      leading: choice.icon == null
          ? null
          : CircleAvatar(
              backgroundColor: tint.withValues(alpha: 0.12),
              child: Icon(choice.icon, color: tint, size: DsSizes.iconSm),
            ),
      title: Text(
        choice.label,
        style: TextStyle(
          color: choice.destructive ? c.error : c.onSurface,
          fontWeight: DsTypography.medium,
        ),
      ),
    );
  }
}

/// A consistent layout shell for bottom-sheet content: header (title + close)
/// and a body that is scrollable by default. Every variant keeps its lowest
/// element above the keyboard, so content inside must not add the inset again.
class DsSheetScaffold extends StatelessWidget {
  const DsSheetScaffold({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.showClose = true,
    this.scrollable = true,
    this.padding = const EdgeInsets.fromLTRB(
      DsSpacing.lg,
      DsSpacing.xs,
      DsSpacing.lg,
      DsSpacing.lg,
    ),
    this.footer,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final bool showClose;
  final bool scrollable;
  final EdgeInsets padding;

  /// Optional pinned footer (e.g. primary action) that stays above the keyboard.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.dsColors;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    final header = (title == null)
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.xs,
              DsSpacing.xs,
              DsSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: DsTypography.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: DsSpacing.xxs),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showClose)
                  DsIconButton(
                    icon: Icons.close_rounded,
                    tooltip: context.l10n.close,
                    variant: DsIconButtonVariant.tonal,
                    size: 36,
                    iconSize: 20,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
              ],
            ),
          );

    // The keyboard is paid for exactly once, by whatever sits lowest: the
    // pinned footer when there is one, otherwise the body. A non-scrollable
    // body used to pay nothing, so a short form — naming a highlight, a new
    // collection — opened with its field and its Save button under the
    // keyboard, and the sheet did not rise to meet it.
    final bodyInset = footer == null ? viewInsets : 0.0;
    final body = Padding(padding: padding, child: child);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?header,
        Flexible(
          child: scrollable
              ? SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bodyInset),
                  child: body,
                )
              : Padding(
                  padding: EdgeInsets.only(bottom: bodyInset),
                  child: body,
                ),
        ),
        if (footer != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.xs,
              DsSpacing.lg,
              DsSpacing.lg + viewInsets,
            ),
            child: footer!,
          ),
      ],
    );
  }
}
