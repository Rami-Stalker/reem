import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/seller_orders/domain/entities/seller_order.dart';
import 'package:ohara/features/seller_orders/presentation/seller_order_labels.dart';
import 'package:url_launcher/url_launcher.dart';

/// What the seller may see of the customer, and why.
///
/// Q57 makes this depend on the shipping method: a seller carrying her own
/// parcel gets the door she has to reach, and one whose parcel a courier
/// collects gets a first name and a governorate. The server decides — this
/// panel only renders the decision, and states the reason in place of the
/// hidden fields.
///
/// Saying *why* matters more than it looks. A blank address with no
/// explanation reads as a broken screen, and a seller who thinks the app is
/// broken phones support; one who reads «العنوان مع المندوب» does not.
class SellerCustomerPanel extends StatelessWidget {
  const SellerCustomerPanel({
    super.key,
    required this.customer,
    required this.mode,
  });

  final SellerOrderCustomer customer;
  final FulfilmentMode mode;

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: atelier.surface,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: atelier.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: atelier.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 18,
                  color: atelier.primary,
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer.name,
                      style: context.dsText.tileTitle.semibold.tint(atelier.ink),
                    ),
                    Text(
                      context.l10n.fulfilmentMode(mode),
                      style: context.dsText.caption.tint(atelier.muted),
                    ),
                  ],
                ),
              ),

              // Q55's one-tap call, on the only parcels where the seller is
              // the one delivering and therefore has a number at all.
              if (customer.phone != null)
                DsIconButton(
                  icon: Icons.phone_outlined,
                  onPressed: () => _call(customer.phone!),
                  tooltip: context.l10n.sellerOrderCallCustomer,
                ),
              // She dropped a pin at checkout: one tap opens it in the
              // phone's map app, straight to the door.
              if (customer.hasPin)
                DsIconButton(
                  icon: Icons.directions_rounded,
                  onPressed: () =>
                      _openPin(customer.latitude!, customer.longitude!),
                  tooltip: context.l10n.locationFieldOpenInMaps,
                ),
            ],
          ),

          if (customer.addressSummary.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            _Line(
              icon: Icons.location_on_outlined,
              text: customer.addressSummary,
              onLongPress: customer.hasAddress
                  ? () => _copy(context, customer.addressSummary)
                  : null,
            ),
          ],

          if (customer.landmark != null && customer.landmark!.isNotEmpty)
            _Line(icon: Icons.place_outlined, text: customer.landmark!),

          if (customer.deliveryInstructions != null &&
              customer.deliveryInstructions!.isNotEmpty)
            _Line(
              icon: Icons.sticky_note_2_outlined,
              text: customer.deliveryInstructions!,
              tone: atelier.caution,
            ),

          if (customer.isMasked && customer.maskedBecause != null) ...[
            const SizedBox(height: DsSpacing.sm),
            Container(
              padding: const EdgeInsets.all(DsSpacing.sm),
              decoration: BoxDecoration(
                color: atelier.primarySoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(DsRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 15,
                    color: atelier.primary,
                  ),
                  const SizedBox(width: DsSpacing.xs),
                  Expanded(
                    child: Text(
                      customer.maskedBecause!,
                      style: context.dsText.caption.tint(atelier.primary).copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openPin(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _copy(BuildContext context, String value) {
    Clipboard.setData(ClipboardData(text: value));
    DsSnackbar.success(context, context.l10n.sellerOrderAddressCopied);
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.text,
    this.tone,
    this.onLongPress,
  });

  final IconData icon;
  final String text;
  final Color? tone;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final atelier = context.atelier;
    final color = tone ?? atelier.ink;

    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.xs),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: tone ?? atelier.muted),
            const SizedBox(width: DsSpacing.xs),
            Expanded(
              child: Text(
                text,
                style: context.dsText.bodySmall.tint(color).copyWith(height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
