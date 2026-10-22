import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';
import 'package:reem/features/checkout/domain/entities/checkout.dart';
import 'package:reem/features/checkout/presentation/order_labels.dart';
import 'package:reem/features/checkout/presentation/providers/applied_coupon_provider.dart';
import 'package:reem/features/checkout/presentation/providers/checkout_controller.dart';
import 'package:reem/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:reem/features/checkout/presentation/providers/saved_addresses_provider.dart';
import 'package:reem/features/checkout/presentation/widgets/cod_confirmation_sheet.dart';
import 'package:reem/features/policies/presentation/widgets/policy_link.dart';
import 'package:reem/features/settings/domain/entities/address_entity.dart';

/// The last screen before she pays.
///
/// Three things changed here that were each their own small betrayal: the copy
/// was English in an Arabic-first app, the address book she could fill in her
/// settings could not fill a single field of this form, and the district and
/// rural flag that decide Q53's two delivery tiers were never asked for — so
/// every village was quoted, charged and settled at the city-centre price.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _instructions = TextEditingController();
  final _coupon = TextEditingController();

  String? _governorate;
  String? _district;
  bool _isRural = false;
  bool _saveAddress = true;
  String? _paymentMethod;

  /// Q44 — whether the boutique sees her full name.
  bool _privacyMask = false;

  /// Null means "a new address" — the form. Anything else is a saved one.
  String? _selectedAddressId;
  bool _seededFromUser = false;
  bool _seededFromBook = false;

  /// A coupon she already applied from her coupons screen.
  ///
  /// Seeded once, so typing over it wins: the field is hers from that point
  /// on, and re-seeding on every rebuild would fight her keystrokes.
  bool _seededFromAppliedCoupon = false;
  Money? _appliedDiscount;

  /// Reads what the coupons screen validated against this basket.
  ///
  /// Only honoured while the basket still matches the one the discount was
  /// quoted against — [AppliedCouponNotifier] clears it otherwise, because a
  /// figure quoted against a different subtotal is one the order will not
  /// keep.
  void _seedAppliedCoupon() {
    if (_seededFromAppliedCoupon) return;
    final applied = ref.read(appliedCouponProvider);
    if (applied == null) return;

    _seededFromAppliedCoupon = true;
    _coupon.text = applied.code;
    _appliedDiscount = applied.discount;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _city,
      _address,
      _landmark,
      _instructions,
      _coupon,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Money? get _subtotal => ref.read(cartNotifierProvider).cart.summary.subtotal;

  /// Re-quotes whenever the place changes. The fee on screen must be the fee
  /// the server will charge, and that depends on all three of these.
  void _requote() {
    final governorate = _governorate;
    if (governorate == null) return;
    ref
        .read(checkoutControllerProvider.notifier)
        .selectPlace(
          governorate,
          _subtotal,
          district: _district,
          isRural: _isRural,
        );
  }

  void _useSaved(AddressEntity address) {
    setState(() {
      _selectedAddressId = address.id;
      _governorate = address.governorate;
      _district = address.district;
      _isRural = address.isRural;
    });
    _requote();
  }

  void _useNewAddress() {
    setState(() {
      _selectedAddressId = null;
      _governorate = null;
      _district = null;
      _isRural = false;
    });
  }

  Future<void> _place() async {
    final l10n = context.l10n;

    // A saved address is already complete; only the typed one is validated.
    if (_selectedAddressId == null) {
      if (!_formKey.currentState!.validate()) return;
      if (_governorate == null) {
        DsSnackbar.show(
          context,
          message: l10n.checkoutChooseGovernorate,
          type: DsSnackbarType.error,
        );
        return;
      }
    }
    if (_paymentMethod == null) {
      DsSnackbar.show(
        context,
        message: l10n.checkoutChoosePayment,
        type: DsSnackbarType.error,
      );
      return;
    }

    final placed = await ref
        .read(checkoutControllerProvider.notifier)
        .place(
          addressId: _selectedAddressId,
          shipping: _selectedAddressId != null
              ? null
              : ShippingInput(
                  recipientName: _name.text.trim(),
                  recipientPhone: _phone.text.trim(),
                  governorate: _governorate!,
                  district: _district,
                  isRural: _isRural,
                  city: _city.text.trim(),
                  addressLine: _address.text.trim(),
                  landmark: _landmark.text.trim().isEmpty
                      ? null
                      : _landmark.text.trim(),
                ),
          saveAddress: _selectedAddressId == null && _saveAddress,
          paymentMethod: _paymentMethod!,
          privacyMask: _privacyMask,
          couponCode: _coupon.text.trim().isEmpty ? null : _coupon.text.trim(),
          deliveryInstructions: _instructions.text.trim().isEmpty
              ? null
              : _instructions.text.trim(),
        );

    if (!mounted) return;
    if (placed != null) {
      await ref.read(cartNotifierProvider.notifier).refresh();
      if (!mounted) return;

      // A cash order the trust engine held is placed but not yet on its way.
      // The code is collected here, while she is still on the screen that
      // asked for it — sending her to the order detail to discover a blocked
      // order would turn ten seconds of typing into a support ticket.
      if (placed.awaitsCodConfirmation) {
        final confirmed = await showCodConfirmationSheet(
          context,
          orderId: placed.order.id,
          assurance: placed.codAssurance!,
        );
        if (!mounted) return;
        DsSnackbar.show(
          context,
          message: confirmed
              ? context.l10n.codConfirmed
              : context.l10n.codAwaitingBanner,
          type: confirmed ? DsSnackbarType.success : DsSnackbarType.info,
        );
        context.pushReplacement(RoutePaths.orderDetailOf(placed.order.id));
        return;
      }

      DsSnackbar.show(
        context,
        message: context.l10n.checkoutPlacedSuccess(placed.order.number),
        type: DsSnackbarType.success,
      );
      context.pushReplacement(RoutePaths.orderDetailOf(placed.order.id));
    } else {
      final error = ref.read(checkoutControllerProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final state = ref.watch(checkoutControllerProvider);
    final cart = ref.watch(cartNotifierProvider).cart;
    final saved = ref.watch(savedAddressesProvider);

    if (!_seededFromUser) {
      final user = ref.read(authNotifierProvider).user;
      if (user != null) {
        _name.text = user.name;
        _phone.text = user.phone;
        _seededFromUser = true;
      }
    }

    // She may have chosen the offer on her coupons screen; arriving here to an
    // empty field would make her type it again, or wonder whether it took.
    _seedAppliedCoupon();

    // Open on her default address, once, and quote for it straight away — so
    // the delivery fee is on screen before she has touched anything.
    final addresses = saved.asData?.value ?? const <AddressEntity>[];
    if (!_seededFromBook && addresses.isNotEmpty) {
      _seededFromBook = true;
      final first = preselect(addresses);
      if (first != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _useSaved(first));
      }
    }

    final deliveryFee = state.quote?.deliveryFee;
    final subtotal = cart.summary.subtotal;

    // The charged total is NOT computed here. It needs the coupon, the shipping
    // quote and a frozen exchange rate, all of which the server applies when the
    // order is placed — adding two figures in the client would only produce a
    // number that can disagree with the invoice. What is shown before placing
    // is the subtotal and the quoted delivery, each on its own line.

    return ReemScrollPage(
      bottom: _BottomBar(
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        isPlacing: state.isPlacing,
        onPlace: _place,
      ),
      slivers: [
        PremiumAppBar(title: l10n.checkoutTitle, showBack: true),
        if (state.isLoadingOptions)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: DsLoadingIndicator(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.md,
              DsSpacing.lg,
              140,
            ),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label(context, l10n.checkoutDeliveryAddress),

                    if (addresses.isNotEmpty) ...[
                      for (final address in addresses)
                        _AddressOption(
                          address: address,
                          selected: _selectedAddressId == address.id,
                          onTap: () => _useSaved(address),
                        ),
                      _NewAddressOption(
                        selected: _selectedAddressId == null,
                        onTap: _useNewAddress,
                      ),
                      const SizedBox(height: DsSpacing.sm),
                    ],

                    if (_selectedAddressId == null)
                      ..._addressForm(context, state),

                    const SizedBox(height: DsSpacing.sm),
                    _label(context, l10n.checkoutCoupon),
                    DsInputField(
                      controller: _coupon,
                      label: l10n.checkoutCouponOptional,
                    ),
                    if (_appliedDiscount != null) ...[
                      const SizedBox(height: DsSpacing.xs),
                      _AppliedCouponNote(discount: _appliedDiscount!),
                    ],

                    const SizedBox(height: DsSpacing.sm),
                    _label(context, l10n.checkoutPaymentMethod),
                    for (final method in state.paymentMethods)
                      _PaymentTile(
                        option: method,
                        selected: _paymentMethod == method.method,
                        onTap: () =>
                            setState(() => _paymentMethod = method.method),
                      ),

                    // Q44 — «إخفاء هوية الزبونة عن البائعة». The server has
                    // honoured `privacy_mask` since checkout was written and
                    // nothing ever sent it, so a promise the client asked for
                    // could not be made from the phone.
                    const SizedBox(height: DsSpacing.sm),
                    SwitchListTile(
                      value: _privacyMask,
                      onChanged: (value) =>
                          setState(() => _privacyMask = value),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: colors.primary,
                      title: Text(
                        l10n.checkoutPrivacyMask,
                        style: context.dsText.body.semibold.tint(
                          colors.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        l10n.checkoutPrivacyMaskHint,
                        style: context.dsText.caption.tint(
                          colors.onSurfaceVariant,
                        ),
                      ),
                    ),

                    const SizedBox(height: DsSpacing.lg),
                    _label(context, l10n.checkoutOrderSummary),
                    _summaryRow(context, l10n.checkoutSubtotal, subtotal),
                    _summaryRow(context, l10n.checkoutDelivery, deliveryFee),
                    if (cart.willSplit)
                      Padding(
                        padding: const EdgeInsets.only(top: DsSpacing.xs),
                        child: Text(
                          l10n.checkoutSplitNotice(
                            '${cart.sellerGroups.length}',
                          ),
                          style: context.dsText.bodySmall.tint(
                            colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (state.quote != null)
                      Padding(
                        padding: const EdgeInsets.only(top: DsSpacing.xxs),
                        child: Text(
                          _etaLabel(context, state.quote!),
                          style: context.dsText.bodySmall.tint(
                            colors.onSurfaceVariant,
                          ),
                        ),
                      ),

                    // What confirming this order commits her to, said where
                    // she is about to confirm it. The returns policy in
                    // particular belongs here rather than in a settings menu:
                    // «كم يوم عندي أرجّع؟» is a question asked at the till.
                    const SizedBox(height: DsSpacing.lg),
                    _CheckoutPolicyNotice(),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _addressForm(BuildContext context, CheckoutState state) {
    final l10n = context.l10n;
    final governorate = state.governorates
        .where((option) => option.name == _governorate)
        .firstOrNull;
    final districts = governorate?.districts ?? const <GovernorateDistrict>[];

    return [
      DsInputField(
        controller: _name,
        label: l10n.checkoutRecipientName,
        validator: _required,
      ),
      DsInputField(
        controller: _phone,
        label: l10n.checkoutRecipientPhone,
        keyboardType: TextInputType.phone,
        validator: (value) {
          final phone = value?.trim() ?? '';
          if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone)) {
            return l10n.checkoutInvalidPhone;
          }
          return null;
        },
      ),
      DropdownButtonFormField<String>(
        initialValue: _governorate,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.checkoutGovernorate),
        items: [
          for (final option in state.governorates)
            DropdownMenuItem(
              value: option.name,
              child: Text('${option.name} · ${option.fee.format()}'),
            ),
        ],
        onChanged: (value) {
          setState(() {
            _governorate = value;
            // A district from the previous governorate would quote a zone that
            // does not exist, so the choice below starts again.
            _district = null;
            _isRural = false;
          });
          _requote();
        },
      ),
      const SizedBox(height: DsSpacing.md),

      // Q53's two tiers, picked by choosing a district rather than by asking
      // her to know which tier she lives in. Districts come from the shipping
      // zones themselves, each carrying its own rural flag and fee.
      if (districts.isNotEmpty)
        DropdownButtonFormField<String>(
          initialValue: _district,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.checkoutDistrict),
          items: [
            for (final district in districts)
              DropdownMenuItem(
                value: district.name,
                child: Text('${district.name} · ${district.fee.format()}'),
              ),
          ],
          onChanged: (value) {
            final chosen = districts
                .where((district) => district.name == value)
                .firstOrNull;
            setState(() {
              _district = value;
              _isRural = chosen?.isRural ?? false;
            });
            _requote();
          },
        )
      else
        // No districts configured for this governorate: she says it herself.
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _isRural,
          title: Text(l10n.checkoutRural),
          subtitle: Text(l10n.checkoutRuralHint),
          onChanged: (value) {
            setState(() => _isRural = value);
            _requote();
          },
        ),
      const SizedBox(height: DsSpacing.md),

      DsInputField(
        controller: _city,
        label: l10n.checkoutCity,
        validator: _required,
      ),
      DsInputField(
        controller: _address,
        label: l10n.checkoutAddressLine,
        hint: l10n.checkoutAddressLineHint,
        maxLines: 2,
        validator: _required,
      ),
      DsInputField(
        controller: _landmark,
        label: l10n.checkoutLandmark,
        hint: l10n.checkoutLandmarkHint,
      ),
      DsInputField(
        controller: _instructions,
        label: l10n.checkoutInstructions,
        hint: l10n.checkoutInstructionsHint,
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: _saveAddress,
        onChanged: (value) => setState(() => _saveAddress = value ?? false),
        title: Text(l10n.checkoutSaveAddress, style: context.dsText.bodySmall),
      ),
    ];
  }

  String? _required(String? value) => (value == null || value.trim().isEmpty)
      ? context.l10n.checkoutRequired
      : null;

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: DsSpacing.sm, bottom: DsSpacing.xs),
    child: Text(
      text,
      style: context.dsText.tileTitle.semibold.tint(context.dsColors.onSurface),
    ),
  );

  Widget _summaryRow(BuildContext context, String label, Money? value) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
      child: Row(
        children: [
          Text(
            label,
            style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            value?.format() ?? '—',
            style: context.dsText.body.semibold.tint(colors.onSurface),
          ),
        ],
      ),
    );
  }
}

