import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/result/result.dart';
import '../../../../core/shared/value_objects/money.dart';
import '../../../cart/presentation/providers/cart_providers.dart';
import '../../../checkout/presentation/providers/applied_coupon_provider.dart';
import 'settings_provider.dart';

/// Why a coupon could not be applied from this screen.
///
/// Separated from the server's refusals because they are answered differently:
/// an empty basket is not the coupon's fault and has no message worth quoting,
/// it needs a nudge towards shopping.
enum CouponApplyIssue { emptyBasket, unknownSubtotal }

class CouponApplyResult {
  const CouponApplyResult._({this.issue, this.serverMessage, this.discount});

  const CouponApplyResult.applied(Money discount)
    : this._(discount: discount);
  const CouponApplyResult.blocked(CouponApplyIssue issue)
    : this._(issue: issue);
  const CouponApplyResult.refused(String message)
    : this._(serverMessage: message);

  final CouponApplyIssue? issue;

  /// The server's own sentence — below the minimum, already spent, not for
  /// this account. Worth quoting verbatim: it names the condition she can
  /// actually do something about.
  final String? serverMessage;

  final Money? discount;

  bool get didApply => discount != null;
}

/// Applying a coupon to her live basket.
///
/// The validation is the server's, against the real subtotal, before she ever
/// reaches checkout — so «حد أدنى ٥٠٬٠٠٠» is answered here, on the screen where
/// she chose the offer, rather than by an order that fails at the end.
class CouponApplyNotifier extends StateNotifier<String?> {
  CouponApplyNotifier(this._ref) : super(null);

  final Ref _ref;

  /// The code currently being validated, so one ticket can show a spinner
  /// without freezing the rest of the list.
  String? get pending => state;

  Future<CouponApplyResult> apply(String code) async {
    final cart = _ref.read(cartNotifierProvider).cart;
    if (cart.isEmpty) {
      return const CouponApplyResult.blocked(CouponApplyIssue.emptyBasket);
    }

    final subtotal = cart.summary.subtotal;
    if (subtotal == null) {
      // A multi-currency basket has no single figure to validate against, and
      // guessing one would quote a discount against the wrong money.
      return const CouponApplyResult.blocked(CouponApplyIssue.unknownSubtotal);
    }

    state = code;
    final result = await _ref
        .read(settingsRepositoryProvider)
        .validateCoupon(
          code: code,
          subtotal: subtotal.approximateValue,
          currency: subtotal.currency.wire,
        );
    if (!mounted) return const CouponApplyResult.refused('');
    state = null;

    return switch (result) {
      Success(:final data) => () {
        _ref.read(appliedCouponProvider.notifier).apply(data, subtotal);
        return CouponApplyResult.applied(data.discount);
      }(),
      Error(:final failure) => CouponApplyResult.refused(
        failure.displayMessage,
      ),
    };
  }
}

final couponApplyProvider =
    StateNotifierProvider<CouponApplyNotifier, String?>(
      CouponApplyNotifier.new,
    );
