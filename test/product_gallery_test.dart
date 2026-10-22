// A product page carries three photographs and shoppers were reporting one.
// The swipe worked; nothing else did — no thumbnails, no way in but a guess,
// and a row of dots over a busy image as the only hint that there was more.
//
// These pin what the page now offers: a rail that shows every photograph and
// jumps to it, and a counter that says how many there are.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/features/product_details/presentation/widgets/product_gallery_header.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;
import 'package:reem/l10n/app_localizations_ar.dart';

void main() {
  // The header is a portrait plate plus its rail: on a phone-sized surface the
  // rail sits below the fold, and a tap on something off screen proves
  // nothing. These tests stand on a tall viewport so the whole header is real.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  Widget harness(List<MediaItem> media) {
    return MaterialApp(
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
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            ProductGalleryHeader(media: media, title: 'فستان سهرة'),
            const SliverToBoxAdapter(child: SizedBox(height: 1200)),
          ],
        ),
      ),
    );
  }

  List<MediaItem> photographs(int count) => [
    for (var i = 0; i < count; i++)
      MediaItem(url: 'https://example.com/$i.jpg', sortOrder: i),
  ];

  testWidgets('three photographs get a rail and a counter', (tester) async {
    await tester.pumpWidget(harness(photographs(3)));
    await tester.pump();

    final l10n = AppLocalizationsAr();
    // "1/3" over the plate, and one thumbnail per photograph in the rail.
    expect(find.byType(DsCounterPill), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.galleryPhotoPosition(2, 3)), findsWidgets);
  });

  testWidgets('a single photograph gets neither', (tester) async {
    await tester.pumpWidget(harness(photographs(1)));
    await tester.pump();

    expect(find.byType(DsCounterPill), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('tapping a thumbnail moves the gallery to it', (tester) async {
    await tester.pumpWidget(harness(photographs(3)));
    await tester.pump();

    final l10n = AppLocalizationsAr();
    await tester.tap(
      find.bySemanticsLabel(l10n.galleryPhotoPosition(3, 3)).last,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('the bookmark reports taps to whoever owns the shelf', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: L10nSetup.supportedLocales,
        localizationsDelegates: const [
          gen.AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              ProductGalleryHeader(
                media: photographs(2),
                title: 'فستان سهرة',
                onToggleSave: () => taps += 1,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // A bookmark, not a heart. The heart on every catalogue tile is the
    // product's public like now, and this control is «المفضّلة» — her private
    // shelf. Drawing both as hearts meant filling one and finding the other
    // empty on the same product.
    await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
    await tester.pump();

    expect(taps, 1, reason: 'the screen never passed a handler before');
  });
}
