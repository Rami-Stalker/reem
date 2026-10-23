// Renders the profile headers to PNGs so the design can be eyeballed without a
// session or a running backend. Not an assertion test in the usual sense — it
// writes `build/visual/profile_*.png` and is meant to be run on demand.
//
//   flutter test test/profile_visual_preview_test.dart
//
// It draws the parts the redesign changed — the arch portrait, nameplate,
// quote, arch stats, actions, a boutique's awning and the tab bar — for a
// shopper's page, a boutique's page and her own profile, in both themes. The
// tabs' contents are the app's ordinary feeds and are not part of this.
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/profile/presentation/widgets/profile_header.dart';
import 'package:reem/features/user_profile/domain/entities/seller_stats.dart';
import 'package:reem/features/user_profile/domain/entities/user_profile.dart';
import 'package:reem/features/user_profile/presentation/widgets/profile_page_header.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

String? _materialIconsPath() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String>[
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    'C:/src/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
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

final _shopper = UserProfile(
  user: User(
    id: 'u-shopper',
    name: 'لمى الحسن',
    username: 'lama.styles',
    phone: '+963991234567',
    bio: 'أحب الألوان الهادئة والقطع التي تعيش طويلاً. أشارك هنا ما ألبسه فعلاً.',
    location: 'دمشق، المزة',
    followersCount: 1280,
    followingCount: 214,
    createdAt: DateTime(2026),
  ),
  postsCount: 46,
  hasStory: true,
  profileIsPublic: true,
);

final _boutique = UserProfile(
  user: User(
    id: 'u-boutique',
    name: 'بوتيك ياسمين',
    username: 'yasmine.boutique',
    phone: '+963944000111',
    role: UserRole.seller,
    isVerified: true,
    bio: 'فساتين سهرة وعبايات مطرّزة يدوياً — من مشغلنا في الشعلان إلى خزانتكِ.',
    location: 'دمشق، الشعلان',
    followersCount: 18400,
    followingCount: 37,
    createdAt: DateTime(2025),
  ),
  isFollowing: true,
  postsCount: 312,
  profileIsPublic: true,
  sellerStats: const SellerStats(
    productsCount: 128,
    totalSales: [Money(raw: '84500000', currency: Currency.syp)],
    ordersCount: 642,
    averageRating: 4.7,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders a shopper page in ${mode.name}', (tester) async {
      await _render(
        tester,
        mode,
        _Page(
          header: ProfilePageHeader(
            profile: _shopper,
            isFollowLoading: false,
            onToggleFollow: () {},
          ),
          tone: ProfileTone.shopper,
          tabs: const [
            ProfileTabItem(icon: Icons.grid_view_rounded, label: 'المنشورات'),
            ProfileTabItem(icon: Icons.play_circle_rounded, label: 'ريلز'),
            ProfileTabItem(icon: Icons.bookmark_added_rounded, label: 'اختياراتها'),
            ProfileTabItem(icon: Icons.auto_stories_rounded, label: 'القصص'),
          ],
        ),
        'profile_shopper_${mode.name}',
      );
    });

    testWidgets('renders a boutique page in ${mode.name}', (tester) async {
      await _render(
        tester,
        mode,
        _Page(
          header: ProfilePageHeader(
            profile: _boutique,
            isFollowLoading: false,
            onToggleFollow: () {},
          ),
          tone: ProfileTone.boutique,
          tabs: const [
            ProfileTabItem(icon: Icons.shopping_bag_rounded, label: 'المنتجات'),
            ProfileTabItem(icon: Icons.grid_view_rounded, label: 'المنشورات'),
            ProfileTabItem(icon: Icons.play_circle_rounded, label: 'ريلز'),
            ProfileTabItem(icon: Icons.auto_stories_rounded, label: 'القصص'),
            ProfileTabItem(icon: Icons.star_rounded, label: 'التقييمات'),
          ],
        ),
        'profile_boutique_${mode.name}',
      );
    });

    testWidgets('renders her own profile in ${mode.name}', (tester) async {
      await _render(
        tester,
        mode,
        _Page(
          header: ProfileHeader(user: _shopper.user, savedCount: 23),
          tone: ProfileTone.shopper,
          tabs: const [],
        ),
        'profile_mine_${mode.name}',
      );
    });
  }
}

Future<void> _render(
  WidgetTester tester,
  ThemeMode mode,
  Widget page,
  String name,
) async {
  tester.view.physicalSize = const Size(1125, 3300);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
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
        home: RepaintBoundary(key: _captureKey, child: page),
      ),
    ),
  );
  await tester.pump();
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }

  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });

  // Stop the ambient loops so the test can finish cleanly.
  await tester.pumpWidget(const SizedBox.shrink());
}

class _Page extends StatelessWidget {
  const _Page({required this.header, required this.tone, required this.tabs});

  final Widget header;
  final ProfileTone tone;
  final List<ProfileTabItem> tabs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dsColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: header),
          if (tabs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.lg,
                  vertical: DsSpacing.xs,
                ),
                child: ProfileTabBar(
                  items: tabs,
                  selected: 0,
                  tone: tone,
                  onSelect: (_) {},
                ),
              ),
            ),
        ],
      ),
    );
  }
}
