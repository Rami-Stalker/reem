// The seller application, around the two things that silently destroy work.
//
// A woman told to send more papers comes back to this screen with documents
// already on file. If the form loads blank, submitting replaces her whole
// application with one that has no ID attached — and nothing on screen ever
// said so. And on a form of twenty-odd fields, "complete all required fields"
// is a puzzle; the message has to name the gap.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/auth/domain/entities/auth_account.dart';
import 'package:reem/features/auth/domain/repositories/auth_repository.dart';
import 'package:reem/features/auth/presentation/providers/auth_account_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/screens/seller_verification_screen.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;
import 'package:reem/l10n/app_localizations_ar.dart';

final _ar = AppLocalizationsAr();

SellerVerification _application({
  String? governmentIdUrl = 'http://host/media/11111111-1111-1111-1111-111111111111/file',
  List<String> documentUrls = const [
    'http://host/media/22222222-2222-2222-2222-222222222222/file',
  ],
}) => SellerVerification(
  id: 'app-1',
  status: 'needs_more_documents',
  businessName: 'أتيليه رهف',
  legalName: 'رهف محمود الشامي',
  businessCategory: 'أزياء',
  storeDescription: 'فساتين سهرة مصمّمة يدوياً في قلب دمشق، بخامات مختارة.',
  storeLogoUrl: 'http://host/media/files/2026/08/logo.png',
  contactPhone: '+963931000101',
  contactEmail: 'rahaf@example.com',
  businessAddress: 'دمشق، المزة',
  warehouseAddress: 'دمشق، المزة، مستودع 3',
  commercialRegistration: 'CR-99120',
  governmentIdUrl: governmentIdUrl,
  businessLicenseUrl:
      'http://host/media/33333333-3333-3333-3333-333333333333/file',
  bankName: 'بنك بيمو',
  accountHolder: 'رهف محمود الشامي',
  iban: 'SY0000000000000001',
  shippingMethods: const ['مندوب'],
  returnPolicy: 'الإرجاع خلال سبعة أيام بشرط بقاء القطعة كما هي.',
  productCategories: const ['فساتين'],
  yearsExperience: 8,
  documentUrls: documentUrls,
  reviewReason: 'نحتاج صورة أوضح للسجل التجاري',
  submittedAt: DateTime.utc(2026, 8, 20),
);

void main() {
  testWidgets('a returning applicant finds her documents still attached', (
    tester,
  ) async {
    final repo = _FakeAuthRepository();
    await tester.pumpWidget(_Harness(existing: _application(), repo: repo));
    await tester.pumpAndSettle();

    // Three private pickers, each seeded: ID, licence, and one extra document.
    // A chip, never a network image — the bytes sit behind an authorised
    // endpoint, and caching a photograph of a national ID onto the handset to
    // draw a thumbnail is not a trade worth making.
    expect(find.text(_ar.mediaDocumentAttached), findsNWidgets(3));

    // The reviewer's note is why she is here, so it outranks the generic copy.
    expect(find.text('نحتاج صورة أوضح للسجل التجاري'), findsOneWidget);
  });

  testWidgets('submitting a seeded application does not ask for the documents again', (
    tester,
  ) async {
    final repo = _FakeAuthRepository();
    await tester.pumpWidget(_Harness(existing: _application(), repo: repo));
    await tester.pumpAndSettle();

    await _submit(tester);
    await tester.pumpAndSettle();

    // It reached the repository at all, which means the seeded document URLs
    // satisfied the completeness check rather than reading as blank.
    expect(repo.submitted, isNotNull);
    expect(
      repo.submitted!['government_id_url'],
      'http://host/media/11111111-1111-1111-1111-111111111111/file',
    );
    expect(repo.submitted!['document_urls'], hasLength(1));

    // Exactly once. The step-up wrapper runs the action itself and reports
    // whether to retry; treating "went through first time" as "retry" would
    // file her application twice, which for a KYC submission is not a
    // cosmetic bug.
    expect(repo.submitCalls, 1);
  });

  testWidgets('a missing document is named, not summarised', (tester) async {
    final repo = _FakeAuthRepository();
    await tester.pumpWidget(
      _Harness(existing: _application(governmentIdUrl: null), repo: repo),
    );
    await tester.pumpAndSettle();

    await _submit(tester);
    await tester.pump();

    expect(
      find.text(_ar.verificationFieldRequired(_ar.governmentIdDocument)),
      findsOneWidget,
    );
    expect(repo.submitted, isNull);
  });

  testWidgets('a first-time applicant gets an empty form and the intro copy', (
    tester,
  ) async {
    final repo = _FakeAuthRepository();
    await tester.pumpWidget(_Harness(existing: null, repo: repo));
    await tester.pumpAndSettle();

    expect(find.text(_ar.noVerificationSubmitted), findsOneWidget);
    expect(find.text(_ar.mediaDocumentAttached), findsNothing);

    await _submit(tester);
    await tester.pump();

    // The first gap in screen order, not the last one checked.
    expect(
      find.text(_ar.verificationFieldRequired(_ar.businessName)),
      findsOneWidget,
    );
  });
}

