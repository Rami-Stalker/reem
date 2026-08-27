import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../../checkout/domain/entities/checkout.dart';
import '../../../checkout/presentation/providers/checkout_providers.dart';

/// The payment rails the platform currently accepts.
///
/// Read from `/payments/methods` — the same endpoint checkout offers her, and
/// deliberately the same one: a settings screen listing a rail that checkout
/// does not offer, or omitting one it does, is worse than no screen at all.
/// The list is the provider registry's, so a rail switched off on the server
/// disappears from both places at once.
final paymentOptionsProvider =
    FutureProvider.autoDispose<List<PaymentMethodOption>>((ref) async {
      final result = await ref
          .watch(checkoutRepositoryProvider)
          .getPaymentMethods();
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw Exception(failure.message),
      };
    });
