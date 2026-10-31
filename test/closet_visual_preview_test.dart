// Renders the closet — خزانتي — to PNGs so the design can be eyeballed
// without a session or a running backend, and checks the behaviour the
// redesign added. Run on demand:
//
//   flutter test test/closet_visual_preview_test.dart
//
// Writes `build/visual/closet_*.png`. The wardrobe is a hand-built fake of a
// realistic closet: twelve pieces across eight slots, two shelved for the
// season, four looks (two ready, two short), three gaps and three answers to
// "what can I wear today". Photos are absent on purpose — `flutter test` has
// no network — so every piece draws the slot art a photo-less piece gets in
// the app.
//
// Beyond the screenshots it asserts what a screenshot cannot:
//
//   - the forgotten pieces the server sends reach the front page;
//   - every slot she can own has a compartment in the wardrobe;
//   - a compartment opens onto exactly its own slot;
//   - the "+" on a compartment opens the form with that slot chosen;
//   - shelved pieces can be found again, in the season box;
//   - a wear logged from a tile can be taken back from its snackbar;
//   - the grid's query is a stable family key, so a rebuild does not refetch.
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
import 'package:ohara/core/shared/entities/category.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/screens/add_personal_item_screen.dart';
import 'package:ohara/features/closet/presentation/screens/closet_compartment_screen.dart';
import 'package:ohara/features/closet/presentation/screens/closet_gap_screen.dart';
import 'package:ohara/features/closet/presentation/screens/closet_item_screen.dart';
import 'package:ohara/features/closet/presentation/screens/closet_look_screen.dart';
import 'package:ohara/features/closet/presentation/screens/closet_looks_screen.dart';
import 'package:ohara/features/closet/presentation/screens/closet_today_screen.dart';
import 'package:ohara/features/closet/presentation/screens/my_closet_screen.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_armoire.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_home_sections.dart';
import 'package:ohara/features/market/presentation/providers/market_providers.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

String? _materialIconsPath() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String>[
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
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
      ..addFont(File(icons).readAsBytes().then((b) => ByteData.view(b.buffer)));
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

void _stubPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.createTempSync('reem_test').path,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
}

