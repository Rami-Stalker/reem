// Why «عناويني», «مقاساتي» and «تقييماتي» stopped working on a real phone
// while every screen rendered fine with sample data.
//
//   flutter test test/profile_pages_reliability_test.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/network/interceptors/auth_interceptor.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/security/device_identity_service.dart';
import 'package:ohara/core/storage/secure_storage_service.dart';
import 'package:ohara/features/auth/domain/repositories/auth_repository.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/widgets/step_up_sheet.dart';
import 'package:ohara/features/settings/domain/entities/address_draft.dart';
import 'package:ohara/features/settings/domain/entities/address_entity.dart';
import 'package:ohara/features/settings/domain/repositories/settings_repository.dart';
import 'package:ohara/features/settings/presentation/providers/address_book_notifier.dart';

class _MemStorage extends SecureStorageService {
  final values = <String, String>{};
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> deleteAll() async => values.clear();
}

AddressEntity _address(String id, {bool isDefault = false}) => AddressEntity(
  id: id,
  label: id,
  recipientName: 'مها',
  recipientPhone: '0999999999',
  governorate: 'دمشق',
  city: 'دمشق',
  addressLine: 'شارع $id',
  isDefault: isDefault,
);

const _draft = AddressDraft(
  label: 'العمل',
  recipientName: 'مها',
  recipientPhone: '0999999999',
  governorate: 'دمشق',
  city: 'دمشق',
  addressLine: 'شارع بغداد',
);

/// A server that saves the address and then fails the read that follows —
/// a slow line, an instance waking up.
class _FlakyBook implements SettingsRepository {
  _FlakyBook(this.saved);

  final List<AddressEntity> saved;
  bool readFails = false;

  @override
  Future<Result<List<AddressEntity>>> getAddresses() async => readFails
      ? const Error(NetworkFailure('offline'))
      : Success(List.of(saved));

  @override
  Future<Result<AddressEntity>> createAddress(AddressDraft draft) async =>
      Success(_address('new'));

  @override
  Future<Result<AddressEntity>> setDefaultAddress(String id) async =>
      Success(_address(id, isDefault: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ReenrollingAuth implements AuthRepository {
  int reenrolments = 0;

  @override
  Future<Result<void>> reenrolDevice() async {
    reenrolments++;
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers every request with [status] and [body].
class _Answer implements HttpClientAdapter {
  _Answer(this.status, this.body);

  final int status;
  final Map<String, Object?> body;
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the address book', () {
    test('a saved address appears even when the reload fails', () async {
      final repository = _FlakyBook([_address('home', isDefault: true)]);
      final book = AddressBookNotifier(repository);
      await book.load();

      repository.readFails = true;
      final failure = await book.create(_draft);

      expect(failure, isNull);
      expect(book.state.addresses.map((a) => a.id), ['home', 'new']);
      expect(book.state.isSaving, isFalse);
    });

    test('making one address the default un-defaults the others', () async {
      final repository = _FlakyBook([
        _address('home', isDefault: true),
        _address('work'),
      ])..readFails = false;
      final book = AddressBookNotifier(repository);
      await book.load();
      repository.readFails = true;

      await book.makeDefault('work');

      expect(book.state.addresses.first.id, 'work');
      expect(
        book.state.addresses.where((a) => a.isDefault).map((a) => a.id),
        ['work'],
      );
    });
  });

  group('the device key', () {
    test('a reset by one instance is seen by another', () async {
      // The network layer signs with one instance, sign-in enrols with
      // another. The signer used to keep its cached key after a re-enrolment
      // and every proof it made was refused.
      final storage = _MemStorage();
      final signer = DeviceIdentityService(storage);
      final enroller = DeviceIdentityService(storage);

      final before = await signer.publicKeyBase64Url();
      await enroller.reset();
      final enrolled = await enroller.publicKeyBase64Url();

      expect(enrolled, isNot(before));
      expect(await signer.publicKeyBase64Url(), enrolled);
    });

    test('a refused device signature does not sign her out', () async {
      final storage = _MemStorage()
        ..values[SecureStorageKeys.accessToken] = 'access'
        ..values[SecureStorageKeys.refreshToken] = 'refresh';
      final refresh = Dio()
        ..httpClientAdapter = _Answer(401, {'code': 'INVALID_TOKEN'});
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..interceptors.add(AuthInterceptor(storage, refreshClient: refresh))
        ..httpClientAdapter = _Answer(401, {
          'code': 'DEVICE_PROOF_INVALID',
          'details': {'reason': 'unknown_key'},
        });

      await expectLater(
        dio.post<dynamic>('/addresses'),
        throwsA(isA<DioException>()),
      );

      expect((refresh.httpClientAdapter as _Answer).paths, isEmpty);
      expect(storage.values[SecureStorageKeys.accessToken], 'access');
      expect(storage.values[SecureStorageKeys.refreshToken], 'refresh');
    });
  });

  group('runWithStepUp', () {
    Future<(StepUpResult, int, int)> run(
      WidgetTester tester,
      List<Result<Object?>> answers,
    ) async {
      final auth = _ReenrollingAuth();
      late WidgetRef capturedRef;
      late BuildContext capturedContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      var calls = 0;
      final result = await runWithStepUp(
        capturedContext,
        capturedRef,
        action: () async => answers[calls++],
      );
      return (result, auth.reenrolments, calls);
    }

    testWidgets('an unknown key is re-enrolled and the action retried', (
      tester,
    ) async {
      final (result, reenrolments, calls) = await run(tester, [
        const Error(
          UnauthorizedFailure(
            'refused',
            code: 'DEVICE_PROOF_INVALID',
            details: {'reason': 'unknown_key'},
          ),
        ),
        const Success(null),
      ]);
      expect(result.outcome, StepUpOutcome.succeeded);
      expect(reenrolments, 1);
      expect(calls, 2);
    });

    testWidgets('an install with no key is enrolled and retried', (
      tester,
    ) async {
      final (result, reenrolments, _) = await run(tester, [
        const Error(
          ForbiddenFailure('refused', code: 'DEVICE_PROOF_REQUIRED'),
        ),
        const Success(null),
      ]);
      expect(result.outcome, StepUpOutcome.succeeded);
      expect(reenrolments, 1);
    });

    testWidgets('a revoked key is not silently replaced', (tester) async {
      final (result, reenrolments, calls) = await run(tester, [
        const Error(
          UnauthorizedFailure(
            'refused',
            code: 'DEVICE_PROOF_INVALID',
            details: {'reason': 'revoked_key'},
          ),
        ),
      ]);
      expect(result.outcome, StepUpOutcome.blocked);
      expect(reenrolments, 0);
      expect(calls, 1);
    });
  });
}
