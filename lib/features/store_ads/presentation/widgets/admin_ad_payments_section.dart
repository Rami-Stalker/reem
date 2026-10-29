import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/checkout/presentation/order_labels.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/presentation/providers/store_ads_providers.dart';
import 'package:ohara/features/store_ads/presentation/widgets/store_ads_labels.dart';

/// «باقات الإعلان» on the finance desk.
///
/// The month at a glance, the plan payments boutiques have sent and nobody
/// has matched yet, and where boutiques are told to send the money. A
/// boutique that paid and is still on the free plan is a boutique waiting on
/// this screen, so the queue is the part that matters.
class AdminAdPaymentsSection extends ConsumerWidget {
  const AdminAdPaymentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.console;
    final l10n = context.l10n;
    final summary = ref.watch(adminAdsSummaryProvider).value;
    final pending = ref.watch(adminAdsPendingProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.adminAdsTitle,
          style: context.dsText.cardTitle.bold.tint(palette.ink),
        ),
        if (summary != null) ...[
          DsGaps.vXs,
          Text(
            l10n.adminAdsSummary(
              summary.activePlans.values.fold(0, (a, b) => a + b),
              formatSyp(summary.revenueThisMonth),
            ),
            style: context.dsText.bodySmall.tint(palette.muted),
          ),
        ],
        DsGaps.vMd,
        switch (pending) {
          AsyncData(:final value) when value.isEmpty => _Note(
            text: l10n.adminAdsNoPending,
          ),
          AsyncData(:final value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final p in value) _PaymentTile(payment: p)],
          ),
          AsyncError() => _Note(text: l10n.adsFailed),
          _ => const Padding(
            padding: DsSpacing.paddingMd,
            child: DsLoadingIndicator.inline(),
          ),
        },
        DsGaps.vMd,
        const _InstructionsEditor(),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: DsSpacing.sm),
    child: Text(
      text,
      style: context.dsText.bodySmall.tint(context.console.muted),
    ),
  );
}

class _PaymentTile extends ConsumerStatefulWidget {
  const _PaymentTile({required this.payment});

  final AdPendingPayment payment;

  @override
  ConsumerState<_PaymentTile> createState() => _PaymentTileState();
}

class _PaymentTileState extends ConsumerState<_PaymentTile> {
  bool _busy = false;

  Future<void> _run(
    Future<Result<void>> Function() action,
    String success,
  ) async {
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Success():
        DsSnackbar.success(context, success);
        ref
          ..invalidate(adminAdsPendingProvider)
          ..invalidate(adminAdsSummaryProvider);
      case Error(:final Failure failure):
        DsSnackbar.error(context, adFailureMessage(context.l10n, failure));
    }
  }

  Future<void> _confirm() async {
    final l10n = context.l10n;
    final p = widget.payment.purchase;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.financeTransferConfirmTitle),
        content: Text(
          l10n.adminAdsConfirmBody(
            formatSyp(p.amount),
            widget.payment.sellerName,
            p.tier.label(l10n),
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
      () => ref.read(adminAdsRepositoryProvider).confirm(p.id),
      l10n.adminAdsConfirmed,
    );
  }

  Future<void> _reject() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.financeTransferRejectTitle),
        content: DsInputField(
          controller: controller,
          label: l10n.financeTransferRejectReason,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l10n.financeTransferReject),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.trim().isEmpty || !mounted) return;
    await _run(
      () => ref
          .read(adminAdsRepositoryProvider)
          .reject(widget.payment.purchase.id, reason.trim()),
      l10n.financeTransferRejected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    final p = widget.payment.purchase;
    final jewel = p.tier.jewel;
    final hasReference = p.reference != null && p.reference!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.sm),
      padding: DsSpacing.paddingMd,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (jewel != null) ...[
                DsTierBadge(tier: jewel, label: p.tier.label(l10n)),
                DsGaps.hSm,
              ],
              Expanded(
                child: Text(
                  widget.payment.sellerName,
                  style: context.dsText.body.bold.tint(palette.ink),
                ),
              ),
              Text(
                formatSyp(p.amount),
                style: context.dsText.price.tabular.tint(palette.ink),
              ),
            ],
          ),
          DsGaps.vXs,
          Text(
            l10n.paymentMethodName(p.method),
            style: context.dsText.bodySmall.tint(palette.ink),
          ),
          Text(
            hasReference
                ? l10n.adminAdsReference(p.reference!)
                : l10n.financeTransferNoReference,
            style: context.dsText.bodySmall.tint(
              hasReference ? palette.ink : palette.caution,
            ),
          ),
          if (widget.payment.sellerPhone != null)
            Text(
              widget.payment.sellerPhone!,
              style: context.dsText.caption.tint(palette.muted),
            ),
          DsGaps.vSm,
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: l10n.financeTransferConfirm,
                  isLoading: _busy,
                  onPressed: _busy ? null : _confirm,
                ),
              ),
              DsGaps.hSm,
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

/// Where boutiques send the money for a plan. A method left empty is not
/// offered to them at all.
class _InstructionsEditor extends ConsumerStatefulWidget {
  const _InstructionsEditor();

  @override
  ConsumerState<_InstructionsEditor> createState() =>
      _InstructionsEditorState();
}

class _InstructionsEditorState extends ConsumerState<_InstructionsEditor> {
  static const _methods = [
    'sham_cash',
    'syriatel_cash',
    'mtn_cash',
    'bank_transfer',
    'hawala',
  ];

  final _controllers = {for (final m in _methods) m: TextEditingController()};
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    final result = await ref.read(adminAdsRepositoryProvider).saveInstructions({
      for (final e in _controllers.entries) e.key: e.value.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success():
        DsSnackbar.success(context, l10n.adminAdsInstructionsSaved);
        ref.invalidate(adminAdsInstructionsProvider);
      case Error(:final failure):
        DsSnackbar.error(context, failure.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.console;
    final current = ref.watch(adminAdsInstructionsProvider).value;
    if (current != null && !_loaded) {
      _loaded = true;
      for (final m in _methods) {
        _controllers[m]!.text = current[m] ?? '';
      }
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        l10n.adminAdsInstructionsTitle,
        style: context.dsText.bodyStrong.tint(palette.ink),
      ),
      subtitle: Text(
        l10n.adminAdsInstructionsHint,
        style: context.dsText.caption.tint(palette.muted),
      ),
      children: [
        for (final m in _methods) ...[
          DsInputField(
            controller: _controllers[m],
            label: l10n.paymentMethodName(m),
            maxLines: 2,
          ),
          DsGaps.vSm,
        ],
        PrimaryButton(
          label: l10n.adminAdsInstructionsSave,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
        DsGaps.vMd,
      ],
    );
  }
}