/// A phone, and the same phone tall enough to hold a whole page.
const _phone = Size(1125, 2436);
const _tall = Size(1125, 8400);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _stubPlatformChannels();
    await _loadFonts();
  });

  // ── The screenshots ──────────────────────────────────────────────────────

  final screens = <String, (Widget, Size)>{
    'home': (const MyClosetScreen(), _tall),
    'home_phone': (const MyClosetScreen(), _phone),
    'item': (const ClosetItemScreen(itemId: 'item-2'), Size(1125, 4200)),
    'item_unworn': (const ClosetItemScreen(itemId: 'item-4'), Size(1125, 4200)),
    'add': (const AddPersonalItemScreen(), Size(1125, 3600)),
    'looks': (const ClosetLooksScreen(), _phone),
    'look': (const ClosetLookScreen(lookId: 'look-3'), Size(1125, 4200)),
    'today': (const ClosetTodayScreen(), Size(1125, 5400)),
    'gap': (const ClosetGapScreen(gapId: 'gap-1'), Size(1125, 3600)),
    // One of each way a compartment keeps things.
    'drawer_rail': (const ClosetCompartmentScreen(compartmentKey: 'DRESS'), _phone),
    'drawer_shelf': (const ClosetCompartmentScreen(compartmentKey: 'TOP'), _phone),
    'drawer_hooks': (const ClosetCompartmentScreen(compartmentKey: 'BAG'), _phone),
    'drawer_velvet': (const ClosetCompartmentScreen(compartmentKey: 'JEWELRY'), _phone),
    'drawer_rack': (const ClosetCompartmentScreen(compartmentKey: 'SHOES'), _phone),
    'drawer_all': (const ClosetCompartmentScreen(compartmentKey: 'all'), Size(1125, 4200)),
    'drawer_stored': (const ClosetCompartmentScreen(compartmentKey: 'stored'), _phone),
    'drawer_empty': (const ClosetCompartmentScreen(compartmentKey: 'PERFUME'), _phone),
    'add_to_drawer': (const AddPersonalItemScreen(initialSlot: 'JEWELRY'), Size(1125, 3600)),
  };

  for (final entry in screens.entries) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('renders ${entry.key} in ${mode.name}', (tester) async {
        tester.view.physicalSize = entry.value.$2;
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _Preview(themeMode: mode, screen: entry.value.$1),
        );
        await _settle(tester);
        await _capture(tester, 'closet_${entry.key}_${mode.name}');
      });
    }
  }

  testWidgets('renders the empty closet', (tester) async {
    tester.view.physicalSize = const Size(1125, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: const MyClosetScreen(),
        repository: _FakeClosetRepository(empty: true),
      ),
    );
    await _settle(tester);
    await _capture(tester, 'closet_empty_light');
  });

  testWidgets('the front page survives 200% text', (tester) async {
    tester.view.physicalSize = _tall;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: const MyClosetScreen(),
        textScale: 2,
      ),
    );
    await _settle(tester);
    await _capture(tester, 'closet_home_large_text');
    expect(tester.takeException(), isNull);
  });

  // ── The rules a screenshot cannot check ──────────────────────────────────

  testWidgets('the forgotten pieces reach the front page', (tester) async {
    tester.view.physicalSize = _tall;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(themeMode: ThemeMode.light, screen: MyClosetScreen()),
    );
    await _settle(tester);

    final neglected = _overview().neglected;
    expect(neglected, isNotEmpty);
    // The rail builds lazily; walk along it to each one.
    final rail = find.descendant(
      of: find.byType(ClosetRediscoverRail),
      matching: find.byType(Scrollable),
    );
    for (final item in neglected) {
      await tester.scrollUntilVisible(find.text(item.title), 100, scrollable: rail);
      expect(
        find.text(item.title),
        findsWidgets,
        reason: 'the server sent ${item.title} as forgotten; nothing drew it',
      );
    }
  });

  testWidgets('every slot she can own has a compartment', (tester) async {
    tester.view.physicalSize = _tall;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(themeMode: ThemeMode.light, screen: MyClosetScreen()),
    );
    await _settle(tester);

    for (final slot in _slotLabels.keys) {
      expect(
        find.byKey(closetBayKey(slot)),
        slot == 'GIFT' ? findsNothing : findsOneWidget,
        reason: slot == 'GIFT'
            ? 'a gift is a purchase intent, not something kept in a wardrobe'
            : 'nothing in the wardrobe holds $slot',
      );
    }
    expect(find.byKey(closetBayKey('favourites')), findsOneWidget);
    expect(find.byKey(closetBayKey('stored')), findsOneWidget);
  });

  testWidgets('a compartment opens onto its own slot', (tester) async {
    tester.view.physicalSize = _tall;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repository = _FakeClosetRepository();
    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: const MyClosetScreen(),
        repository: repository,
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(closetBayKey('JEWELRY')));
    await _settle(tester);

    expect(find.byType(ClosetCompartmentScreen), findsOneWidget);
    expect(repository.queries.last.slot, 'JEWELRY');
    expect(find.text('عقد لؤلؤ'), findsWidgets);
    // Nothing from any other compartment is in the drawer.
    expect(find.text('فستان سهرة كحلي'), findsNothing);
  });

  testWidgets('the + on a compartment files the new piece there', (tester) async {
    tester.view.physicalSize = _tall;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(themeMode: ThemeMode.light, screen: MyClosetScreen()),
    );
    await _settle(tester);

    final l10n = gen.AppLocalizations.of(
      tester.element(find.byType(MyClosetScreen)),
    )!;
    await tester.tap(find.byTooltip(l10n.closetDrawerAddTo(l10n.closetDrawerJewelry)));
    await _settle(tester);

    final form = tester.widget<AddPersonalItemScreen>(
      find.byType(AddPersonalItemScreen),
    );
    expect(form.initialSlot, 'JEWELRY');
    expect(find.text(l10n.closetAddingTo(l10n.closetDrawerJewelry)), findsOneWidget);
  });

  testWidgets('shelved pieces can be found again in the season box', (tester) async {
    tester.view.physicalSize = _tall;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repository = _FakeClosetRepository();
    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: const MyClosetScreen(),
        repository: repository,
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(closetBayKey('stored')));
    await _settle(tester);

    expect(repository.queries.last.status, ClosetItemStatus.archived);
    for (final item in _shelvedItems()) {
      expect(find.text(item.title), findsWidgets);
    }
  });

  testWidgets('a wear logged inside a compartment can be undone', (tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repository = _FakeClosetRepository();
    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: const ClosetCompartmentScreen(compartmentKey: 'TOP'),
        repository: repository,
      ),
    );
    await _settle(tester);

    final l10n = gen.AppLocalizations.of(
      tester.element(find.byType(ClosetCompartmentScreen)),
    )!;
    await tester.tap(find.byTooltip(l10n.closetWoreToday).first);
    await _settle(tester);
    expect(repository.wears, hasLength(1));

    await tester.tap(find.text(l10n.closetUndo));
    await _settle(tester);
    expect(repository.unwears, [repository.wears.single]);
  });

  testWidgets('a wear logged from a tile can be undone', (tester) async {
    tester.view.physicalSize = _tall;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final repository = _FakeClosetRepository();
    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: const MyClosetScreen(),
        repository: repository,
      ),
    );
    await _settle(tester);

    final l10n = gen.AppLocalizations.of(
      tester.element(find.byType(MyClosetScreen)),
    )!;
    // The first forgotten piece on the front page — none is worn today.
    final wearButtons = find.descendant(
      of: find.byType(ClosetRediscoverRail),
      matching: find.byTooltip(l10n.closetWoreToday),
    );
    expect(wearButtons, findsWidgets);
    await tester.tap(wearButtons.first);
    await _settle(tester);

    expect(repository.wears, hasLength(1));
    final undo = find.text(l10n.closetUndo);
    expect(undo, findsOneWidget, reason: 'a logged wear must offer an undo');

    await tester.tap(undo);
    await _settle(tester);
    expect(repository.unwears, [repository.wears.single]);
  });

  test('the grid query is a stable family key', () {
    const a = ClosetItemQuery(slot: 'TOP', favouritesOnly: true, limit: 48);
    const b = ClosetItemQuery(slot: 'TOP', favouritesOnly: true, limit: 48);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == const ClosetItemQuery(slot: 'DRESS', limit: 48), isFalse);
  });
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
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

