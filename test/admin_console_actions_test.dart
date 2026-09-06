// The console's governance actions: who is offered them, and what they send.
//
// Until this suite the admin surface had no test that touched a write at all,
// because there were no writes — every screen listed records and stopped. The
// two things worth pinning are the two that go wrong quietly: an action offered
// to someone who cannot perform it, and an action that sends the wrong payload
// to the right-looking endpoint.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/auth/app_permissions.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';
import 'package:reem/features/admin/domain/entities/admin_stats_entity.dart';
import 'package:reem/features/admin/domain/entities/analytics_dashboard_entity.dart';
import 'package:reem/features/admin/domain/repositories/admin_repository.dart';
import 'package:reem/features/admin/presentation/providers/admin_actions.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/screens/admin_section_screen.dart';
import 'package:reem/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_stubPlatformChannels);

  group('the action catalogue', () {
    test('offers nothing on a read-only section', () {
      expect(adminSectionConfigs['orders']!.actions, isEmpty);
      expect(adminSectionConfigs['audit']!.actions, isEmpty);
      expect(adminSectionConfigs['financials']!.actions, isEmpty);
    });

    test('names a permission on every action it offers', () {
      for (final config in adminSectionConfigs.values) {
        for (final action in config.actions) {
          expect(
            action.permission,
            isNotEmpty,
            reason:
                '${config.key}/${action.id} would be offered to every operator',
          );
        }
      }
    });

    test('never offers to grant the last unrevocable role', () {
      final roleAction = adminSectionConfigs['users']!.actions.firstWhere(
        (action) => action.id == 'role',
      );
      final choices = roleAction.fields
          .firstWhere((field) => field.key == 'role')
          .choices
          .map((choice) => choice.value);

      expect(choices, isNot(contains('SUPER_ADMIN')));
      expect(choices, contains('FINANCE_ADMIN'));
    });

    test('offers suspend and restore to opposite rows, never both', () {
      final actions = adminSectionConfigs['users']!.actions;
      final suspend = actions.firstWhere((action) => action.id == 'suspend');
      final restore = actions.firstWhere((action) => action.id == 'restore');

      final live = _record(raw: const {'id': 'u1', 'is_disabled': false});
      final locked = _record(raw: const {'id': 'u2', 'is_disabled': true});

      expect(suspend.appliesTo(live), isTrue);
      expect(restore.appliesTo(live), isFalse);
      expect(suspend.appliesTo(locked), isFalse);
      expect(restore.appliesTo(locked), isTrue);
    });

    test('offers a settlement change only on a ledger entry', () {
      final ledgerAction = adminSectionConfigs['commissions']!.actions.first;

      // The commissions payload carries rules beside ledger entries; a rule has
      // no settlement status to move.
      expect(
        ledgerAction.appliesTo(
          _record(raw: const {'id': 'l1', 'kind': 'ledger', 'seller_id': 's1'}),
        ),
        isTrue,
      );
      expect(
        ledgerAction.appliesTo(
          _record(
            raw: const {'id': 'r1', 'kind': 'rule', 'name': 'Standard'},
          ),
        ),
        isFalse,
      );
    });
  });

  group('status labels', () {
    testWidgets('translate every token the console filters by', (tester) async {
      final l10n = await _arabic(tester);

      for (final config in adminSectionConfigs.values) {
        for (final token in config.statusFilters) {
          final label = adminStatusLabel(l10n, token);
          expect(
            label,
            isNot(equals(token)),
            reason: '$token is shown to an Arabic-speaking operator untranslated',
          );
        }
      }
    });

    testWidgets('fall back to a readable form for an unknown token', (
      tester,
    ) async {
      final l10n = await _arabic(tester);
      expect(adminStatusLabel(l10n, 'SOME_NEW_STATE'), 'Some New State');
    });
  });

  group('the moderation console', () {
    testWidgets('offers no action to an operator who cannot moderate', (
      tester,
    ) async {
      final repository = _RecordingAdminRepository();
      await _pumpSection(
        tester,
        repository: repository,
        permissions: const {AppPermissions.contentModerate},
        readOnly: true,
      );

      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });

    testWidgets('sends the decision the operator filled in', (tester) async {
      final repository = _RecordingAdminRepository();
      await _pumpSection(
        tester,
        repository: repository,
        permissions: const {AppPermissions.contentModerate},
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('البتّ في الحالة').last);
      await tester.pumpAndSettle();

      // The form opens on the record's current status; the resolution note is
      // the field the API refuses the request without.
      await tester.enterText(find.byType(TextField).last, 'Removed the image');
      await tester.pumpAndSettle();
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();

      expect(repository.moderationCalls, hasLength(1));
      final (id, payload) = repository.moderationCalls.single;
      expect(id, 'case-1');
      expect(payload['resolution'], 'Removed the image');
      expect(payload['status'], isNotNull);
    });
  });
}

