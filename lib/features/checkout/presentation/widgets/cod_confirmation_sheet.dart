import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/checkout/domain/entities/checkout.dart';
import 'package:ohara/features/checkout/presentation/providers/checkout_providers.dart';

/// Collects the code that releases a cash order the platform is holding.
///
/// Modelled on the step-up sheet rather than a full screen, because this is a
/// step inside placing an order and not a journey of its own: the order is
/// already hers, nothing has been lost, and the way out is one field.
///
/// She is never told a score exists. [CodAssurance.message] is written by the
/// server and is the whole explanation — so support, the notification and this
/// sheet all say the same sentence.
///
/// Returns `true` once the order has been confirmed.
Future<bool> showCodConfirmationSheet(
  BuildContext context, {
  required String orderId,
  required CodAssurance assurance,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // Dismissible on purpose. A held order is recoverable from its own detail
    // screen, and trapping a woman in a sheet because an algorithm wanted a
    // code is a worse failure than an order that waits.
    isDismissible: true,
    builder: (sheetContext) =>
        _CodConfirmationSheet(orderId: orderId, assurance: assurance),
  );
  return confirmed ?? false;
}

class _CodConfirmationSheet extends ConsumerStatefulWidget {
  const _CodConfirmationSheet({required this.orderId, required this.assurance});

  final String orderId;
  final CodAssurance assurance;

  @override
  ConsumerState<_CodConfirmationSheet> createState() =>
      _CodConfirmationSheetState();
}

class _CodConfirmationSheetState extends ConsumerState<_CodConfirmationSheet> {
  final _controller = TextEditingController();

  late CodAssurance _assurance = widget.assurance;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _controller.text.trim();
    if (code.length != 6) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref
        .read(confirmCodOrderUseCaseProvider)
        .call(widget.orderId, code);

    if (!mounted) return;
    switch (result) {
      case Success():
        Navigator.pop(context, true);
      case Error(:final failure):
        setState(() {
          _busy = false;
          _error = failure.message;
        });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref
        .read(resendCodConfirmationUseCaseProvider)
        .call(widget.orderId);

    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        setState(() {
          _assurance = data;
          _busy = false;
        });
        DsSnackbar.show(
          context,
          message: context.l10n.codConfirmResent,
          type: DsSnackbarType.success,
        );
      case Error(:final failure):
        setState(() {
          _busy = false;
          _error = failure.message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: DsSpacing.lg,
        right: DsSpacing.lg,
        top: DsSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + DsSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.codConfirmTitle, style: text.titleLarge),
          const SizedBox(height: DsSpacing.xs),
          Text(
            _assurance.dispatchFailed
                ? l10n.codConfirmDispatchFailed
                : (_assurance.message ?? l10n.codConfirmFallback),
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (_assurance.maskedDestination != null) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              _assurance.maskedDestination!,
              textDirection: TextDirection.ltr,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          // The two digits also printed inside the message. She compares them,
          // which is what makes a code recited to her over the phone useless.
          if (_assurance.matchCode != null) ...[
            const SizedBox(height: DsSpacing.md),
            Row(
              children: [
                Text('${l10n.matchCodeLabel}: ', style: text.bodySmall),
                Text(
                  _assurance.matchCode!,
                  style: text.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: DsSpacing.lg),
          DsInputField(
            controller: _controller,
            label: l10n.verificationCode,
            keyboardType: TextInputType.number,
            autofocus: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            onSubmitted: (_) => _busy ? null : _confirm(),
          ),
          if (_error != null) ...[
            const SizedBox(height: DsSpacing.sm),
            Text(
              _error!,
              style: text.bodySmall?.copyWith(color: colors.error),
            ),
          ],
          const SizedBox(height: DsSpacing.lg),
          PrimaryButton(
            label: l10n.codConfirmAction,
            isLoading: _busy,
            onPressed: _busy ? null : _confirm,
          ),
          const SizedBox(height: DsSpacing.sm),
          TextButton(
            onPressed: _busy ? null : _resend,
            child: Text(l10n.codConfirmResend),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: Text(l10n.codConfirmLater),
          ),
        ],
      ),
    );
  }
}