class _Preview extends StatelessWidget {
  const _Preview({
    required this.themeMode,
    required this.screen,
    this.repository,
    this.textScale = 1,
  });

  final ThemeMode themeMode;
  final Widget screen;
  final ClosetRepository? repository;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale,
            maxScaleFactor: textScale,
            child: RepaintBoundary(key: _captureKey, child: screen),
          ),
        ),
        GoRoute(
          path: '/closet/drawers/:key',
          builder: (context, state) => ClosetCompartmentScreen(
            compartmentKey: state.pathParameters['key']!,
          ),
        ),
        GoRoute(
          path: '/closet/add',
          builder: (context, state) => AddPersonalItemScreen(
            initialSlot: state.uri.queryParameters['slot'],
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        closetRepositoryProvider.overrideWithValue(
          repository ?? _FakeClosetRepository(),
        ),
        wardrobeSummaryProvider.overrideWith((ref) async => null),
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
        routerConfig: router,
      ),
    );
  }
}

// ── The fake wardrobe ─────────────────────────────────────────────────────

Money _syp(num value) => Money(raw: '$value', currency: Currency.syp);

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

ClosetTerm _t(String key, String label) => ClosetTerm(key: key, label: label);

const _slotLabels = {
  'DRESS': 'فستان',
  'TOP': 'قطعة علوية',
  'BOTTOM': 'قطعة سفلية',
  'OUTERWEAR': 'معطف',
  'ABAYA': 'عباءة',
  'SHOES': 'حذاء',
  'BAG': 'حقيبة',
  'JEWELRY': 'مجوهرات',
  'ACCESSORY': 'إكسسوار',
  'PERFUME': 'عطر',
  'BEAUTY': 'تجميل',
  'GIFT': 'هدية',
};