/// The application is longer than any screen, so the button has to be brought
/// into view before it can be tapped.
Future<void> _submit(WidgetTester tester) async {
  final button = find.text(_ar.submitVerification);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
}

class _Harness extends StatelessWidget {
  _Harness({required this.existing, required this.repo});

  final SellerVerification? existing;
  final _FakeAuthRepository repo;

  /// `PremiumAppBar` reads `GoRouterState`, so the screen cannot be mounted
  /// under a plain `MaterialApp` — it throws before the form is ever built.
  late final GoRouter _router = GoRouter(
    initialLocation: '/seller-verification',
    routes: [
      GoRoute(
        path: '/seller-verification',
        builder: (_, _) => const SellerVerificationScreen(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        sellerVerificationProvider.overrideWith((ref) async => existing),
      ],
      child: MaterialApp.router(
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
        routerConfig: _router,
      ),
    );
  }
}

/// Records what the screen submitted; everything else refuses politely.
class _FakeAuthRepository implements AuthRepository {
  Map<String, dynamic>? submitted;
  int submitCalls = 0;

  @override
  Future<Result<SellerVerification>> submitSellerVerification({
    required String businessName,
    required String legalName,
    required String businessCategory,
    required String storeDescription,
    required String storeLogoUrl,
    required String contactPhone,
    required String contactEmail,
    required String businessAddress,
    required String warehouseAddress,
    required String commercialRegistration,
    required String governmentIdUrl,
    required String businessLicenseUrl,
    String? taxId,
    required String bankName,
    required String accountHolder,
    required String iban,
    Map<String, dynamic>? paymentInformation,
    required List<String> shippingMethods,
    required String returnPolicy,
    required List<String> productCategories,
    required int yearsExperience,
    String? website,
    Map<String, dynamic>? socialMediaLinks,
    required List<String> documentUrls,
    List<String> acceptedPolicyVersionIds = const [],
  }) async {
    submitCalls++;
    submitted = {
      'store_logo_url': storeLogoUrl,
      'government_id_url': governmentIdUrl,
      'business_license_url': businessLicenseUrl,
      'document_urls': documentUrls,
      'accepted_policy_version_ids': acceptedPolicyVersionIds,
    };
    return Success(_application());
  }

  /// Every other method on the interface — thirty-eight of them, several of
  /// which `AuthNotifier` calls as it builds — answers with a refusal.
  ///
  /// `Error<Never>` satisfies `Result<T>` for every T, because Dart generics
  /// are covariant. That is what makes one line stand in for all of them
  /// instead of a wall of stubs, and every caller on this path treats a
  /// refusal as a no-op.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('not used in this test')));
}
