// Renders the pages the client's social walkthrough was about — a shopper's
// page, a boutique's page in the post shape, a department's product posts and
// the «…» menu — to PNGs, so they can be eyeballed without booting the app.
// Not an assertion test beyond "it builds"; it writes `build/visual/*.png`.
//
//   flutter test test/social_pages_visual_preview_test.dart
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
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/domain/pagination/paginated_data.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/brand.dart';
import 'package:reem/core/shared/entities/category.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/seller_offer.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/auth/presentation/providers/auth_notifier.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_state.dart';
import 'package:reem/features/discovery/domain/entities/product_page.dart';
import 'package:reem/features/discovery/presentation/providers/collection_notifier.dart';
import 'package:reem/features/discovery/presentation/providers/collection_state.dart';
import 'package:reem/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:reem/features/discovery/presentation/screens/collection_screen.dart';
import 'package:reem/features/product_social/domain/entities/product_engagement.dart';
import 'package:reem/features/product_social/domain/repositories/product_social_repository.dart';
import 'package:reem/features/product_social/presentation/providers/product_social_providers.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/domain/repositories/social_repository.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';
import 'package:reem/features/user_profile/domain/entities/user_profile.dart';
import 'package:reem/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:reem/features/user_profile/presentation/providers/user_profile_providers.dart';
import 'package:reem/features/user_profile/presentation/screens/user_profile_screen.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

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
}

void _stubChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (_) async => Directory.systemTemp.path,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (_) async => null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    _stubChannels();
    await _loadFonts();
  });

  Future<void> render(
    WidgetTester tester, {
    required String name,
    required Widget home,
    List<Override> overrides = const [],
    ThemeMode mode = ThemeMode.light,
    Future<void> Function()? interact,
  }) async {
    tester.view.physicalSize = const Size(1125, 4200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => _SignedIn(_me)),
          productSocialRepositoryProvider.overrideWithValue(_ProductSocial()),
          socialRepositoryProvider.overrideWithValue(_Social()),
          userProfileRepositoryProvider.overrideWithValue(_Profiles()),
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
          home: home,
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    if (interact != null) {
      await interact();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }
    await _capture(tester, name);
  }

  testWidgets('a shopper\'s page, seen by another shopper', (tester) async {
    await render(
      tester,
      name: 'social_shopper_page',
      home: const UserProfileScreen(userId: 'u-lina'),
    );
    expect(find.byType(UserProfileScreen), findsOneWidget);
  });

  testWidgets('a private shopper\'s page says so', (tester) async {
    await render(
      tester,
      name: 'social_shopper_private',
      home: const UserProfileScreen(userId: 'u-private'),
    );
  });

  testWidgets('her own page, with the switch and the composer', (
    tester,
  ) async {
    await render(
      tester,
      name: 'social_my_page',
      home: const UserProfileScreen(userId: 'u-me'),
    );
  });

  testWidgets('a boutique\'s page shows its pieces as posts', (tester) async {
    await render(
      tester,
      name: 'social_boutique_page',
      home: const UserProfileScreen(userId: 's-atelier'),
      overrides: [
        sellerProductsProvider.overrideWith(
          (ref, id) => CollectionNotifier(
            (page) async => Success(
              ProductPage(items: _products, page: 1, hasNextPage: false),
            ),
          )..load(),
        ),
      ],
    );
  });

  testWidgets('a department\'s posts carry the gestures and a menu', (
    tester,
  ) async {
    await render(
      tester,
      name: 'social_department_posts',
      home: CollectionScreen(provider: _department, title: 'مكياج'),
    );
  });

  testWidgets('the «…» on a product post opens its menu', (tester) async {
    await render(
      tester,
      name: 'social_product_menu',
      home: CollectionScreen(provider: _department, title: 'مكياج'),
      interact: () async {
        await tester.tap(find.byTooltip('خيارات المنشور').first);
      },
    );
  });
}

