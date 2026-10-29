// Renders the OHARA wordmark to PNGs — splash lockup and top bar, Arabic and
// English, light and dark — so the brand mark can be eyeballed without
// booting the app. Writes `build/visual/wordmark_*.png`.
//
//   flutter test test/ohara_wordmark_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

Future<void> _loadFonts() async {
  for (final entry in const {
    'Cairo': 'assets/fonts/Cairo-VariableFont.ttf',
    'PlayfairDisplay': 'assets/fonts/PlayfairDisplay-VariableFont.ttf',
    'CinzelDecorative': 'assets/fonts/CinzelDecorative-Bold.ttf',
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

  testWidgets('reads the localised name to screen readers', (tester) async {
    await tester.pumpWidget(const _Preview(
      locale: Locale('ar'),
      themeMode: ThemeMode.light,
    ));
    expect(find.text('OHARA'), findsWidgets);
    expect(find.bySemanticsLabel('أوهارا'), findsWidgets);
  });

  testWidgets('renders the wordmark in both languages and themes',
      (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(_Preview(locale: locale, themeMode: mode));
        await tester.pump(const Duration(milliseconds: 300));
        await _capture(
          tester,
          'wordmark_${locale.languageCode}_${mode.name}',
        );
      }
    }
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.locale, required this.themeMode});

  final Locale locale;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: locale,
      supportedLocales: L10nSetup.supportedLocales,
      localizationsDelegates: const [
        gen.AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: RepaintBoundary(
        key: _captureKey,
        child: Builder(
          builder: (context) {
            final l10n = context.l10n;
            final colors = context.dsColors;
            return Scaffold(
              body: Stack(
                children: [
                  const FeminineMeshBackground(),
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(DsSpacing.lg),
                          child: Row(
                            children: [
                              OharaWordmark(
                                semanticLabel: l10n.appTitle,
                                color: colors.onSurface,
                              ),
                              const Spacer(),
                              Icon(
                                Icons.shopping_bag_outlined,
                                color: colors.onSurface,
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        OharaWordmark(
                          semanticLabel: l10n.appTitle,
                          size: OharaWordmarkSize.hero,
                        ),
                        DsGaps.vSm,
                        Text(
                          l10n.splashTagline,
                          style: context.dsText.bodyLarge.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        OharaWordmark(
                          semanticLabel: l10n.appTitle,
                          size: OharaWordmarkSize.footer,
                          color: colors.onSurfaceVariant,
                        ),
                        DsGaps.vXl,
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    final file = File('${dir.path}/$name.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}
