import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/admin_finance/domain/entities/pending_transfer.dart';
import 'package:ohara/features/admin_finance/presentation/providers/admin_finance_provider.dart';
import 'package:ohara/features/checkout/presentation/order_labels.dart';

/// Q51 — the bank transfers and hawala finance still has to match.
///
/// The customer's half of this flow existed — she could send the reference
/// her bank or the exchange office gave her — and the platform's half did
/// not: nobody had a screen to see it or a button to accept it, so her order
/// waited until it expired with her money on its way. Confirming here settles
/// the payment and sends the order to its sellers in one step; rejecting sends
/// the reason back to her so she can send the right one.
class PendingTransfersSection extends ConsumerWidget {
  const PendingTransfersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.console;
    final l10n = context.l10n;
    final transfers = ref.watch(pendingTransfersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: DsSpacing.md),
          child: Text(
            l10n.financePendingTransfers,
            style: context.dsText.cardTitle.bold.tint(palette.ink),
          ),
        ),
        switch (transfers) {
          AsyncData(:final value) when value.isEmpty => _Note(
            text: l10n.financePendingTransfersEmpty,
          ),
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final transfer in value) _TransferTile(transfer: transfer),
            ],
          ),
          AsyncError() => _Note(text: l10n.financePendingTransfersError),
          _ => const Padding(
            padding: EdgeInsets.all(DsSpacing.md),
            child: DsLoadingIndicator.inline(),
          ),
        },
      ],
    );
  }
}

class _TransferTile extends ConsumerStatefulWidget {
  const _TransferTile({required this.transfer});

  final PendingTransfer transfer;

  @override
  ConsumerState<_TransferTile> createState() => _TransferTileState();
}

class _TransferTileState extends ConsumerState<_TransferTile> {
  bool _busy = false;

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.financeTransferConfirmTitle),
        content: Text(
          l10n.financeTransferConfirmBody(
            widget.transfer.amount.format(),
            widget.transfer.orderNumber,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.financeTransferConfirm),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    await _run(
      () => ref
          .read(adminFinanceRepositoryProvider)
          .confirmTransfer(widget.transfer.paymentId),
      success: l10n.financeTransferConfirmed,
    );
  }

  Future<void> _reject() async {
    final l10n = context.l10n;
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectDialog(),
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    await _run(
      () => ref
          .read(adminFinanceRepositoryProvider)
          .rejectTransfer(widget.transfer.paymentId, reason.trim()),
      success: l10n.financeTransferRejected,
    );
  }

  Future<void> _run(
    Future<Result<void>> Function() action, {
    required String success,
  }) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case Success():
        DsSnackbar.success(context, success);
        ref.invalidate(pendingTransfersProvider);
        // Confirming moves money; the positions above should say so.
        await ref.read(adminFinanceNotifierProvider.notifier).refresh();
      case Error(:final failure):
        DsSnackbar.error(context, failure.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    final transfer = widget.transfer;
    final locale = Localizations.localeOf(context).languageCode;
    String when(DateTime value) =>
        DateFormat.MMMd(locale).add_Hm().format(value);

    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.sm),
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: palette.primary),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Text(
                  '${transfer.orderNumber} · '
                  '${l10n.paymentMethodName(transfer.method)}',
                  style: context.dsText.body.bold.tint(palette.ink),
                ),
              ),
              Text(
                transfer.amount.format(),
                style: context.dsText.price.tabular.tint(palette.ink),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            transfer.reference == null
                ? l10n.financeTransferNoReference
                : '${l10n.paymentReferenceOnFile}: ${transfer.reference}',
            style: context.dsText.bodySmall.tint(
              transfer.reference == null ? palette.caution : palette.ink,
            ),
          ),
          if (transfer.customerName != null || transfer.customerPhone != null)
            Text(
              [
                transfer.customerName,
                transfer.customerPhone,
              ].whereType<String>().join(' · '),
              style: context.dsText.caption.tint(palette.muted),
            ),
          if (transfer.expiresAt != null)
            Text(
              l10n.financeTransferExpires(when(transfer.expiresAt!)),
              style: context.dsText.caption.tint(palette.muted),
            ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: l10n.financeTransferConfirm,
                  isLoading: _busy,
                  onPressed: _busy ? null : _confirm,
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: SecondaryButton(
                  label: l10n.financeTransferReject,
                  onPressed: _busy ? null : _reject,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.financeTransferRejectTitle),
      content: DsInputField(
        controller: _reason,
        label: l10n.financeTransferRejectReason,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_reason.text),
          child: Text(l10n.financeTransferReject),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(DsRadius.lg),
      ),
      child: Text(
        text,
        style: context.dsText.bodySmall.tint(palette.muted),
      ),
    );
  }
}
