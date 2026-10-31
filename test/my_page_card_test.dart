// «صفحتي» on a shopper's own profile.
//
// The public/private switch is a list tile, and list tiles paint their ink on
// the nearest Material. The card is a decorated box, so Flutter refused to
// build the tile: a red error panel on her own profile in a debug build.
//
//   flutter test test/my_page_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/auth/presentation/providers/auth_notifier.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_state.dart';
import 'package:ohara/features/user_profile/domain/entities/user_profile.dart';
import 'package:ohara/features/user_profile/presentation/providers/user_profile_notifier.dart';
import 'package:ohara/features/user_profile/presentation/providers/user_profile_providers.dart';
import 'package:ohara/features/user_profile/presentation/providers/user_profile_state.dart';
import 'package:ohara/features/user_profile/presentation/widgets/my_page_card.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _me = User(
  id: 'u-me',
  name: 'ريم',
  username: 'reem',
  phone: '+963933118204',
  createdAt: DateTime(2026, 1, 1),
);

class _SignedIn extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedIn() : super(AuthState(user: _me, isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Loaded extends StateNotifier<UserProfileState>
    implements UserProfileNotifier {
  _Loaded()
    : super(
        UserProfileState(
          profile: UserProfile(user: _me, isMe: true, profileIsPublic: true),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the public-page switch builds on the card', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => _SignedIn()),
          userProfileNotifierProvider(null).overrideWith((ref) => _Loaded()),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ar'),
          supportedLocales: L10nSetup.supportedLocales,
          localizationsDelegates: const [
            gen.AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // A bare canvas: the card must not lean on a Material from the page.
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Center(child: MyPageCard()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
