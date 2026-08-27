import 'package:reem/core/result/result.dart';

import '../../../../core/shared/value_objects/money.dart';
import '../entities/checkout.dart';
import '../entities/order.dart';
import '../repositories/checkout_repository.dart';

class GetGovernoratesUseCase {
  const GetGovernoratesUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<List<Governorate>>> call() => _repo.getGovernorates();
}

class GetDeliveryQuoteUseCase {
  const GetDeliveryQuoteUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<DeliveryQuote>> call(
    String governorate,
    Money? subtotal, {
    String? district,
    bool isRural = false,
  }) => _repo.getDeliveryQuote(
    governorate: governorate,
    subtotal: subtotal,
    district: district,
    isRural: isRural,
  );
}

class GetPaymentMethodsUseCase {
  const GetPaymentMethodsUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<List<PaymentMethodOption>>> call() => _repo.getPaymentMethods();
}

class PlaceOrderUseCase {
  const PlaceOrderUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<PlacedOrder>> call({
    ShippingInput? shipping,
    String? addressId,
    bool saveAddress = false,
    required String paymentMethod,
    String? couponCode,
    String? deliveryInstructions,
    String? notes,
  }) =>
      _repo.placeOrder(
        shipping: shipping,
        addressId: addressId,
        saveAddress: saveAddress,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        deliveryInstructions: deliveryInstructions,
        notes: notes,
      );
}

class VerifyPaymentUseCase {
  const VerifyPaymentUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<OrderPayment>> call(String paymentId) =>
      _repo.verifyPayment(paymentId);
}

class GetOrdersUseCase {
  const GetOrdersUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<List<OrderSummary>>> call({int page = 1, int limit = 20}) =>
      _repo.getOrders(page: page, limit: limit);
}

class GetOrderUseCase {
  const GetOrderUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<OrderDetail>> call(String id) => _repo.getOrder(id);
}

class CancelOrderUseCase {
  const CancelOrderUseCase(this._repo);
  final CheckoutRepository _repo;
  Future<Result<OrderDetail>> call(String id) => _repo.cancelOrder(id);
}
