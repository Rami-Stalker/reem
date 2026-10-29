// Renders the pages behind her profile — settings and its rooms, language,
// appearance, notifications, addresses, sizes, editing her profile — to PNGs
// so the design can be judged without a session or a backend. Not an
// assertion test: it writes `build/visual/profile_page_*.png`.
//
//   flutter test test/profile_pages_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/notifications/push_notification_service.dart';
import 'package:ohara/core/notifications/push_providers.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/auth/domain/entities/auth_account.dart';
import 'package:ohara/features/auth/presentation/providers/auth_account_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_notifier.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_state.dart';
import 'package:ohara/features/auth/presentation/screens/account_settings_screen.dart';
import 'package:ohara/features/auth/presentation/screens/device_management_screen.dart';
import 'package:ohara/features/auth/presentation/screens/security_settings_screen.dart';
import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';
import 'package:ohara/features/reputation/domain/entities/reputation_entities.dart';
import 'package:ohara/features/reputation/presentation/providers/reputation_provider.dart';
import 'package:ohara/features/reputation/presentation/screens/fit_profile_screen.dart';
import 'package:ohara/features/reputation/presentation/screens/my_reviews_screen.dart';
import 'package:ohara/features/settings/domain/entities/address_entity.dart';
import 'package:ohara/features/settings/domain/entities/notification_preferences.dart';
import 'package:ohara/features/settings/domain/repositories/settings_repository.dart';
import 'package:ohara/features/settings/presentation/providers/address_book_notifier.dart';
import 'package:ohara/features/settings/presentation/providers/address_book_provider.dart';
import 'package:ohara/features/settings/presentation/providers/settings_provider.dart';
import 'package:ohara/features/settings/presentation/screens/adresses_screen.dart';
import 'package:ohara/features/settings/presentation/screens/appearance_screen.dart';
import 'package:ohara/features/settings/presentation/screens/language_screen.dart';
import 'package:ohara/features/settings/presentation/screens/notifications_screen.dart';
import 'package:ohara/features/settings/presentation/screens/settings_screen.dart';
import 'package:ohara/features/user_profile/presentation/providers/edit_profile_notifier.dart';
import 'package:ohara/features/user_profile/presentation/providers/edit_profile_state.dart';
import 'package:ohara/features/user_profile/presentation/providers/user_profile_providers.dart';
import 'package:ohara/features/user_profile/presentation/screens/edit_profile_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

final _me = User(
  id: 'u-me',
  name: 'ريم الأحمد',
  username: 'reem.ahmad',
  phone: '+963933118204',
  email: 'reem@example.com',
  bio: 'بحب الألوان الهادية والقطع اليدوية.',
  location: 'دمشق',
  followersCount: 42,
  followingCount: 18,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _loadFonts() async {
  for (final entry in const {
    'Cairo': 'assets/fonts/Cairo-VariableFont.ttf',
    'PlayfairDisplay': 'assets/fonts/PlayfairDisplay-VariableFont.ttf',
  }.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(
        File(entry.value).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    await loader.load();
  }
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (root != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
    await loader.load();
  }
}

void _stubPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.createTempSync('ohara_test').path,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async => <String, Object>{},
  );
}

const _prefs = NotificationPreferences(
  inAppPosts: true,
  inAppStories: true,
  inAppOrders: true,
  inAppCoupons: false,
  inAppRooms: true,
  inAppSocial: true,
  inAppModeration: true,
  push: true,
  email: false,
  sms: true,
);

const _addresses = [
  AddressEntity(
    id: 'a1',
    label: 'البيت',
    recipientName: 'ريم الأحمد',
    recipientPhone: '+963933118204',
    governorate: 'دمشق',
    city: 'دمشق',
    addressLine: 'المزة، شارع الجلاء، بناء ١٤',
    landmark: 'قرب صيدلية الشفاء',
    isDefault: true,
  ),
  AddressEntity(
    id: 'a2',
    label: 'العمل',
    recipientName: 'ريم الأحمد',
    recipientPhone: '+963933118204',
    governorate: 'دمشق',
    city: 'دمشق',
    addressLine: 'أبو رمانة، مقابل الحديقة',
  ),
];