ClosetItem _item(
  int n,
  String title,
  String slot, {
  int wears = 0,
  int? lastWornDays,
  bool favourite = false,
  bool personal = false,
  num? price,
  ClosetItemStatus status = ClosetItemStatus.active,
  List<ClosetTerm> colours = const [],
  List<String> materials = const [],
  String? brand,
  String? size,
  String? note,
}) => ClosetItem(
  id: 'item-$n',
  source: personal ? ClosetItemSource.personal : ClosetItemSource.purchase,
  sourceLabel: personal ? 'من خزانتي' : 'من أوهارا',
  status: status,
  title: title,
  slot: slot,
  slotLabel: _slotLabels[slot]!,
  colours: colours,
  materials: materials,
  seasons: [_t('TRANSITIONAL', 'الخريف والربيع')],
  occasions: slot == 'DRESS' || slot == 'ABAYA'
      ? [_t('WEDDING', 'عرس'), _t('EVENING', 'سهرة')]
      : [_t('WORK', 'عمل'), _t('CASUAL', 'يومي')],
  modestyLabel: 'محتشمة',
  size: size,
  brandName: brand,
  productId: personal ? null : 'product-$n',
  purchasePrice: price == null ? null : _syp(price),
  costPerWear: price == null || wears == 0 ? null : _syp((price / wears).round()),
  wearCount: wears,
  lastWornAt: lastWornDays == null ? null : _daysAgo(lastWornDays),
  isFavourite: favourite,
  note: note,
);

final _items = <ClosetItem>[
  _item(
    1,
    'فستان سهرة كحلي',
    'DRESS',
    wears: 3,
    lastWornDays: 21,
    favourite: true,
    price: 450000,
    colours: [_t('NAVY', 'كحلي')],
    materials: ['ساتان'],
    brand: 'لمسة',
    size: 'M',
  ),
  _item(
    2,
    'بلوزة حرير بيضاء',
    'TOP',
    wears: 14,
    lastWornDays: 3,
    price: 180000,
    colours: [_t('WHITE', 'أبيض')],
    materials: ['حرير'],
    brand: 'دار ياسمين',
    size: 'S',
    note: 'تليق مع البنطال البيج والحقيبة البنية — إطلالتي المفضلة للاجتماعات.',
  ),
  _item(3, 'بنطال واسع بيج', 'BOTTOM', wears: 7, lastWornDays: 3, price: 120000),
  _item(4, 'عباءة سوداء مطرّزة', 'ABAYA', personal: true, colours: [_t('BLACK', 'أسود')]),
  _item(5, 'معطف صوف جملي', 'OUTERWEAR', wears: 6, lastWornDays: 140, price: 600000),
  _item(6, 'حذاء كعب نود', 'SHOES', wears: 5, lastWornDays: 0, price: 210000),
  _item(7, 'حقيبة يد جلد بني', 'BAG', wears: 9, lastWornDays: 3, favourite: true, price: 330000),
  _item(8, 'عقد لؤلؤ', 'JEWELRY', wears: 2, lastWornDays: 21, favourite: true),
  _item(9, 'تنورة ميدي زهرية', 'BOTTOM', personal: true),
  _item(10, 'كنزة كشمير رمادية', 'TOP', wears: 4, lastWornDays: 9, price: 260000),
  _item(11, 'وشاح حرير مزخرف', 'ACCESSORY', wears: 1, lastWornDays: 110, personal: true),
  _item(12, 'حذاء رياضي أبيض', 'SHOES', wears: 22, lastWornDays: 1, price: 150000),
];

List<ClosetItem> _shelvedItems() => [
  _item(13, 'فستان صيفي كتان', 'DRESS', wears: 8, lastWornDays: 70, status: ClosetItemStatus.archived),
  _item(14, 'صندل ذهبي', 'SHOES', wears: 5, lastWornDays: 75, status: ClosetItemStatus.archived),
];

ClosetItem _byId(String id) =>
    [..._items, ..._shelvedItems()].firstWhere((item) => item.id == id);

Product _product(String id, String title, num price) => Product(
  id: id,
  slug: id,
  title: title,
  description: '',
  category: const Category(id: 'c', slug: 'c', nameAr: 'أزياء', nameEn: 'Fashion'),
  createdAt: DateTime(2026, 9),
  priceFrom: _syp(price),
);

