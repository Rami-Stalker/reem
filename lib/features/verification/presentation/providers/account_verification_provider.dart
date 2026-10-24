import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/verification/data/datasources/account_verification_datasource.dart';
import 'package:ohara/features/verification/domain/entities/account_verification.dart';

final accountVerificationDataSourceProvider =
    Provider<AccountVerificationDataSource>(
      (ref) => AccountVerificationDataSource(ref.watch(dioProvider)),
    );

/// Her claim on the badge, or null when she has never filed one.
///
/// Rebuilt when the account changes — a claim belongs to one woman and the
/// previous one's status must not survive a switch.
final accountVerificationProvider =
    FutureProvider.autoDispose<AccountVerification?>((ref) async {
      ref.watch(authNotifierProvider.select((s) => s.user?.id));
      return ref.watch(accountVerificationDataSourceProvider).mine();
    });