final _pages = <(String, Widget, List<Override>)>[
  ('settings', const SettingsScreen(), const []),
  ('language', const LanguageScreen(), const []),
  ('appearance', const AppearanceScreen(), const []),
  (
    'notifications',
    const NotificationsScreen(),
    [
      notificationPreferencesProvider.overrideWith((ref) async => _prefs),
      pushPermissionProvider.overrideWith(
        (ref) async => PushPermission.granted,
      ),
    ],
  ),
  (
    'addresses',
    const AddressesScreen(),
    [
      addressBookProvider.overrideWith(
        (ref) => AddressBookNotifier(_Settings())..load(),
      ),
    ],
  ),
  (
    'fit',
    const FitProfileScreen(),
    [
      fitProfileProvider.overrideWith(
        (ref) async => const FitProfile(
          heightCm: 164,
          usualSize: 'M',
          sizes: ['XS', 'S', 'M', 'L', 'XL'],
        ),
      ),
    ],
  ),
  (
    'edit',
    const EditProfileScreen(),
    [editProfileNotifierProvider.overrideWith((ref) => _Edit())],
  ),
  (
    'security',
    const SecuritySettingsScreen(),
    [
      authAccountProvider.overrideWith((ref) async => _account),
      accountDevicesProvider.overrideWith((ref) async => _devices),
      accountSessionsProvider.overrideWith((ref) async => _sessions),
    ],
  ),
  (
    'account',
    const AccountSettingsScreen(),
    [authAccountProvider.overrideWith((ref) async => _account)],
  ),
  (
    'devices',
    const DeviceManagementScreen(),
    [accountDevicesProvider.overrideWith((ref) async => _devices)],
  ),
  (
    'reviews',
    const MyReviewsScreen(),
    [myReviewsProvider.overrideWith((ref) async => _reviews)],
  ),
];

final _account = AuthAccount(
  user: _me,
  permissions: const [],
  security: const SecuritySettings(
    mfaEnabled: true,
    deviceVerificationRequired: false,
    recoveryCodesRemaining: 8,
  ),
);

final _devices = [
  AccountDevice(
    id: 'd1',
    name: 'iPhone 15',
    trustLevel: 'trusted',
    verifiedAt: DateTime(2026, 3, 1),
    lastSeenAt: DateTime.now(),
  ),
  AccountDevice(
    id: 'd2',
    name: 'Galaxy A54',
    trustLevel: 'new',
    lastSeenAt: DateTime.now(),
  ),
];

final _sessions = [
  AccountSession(
    id: 's1',
    status: 'active',
    deviceName: 'iPhone 15',
    lastSeenAt: DateTime.now(),
    idleExpiresAt: DateTime.now().add(const Duration(days: 7)),
    absoluteExpiresAt: DateTime(2026, 12, 1),
    createdAt: DateTime(2026, 9, 1),
  ),
];

final _reviews = MyReviews(
  count: 3,
  average: 4.3,
  reviews: [
    AuthoredReview(
      id: 'r1',
      rating: 5,
      isAboutProduct: true,
      subject: const ReviewSubject(id: 'p1', title: 'عطر الياسمين الدمشقي'),
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      title: 'ريحته بتضل طول النهار',
      body: 'وصلني مغلّف بشكل حلو كتير، والريحة هادية ومو قوية.',
      status: 'approved',
      sellerReply: 'شكراً إلكِ، نورتينا!',
    ),
    AuthoredReview(
      id: 'r2',
      rating: 4,
      isAboutProduct: false,
      subject: const ReviewSubject(id: 's1', title: 'بيت الورد'),
      createdAt: DateTime.now().subtract(const Duration(days: 9)),
      body: 'التوصيل كان بوقته والورد طازة.',
      status: 'approved',
    ),
    AuthoredReview(
      id: 'r3',
      rating: 4,
      isAboutProduct: true,
      subject: const ReviewSubject(id: 'p2', title: 'شال حرير مطرّز'),
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      body: 'اللون أحلى من الصورة.',
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _stubPlatformChannels();
    await _loadFonts();
  });

  for (final (name, screen, overrides) in _pages) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('renders $name in ${mode.name}', (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authNotifierProvider.overrideWith((ref) => _SignedIn(_me)),
              ...overrides,
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              locale: const Locale('ar'),
              supportedLocales: L10nSetup.supportedLocales,
              localizationsDelegates: const [
                gen.AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) =>
                  RepaintBoundary(key: _captureKey, child: child),
              home: screen,
            ),
          ),
        );
        await tester.pump();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        await tester.runAsync(() async {
          final boundary =
              _captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.0);
          final data = await image.toByteData(format: ImageByteFormat.png);
          final dir = Directory('build/visual')..createSync(recursive: true);
          File(
            '${dir.path}/profile_page_${name}_${mode.name}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
        });
        // Let any stray timers from the page's entrance finish.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
      });
    }
  }
}

class _SignedIn extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedIn(User user) : super(AuthState(user: user, isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Edit extends StateNotifier<EditProfileState>
    implements EditProfileNotifier {
  _Edit() : super(EditProfileState(user: _me));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Settings implements SettingsRepository {
  @override
  Future<Result<List<AddressEntity>>> getAddresses() async =>
      const Success(_addresses);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