final _department = StateNotifierProvider<CollectionNotifier, CollectionState>(
  (ref) => CollectionNotifier(
    (page) async =>
        Success(ProductPage(items: _products, page: 1, hasNextPage: false)),
  )..load(),
);

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    final file = File('${dir.path}/$name.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}

// ── Fakes ───────────────────────────────────────────────────────────────────

/// Signed in as a shopper, without the session machinery behind it.
class _SignedIn extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedIn(User user) : super(AuthState(user: user, isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profiles implements UserProfileRepository {
  @override
  Future<Result<UserProfile>> getProfile(String userId) async =>
      Success(_profiles[userId]!);

  @override
  Future<Result<UserProfile>> getMyProfile() async =>
      Success(_profiles['u-me']!);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Social implements SocialRepository {
  @override
  Future<Result<PaginatedData<TimelineEntry>>> userTimeline(
    String userId, {
    String? cursor,
    int limit = 20,
  }) async => Success(
    PaginatedData(
      items: [
        OwnContentEntry(_post('p1', _lina, 'إطلالة العيد — فستان من أتيليه رحاف')),
        ResharedContentEntry(
          ContentReshare(
            id: 'r1',
            resharer: _lina,
            content: _post('p2', _atelier, 'تشكيلة الخريف وصلت ✨'),
            resharedAt: DateTime(2026, 9, 14),
            note: 'بحبها كتير!',
          ),
        ),
      ],
      pageInfo: const PageInfo(page: 1),
    ),
  );

  @override
  Future<Result<PaginatedData<Content>>> byAuthor(
    String authorId, {
    String? contentType,
    String? cursor,
    int limit = 20,
  }) async => Success(PaginatedData.empty<Content>());

  @override
  Future<Result<List<StoryGroup>>> storiesOf(String userId) async =>
      const Success([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProductSocial implements ProductSocialRepository {
  @override
  Future<Result<Map<String, ProductEngagement>>> engagement(
    List<String> ids,
  ) async => Success({
    for (final id in ids)
      id: const ProductEngagement(
        likes: 128,
        comments: 14,
        shares: 6,
        picks: 9,
        isLiked: true,
        viewerKnown: true,
      ),
  });

  @override
  Future<Result<ProductPage>> picksOf(String userId, {int page = 1}) async =>
      Success(ProductPage(items: _products, page: 1, hasNextPage: false));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Fixtures ────────────────────────────────────────────────────────────────

final _me = User(
  id: 'u-me',
  name: 'ريم الأحمد',
  username: 'reem.ahmad',
  phone: '',
  bio: 'بحب الألوان الهادية والقطع اليدوية.',
  followersCount: 42,
  followingCount: 18,
  createdAt: DateTime(2026, 1, 1),
);

final _lina = User(
  id: 'u-lina',
  name: 'لينا حداد',
  username: 'lina.h',
  phone: '',
  bio: 'إطلالات يومية من دمشق 🌸',
  location: 'دمشق',
  followersCount: 1240,
  followingCount: 310,
  createdAt: DateTime(2026, 1, 1),
);

final _private = User(
  id: 'u-private',
  name: 'سلمى',
  username: 'salma',
  phone: '',
  createdAt: DateTime(2026, 1, 1),
);

final _atelier = User(
  id: 's-atelier',
  name: 'أتيليه رحاف',
  username: 'rahaf_atelier',
  phone: '',
  role: UserRole.seller,
  isVerified: true,
  bio: 'فساتين سهرة مطرّزة يدوياً',
  followersCount: 8600,
  followingCount: 12,
  createdAt: DateTime(2026, 1, 1),
);

final _profiles = <String, UserProfile>{
  'u-me': UserProfile(user: _me, isMe: true, postsCount: 3),
  'u-lina': UserProfile(
    user: _lina,
    postsCount: 24,
    picksCount: 9,
    hasStory: true,
    profileIsPublic: true,
  ),
  'u-private': UserProfile(user: _private, postsCount: 5),
  's-atelier': UserProfile(user: _atelier, postsCount: 61, productsCount: 38),
};

Content _post(String id, User author, String body) => Content(
  id: id,
  author: author,
  authorKind: author.isSeller
      ? ContentAuthorKind.seller
      : ContentAuthorKind.customer,
  format: ContentFormat.post,
  status: ContentStatus.published,
  moderationState: ContentModerationState.active,
  visibility: ContentVisibility.public,
  createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  body: body,
  media: const [MediaItem(url: 'https://example.invalid/look.jpg')],
  counts: const ContentCounts(likes: 86, comments: 7, shares: 3),
);

const _category = Category(
  id: 'c1',
  slug: 'makeup',
  nameAr: 'مكياج',
  nameEn: 'Makeup',
  level: 2,
);

Product _product(String id, String title, int price) => Product(
  id: id,
  slug: id,
  title: title,
  description: 'أحمر شفاه مخملي بثبات يدوم طول السهرة.',
  category: _category,
  brand: const Brand(id: 'b1', slug: 'reem', nameAr: 'ريم', nameEn: 'Reem'),
  createdAt: DateTime.now().subtract(const Duration(days: 1)),
  rating: 4.7,
  reviewsCount: 32,
  offers: [
    SellerOffer(
      id: 'o$id',
      seller: _atelier,
      status: OfferStatus.active,
      stock: 5,
      price: Money(raw: '$price', currency: Currency.syp),
    ),
  ],
);

final _products = <Product>[
  _product('11111111-1111-1111-1111-111111111111', 'أحمر شفاه مخملي', 4500),
  _product('22222222-2222-2222-2222-222222222222', 'باليت ظلال', 9800),
];
