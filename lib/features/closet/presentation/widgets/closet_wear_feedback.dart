import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';

/// "لبستها اليوم", said back to her — with a way to take it back.
///
/// Every place in the closet that logs a wear goes through here, so the
/// answer is the same everywhere: a confirmation that names the piece, and an
/// undo. The log is only worth keeping if a mistaken tap is free to reverse;
/// without the undo, the honest response to an accidental wear is to stop
/// trusting the counts.
///
/// [onChanged] receives the server's copy of the piece after the wear and
/// after an undo, for a caller that patches its own list rather than
/// refetching it.
Future<void> logClosetWear(
  BuildContext context,
  WidgetRef ref,
  ClosetItem item, {
  ValueChanged<ClosetItem>? onChanged,
}) async {
  final actions = ref.read(closetActionsProvider);
  final patchesItself = onChanged != null;

  // Worn today already: the server treats a second wear on the same day as
  // the same wear, so the honest answer is to say so rather than to pretend
  // a second one was counted.
  if (item.daysSinceWorn == 0) {
    DsSnackbar.show(context, message: context.l10n.closetAlreadyWornToday);
    return;
  }

  final result = await actions.logWear(
    item.id,
    refreshWardrobe: !patchesItself,
  );
  if (!context.mounted) return;

  switch (result) {
    case Success(:final data):
      onChanged?.call(data);
      final messenger = ScaffoldMessenger.of(context);
      final undoneMessage = context.l10n.closetWearUndone;
      DsSnackbar.show(
        context,
        message: context.l10n.closetWearLogged(item.title),
        type: DsSnackbarType.success,
        actionLabel: context.l10n.closetUndo,
        onAction: () async {
          final undo = await actions.removeWear(
            item.id,
            refreshWardrobe: !patchesItself,
          );
          if (undo case Success(:final data)) {
            onChanged?.call(data);
            DsSnackbar.on(messenger, message: undoneMessage);
          }
        },
      );
    case Error():
      DsSnackbar.show(
        context,
        message: context.l10n.closetWearFailed,
        type: DsSnackbarType.error,
      );
  }
}

/// Logs one of today's outfits. Returns whether it was logged.
///
/// Logging a wear from a suggestion is worth more than from the grid: this is
/// the moment she is actually deciding what to put on, so it is the one
/// moment the log costs her nothing to keep.
Future<bool> logTodayOutfitWear(
  BuildContext context,
  WidgetRef ref,
  TodayOutfit outfit,
) async {
  final actions = ref.read(closetActionsProvider);

  var ok = true;
  if (outfit.lookId != null) {
    ok = await actions.logLookWear(outfit.lookId!) is Success;
  } else {
    // A composition has no look row, so each piece is logged individually —
    // which is exactly what a look wear fans out to anyway.
    for (final piece in outfit.pieces) {
      final result = await actions.logWear(piece.id);
      ok = ok && result is Success;
    }
  }
  if (!context.mounted) return ok;

  DsSnackbar.show(
    context,
    message: ok ? context.l10n.closetTodayLogged : context.l10n.closetWearFailed,
    type: ok ? DsSnackbarType.success : DsSnackbarType.error,
  );
  return ok;
}

/// Turns a composition into a look she owns.
///
/// The bridge from "the app arranged this" to "this is mine": the pieces are
/// already hers, so saving is a title and a set of slots.
Future<void> saveTodayOutfitAsLook(
  BuildContext context,
  WidgetRef ref,
  TodayOutfit outfit,
) async {
  final result = await ref.read(closetActionsProvider).createLook(
    LookDraft(
      title: outfit.title,
      items: outfit.pieces
          .map((piece) => LookSlotDraft(slot: piece.slot, closetItemId: piece.id))
          .toList(growable: false),
    ),
  );
  if (!context.mounted) return;

  result.when(
    success: (_) => DsSnackbar.show(
      context,
      message: context.l10n.closetSavedToLooks,
      type: DsSnackbarType.success,
    ),
    error: (_) => DsSnackbar.show(
      context,
      message: context.l10n.closetSaveLookFailed,
      type: DsSnackbarType.error,
    ),
  );
}
