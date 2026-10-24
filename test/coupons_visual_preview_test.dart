// Renders the coupons screen to PNGs so it can be eyeballed without a handset.
// Not an assertion test — it writes `build/visual/*.png` and is run on demand.
//
//   flutter test test/coupons_visual_preview_test.dart
//
// The coupons are not invented: `coupons_live.json` is the verbatim response
// of `GET /coupons` for a real seeded account (رغد يوسف), and the applied
// discount is the verbatim answer of `POST /coupons/validate` against her real
// 3,833,000 SYP basket. Rendering anything else here would repeat the mistake
// this screen was built to fix.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/cart/domain/entities/cart.dart';
import 'package:ohara/features/cart/domain/repositories/cart_repository.dart';
import 'package:ohara/features/cart/presentation/providers/cart_providers.dart';
import 'package:ohara/features/checkout/presentation/providers/applied_coupon_provider.dart';
import 'package:ohara/features/settings/data/models/coupon_model.dart';
import 'package:ohara/features/settings/domain/entities/coupon_entity.dart';
import 'package:ohara/features/settings/domain/entities/coupon_validation.dart';
import 'package:ohara/features/settings/presentation/providers/coupons_provider.dart';
import 'package:ohara/features/settings/presentation/screens/coupons_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

/// Her real basket, from the seeded demo data.
final _subtotal = Money(raw: '3833000', currency: Currency.syp);

/// What `POST /coupons/validate` actually answered for `REEM-EB2250` against
/// that basket: 15% of 3,833,000.
final _discount = Money(raw: '574950.0000', currency: Currency.syp);

List<CouponEntity> _liveCoupons() {
  final raw =
      jsonDecode(File('test/contract/coupons_live.json').readAsStringSync())
          as List<dynamic>;
  return raw
      .map((e) => CouponModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

/// The icon font is not bundled into `flutter test` the way the app bundles
/// it, so every `Icon` renders as an empty square unless it is loaded here —
/// which makes a preview look broken in a way the real screen is not.
String? _materialIconsPath() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String>[
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    'C:/src/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

Future<void> _loadFonts() async {
  final icons = _materialIconsPath();
  if (icons != null) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(
        File(icons).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    await loader.load();
  }

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  testWidgets('renders the coupons screen in both themes', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(_Preview(themeMode: mode));
      await _settle(tester);
      await _capture(tester, 'coupons_${mode.name}');
    }
  });

  testWidgets('renders the applied state', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_Preview(themeMode: ThemeMode.light, applied: true));
    await _settle(tester);
    await _capture(tester, 'coupons_applied');
  });
}

class _Preview extends StatelessWidget {
  _Preview({required this.themeMode, this.applied = false});

  final ThemeMode themeMode;
  final bool applied;

  /// `PremiumAppBar` reads `GoRouterState` for its back button, so the screen
  /// has to sit under a real router rather than a bare `home:`.
  late final GoRouter _router = GoRouter(
    initialLocation: '/coupons',
    routes: [GoRoute(path: '/coupons', builder: (_, _) => const CouponsScreen())],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        // Synchronous on purpose: a `FutureProvider` whose creator returns a
        // value rather than a `Future` resolves to data on the first frame,
        // which is the only way to capture a settled screen under fake async.
        couponsProvider.overrideWith((ref) => _liveCoupons()),
        cartRepositoryProvider.overrideWithValue(const _StubCartRepository()),
        if (applied)
          appliedCouponProvider.overrideWith(
            (ref) => AppliedCouponNotifier()
              ..apply(
                CouponValidation(
                  code: 'REEM-EB2250',
                  kind: CouponKind.percent,
                  discount: _discount,
                ),
                _subtotal,
              ),
          ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
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
        routerConfig: _router,
        builder: (context, child) =>
            RepaintBoundary(key: _captureKey, child: child),
      ),
    );
  }
}

/// Stands in for the network so the basket hint has her real subtotal to show.
class _StubCartRepository implements CartRepository {
  const _StubCartRepository();

  static final _cart = Cart(
    items: const [],
    summary: CartSummary(
      subtotalsByCurrency: [_subtotal],
      itemsCount: 4,
      sellersCount: 2,
      totalQuantity: 6,
    ),
  );

  @override
  Future<Result<Cart>> getCart() async => Success(_cart);

  @override
  Future<Result<Cart>> addItem({
    required String offerId,
    String? offerVariantId,
    int quantity = 1,
  }) async => Success(_cart);

  @override
  Future<Result<Cart>> updateQuantity({
    required String itemId,
    required int quantity,
  }) async => Success(_cart);

  @override
  Future<Result<Cart>> removeItem(String itemId) async => Success(_cart);

  @override
  Future<Result<Cart>> clear() async => Success(_cart);
}

/// Lets the coupon future resolve and the entry animations finish.
///
/// A plain `pump(600ms)` captured the header over an empty list: the
/// `FutureProvider` had not completed, and `flutter_animate` starts every
/// ticket at zero opacity.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  // `pumpAndSettle` rather than a fixed pump: `flutter_animate` staggers each
  // ticket by 80ms and starts it at zero opacity, so a single long pump
  // captured a page of invisible cards under a visible header.
  await tester.pumpAndSettle(const Duration(milliseconds: 32));
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    final file = File('${dir.path}/$name.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}
