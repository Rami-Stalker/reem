import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/checkout.dart';
import '../../domain/usecases/checkout_usecases.dart';

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

  Future<void> selectGovernorate(String name, double subtotal) async {
    state = state.copyWith(selectedGovernorate: name);
    final result = await _getDeliveryQuote(name, subtotal);
    if (result case Success(:final data)) {
      state = state.copyWith(quote: data);
    }
  }

  /// Places the order and, for online gateways, confirms the payment (sandbox).
  Future<PlacedOrder?> place({
    required ShippingInput shipping,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
  }) async {
    state = state.copyWith(isPlacing: true, clearError: true);
    final result = await _placeOrder(
      shipping: shipping,
      paymentMethod: paymentMethod,
      couponCode: couponCode,
      deliveryInstructions: deliveryInstructions,
      notes: notes,
    );

    if (result case Error(:final failure)) {
      state = state.copyWith(isPlacing: false, error: failure.message);
      return null;
    }

    final placed = (result as Success<PlacedOrder>).data;
    if (placed.requiresOnlineConfirmation && placed.order.payment != null) {
      await _verifyPayment(placed.order.payment!.id);
    }

    state = state.copyWith(isPlacing: false);
    return placed;
  }
}
