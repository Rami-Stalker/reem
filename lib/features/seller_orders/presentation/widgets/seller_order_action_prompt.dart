import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../domain/entities/seller_order.dart';
import '../seller_order_labels.dart';

/// What an action needs from her before it can run.
class SellerActionInput {
  const SellerActionInput({this.reason, this.collected, this.carrier});

  final String? reason;
  final String? collected;
  final String? carrier;
}

/// Asks for the one thing an action cannot invent.
///
/// Two of the five actions carry a decision the server refuses to guess: a
/// cancellation needs a reason (the customer's only explanation and the
/// seller's own quality record), and a delivery needs what she actually
/// collected. Everything else runs on a single tap, because adding a
/// confirmation dialog to «قبول الطلب» would only train her to tap through it.
abstract final class SellerOrderActionPrompt {
  /// Returns null when she backs out.
  static Future<SellerActionInput?> ask(
    BuildContext context,
    SellerOrderAction action, {
    required SellerOrderSummary order,
  }) {
    return switch (action) {
      SellerOrderAction.cancel => _askCancel(context, order),
      SellerOrderAction.deliver => _askDelivery(context, order),
      _ => Future.value(const SellerActionInput()),
    };
  }

  static Future<SellerActionInput?> _askCancel(
    BuildContext context,
    SellerOrderSummary order,
  ) {
    return DsBottomSheet.showTitled<SellerActionInput>(
      context,
      title: context.l10n.parcelAction(SellerOrderAction.cancel),
      subtitle: context.l10n.sellerCancelSubtitle,
      child: const _ReasonForm(),
    );
  }

  static Future<SellerActionInput?> _askDelivery(
    BuildContext context,
    SellerOrderSummary order,
  ) {
    return DsBottomSheet.showTitled<SellerActionInput>(
      context,
      title: context.l10n.sellerDeliverTitle,
      subtitle: order.isCashOnDelivery
          ? context.l10n.sellerDeliverSubtitleCash
          : context.l10n.sellerDeliverSubtitlePrepaid,
      child: _DeliveryForm(collectsCash: order.isCashOnDelivery),
    );
  }
}

class _ReasonForm extends StatefulWidget {
  const _ReasonForm();

  @override
  State<_ReasonForm> createState() => _ReasonFormState();
}

class _ReasonFormState extends State<_ReasonForm> {
  final _controller = TextEditingController();
  String? _error;

  /// The reasons a seller actually has, offered as taps.
  ///
  /// Free text stays available underneath — these only remove the friction of
  /// typing the same sentence every time, which is what turns a mandatory
  /// reason into a meaningful one instead of a keyboard-mash.
  static List<String> _presetsFor(BuildContext context) => [
    context.l10n.sellerCancelPresetOutOfStock,
    context.l10n.sellerCancelPresetSizeGone,
    context.l10n.sellerCancelPresetPriceError,
    context.l10n.sellerCancelPresetNoTime,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            for (final preset in _presetsFor(context))
              DsChip(
                label: preset,
                selected: _controller.text == preset,
                onTap: () => setState(() {
                  _controller.text = preset;
                  _error = null;
                }),
              ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),

        DsInputField(
          controller: _controller,
          label: l10n.sellerCancelReasonLabel,
          hint: l10n.sellerCancelReasonHint,
          maxLines: 3,
          errorText: _error,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: DsSpacing.lg),

        DsButton(
          label: l10n.sellerCancelConfirm,
          variant: DsButtonVariant.danger,
          onPressed: () {
            final reason = _controller.text.trim();
            // The server asks for five characters; saying so here is kinder
            // than letting her press send and reading a red banner.
            if (reason.length < 5) {
              setState(() => _error = l10n.sellerCancelReasonTooShort);
              return;
            }
            Navigator.of(context).pop(SellerActionInput(reason: reason));
          },
        ),
        const SizedBox(height: DsSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.sellerCancelDismiss,
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                color: atelier.muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeliveryForm extends StatefulWidget {
  const _DeliveryForm({required this.collectsCash});

  final bool collectsCash;

  @override
  State<_DeliveryForm> createState() => _DeliveryFormState();
}

class _DeliveryFormState extends State<_DeliveryForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.collectsCash) ...[
          DsInputField(
            controller: _controller,
            label: context.l10n.sellerDeliverCollectedLabel,
            // Left empty on purpose rather than pre-filled with what is due:
            // empty means "the full amount", and a pre-filled figure invites
            // confirming without looking — which becomes a shortfall somebody
            // has to chase later.
            hint: context.l10n.sellerDeliverCollectedHint,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          ),
          const SizedBox(height: DsSpacing.lg),
        ],

        DsButton(
          label: context.l10n.parcelAction(SellerOrderAction.deliver),
          onPressed: () {
            final collected = _controller.text.trim();
            Navigator.of(context).pop(
              SellerActionInput(
                collected: collected.isEmpty ? null : collected,
              ),
            );
          },
        ),
      ],
    );
  }
}