ClosetOverview _overview({bool empty = false}) => ClosetOverview(
  settings: const ClosetSettings(id: 'closet-1'),
  season: 'TRANSITIONAL',
  seasonLabel: 'الخريف',
  itemsCount: empty ? 0 : _items.length,
  archivedCount: empty ? 0 : _shelvedItems().length,
  looksCount: empty ? 0 : _looks().length,
  completeLooksCount: empty ? 0 : 2,
  wornThisMonth: empty ? 0 : 14,
  outfitCapacity: empty ? 0 : 36,
  seasonOutfitCapacity: empty ? 0 : 24,
  slotCounts: empty
      ? const []
      : const [
          SlotCount(slot: 'TOP', label: 'قطعة علوية', count: 2),
          SlotCount(slot: 'BOTTOM', label: 'قطعة سفلية', count: 2),
          SlotCount(slot: 'SHOES', label: 'حذاء', count: 2),
          SlotCount(slot: 'DRESS', label: 'فستان', count: 1),
          SlotCount(slot: 'ABAYA', label: 'عباءة', count: 1),
          SlotCount(slot: 'OUTERWEAR', label: 'معطف', count: 1),
          SlotCount(slot: 'BAG', label: 'حقيبة', count: 1),
          SlotCount(slot: 'JEWELRY', label: 'مجوهرات', count: 1),
          SlotCount(slot: 'ACCESSORY', label: 'إكسسوار', count: 1),
        ],
  neglected: empty
      ? const []
      : [_byId('item-4'), _byId('item-9'), _byId('item-5'), _byId('item-11')],
  gaps: empty ? const [] : _gaps(),
  vocabulary: ClosetVocabulary(
    slots: [for (final e in _slotLabels.entries) _t(e.key, e.value)],
    occasions: [
      _t('WORK', 'عمل'),
      _t('CASUAL', 'يومي'),
      _t('EVENING', 'سهرة'),
      _t('WEDDING', 'عرس'),
      _t('EID', 'عيد'),
    ],
    seasons: [_t('SUMMER', 'صيف'), _t('WINTER', 'شتاء')],
  ),
);

List<ClosetGap> _gaps() => [
  ClosetGap(
    id: 'gap-1',
    kind: ClosetGapKind.coverage,
    slot: 'SHOES',
    slotLabel: 'حذاء',
    headline: 'حذاء سهرة أسود يفتح لكِ ٦ إطلالات جديدة',
    rationale:
        'لديكِ فستانان وعباءة للمناسبات، وحذاء واحد فقط يليق بها. حذاء أسود بكعب متوسط ينسجم مع ٥ من قطعكِ.',
    priority: 78,
    components: const {
      'base': 30,
      'outfit_gain': 28,
      'outfits_unlocked': 6,
      'core_slot': 10,
      'season_fit': 4,
    },
    suggestedColours: [_t('BLACK', 'أسود'), _t('GOLD', 'ذهبي')],
    suggestedSize: '38',
    suggestedBudgetMin: _syp(150000),
    suggestedBudgetMax: _syp(300000),
  ),
  const ClosetGap(
    id: 'gap-2',
    kind: ClosetGapKind.lookSlot,
    slot: 'BAG',
    slotLabel: 'حقيبة',
    lookId: 'look-3',
    lookTitle: 'سهرة الخميس',
    headline: 'حقيبة سهرة صغيرة تُكمل «سهرة الخميس»',
    rationale: 'اخترتِ الفستان الكحلي وعقد اللؤلؤ، وتنقص الإطلالة حقيبة فقط.',
    priority: 64,
    components: {'base': 25, 'nearly_complete': 24, 'favourite_look': 15},
  ),
  const ClosetGap(
    id: 'gap-3',
    kind: ClosetGapKind.season,
    slot: 'OUTERWEAR',
    slotLabel: 'معطف',
    headline: 'معطف خفيف للخريف',
    rationale: 'معطفكِ الوحيد صوفي ثقيل، والطقس هذه الأيام بين الدافئ والبارد.',
    priority: 51,
    components: {'base': 20, 'season_fit': 18, 'sole_in_slot': 13},
  ),
];

LookPiece _owned(String slot, String itemId, [int position = 0]) => LookPiece(
  id: '$slot-$itemId',
  slot: slot,
  slotLabel: _slotLabels[slot]!,
  position: position,
  owned: _byId(itemId),
);

