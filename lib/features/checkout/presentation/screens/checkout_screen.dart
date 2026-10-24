import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/analytics/analytics_tracker.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/location/picked_place.dart';
import 'package:ohara/core/location/presentation/map_location_field.dart';
import 'package:ohara/core/location/syria_governorates.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/cart/presentation/providers/cart_providers.dart';
import 'package:ohara/features/checkout/domain/entities/checkout.dart';
import 'package:ohara/features/checkout/presentation/order_labels.dart';
import 'package:ohara/features/checkout/presentation/providers/applied_coupon_provider.dart';
import 'package:ohara/features/checkout/presentation/providers/checkout_controller.dart';
import 'package:ohara/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:ohara/features/checkout/presentation/providers/saved_addresses_provider.dart';
import 'package:ohara/features/checkout/presentation/widgets/cod_confirmation_sheet.dart';
import 'package:ohara/features/policies/presentation/widgets/policy_link.dart';
import 'package:ohara/features/settings/domain/entities/address_entity.dart';

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

  /// The pin she dropped on the map, when she chose the map over typing.
  PickedPlace? _pin;

  /// Whether the fields the pin filled are open for her to correct. Closed
  /// once the map has filled them all — that is the point of the map — and
  /// forced open when it could not, so a required field is never hidden.
  bool _detailsOpen = true;

  /// The map's governorate is not one the platform delivers to by that name.
  bool _governorateUnmatched = false;
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportCheckoutStart());
  }

  /// The funnel's third step, once per visit: one event per boutique in the
  /// basket, the same unit the server counts placed orders in, so a seller's
  /// own funnel adds up. Guests are skipped — the event belongs to an account.
  void _reportCheckoutStart() {
    if (!mounted) return;
    if (ref.read(authNotifierProvider).user == null) return;
    final tracker = ref.read(analyticsTrackerProvider);
    final groups = ref.read(cartNotifierProvider).cart.sellerGroups;
    for (final group in groups) {
      tracker.track(
        'CHECKOUT_START',
        sellerId: group.sellerId,
        source: 'checkout',
      );
    }
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
    // A pin she dropped before looking at a saved address still stands.
    if (_pin != null) _applyPin(_pin);
  }

  /// Fills the form from the map, the way she would have typed it.
  ///
  /// Every field it fills stays editable: OpenStreetMap knows Damascus street
  /// by street and a village by little more than its name, so the map is a
  /// fast first draft, not the last word.
  void _applyPin(PickedPlace? place) {
    if (place == null) {
      setState(() {
        _pin = null;
        _detailsOpen = true;
        _governorateUnmatched = false;
      });
      return;
    }

    final options = ref.read(checkoutControllerProvider).governorates;
    final governorateName = matchPlaceName(
      options.map((option) => option.name),
      [place.governorate, place.city],
    );
    final governorate = options
        .where((option) => option.name == governorateName)
        .firstOrNull;
    final districtName = governorate == null
        ? null
        : matchPlaceName(
            governorate.districts.map((district) => district.name),
            [place.district, place.neighbourhood, place.city],
          );
    final district = governorate?.districts
        .where((option) => option.name == districtName)
        .firstOrNull;

    final city = place.city ?? place.district ?? governorateName;
    final line = place.addressLine;

    setState(() {
      _pin = place;
      _governorateUnmatched = governorateName == null;
      if (governorateName != null) {
        _governorate = governorateName;
        _district = district?.name;
        _isRural = district?.isRural ?? place.isRural;
      }
      if (city != null && city.trim().isNotEmpty) _city.text = city;
      if (line != null && line.trim().isNotEmpty) _address.text = line;
      _detailsOpen =
          governorateName == null ||
          _city.text.trim().isEmpty ||
          _address.text.trim().isEmpty;
    });
    _requote();
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
                  latitude: _pin?.latitude,
                  longitude: _pin?.longitude,
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

    // A saved address is complete as it stands; a new one once the place that
    // prices the delivery has been chosen.
    final addressDone = _selectedAddressId != null || _governorate != null;

    // The charged total is NOT computed here. It needs the coupon, the shipping
    // quote and a frozen exchange rate, all of which the server applies when the
    // order is placed — adding two figures in the client would only produce a
    // number that can disagree with the invoice. What is shown before placing
    // is the subtotal and the quoted delivery, each on its own line.

    return OharaScrollPage(
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
              DsSpacing.lg,
              DsSpacing.lg,
              // The ticket floating over the foot of the page is cleared by
              // `OharaScrollPage` itself, measured rather than guessed.
              DsSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    JourneyStep(
                      number: 1,
                      title: l10n.checkoutDeliveryAddress,
                      complete: addressDone,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                            if (_selectedAddressId == null) DsGaps.vMd,
                          ],
                          if (_selectedAddressId == null)
                            ..._addressForm(context, state),
                        ],
                      ),
                    ),

                    JourneyStep(
                      number: 2,
                      title: l10n.checkoutCoupon,
                      complete: _appliedDiscount != null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PerforatedTicket(
                            active: _appliedDiscount != null,
                            child: DsInputField(
                              controller: _coupon,
                              hint: l10n.checkoutCouponOptional,
                              variant: DsFieldVariant.bare,
                              textCapitalization: TextCapitalization.characters,
                              autocorrect: false,
                            ),
                          ),
                          if (_appliedDiscount != null) ...[
                            DsGaps.vXs,
                            _AppliedCouponNote(discount: _appliedDiscount!),
                          ],
                        ],
                      ),
                    ),

                    JourneyStep(
                      number: 3,
                      title: l10n.checkoutPaymentMethod,
                      complete: _paymentMethod != null,
                      child: Column(
                        children: [
                          for (final method in state.paymentMethods)
                            _PaymentTile(
                              option: method,
                              selected: _paymentMethod == method.method,
                              onTap: () => setState(
                                () => _paymentMethod = method.method,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Q44 — «إخفاء هوية الزبونة عن البائعة». The server has
                    // honoured `privacy_mask` since checkout was written and
                    // nothing ever sent it, so a promise the client asked for
                    // could not be made from the phone.
                    JourneyStep(
                      number: 4,
                      title: l10n.checkoutStepPrivacy,
                      // A choice either way; it is behind her once she has
                      // chosen how to pay.
                      complete: _paymentMethod != null,
                      child: _PrivacyCard(
                        value: _privacyMask,
                        onChanged: (value) =>
                            setState(() => _privacyMask = value),
                      ),
                    ),

                    JourneyStep(
                      number: 5,
                      title: l10n.checkoutOrderSummary,
                      complete: addressDone && _paymentMethod != null,
                      isLast: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ReceiptCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _summaryRow(
                                  context,
                                  l10n.checkoutSubtotal,
                                  subtotal,
                                ),
                                _summaryRow(
                                  context,
                                  l10n.checkoutDelivery,
                                  deliveryFee,
                                ),
                                if (_appliedDiscount != null)
                                  _summaryRow(
                                    context,
                                    l10n.checkoutCoupon,
                                    _appliedDiscount,
                                    minus: true,
                                  ),
                                DsGaps.vSm,
                                const DashedRule(),
                                DsGaps.vSm,
                                // The total is the server's to compute, when
                                // the order is placed — said rather than
                                // guessed (see the note above `return`).
                                Text(
                                  l10n.checkoutTotalPending,
                                  style: context.dsText.caption,
                                ),
                                if (cart.willSplit) ...[
                                  DsGaps.vXs,
                                  _ReceiptNote(
                                    icon: Icons.call_split_rounded,
                                    text: l10n.checkoutSplitNotice(
                                      '${cart.sellerGroups.length}',
                                    ),
                                  ),
                                ],
                                if (state.quote != null) ...[
                                  DsGaps.vXs,
                                  _ReceiptNote(
                                    icon: Icons.local_shipping_rounded,
                                    text: _etaLabel(context, state.quote!),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // What confirming this order commits her to, said
                          // where she is about to confirm it. The returns
                          // policy in particular belongs here rather than in a
                          // settings menu: «كم يوم عندي أرجّع؟» is a question
                          // asked at the till.
                          DsGaps.vLg,
                          const _CheckoutPolicyNotice(),
                        ],
                      ),
                    ),
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
    final pinned = _pin != null;
    final showPlaceFields = !pinned || _detailsOpen;

    return [
      // The quick way: one pin instead of four fields.
      MapLocationField(
        value: _pin,
        onChanged: _applyPin,
        initialGovernorate: _governorate,
        placeLabel: l10n.mapPickerDeliveryHere,
      ),
      if (pinned)
        _PinFilledNote(
          unmatched: _governorateUnmatched,
          open: _detailsOpen,
          onToggle: () => setState(() => _detailsOpen = !_detailsOpen),
        )
      else
        const MapOrTypeDivider(),

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
      // Folded away once the map has filled it; never while it is empty.
      if (showPlaceFields) ...[
        DropdownButtonFormField<String>(
          // Keyed by the value so a governorate the map chose replaces the
          // one on screen: a form field reads its initial value only once.
          key: ValueKey('governorate-$_governorate'),
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
              // A district from the previous governorate would quote a zone
              // that does not exist, so the choice below starts again.
              _district = null;
              _isRural = false;
            });
            _requote();
          },
        ),
        const SizedBox(height: DsSpacing.md),
      ],

      // Q53's two tiers, picked by choosing a district rather than by asking
      // her to know which tier she lives in. Districts come from the shipping
      // zones themselves, each carrying its own rural flag and fee.
      if (districts.isNotEmpty)
        DropdownButtonFormField<String>(
          key: ValueKey('district-$_governorate-$_district'),
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

      if (showPlaceFields) ...[
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
      ],
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

  Widget _summaryRow(
    BuildContext context,
    String label,
    Money? value, {
    bool minus = false,
  }) {
    final colors = context.dsColors;
    final figure = value?.format() ?? '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
      child: Row(
        children: [
          Text(label, style: context.dsText.body.tint(colors.onSurfaceVariant)),
          const Spacer(),
          Text(
            minus && value != null ? '− $figure' : figure,
            style: context.dsText.body.semibold.tabular.tint(
              minus ? colors.success : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// Under the map preview: what the pin filled in, and the way to check it.
class _PinFilledNote extends StatelessWidget {
  const _PinFilledNote({
    required this.unmatched,
    required this.open,
    required this.onToggle,
  });

  final bool unmatched;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    final tone = unmatched ? colors.warning : colors.success;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.sm, bottom: DsSpacing.md),
      child: Row(
        children: [
          Icon(
            unmatched
                ? Icons.error_outline_rounded
                : Icons.auto_awesome_rounded,
            size: DsSizes.iconXs,
            color: tone,
          ),
          DsGaps.hXs,
          Expanded(
            child: Text(
              unmatched
                  ? l10n.locationFieldGovernorateUnmatched
                  : l10n.locationFieldFilled,
              style: context.dsText.caption.tint(
                unmatched ? tone : colors.onSurfaceVariant,
              ),
            ),
          ),
          if (!unmatched)
            TextButton(
              onPressed: onToggle,
              child: Text(
                open
                    ? l10n.locationFieldHideDetails
                    : l10n.locationFieldEditDetails,
              ),
            ),
        ],
      ),
    );
  }
}

/// A choice on the journey: a medallion, the words, and a ring that fills —
/// lit with a gradient rim and a soft glow once chosen.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: DsMotion.moderate,
            curve: DsMotion.gentle,
            padding: const EdgeInsets.all(DsSpacing.md),
            decoration: BoxDecoration(
              borderRadius: DsRadius.borderXl,
              color: selected
                  ? Color.alphaBlend(
                      colors.primary.withValues(alpha: 0.07),
                      isDark ? colors.surfaceElevated : colors.surface,
                    )
                  : (isDark ? colors.surfaceElevated : colors.surface)
                        .withValues(alpha: 0.85),
              border: Border.all(
                color: selected ? colors.primary : colors.border,
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? context.glowShadow(colors.primary, blur: 18, alpha: 0.18)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: DsMotion.moderate,
                  width: DsSizes.avatarMd,
                  height: DsSizes.avatarMd,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? context.primaryGradient : null,
                    color: selected ? null : colors.primaryContainer,
                  ),
                  child: Icon(
                    icon,
                    size: DsSizes.iconSm,
                    color: selected ? DsColors.onMedia : colors.primary,
                  ),
                ),
                DsGaps.hSm,
                Expanded(child: child),
                DsGaps.hXs,
                _Ring(on: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return AnimatedContainer(
      duration: DsMotion.moderate,
      width: DsSizes.iconMd,
      height: DsSizes.iconMd,
      padding: const EdgeInsets.all(DsSpacing.xxs),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: on ? colors.primary : colors.outline,
          width: 1.6,
        ),
      ),
      child: AnimatedScale(
        scale: on ? 1 : 0,
        duration: DsMotion.moderate,
        curve: DsMotion.softSpring,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: context.primaryGradient,
          ),
        ),
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
    return _ChoiceCard(
      icon: address.isDefault ? Icons.home_rounded : Icons.place_rounded,
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  address.label,
                  style: context.dsText.body.semibold.tint(colors.onSurface),
                ),
              ),
              if (address.isDefault) ...[
                DsGaps.hXs,
                Icon(
                  Icons.star_rounded,
                  size: DsSizes.iconXs,
                  color: colors.rating,
                ),
              ],
              // Pinned on the map: the courier is taken to the door.
              if (address.hasPin) ...[
                DsGaps.hXs,
                Icon(
                  Icons.location_on_rounded,
                  size: DsSizes.iconXs,
                  color: colors.primary,
                ),
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
          Text(address.recipientName, style: context.dsText.caption),
        ],
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
    return _ChoiceCard(
      icon: Icons.add_location_alt_rounded,
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: DsSpacing.sm),
        child: Text(
          context.l10n.checkoutNewAddress,
          style: context.dsText.body.semibold.tint(context.dsColors.onSurface),
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

  static IconData _iconOf(String method) => switch (method) {
    'cod' || 'courier_collect' => Icons.payments_rounded,
    'syriatel_cash' || 'mtn_cash' || 'sham_cash' => Icons.phone_iphone_rounded,
    'bank_card' => Icons.credit_card_rounded,
    'bank_transfer' => Icons.account_balance_rounded,
    'hawala' => Icons.currency_exchange_rounded,
    'platform_wallet' => Icons.account_balance_wallet_rounded,
    _ => Icons.payments_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return _ChoiceCard(
      icon: _iconOf(option.method),
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: DsSpacing.sm),
            child: Text(
              // The app's own name for a known method, so checkout and the
              // order page agree («محفظة أوهارا»); the server's label for one the
              // app does not know yet.
              switch (context.l10n.paymentMethodName(option.method)) {
                final name when name != option.method => name,
                _ => option.label,
              },
              style: context.dsText.body.semibold.tint(colors.onSurface),
            ),
          ),
          // Who to pay, before she commits to the order — not after, when she
          // is already standing at the office.
          AnimatedSize(
            duration: DsMotion.moderate,
            curve: DsMotion.gentle,
            alignment: AlignmentDirectional.topStart,
            child: selected && (option.instructions ?? '').isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: DsSpacing.xs),
                    child: Text(
                      option.instructions!,
                      style: context.dsText.bodySmall.tint(
                        colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Q44, as a card: a veil over her name, and the switch that draws it.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;
    return AnimatedContainer(
      duration: DsMotion.moderate,
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXl,
        color: value
            ? colors.secondaryContainer.withValues(alpha: 0.6)
            : colors.surface.withValues(alpha: 0.85),
        border: Border.all(color: value ? colors.secondary : colors.border),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: DsMotion.moderate,
            child: Icon(
              value ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              key: ValueKey(value),
              color: value ? colors.secondary : colors.onSurfaceVariant,
            ),
          ),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.checkoutPrivacyMask,
                  style: context.dsText.body.semibold.tint(colors.onSurface),
                ),
                Text(
                  l10n.checkoutPrivacyMaskHint,
                  style: context.dsText.caption,
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colors.secondary,
          ),
        ],
      ),
    );
  }
}

/// A small line on the receipt with its own mark.
class _ReceiptNote extends StatelessWidget {
  const _ReceiptNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: DsSizes.iconXs, color: colors.primary),
        DsGaps.hXs,
        Expanded(
          child: Text(
            text,
            style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// The pinned footer, on the floating ticket.
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

    return TicketBar(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The price must survive a narrow phone whole, so it shrinks
                // to fit rather than losing digits to an ellipsis; the delivery
                // fee takes the line under it.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    subtotal?.format() ?? '—',
                    style: context.dsText.tileTitle.bold.tabular.tint(
                      colors.onSurface,
                    ),
                  ),
                ),
                if (deliveryFee != null)
                  Text(
                    '+ ${deliveryFee!.format()} ${l10n.checkoutDelivery}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.bodySmall.tint(
                      colors.onSurfaceVariant,
                    ),
                  ),
                Text(l10n.checkoutTotalPending, style: context.dsText.caption),
              ],
            ),
          ),
          DsGaps.hSm,
          Expanded(
            child: PrimaryButton(
              label: l10n.checkoutPlaceOrder,
              icon: Icons.lock_rounded,
              size: DsButtonSize.md,
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