/// One saved address, offered rather than retyped.
class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final AddressEntity address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DsRadius.lg),
          child: Ink(
            padding: const EdgeInsets.all(DsSpacing.md),
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : colors.card,
              borderRadius: BorderRadius.circular(DsRadius.lg),
              border: Border.all(
                color: selected ? colors.primary : colors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            address.label,
                            style: context.dsText.body.semibold.tint(
                              colors.onSurface,
                            ),
                          ),
                          if (address.isDefault) ...[
                            const SizedBox(width: DsSpacing.xs),
                            Icon(Icons.star, size: 13, color: colors.primary),
                          ],
                        ],
                      ),
                      DsGaps.vXxxs,
                      Text(
                        address.summary,
                        style: context.dsText.bodySmall
                            .tint(colors.onSurfaceVariant)
                            .copyWith(height: 1.5),
                      ),
                      Text(
                        address.recipientName,
                        style: context.dsText.caption.tint(
                          colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewAddressOption extends StatelessWidget {
  const _NewAddressOption({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(DsSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DsRadius.lg),
            border: Border.all(
              color: selected ? colors.primary : colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: DsSpacing.sm),
              Icon(
                Icons.add_location_alt_outlined,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: DsSpacing.xs),
              Text(
                context.l10n.checkoutNewAddress,
                style: context.dsText.body.medium.tint(colors.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One way to pay (Q51 P1). The label comes from the server, so a rail added
/// later needs no client release to appear.
class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethodOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DsRadius.lg),
          child: Ink(
            padding: const EdgeInsets.all(DsSpacing.md),
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : colors.card,
              borderRadius: BorderRadius.circular(DsRadius.lg),
              border: Border.all(
                color: selected ? colors.primary : colors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // The app's own name for a known method, so checkout
                        // and the order page agree («محفظة ريم»); the
                        // server's label for one the app does not know yet.
                        switch (context.l10n.paymentMethodName(option.method)) {
                          final name when name != option.method => name,
                          _ => option.label,
                        },
                        style: context.dsText.body.tint(colors.onSurface),
                      ),
                      // Who to pay, before she commits to the order — not
                      // after, when she is already standing at the office.
                      if (selected && (option.instructions ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: DsSpacing.xs),
                          child: Text(
                            option.instructions!,
                            style: context.dsText.bodySmall.tint(
                              colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pinned footer.
///
/// It shows the two figures the server has actually quoted and says plainly
/// that the total is computed when the order is placed. Adding them here would
/// produce a number that can disagree with the invoice — the coupon, the
/// rounding policy (Q48) and the frozen exchange rate all apply server-side.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.subtotal,
    required this.deliveryFee,
    required this.isPlacing,
    required this.onPlace,
  });

  final Money? subtotal;
  final Money? deliveryFee;
  final bool isPlacing;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Both figures give way before the bar does. A basket total
                // beside a delivery fee, next to a fixed-width button, ran off
                // the edge on a narrow phone — the price is what must survive,
                // so it is the wider of the two flexes.
                Row(
                  children: [
                    Flexible(
                      flex: 3,
                      child: Text(
                        subtotal?.format() ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.tileTitle.bold.tint(
                          colors.onSurface,
                        ),
                      ),
                    ),
                    if (deliveryFee != null) ...[
                      const SizedBox(width: DsSpacing.xs),
                      Flexible(
                        flex: 2,
                        child: Text(
                          '+ ${deliveryFee!.format()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.bodySmall.tint(
                            colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  l10n.checkoutTotalPending,
                  style: context.dsText.caption.tint(colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          SizedBox(
            width: 160,
            child: PrimaryButton(
              label: l10n.checkoutPlaceOrder,
              isLoading: isPlacing,
              onPressed: isPlacing ? null : onPlace,
            ),
          ),
        ],
      ),
    );
  }
}

/// The terms this order is placed under, and the way back to them.
class _CheckoutPolicyNotice extends StatelessWidget {
  const _CheckoutPolicyNotice();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PolicyNotice(
      message: l10n.checkoutPolicyNotice,
      links: [
        PolicyLink(label: l10n.policiesLinkReturns, slug: PolicySlugs.returns),
        PolicyLink(
          label: l10n.policiesLinkCustomerTerms,
          slug: PolicySlugs.customerTerms,
        ),
      ],
    );
  }
}

/// Confirms the coupon she applied before she got here, and what it is worth.
///
/// The figure is the server's, quoted against this exact basket by
/// `POST /coupons/validate` — not arithmetic done here, which could disagree
/// with the invoice the order raises.
class _AppliedCouponNote extends StatelessWidget {
  const _AppliedCouponNote({required this.discount});

  final Money discount;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: colors.success),
        const SizedBox(width: DsSpacing.sm),
        Text(
          context.l10n.checkoutCouponApplied(discount.format()),
          style: context.dsText.caption.semibold.tint(colors.success),
        ),
      ],
    );
  }
}

/// «يصلكِ اليوم بإذن الله» / «خلال يومين».
String _etaLabel(BuildContext context, DeliveryQuote quote) {
  if (quote.etaHoursMax <= 12) return context.l10n.checkoutEtaToday;
  final days = (quote.etaHoursMax / 24).ceil();
  return context.l10n.checkoutEtaDays(days < 1 ? 1 : days);
}
