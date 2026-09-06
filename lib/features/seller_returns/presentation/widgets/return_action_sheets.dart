import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/seller_returns/domain/entities/return_request.dart';
import 'package:reem/features/seller_returns/presentation/return_labels.dart';

/// What an action needs from her before it can be sent.
class ReturnActionInput {
  const ReturnActionInput({
    this.reason,
    this.note,
    this.restock,
    this.shippingBorneBy,
  });

  final String? reason;
  final String? note;
  final bool? restock;
  final ReturnCostBearer? shippingBorneBy;
}

/// Collects whatever the chosen action requires, and returns null if she backs
/// out.
///
/// Three of the six actions carry no question at all — marking a parcel in
/// transit is a statement of fact — and those go straight through rather than
/// asking her to confirm something she just tapped.
Future<ReturnActionInput?> askForReturnAction(
  BuildContext context,
  ReturnRequest request,
  ReturnAction action,
) async {
  return switch (action) {
    ReturnAction.approve => _approveSheet(context, request),
    ReturnAction.reject => _rejectSheet(context),
    ReturnAction.receive => _receiveSheet(context, request),
    _ => Future.value(const ReturnActionInput()),
  };
}

/// Accepting a return decides one thing beyond "yes": who pays to get the
/// goods back. The server derives a default from the reason — a faulty item is
/// not the customer's freight to fund — and this only offers her the override
/// the API allows, with that default plainly the first option.
Future<ReturnActionInput?> _approveSheet(
  BuildContext context,
  ReturnRequest request,
) {
  ReturnCostBearer? bearer = request.shippingBorneBy;
  final note = TextEditingController();

  return DsBottomSheet.show<ReturnActionInput>(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (innerContext, setSheetState) => DsSheetScaffold(
        title: innerContext.l10n.returnApproveTitle,
        subtitle: innerContext.returnReasonLabel(request.reason),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                innerContext.l10n.returnShippingBearer,
                style: context.dsText.body.semibold.tint(innerContext.atelier.muted),
              ),
            ),
            const SizedBox(height: DsSpacing.xs),
            Wrap(
              spacing: DsSpacing.sm,
              children: [
                ChoiceChip(
                  label: Text(innerContext.l10n.returnBearerDefault),
                  selected: bearer == null,
                  onSelected: (_) => setSheetState(() => bearer = null),
                ),
                for (final option in ReturnCostBearer.values)
                  ChoiceChip(
                    label: Text(innerContext.returnBearerLabel(option)),
                    selected: bearer == option,
                    onSelected: (_) => setSheetState(() => bearer = option),
                  ),
              ],
            ),
            const SizedBox(height: DsSpacing.md),
            DsInputField(
              controller: note,
              label: innerContext.l10n.returnNoteOptional,
              maxLines: 2,
            ),
            const SizedBox(height: DsSpacing.md),
            DsButton(
              label: innerContext.l10n.returnActionApprove,
              icon: Icons.check_circle_outline_rounded,
              onPressed: () => Navigator.of(sheetContext).pop(
                ReturnActionInput(
                  shippingBorneBy: bearer,
                  note: note.text,
                ),
              ),
            ),
            const SizedBox(height: DsSpacing.sm),
            DsButton(
              label: innerContext.l10n.cancel,
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(note.dispose);
}

/// A refusal is the customer's only explanation and the only evidence a
/// dispute reviewer will have, so the reason is mandatory here exactly as it
/// is on the server — and the sheet says who will read it.
Future<ReturnActionInput?> _rejectSheet(BuildContext context) {
  final reason = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return DsBottomSheet.show<ReturnActionInput>(
    context,
    builder: (sheetContext) => DsSheetScaffold(
      title: sheetContext.l10n.returnActionReject,
      subtitle: sheetContext.l10n.returnRejectHint,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DsInputField(
              controller: reason,
              label: sheetContext.l10n.returnRejectReason,
              maxLines: 3,
              autofocus: true,
              validator: (value) => (value ?? '').trim().length < 5
                  ? sheetContext.l10n.returnRejectTooShort
                  : null,
            ),
            const SizedBox(height: DsSpacing.md),
            DsButton(
              label: sheetContext.l10n.returnActionReject,
              variant: DsButtonVariant.danger,
              icon: Icons.block_rounded,
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.of(
                  sheetContext,
                ).pop(ReturnActionInput(reason: reason.text.trim()));
              },
            ),
            const SizedBox(height: DsSpacing.sm),
            DsButton(
              label: sheetContext.l10n.cancel,
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(reason.dispose);
}

/// Confirming receipt is the moment the refund becomes due, and the moment the
/// stock question has to be answered: the woman holding the parcel is the only
/// one who can say whether what came back can be sold again.
Future<ReturnActionInput?> _receiveSheet(
  BuildContext context,
  ReturnRequest request,
) {
  // Default to restocking, except where the customer's own reason says the
  // goods are not fit to sell — offering "back on the shelf" as the default
  // for a broken item invites a mis-tap with a real cost behind it.
  var restock = !request.reason.allegesFault;
  final note = TextEditingController();

  return DsBottomSheet.show<ReturnActionInput>(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (innerContext, setSheetState) => DsSheetScaffold(
        title: innerContext.l10n.returnReceiveTitle,
        subtitle: innerContext.l10n.returnRefundIsPlatforms,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(innerContext.l10n.returnRestock),
              subtitle: Text(
                innerContext.l10n.returnRestockHint,
                style: context.dsText.caption.tint(innerContext.atelier.muted),
              ),
              value: restock,
              onChanged: (value) => setSheetState(() => restock = value),
            ),
            const SizedBox(height: DsSpacing.sm),
            DsInputField(
              controller: note,
              label: innerContext.l10n.returnNoteOptional,
              maxLines: 2,
            ),
            const SizedBox(height: DsSpacing.md),
            DsButton(
              label: innerContext.l10n.returnActionReceive,
              icon: Icons.inventory_outlined,
              onPressed: () => Navigator.of(sheetContext).pop(
                ReturnActionInput(restock: restock, note: note.text),
              ),
            ),
            const SizedBox(height: DsSpacing.sm),
            DsButton(
              label: innerContext.l10n.cancel,
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    ),
  ).whenComplete(note.dispose);
}
