import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/buttons/ds_icon_button.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_constraints.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

/// Helpers for presenting Reem-styled modal bottom sheets.
///
/// Visuals (shape, drag handle, barrier, elevation) come from the global
/// bottom-sheet theme; these helpers add safe sizing and ergonomics.
abstract final class DsBottomSheet {
  /// Show arbitrary content. Wrap it in a [DsSheetScaffold] for a titled sheet.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: DsConstraints.maxContentWidth),
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
}

/// A consistent layout shell for bottom-sheet content: header (title + close)
/// and a body that is scrollable by default and respects the keyboard inset.
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
                      Text(title!,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: DsTypography.bold)),
                      if (subtitle != null) ...[
                        const SizedBox(height: DsSpacing.xxs),
                        Text(subtitle!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: c.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                if (showClose)
                  DsIconButton(
                    icon: Icons.close_rounded,
                    variant: DsIconButtonVariant.tonal,
                    size: 36,
                    iconSize: 20,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
              ],
            ),
          );

    final body = Padding(padding: padding, child: child);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?header,
        Flexible(
          child: scrollable
              ? SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: viewInsets),
                  child: body,
                )
              : body,
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
