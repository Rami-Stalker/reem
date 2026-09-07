// The platform seam: what an iPhone gets that an Android does not, and the
// app frame that sits above every route on both.
//
// These are the tests the codebase could not have had before, because the
// adaptive decisions were spread across widgets as `Platform.isIOS` — which a
// widget test cannot fake, so half of every branch was uncoverable. Everything
// here runs on a normal `flutter test`, both halves.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/app/app_chrome.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/network/connection_status.dart';
import 'package:reem/core/platform/app_platform.dart';
import 'package:reem/core/platform/app_scroll_behavior.dart';
import 'package:reem/core/platform/system_chrome_controller.dart';
import 'package:reem/core/platform/unsaved_changes_guard.dart';
import 'package:reem/core/router/app_router_provider.dart';

Widget _host(
  Widget child, {
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('ar'),
    supportedLocales: L10nSetup.supportedLocales,
    localizationsDelegates: L10nSetup.localizationsDelegates,
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

/// A button that opens [open] when tapped, so a dialog is raised from a
/// context that has a Navigator above it.
class _Opener extends StatelessWidget {
  const _Opener({required this.open});

  final Future<void> Function(BuildContext context) open;

  @override
  Widget build(BuildContext context) =>
      TextButton(onPressed: () => open(context), child: const Text('open'));
}

void main() {
  tearDown(() => AppPlatform.debugOverride = null);

  group('the platform is one decision, taken in one place', () {
    test('Apple covers iOS and macOS; everything else is Material', () {
      expect(
        AppPlatform.runAs(AppPlatformKind.apple, () => AppPlatform.isApple),
        isTrue,
      );
      expect(
        AppPlatform.runAs(AppPlatformKind.material, () => AppPlatform.isApple),
        isFalse,
      );
    });

    test('runAs restores whatever was pinned before it', () {
      AppPlatform.debugOverride = AppPlatformKind.material;
      AppPlatform.runAs(AppPlatformKind.apple, () {});
      expect(AppPlatform.debugOverride, AppPlatformKind.material);
    });
  });

  group('a confirmation looks native on the phone it is shown on', () {
    testWidgets('iOS gets a Cupertino alert with a destructive action', (
      tester,
    ) async {
      AppPlatform.debugOverride = AppPlatformKind.apple;
      await tester.pumpWidget(
        _host(
          _Opener(
            open: (context) => DsDialog.confirm(
              context,
              title: 'إلغاء الطلب',
              message: 'ما رح تنعاد.',
              destructive: true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('إلغاء الطلب'), findsOneWidget);
    });

    testWidgets('Android gets the Material one', (tester) async {
      AppPlatform.debugOverride = AppPlatformKind.material;
      await tester.pumpWidget(
        _host(
          _Opener(
            open: (context) => DsDialog.confirm(context, title: 'إلغاء الطلب'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('the confirm answer survives the platform branch', (
      tester,
    ) async {
      for (final kind in AppPlatformKind.values) {
        AppPlatform.debugOverride = kind;
        bool? answer;
        await tester.pumpWidget(
          _host(
            _Opener(
              open: (context) async {
                answer = await DsDialog.confirm(
                  context,
                  title: 'تأكيد',
                  confirmLabel: 'نعم',
                  cancelLabel: 'لا',
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('نعم'));
        await tester.pumpAndSettle();
        expect(answer, isTrue, reason: '$kind confirmed');
      }
    });

    testWidgets('dismissing without choosing reads as "no", not as null', (
      tester,
    ) async {
      for (final kind in AppPlatformKind.values) {
        AppPlatform.debugOverride = kind;
        bool? answer;
        await tester.pumpWidget(
          _host(
            _Opener(
              open: (context) async {
                answer = await DsDialog.confirm(
                  context,
                  title: 'تأكيد',
                  cancelLabel: 'لا',
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('لا'));
        await tester.pumpAndSettle();
        expect(answer, isFalse, reason: '$kind declined');
      }
    });
  });

  group('a prompt returns trimmed text and refuses an empty one', () {
    testWidgets('on both platforms', (tester) async {
      for (final kind in AppPlatformKind.values) {
        AppPlatform.debugOverride = kind;
        String? answer;
        await tester.pumpWidget(
          _host(
            _Opener(
              open: (context) async {
                answer = await DsDialog.prompt(
                  context,
                  title: 'اسم الجهاز',
                  confirmLabel: 'حفظ',
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        // Empty: the confirm button is there but does nothing.
        await tester.tap(find.text('حفظ'));
        await tester.pumpAndSettle();
        expect(find.text('اسم الجهاز'), findsOneWidget, reason: '$kind stayed');

        await tester.enterText(find.byType(EditableText), '  جوالي  ');
        await tester.pumpAndSettle();
        await tester.tap(find.text('حفظ'));
        await tester.pumpAndSettle();
        expect(answer, 'جوالي', reason: '$kind trimmed');
      }
    });
  });

  group('a choice of source is an action sheet on iOS', () {
    testWidgets('and a Material list on Android, both answering the same', (
      tester,
    ) async {
      for (final kind in AppPlatformKind.values) {
        AppPlatform.debugOverride = kind;
        String? picked;
        await tester.pumpWidget(
          _host(
            _Opener(
              open: (context) async {
                picked = await DsBottomSheet.choose<String>(
                  context,
                  title: 'من وين؟',
                  choices: const [
                    DsSheetChoice(value: 'camera', label: 'الكاميرا'),
                    DsSheetChoice(value: 'gallery', label: 'الاستوديو'),
                  ],
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(
          find.byType(CupertinoActionSheet),
          kind.isApple ? findsOneWidget : findsNothing,
          reason: '$kind sheet kind',
        );

        await tester.tap(find.text('الاستوديو'));
        await tester.pumpAndSettle();
        expect(picked, 'gallery', reason: '$kind picked');
      }
    });
  });

  group('a dialog survives the largest text the app allows', () {
    testWidgets('on the narrowest phone it supports', (tester) async {
      // A first-generation SE, at the ceiling AppChrome clamps the system
      // setting to. The whole point of the clamp is that this must lay out.
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      for (final kind in AppPlatformKind.values) {
        AppPlatform.debugOverride = kind;
        await tester.pumpWidget(
          _host(
            _Opener(
              open: (context) => DsDialog.alert(
                context,
                title: 'ما قدرنا نكمّل الطلب',
                message:
                    'صار خطأ وقت تثبيت الطلب. جرّبي مرة تانية بعد شوي، وإذا '
                    'ضلّت المشكلة احكي معنا من صفحة الحساب. ما انسحب من '
                    'محفظتك ولا ليرة.',
              ),
            ),
            textScale: 1.6,
            size: const Size(320, 568),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('ما قدرنا نكمّل الطلب'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$kind laid out');

        await tester.tap(find.text('حسناً'));
        await tester.pumpAndSettle();
      }
    });
  });

  group('a half-written form is not lost to a stray edge swipe', () {
    // A real stack: the guarded form is *pushed*, so popping it lands
    // somewhere rather than emptying the navigator.
    Widget guarded({required bool dirty}) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: L10nSetup.supportedLocales,
      localizationsDelegates: L10nSetup.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: UnsavedChangesGuard(
                    hasUnsavedChanges: dirty,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('back'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    Future<void> openForm(WidgetTester tester, {required bool dirty}) async {
      await tester.pumpWidget(guarded(dirty: dirty));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    // One test body per platform. Sharing one and looping does not work here:
    // the pushed route survives a second `pumpWidget`, so the second pass
    // starts on the form rather than in front of it.
    for (final kind in AppPlatformKind.values) {
      group('on ${kind.name}', () {
        setUp(() => AppPlatform.debugOverride = kind);

        testWidgets('an untouched form pops straight away, so predictive '
            'back still animates', (tester) async {
          await openForm(tester, dirty: false);

          // `canPop: true` is the whole reason this is not a flat `false`:
          // Android 13 only shows the peek-behind animation for a route that
          // has already agreed to pop.
          final scope = tester.widget<PopScope<Object?>>(
            find.byWidgetPredicate((w) => w is PopScope<Object?>),
          );
          expect(scope.canPop, isTrue);

          await tester.tap(find.text('back'));
          await tester.pumpAndSettle();
          expect(find.text('open'), findsOneWidget);
        });

        testWidgets('a dirty one asks first, and keeps the screen when she '
            'says no', (tester) async {
          await openForm(tester, dirty: true);

          await tester.tap(find.text('back'));
          await tester.pumpAndSettle();

          expect(find.text('بدك تتركي اللي كتبتيه؟'), findsOneWidget);
          await tester.tap(find.text('كمّلي'));
          await tester.pumpAndSettle();
          expect(find.text('back'), findsOneWidget);
        });

        testWidgets('and lets go when she says yes', (tester) async {
          await openForm(tester, dirty: true);

          await tester.tap(find.text('back'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('اتركيه'));
          await tester.pumpAndSettle();

          expect(find.text('open'), findsOneWidget);
        });
      });
    }
  });

  group('a shared room invite lands somewhere', () {
    test('the authority of a reem:// link is folded back into the path', () {
      // `Uri.parse` reads the first segment of `reem://rooms/join/abc` as the
      // *authority*, so the path GoRouter would match on is `/join/abc` —
      // which matches nothing. This is the fix, and the reason it is a
      // function rather than a comment.
      expect(
        deepLinkPath(Uri.parse('reem://rooms/join/abc')),
        '/rooms/join/abc',
      );
    });

    test('a query string survives the fold', () {
      expect(
        deepLinkPath(Uri.parse('reem://rooms/join/abc?from=whatsapp')),
        '/rooms/join/abc?from=whatsapp',
      );
    });

    test('the empty-authority spelling is already a path', () {
      expect(deepLinkPath(Uri.parse('reem:///rooms/join/abc')), isNull);
    });

    test('an ordinary in-app location is left alone', () {
      expect(deepLinkPath(Uri.parse('/rooms/join/abc')), isNull);
      expect(deepLinkPath(Uri.parse('/checkout')), isNull);
    });

    test('an https share link keeps its own path', () {
      // These carry the host in the authority *and* the route in the path,
      // so folding one in would produce `/reem.shop/product/9`.
      expect(deepLinkPath(Uri.parse('https://reem.shop/product/9')), isNull);
    });
  });

  group('the app frame', () {
    for (final (online, expected) in const [(true, 47.0), (false, 0.0)]) {
      testWidgets(
        'hands the page ${expected}dp of top inset when online is $online',
        (tester) async {
          const inset = EdgeInsets.only(top: 47);
          double? seen;

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                connectionStatusProvider.overrideWith(
                  (ref) => Stream.value(online),
                ),
              ],
              child: MaterialApp(
                theme: AppTheme.light,
                locale: const Locale('ar'),
                supportedLocales: L10nSetup.supportedLocales,
                localizationsDelegates: L10nSetup.localizationsDelegates,
                home: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(390, 844),
                    padding: inset,
                    viewPadding: inset,
                  ),
                  child: AppChrome(
                    child: Builder(
                      builder: (context) {
                        seen = MediaQuery.paddingOf(context).top;
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Online the page keeps the status-bar inset and draws under it.
          // Offline the band has already consumed it — it carries its own
          // SafeArea — so the page must be handed zero. Handing it 47 twice is
          // what used to slide the whole app down the moment the signal
          // dropped, leaving a bald strip under the notch.
          expect(seen, expected);
        },
      );
    }

    testWidgets('clamps the system text scale into the band it is drawn for', (
      tester,
    ) async {
      for (final (asked, expected) in const [
        (0.5, 0.85),
        (1.0, 1.0),
        (3.0, 1.6),
      ]) {
        late TextScaler seen;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectionStatusProvider.overrideWith(
                (ref) => Stream.value(true),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: const Locale('ar'),
              supportedLocales: L10nSetup.supportedLocales,
              localizationsDelegates: L10nSetup.localizationsDelegates,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(asked)),
                child: AppChrome(
                  child: Builder(
                    builder: (context) {
                      seen = MediaQuery.textScalerOf(context);
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          seen.scale(10),
          closeTo(expected * 10, 0.01),
          reason: 'asked for ${asked}x',
        );
      }
    });
  });

  group('scrolling feels like the platform it runs on', () {
    testWidgets('bounce on iOS, clamp on Android, always draggable on both', (
      tester,
    ) async {
      for (final (platform, matcher) in [
        (TargetPlatform.iOS, isA<BouncingScrollPhysics>()),
        (TargetPlatform.android, isA<ClampingScrollPhysics>()),
      ]) {
        late ScrollPhysics physics;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light.copyWith(platform: platform),
            scrollBehavior: const AppScrollBehavior(),
            home: Builder(
              builder: (context) {
                physics = ScrollConfiguration.of(
                  context,
                ).getScrollPhysics(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        // MaterialApp cross-fades between themes, and `ThemeData.lerp` only
        // flips `platform` at the halfway mark — so reading the physics off
        // the first frame after a theme swap answers for the *previous*
        // platform. Settling first is not test decoration; it is what makes
        // this assertion about the theme it names.
        await tester.pumpAndSettle();

        // Always-scrollable on top, so a short page can still be pulled to
        // refresh; the platform's own physics underneath it.
        expect(physics, isA<AlwaysScrollableScrollPhysics>());
        expect(physics.parent, matcher, reason: '$platform');
      }
    });
  });

  group('the system bars are told what to draw over', () {
    test('light theme asks for dark glyphs, dark theme for light ones', () {
      final light = AppSystemChrome.overlayStyleFor(Brightness.light);
      expect(light.statusBarIconBrightness, Brightness.dark);
      expect(light.statusBarBrightness, Brightness.light);
      expect(light.systemNavigationBarIconBrightness, Brightness.dark);

      final dark = AppSystemChrome.overlayStyleFor(Brightness.dark);
      expect(dark.statusBarIconBrightness, Brightness.light);
      expect(dark.statusBarBrightness, Brightness.dark);
      expect(dark.systemNavigationBarIconBrightness, Brightness.light);
    });

    test('both bars are transparent, and neither is given a scrim', () {
      for (final brightness in Brightness.values) {
        final style = AppSystemChrome.overlayStyleFor(brightness);
        expect(style.statusBarColor, const Color(0x00000000));
        expect(style.systemNavigationBarColor, const Color(0x00000000));
        expect(style.systemNavigationBarContrastEnforced, isFalse);
      }
    });
  });

  group('a phone is held upright; a tablet is held either way', () {
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<List<String>> orientationsFor(Size size) async {
      calls.clear();
      await AppSystemChrome.applyOrientationFor(size);
      final call = calls.singleWhere(
        (c) => c.method == 'SystemChrome.setPreferredOrientations',
      );
      return (call.arguments as List).cast<String>();
    }

    test('a 390-wide handset is portrait only', () async {
      expect(await orientationsFor(const Size(390, 844)), [
        'DeviceOrientation.portraitUp',
        'DeviceOrientation.portraitDown',
      ]);
    });

    test('an unfolded 834-wide tablet may rotate', () async {
      expect(await orientationsFor(const Size(834, 1194)), hasLength(4));
    });

    test('a handset in landscape is judged by its shortest side, not its '
        'width', () async {
      expect(await orientationsFor(const Size(844, 390)), hasLength(2));
    });
  });
}
