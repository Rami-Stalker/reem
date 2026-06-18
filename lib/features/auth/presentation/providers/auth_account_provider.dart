import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';

import 'auth_provider.dart';

final authAccountProvider = FutureProvider<AuthAccount>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getAccount();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw Exception(failure.message),
  };
});

final accountDevicesProvider = FutureProvider<List<AccountDevice>>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getDevices();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw Exception(failure.message),
  };
});

final accountSessionsProvider =
    FutureProvider<List<AccountSession>>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getSessions();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw Exception(failure.message),
  };
});

final sellerVerificationProvider =
    FutureProvider<SellerVerification?>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getSellerVerification();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw Exception(failure.message),
  };
});
