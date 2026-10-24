import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/errors/failure_exception.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/auth/domain/entities/auth_account.dart';

import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';

final authAccountProvider = FutureProvider<AuthAccount>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getAccount();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw FailureException(failure),
  };
});

final accountDevicesProvider = FutureProvider<List<AccountDevice>>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getDevices();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw FailureException(failure),
  };
});

final accountSessionsProvider =
    FutureProvider<List<AccountSession>>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getSessions();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw FailureException(failure),
  };
});

final sellerVerificationProvider =
    FutureProvider<SellerVerification?>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getSellerVerification();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw FailureException(failure),
  };
});