AdminRecord _record({required Map<String, dynamic> raw}) {
  return AdminRecord(
    id: raw['id'] as String? ?? '',
    title: 'record',
    subtitle: '',
    status: 'OPEN',
    metrics: const {},
    raw: raw,
  );
}

/// The console reaches for secure storage through the auth interceptor, which
/// has no implementation in a widget test.
void _stubPlatformChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (call) async => call.method == 'readAll' ? <String, String>{} : null,
      );
}

Future<gen.AppLocalizations> _arabic(WidgetTester tester) {
  return gen.AppLocalizations.delegate.load(const Locale('ar'));
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required _RecordingAdminRepository repository,
  required Set<String> permissions,
  bool readOnly = false,
}) async {
  tester.view.physicalSize = const Size(1600, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final config = adminSectionConfigs['moderation']!;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWithValue(repository),
        currentPermissionsProvider.overrideWithValue(
          // A read-only operator here means one who can open the section but
          // holds no write permission; the section's write permission is the
          // same key, so the read-only case is modelled by an empty set.
          readOnly ? const <String>{} : permissions,
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: L10nSetup.supportedLocales,
        localizationsDelegates: const [
          gen.AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: AdminSectionScreen(config: config)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Records what the console asked of the API instead of talking to one.
final class _RecordingAdminRepository implements AdminRepository {
  final moderationCalls = <(String, Map<String, dynamic>)>[];

  @override
  Future<Result<AdminConsoleSection>> getSection({
    required String key,
    required String title,
    required String endpoint,
    int page = 1,
    int limit = 25,
    String? query,
    String? status,
  }) async => Success(
    AdminConsoleSection(
      key: key,
      title: title,
      total: 1,
      records: const [
        AdminRecord(
          id: 'case-1',
          title: 'صورة مخالفة',
          subtitle: 'منشور · دمشق',
          status: 'OPEN',
          metrics: {},
          raw: {'id': 'case-1', 'status': 'OPEN', 'target_type': 'post'},
        ),
      ],
    ),
  );

  @override
  Future<Result<void>> updateModerationCase(
    String id,
    Map<String, dynamic> payload,
  ) async {
    moderationCalls.add((id, payload));
    return const Success(null);
  }

  @override
  Future<Result<AdminStatsEntity>> getStats() async =>
      const Error<AdminStatsEntity>(ValidationFailure('not used'));

  @override
  Future<Result<AnalyticsDashboardEntity>> getAnalyticsDashboard({
    DateTime? start,
    DateTime? end,
  }) async =>
      const Error<AnalyticsDashboardEntity>(ValidationFailure('not used'));

  @override
  Future<Result<void>> createNotificationCampaign(
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> runNotificationCampaign(String campaignId) async =>
      const Success(null);

  @override
  Future<Result<void>> updateUser(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> updateProduct(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> updateSupportTicket(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> updateReport(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> createCommissionRule(
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> updateCommissionLedger(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<void>> upsertSystemSetting(
    Map<String, dynamic> payload,
  ) async => const Success(null);

  @override
  Future<Result<Map<String, dynamic>>> getSellerApplication(String id) async =>
      const Success(<String, dynamic>{});

  @override
  Future<Result<void>> reviewSellerApplication(
    String id,
    Map<String, dynamic> payload,
  ) async => const Success(null);
}
