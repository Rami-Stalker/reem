import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/errors/failure_exception.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/settings/domain/entities/coupon_entity.dart';
import 'package:ohara/features/settings/presentation/providers/settings_provider.dart';

/// Her redeemable coupons, on their own.
///
/// Deliberately not read off the aggregate settings notifier: that one loads
/// addresses, notifications and rewards in the same pass, so opening the
/// coupons screen would wait on three requests it does not use — and would
/// show her stale offers whenever some other screen had loaded it earlier.
final couponsProvider = FutureProvider.autoDispose<List<CouponEntity>>((
  ref,
) async {
  final result = await ref.watch(getCouponsUseCaseProvider)();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw FailureException(failure),
  };
});