List<ClosetLook> _looks() => [
  ClosetLook(
    id: 'look-1',
    title: 'إطلالة العمل الهادئة',
    occasion: 'WORK',
    occasionLabel: 'عمل',
    isComplete: true,
    isFavourite: true,
    wearCount: 5,
    lastWornAt: _daysAgo(3),
    palette: [_t('WHITE', 'أبيض'), _t('BEIGE', 'بيج'), _t('BROWN', 'بني')],
    seasons: [_t('TRANSITIONAL', 'الخريف والربيع')],
    pieces: [
      _owned('TOP', 'item-2'),
      _owned('BOTTOM', 'item-3'),
      _owned('SHOES', 'item-6'),
      _owned('BAG', 'item-7'),
    ],
  ),
  ClosetLook(
    id: 'look-2',
    title: 'غداء مع الصديقات',
    occasion: 'CASUAL',
    occasionLabel: 'يومي',
    isComplete: true,
    pieces: [
      _owned('TOP', 'item-10'),
      _owned('BOTTOM', 'item-9'),
      _owned('SHOES', 'item-12'),
    ],
  ),
  ClosetLook(
    id: 'look-3',
    title: 'سهرة الخميس',
    occasion: 'EVENING',
    occasionLabel: 'سهرة',
    note: 'للعشاء في بيت جدتي — شيء أنيق وبسيط.',
    palette: [_t('NAVY', 'كحلي'), _t('PEARL', 'لؤلؤي')],
    missingSlots: [_t('BAG', 'حقيبة')],
    sourceOutfitId: 'outfit-9',
    pieces: [
      _owned('DRESS', 'item-1'),
      _owned('JEWELRY', 'item-8', 1),
      LookPiece(
        id: 'BAG-wanted',
        slot: 'BAG',
        slotLabel: 'حقيبة',
        position: 2,
        product: _product('p-bag', 'حقيبة سهرة مخملية كحلية', 175000),
      ),
    ],
  ),
  ClosetLook(
    id: 'look-4',
    title: 'عرس ابنة خالتي',
    occasion: 'WEDDING',
    occasionLabel: 'عرس',
    missingSlots: [_t('SHOES', 'حذاء'), _t('BAG', 'حقيبة')],
    pieces: [_owned('ABAYA', 'item-4')],
  ),
];

TodayOutfits _today() => TodayOutfits(
  season: 'TRANSITIONAL',
  outfits: [
    TodayOutfit(
      key: 'saved-look-1',
      origin: 'SAVED',
      lookId: 'look-1',
      lookTitle: 'إطلالة العمل الهادئة',
      occasionLabel: 'عمل',
      score: 0.92,
      reasons: [_t('season', 'تناسب الطقس'), _t('rotation', 'لم تلبسيها منذ ٣ أيام')],
      pieces: [_byId('item-2'), _byId('item-3'), _byId('item-6'), _byId('item-7')],
    ),
    TodayOutfit(
      key: 'composed-1',
      origin: 'COMPOSED',
      score: 0.81,
      reasons: [_t('palette', 'ألوان متناسقة'), _t('fresh', 'قطع لم تلبسيها مؤخراً')],
      pieces: [_byId('item-10'), _byId('item-9'), _byId('item-12')],
    ),
    TodayOutfit(
      key: 'composed-2',
      origin: 'COMPOSED',
      occasionLabel: 'سهرة',
      score: 0.66,
      reasons: [_t('favourite', 'من قطعكِ المفضّلة')],
      missingSlots: [_t('SHOES', 'حذاء')],
      pieces: [_byId('item-1'), _byId('item-8')],
    ),
  ],
);

class _FakeClosetRepository implements ClosetRepository {
  _FakeClosetRepository({this.empty = false});

  final bool empty;
  final queries = <ClosetItemQuery>[];
  final wears = <String>[];
  final unwears = <String>[];

  @override
  Future<Result<ClosetOverview>> overview() async =>
      Success(_overview(empty: empty));

  @override
  Future<Result<ClosetItemPage>> items(ClosetItemQuery query) async {
    queries.add(query);
    if (empty) return const Success(ClosetItemPage());
    final source = query.status == ClosetItemStatus.archived
        ? _shelvedItems()
        : _items;
    final search = query.search?.trim();
    return Success(
      ClosetItemPage(
        items: source
            .where((item) => query.slot == null || item.slot == query.slot)
            .where((item) => query.favouritesOnly != true || item.isFavourite)
            .where(
              (item) =>
                  search == null ||
                  search.isEmpty ||
                  item.title.contains(search),
            )
            .toList(growable: false),
      ),
    );
  }

  @override
  Future<Result<ClosetItem>> item(String id) async => Success(_byId(id));

