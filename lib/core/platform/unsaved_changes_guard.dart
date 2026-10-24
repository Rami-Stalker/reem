import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/components/dialogs/ds_dialog.dart';
import 'package:ohara/core/localization/l10n_extension.dart';

/// Stands between a half-written form and the back gesture.
///
/// The gesture is the point. On Android the system back is a swipe from either
/// edge of the screen, and on iOS it is a swipe from the leading one — both of
/// which a thumb finds by accident while typing. Half of a product listing or
/// a caption she spent five minutes on then disappears with no way back, which
/// is a loss the app caused rather than one she chose.
///
/// [canPop] is deliberately the *inverse* of "has unsaved work" rather than a
/// flat `false`. Android 13's predictive back shows a peek of the screen
/// behind while the finger is still down, and it can only do that for a route
/// that has already said it will pop. Holding `canPop: false` permanently —
/// the obvious way to write this — turns predictive back off for the whole
/// screen, including the common case where there is nothing to lose. This way
/// an untouched form animates like every other screen on the phone, and only a
/// dirty one interrupts.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.title,
    this.message,
    this.discardLabel,
    this.keepLabel,
  });

  /// Whether leaving now would throw something away.
  final bool hasUnsavedChanges;

  final Widget child;

  final String? title;
  final String? message;
  final String? discardLabel;
  final String? keepLabel;

  Future<void> _onPop(BuildContext context, bool didPop) async {
    if (didPop) {
      return;
    }
    final l10n = context.l10n;
    final discard = await DsDialog.confirm(
      context,
      title: title ?? l10n.discardChangesTitle,
      message: message ?? l10n.discardChangesBody,
      confirmLabel: discardLabel ?? l10n.discardChangesConfirm,
      cancelLabel: keepLabel ?? l10n.discardChangesKeep,
      destructive: true,
    );
    if (discard && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) => _onPop(context, didPop),
      child: child,
    );
  }
}
