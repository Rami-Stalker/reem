import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/checkout/domain/entities/order.dart';
import 'package:ohara/features/checkout/presentation/order_labels.dart';
import 'package:ohara/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// The step that actually takes her money, for the rails that need one.
///
/// Placing an order used to be the end of the flow whatever she picked. Cash
/// and the wallet are genuinely finished at that point — but a mobile-money or
/// card payment returns a gateway link the app never opened, and a bank
/// transfer or hawala asks her for a reference the app had nowhere to type. So
/// four of the nine rails ended with an order sitting unpaid and nothing on
/// screen to do about it, which is what «بعضها فيه أخطاء» was.
///
/// One card, two shapes:
///
///  - **online** — re-opens the gateway (a fresh attempt, because a link from
///    an hour ago may have expired) and then checks the result.
///  - **manual** — the instructions plus the field for the reference her bank
///    or the hawala office gave her. Submitting does not mark it paid: only
///    finance matching the transfer does that, and saying otherwise would be
///    a receipt the platform cannot honour.
class PaymentActionCard extends ConsumerStatefulWidget {
  const PaymentActionCard({
    super.key,
    required this.payment,
    required this.onSettled,
  });

  final OrderPayment payment;

  /// Called after anything that may have moved the payment, so the order can
  /// be re-read.
  final Future<void> Function() onSettled;

  @override
  ConsumerState<PaymentActionCard> createState() => _PaymentActionCardState();
}

class _PaymentActionCardState extends ConsumerState<PaymentActionCard> {
  final _reference = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reference.text = widget.payment.providerRef ?? '';
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Future<void> _openGateway() async {
    setState(() => _busy = true);
    final result = await ref
        .read(retryPaymentUseCaseProvider)
        .call(widget.payment.id);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case Success(:final data):
        final url = data.redirectUrl;
        final opened =
            url != null &&
            await launchUrl(
              Uri.parse(url),
              mode: LaunchMode.externalApplication,
            );
        if (!mounted) return;
        if (!opened) {
          DsSnackbar.error(context, context.l10n.paymentCouldNotOpen);
        }
        await widget.onSettled();
      case Error(:final failure):
        DsSnackbar.error(context, failure.displayMessage);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final result = await ref
        .read(verifyPaymentUseCaseProvider)
        .call(widget.payment.id);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case Success(:final data):
        // The truth, not a celebration: the manual rails answer "still
        // waiting" by design, and telling her it was confirmed would be a lie
        // she discovers at the door.
        DsSnackbar.show(
          context,
          message: data.isPaid
              ? context.l10n.paymentConfirmed
              : context.l10n.paymentStillPending,
          type: data.isPaid ? DsSnackbarType.success : DsSnackbarType.info,
        );
        await widget.onSettled();
      case Error(:final failure):
        DsSnackbar.error(context, failure.displayMessage);
    }
  }

  Future<void> _submitReference() async {
    final reference = _reference.text.trim();
    if (reference.isEmpty) {
      DsSnackbar.error(context, context.l10n.paymentReferenceRequired);
      return;
    }

    setState(() => _busy = true);
    final result = await ref
        .read(submitPaymentReferenceUseCaseProvider)
        .call(widget.payment.id, reference);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case Success():
        DsSnackbar.success(context, context.l10n.paymentReferenceSaved);
        await widget.onSettled();
      case Error(:final failure):
        DsSnackbar.error(context, failure.displayMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final l10n = context.l10n;
    final colors = context.dsColors;
    final isManual = payment.rail == PaymentRail.manual;
    final instructions = isManual
        ? ref
              .watch(paymentMethodsCatalogProvider)
              .value
              ?.where((option) => option.method == payment.method)
              .firstOrNull
              ?.instructions
        : null;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isManual
                    ? Icons.receipt_long_rounded
                    : Icons.credit_score_rounded,
                color: colors.primary,
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Text(
                  l10n.paymentActionTitle,
                  style: context.dsText.tileTitle.bold.tint(colors.onSurface),
                ),
              ),
              Text(
                payment.amount.format(),
                style: context.dsText.price.tabular,
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            isManual
                ? l10n.paymentManualHint(l10n.paymentMethodName(payment.method))
                : l10n.paymentGatewayHint(
                    l10n.paymentMethodName(payment.method),
                  ),
            style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
          ),
          if ((instructions ?? '').isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            SelectableText(
              instructions!,
              style: context.dsText.body.tint(colors.onSurface),
            ),
          ],
          // Finance could not match what she sent; say why, so she can send
          // the right one rather than wait for a payment that will not land.
          if (isManual && (payment.failureReason ?? '').isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            Text(
              l10n.paymentReferenceRejected(payment.failureReason!),
              style: context.dsText.bodySmall.tint(colors.errorInk),
            ),
          ],
          const SizedBox(height: DsSpacing.md),

          if (isManual) ...[
            DsInputField(
              controller: _reference,
              label: l10n.paymentReferenceLabel,
              enabled: !_busy,
              prefixIcon: Icon(Icons.tag_rounded, color: colors.primary),
            ),
            const SizedBox(height: DsSpacing.sm),
            PrimaryButton(
              label: l10n.paymentReferenceSubmit,
              isLoading: _busy,
              onPressed: _busy ? null : _submitReference,
            ),
          ] else ...[
            PrimaryButton(
              label: l10n.paymentOpenGateway,
              icon: Icons.open_in_new_rounded,
              isLoading: _busy,
              onPressed: _busy ? null : _openGateway,
            ),
          ],

          const SizedBox(height: DsSpacing.sm),
          SecondaryButton(
            label: l10n.paymentCheckAgain,
            onPressed: _busy ? null : _verify,
          ),

          if ((payment.providerRef ?? '').isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            Text(
              '${l10n.paymentReferenceOnFile}: ${payment.providerRef}',
              style: context.dsText.caption.tint(colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