  @override
  Future<Result<ClosetItem>> logWear(String id, {DateTime? wornOn}) async {
    wears.add(id);
    final item = _byId(id);
    return Success(
      ClosetItem(
        id: item.id,
        source: item.source,
        sourceLabel: item.sourceLabel,
        status: item.status,
        title: item.title,
        slot: item.slot,
        slotLabel: item.slotLabel,
        wearCount: item.wearCount + 1,
        lastWornAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<Result<ClosetItem>> removeWear(String id, {DateTime? wornOn}) async {
    unwears.add(id);
    return Success(_byId(id));
  }

  @override
  Future<Result<List<ClosetLook>>> looks({
    String? occasion,
    bool includeArchived = false,
  }) async => Success(empty ? const [] : _looks());

  @override
  Future<Result<ClosetLook>> look(String id) async =>
      Success(_looks().firstWhere((look) => look.id == id));

  @override
  Future<Result<List<ClosetGap>>> gaps() async =>
      Success(empty ? const [] : _gaps());

  @override
  Future<Result<GapSuggestions>> gapSuggestions(String gapId, {int? limit}) async =>
      Success(
        GapSuggestions(
          gap: _gaps().firstWhere((gap) => gap.id == gapId),
          suggestions: [
            ClosetSuggestion(
              product: _product('p-1', 'حذاء سهرة أسود بكعب متوسط', 245000),
              score: 0.9,
              pairingScore: 0.86,
              pairingReasons: [_t('colour', 'يليق بألوانكِ'), _t('size', 'بمقاسكِ')],
              pairsWithItemIds: const ['item-1', 'item-4', 'item-8', 'item-3', 'item-2'],
              completesLookIds: const ['look-4'],
            ),
            ClosetSuggestion(
              product: _product('p-2', 'حذاء مخمل ذهبي', 198000),
              score: 0.8,
              pairingScore: 0.64,
              pairingReasons: [_t('occasion', 'للمناسبات')],
              pairsWithItemIds: const ['item-1', 'item-4', 'item-8'],
            ),
            ClosetSuggestion(
              product: _product('p-3', 'حذاء جلد لامع بإبزيم', 165000),
              score: 0.7,
              pairingScore: 0.41,
              pairsWithItemIds: const ['item-1', 'item-3'],
            ),
          ],
        ),
      );

  @override
  Future<Result<TodayOutfits>> today({String? occasion, int? limit}) async =>
      Success(empty ? const TodayOutfits(season: 'TRANSITIONAL') : _today());

  // Writes the previews never make.
  Never _unused() => throw UnimplementedError();

  @override
  Future<Result<ClosetSettings>> updateSettings({
    bool? autoAddPurchases,
    bool? suggestionsEnabled,
  }) => _unused();

  @override
  Future<Result<int>> backfill({int? limit}) async => const Success(0);

  @override
  Future<Result<ClosetItem>> addFromCatalog({
    required String productId,
    String? offerId,
    String? variantId,
    String? note,
    DescriptorPatch? descriptor,
  }) => _unused();

  @override
  Future<Result<ClosetItem>> addPersonal(PersonalItemDraft draft) => _unused();

  @override
  Future<Result<ClosetItem>> updateItem(String id, ClosetItemPatch patch) =>
      _unused();

  @override
  Future<Result<ClosetItem>> setItemStatus(String id, ClosetItemStatus status) =>
      _unused();

  @override
  Future<Result<void>> removeItem(String id) => _unused();

  @override
  Future<Result<ClosetLook>> createLook(LookDraft draft) => _unused();

  @override
  Future<Result<ClosetLook>> updateLook(String id, LookPatch patch) => _unused();

  @override
  Future<Result<ClosetLook>> setLookItems(String id, List<LookSlotDraft> items) =>
      _unused();

  @override
  Future<Result<void>> removeLook(String id) => _unused();

  @override
  Future<Result<ClosetLook>> logLookWear(
    String id, {
    DateTime? wornOn,
    String? occasionNote,
  }) => _unused();

  @override
  Future<Result<ClosetLook>> promoteStylistOutfit(String outfitId) => _unused();

  @override
  Future<Result<List<ClosetGap>>> refreshGaps() => _unused();

  @override
  Future<Result<ClosetGap>> dismissGap(String gapId) => _unused();

  @override
  Future<Result<ClosetGap>> restoreGap(String gapId) => _unused();

  @override
  Future<Result<ClosetPairing?>> pairing(String productId) async =>
      const Success(null);
}
