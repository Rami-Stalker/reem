import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/features/discovery/presentation/providers/for_you_dismissals_provider.dart';
import 'package:ohara/features/product_social/presentation/widgets/product_listing_scope.dart';

/// «إزالة من المختارة لكِ» in every card's «…» under [child].
class ForYouRemovalScope extends ConsumerWidget {
  const ForYouRemovalScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProductListingScope(
      action: ProductListingAction(
        label: context.l10n.forYouRemove,
        icon: Icons.visibility_off_outlined,
        onSelected: (product) => _remove(context, ref, product),
      ),
      child: child,
    );
  }

  static Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final l10n = context.l10n;
    // Taken before the card leaves: once it is gone its context is too, and
    // the «تراجع» must not depend on it.
    final messenger = ScaffoldMessenger.of(context);
    final dismissals = ref.read(forYouDismissalsProvider.notifier);

    final result = await dismissals.dismiss(product.id);
    if (!context.mounted) return;
    if (result case Error(:final failure)) {
      DsSnackbar.error(context, failure.message);
      return;
    }
    DsSnackbar.show(
      context,
      message: l10n.forYouRemoved,
      type: DsSnackbarType.success,
      duration: const Duration(seconds: 5),
      actionLabel: l10n.actionUndo,
      onAction: () {
        messenger.hideCurrentSnackBar();
        unawaited(dismissals.restore(product.id));
      },
    );
  }
}
