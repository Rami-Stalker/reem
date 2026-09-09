import 'dart:math';

import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/checkout/domain/entities/checkout.dart';
import 'package:reem/features/checkout/domain/usecases/checkout_usecases.dart';

class CheckoutState {
  const CheckoutState({
    this.isLoadingOptions = false,
    this.governorates = const [],
    this.paymentMethods = const [],
    this.selectedGovernorate,
    this.quote,
    this.isPlacing = false,
    this.error,
  });

  final bool isLoadingOptions;
  final List<Governorate> governorates;
  final List<PaymentMethodOption> paymentMethods;
  final String? selectedGovernorate;
  final DeliveryQuote? quote;
  final bool isPlacing;
  final String? error;

  CheckoutState copyWith({
    bool? isLoadingOptions,
    List<Governorate>? governorates,
    List<PaymentMethodOption>? paymentMethods,
    String? selectedGovernorate,
    DeliveryQuote? quote,
    bool? isPlacing,
    String? error,
    bool clearError = false,
  }) {
    return CheckoutState(
      isLoadingOptions: isLoadingOptions ?? this.isLoadingOptions,
      governorates: governorates ?? this.governorates,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      selectedGovernorate: selectedGovernorate ?? this.selectedGovernorate,
      quote: quote ?? this.quote,
      isPlacing: isPlacing ?? this.isPlacing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CheckoutController extends StateNotifier<CheckoutState> {
  CheckoutController({
    required GetGovernoratesUseCase getGovernorates,
    required GetPaymentMethodsUseCase getPaymentMethods,
    required GetDeliveryQuoteUseCase getDeliveryQuote,
    required PlaceOrderUseCase placeOrder,
    required VerifyPaymentUseCase verifyPayment,
  })  : _getGovernorates = getGovernorates,
        _getPaymentMethods = getPaymentMethods,
        _getDeliveryQuote = getDeliveryQuote,
        _placeOrder = placeOrder,
        _verifyPayment = verifyPayment,
        super(const CheckoutState());

  final GetGovernoratesUseCase _getGovernorates;
  final GetPaymentMethodsUseCase _getPaymentMethods;
  final GetDeliveryQuoteUseCase _getDeliveryQuote;
  final PlaceOrderUseCase _placeOrder;

  /// Names the basket she is buying, across every attempt at buying it.
  /// Null between orders; see [place].
  String? _orderIntentKey;

  /// 128 bits from the platform's secure source, hex-encoded. Not a UUID
  /// library: the server treats the key as opaque, so a dependency to shape it
  /// would buy nothing.
  String _newIntentKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
  final VerifyPaymentUseCase _verifyPayment;

  Future<void> init() async {
    state = state.copyWith(isLoadingOptions: true, clearError: true);
    final (gov, methods) = await (_getGovernorates(), _getPaymentMethods()).wait;

    final governorates =
        gov is Success<List<Governorate>> ? gov.data : const <Governorate>[];
    final paymentMethods = methods is Success<List<PaymentMethodOption>>
        ? methods.data
        : const <PaymentMethodOption>[];

    state = state.copyWith(
      isLoadingOptions: false,
      governorates: governorates,
      paymentMethods: paymentMethods,
    );
  }

  /// Re-quotes for a place, not just a governorate.
  ///
  /// The district and the rural flag are what pick between Q53's two tiers, so
  /// quoting without them showed her a city-centre price for a village and
  /// charged it too.
  Future<void> selectPlace(
    String governorate,
    Money? subtotal, {
    String? district,
    bool isRural = false,
  }) async {
    state = state.copyWith(selectedGovernorate: governorate);
    final result = await _getDeliveryQuote(
      governorate,
      subtotal,
      district: district,
      isRural: isRural,
    );
    if (result case Success(:final data)) {
      state = state.copyWith(quote: data);
    }
  }

  /// Places the order and, for online gateways, confirms the payment (sandbox).
  Future<PlacedOrder?> place({
    ShippingInput? shipping,
    String? addressId,
    bool saveAddress = false,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
    bool privacyMask = false,
  }) async {
    state = state.copyWith(isPlacing: true, clearError: true);

    // One key per *intent*, not per attempt.
    //
    // Checkout takes seconds on a mobile connection, and a request that times
    // out on the handset may well have succeeded on the server. Without a
    // stable key, tapping again — or a transport-level retry — placed a second
    // order: two stock claims and a courier at her door with two bills. The
    // key is minted once for this basket and kept until an order actually
    // comes back, so every retry of the same intent carries it.
    //
    // It is deliberately *not* cleared on failure: a failed request releases
    // the key on the server, so reusing it is both safe and what makes the
    // retry idempotent if the failure was only in the reply.
    final key = _orderIntentKey ??= _newIntentKey();

    final result = await _placeOrder(
      idempotencyKey: key,
      shipping: shipping,
      addressId: addressId,
      saveAddress: saveAddress,
      paymentMethod: paymentMethod,
      couponCode: couponCode,
      deliveryInstructions: deliveryInstructions,
      notes: notes,
      privacyMask: privacyMask,
    );

    if (result case Error(:final failure)) {
      state = state.copyWith(isPlacing: false, error: failure.message);
      return null;
    }

    final placed = (result as Success<PlacedOrder>).data;
    // The basket became an order. Anything she buys after this is a new
    // intent and must not be answered from this one's record.
    _orderIntentKey = null;
    if (placed.requiresOnlineConfirmation && placed.order.payment != null) {
      await _verifyPayment(placed.order.payment!.id);
    }

    state = state.copyWith(isPlacing: false);
    return placed;
  }
}
