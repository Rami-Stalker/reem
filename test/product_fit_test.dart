// The product page's fitting room: the size-fit line under the size row, and
// the collapsing gaps that keep an empty fitting room from leaving a blank
// band. Also renders the line's two voices to PNGs.
//
//   flutter test test/product_fit_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/shared/entities/product_variant.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/intelligence/domain/entities/size_fit.dart';
import 'package:ohara/features/intelligence/presentation/providers/intelligence_providers.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_fit_line.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

Future<void> _loadFonts() async {
  final loader = FontLoader('Cairo')
    ..addFont(
      File(
        'assets/fonts/Cairo-VariableFont.ttf',
      ).readAsBytes().then((b) => ByteData.view(b.buffer)),
    );
  await loader.load();
}

OfferVariant _size(String size) => OfferVariant(
  id: 'ov-$size',
  variantId: 'v-$size',
  name: size,
  price: Money.zeroSyp,
  stock: 3,
  attributes: {'size': size, 'color': 'خوخي'},
);

Widget _host(Widget child, {required List<SizeFit> fits, ThemeMode? mode}) {
  return ProviderScope(
    overrides: [
      productSizeFitProvider('p1').overrideWith((ref) async => fits),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: mode ?? ThemeMode.light,
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
      home: RepaintBoundary(
        key: _captureKey,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.dsColors.background,
            body: Padding(padding: DsSpacing.paddingLg, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  group('one spelling per size, the same as the server', () {
    // These pairs are the server's own cases in kernel/size-fit.spec.ts; if
    // the two sides disagree, a variant never finds its rate.
    test('case, spacing and 2XL are not new sizes', () {
      expect(normaliseSize(' m '), 'M');
      expect(normaliseSize('2xl'), 'XXL');
      expect(normaliseSize('3XL'), 'XXXL');
      expect(normaliseSize(42), '42');
      expect(normaliseSize('  '), isNull);
      expect(normaliseSize(null), isNull);
    });

    test('a size without a rate is not a fit to show', () {
      const fits = [SizeFit(size: 'M', keptRate: 0.92), SizeFit(size: 'L')];
      expect(fitForSize(fits, 'm')?.keptPercent, 92);
      expect(fitForSize(fits, 'L'), isNull);
      expect(fitForSize(fits, 'S'), isNull);
    });
  });

  group('the fit line', () {
    const fits = [
      SizeFit(size: 'M', keptRate: 0.92),
      SizeFit(size: 'L', keptRate: 0.64),
      SizeFit(size: 'XL'),
    ];

    testWidgets('speaks plainly about a size that is kept', (tester) async {
      await tester.pumpWidget(
        _host(
          ProductFitLine(productId: 'p1', variant: _size('M')),
          fits: fits,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('M: أبقته 92% ممّن وصلهنّ بهذا المقاس'), findsOneWidget);
    });

    testWidgets('cautions about a size that is often sent back', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ProductFitLine(productId: 'p1', variant: _size('L')),
          fits: fits,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('L: يُعاد كثيراً بسبب المقاس — أبقته 64% فقط'),
        findsOneWidget,
      );
    });

    testWidgets('says nothing below the sample floor or without a size', (
      tester,
    ) async {
      for (final variant in [
        _size('XL'),
        const OfferVariant(
          id: 'ov-scent',
          variantId: 'v-scent',
          name: 'ياسمين',
          price: Money.zeroSyp,
          attributes: {'scent': 'ياسمين'},
        ),
        null,
      ]) {
        await tester.pumpWidget(
          _host(
            ProductFitLine(productId: 'p1', variant: variant),
            fits: fits,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(ProductFitLine)).height,
          0,
          reason: variant?.name ?? 'no variant',
        );
      }
    });

    testWidgets('renders both voices in both themes', (tester) async {
      tester.view.physicalSize = const Size(1170, 600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          _host(
            Column(
              children: [
                ProductFitLine(productId: 'p1', variant: _size('M')),
                ProductFitLine(productId: 'p1', variant: _size('L')),
              ],
            ),
            fits: fits,
            mode: mode,
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              _captureKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ImageByteFormat.png);
          final dir = Directory('build/visual')..createSync(recursive: true);
          File(
            '${dir.path}/product_fit_line_${mode.name}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
        });
      }
    });
  });

  group('a collapsing gap', () {
    Future<double> heightOf(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 300,
              child: DsCollapsingGap(before: 32, after: 8, child: child),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(DsCollapsingGap)).height;
    }

    testWidgets('takes no room when its section draws nothing', (
      tester,
    ) async {
      expect(await heightOf(tester, const SizedBox.shrink()), 0);
    });

    testWidgets('adds its space around a section that drew something', (
      tester,
    ) async {
      expect(await heightOf(tester, const SizedBox(height: 50)), 32 + 50 + 8);
      // The section sits below the space before it, not on top of it.
      expect(
        tester.getTopLeft(find.byType(SizedBox).last).dy -
            tester.getTopLeft(find.byType(DsCollapsingGap)).dy,
        32,
      );
    });
  });
}
