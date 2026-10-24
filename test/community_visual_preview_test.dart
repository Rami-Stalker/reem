// Renders the community — «اكتشفي» and «أتابع», signed in and signed out, in
// both themes — to PNGs, so the screen can be eyeballed without booting the
// app. Beyond "it builds" it checks what each state must say.
//
//   flutter test test/community_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/domain/pagination/paginated_data.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/auth/presentation/providers/auth_notifier.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_state.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/domain/repositories/social_repository.dart';
import 'package:ohara/features/social/presentation/providers/social_providers.dart';
import 'package:ohara/features/social/presentation/screens/social_feed_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

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
    User? user,
    bool guest = false,
    _Social? social,
    ThemeMode mode = ThemeMode.light,
    Future<void> Function()? interact,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 141, bottom: 102);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            (ref) => _Auth(guest ? null : user ?? _meUser),
          ),
          socialRepositoryProvider.overrideWithValue(social ?? _Social()),
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
          home: const SocialFeedScreen(),
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

  Future<void> openFollowing(WidgetTester tester) async {
    await tester.tap(find.text('أتابع'));
  }

  testWidgets('«اكتشفي» — stories, heading and the first posts', (
    tester,
  ) async {
    await render(tester, name: 'community_discover');
    expect(find.text('المجتمع'), findsOneWidget);
    expect(find.text('قصص اليوم'), findsOneWidget);
    expect(find.text('أحدث الإطلالات'), findsOneWidget);
    expect(find.text('شاركي إطلالتك'), findsOneWidget);
  });

  testWidgets('«اكتشفي» in the dark', (tester) async {
    await render(tester, name: 'community_discover_dark', mode: ThemeMode.dark);
  });

  testWidgets('«أتابع» reads timeline entries and credits the resharer', (
    tester,
  ) async {
    await render(
      tester,
      name: 'community_following',
      interact: () => openFollowing(tester),
    );
    expect(find.text('من اللواتي تتابعينهن'), findsOneWidget);
    // The reshare banner names who put it there.
    expect(find.textContaining(_lina.name), findsWidgets);
  });

  testWidgets('«أتابع» signed out invites her in instead of failing', (
    tester,
  ) async {
    final social = _Social();
    await render(
      tester,
      name: 'community_following_guest',
      guest: true,
      social: social,
      interact: () => openFollowing(tester),
    );
    expect(find.text('دائرتكِ الخاصة'), findsOneWidget);
    expect(social.followingCalls, 0);
  });

  testWidgets('«أتابع» following nobody points back to «اكتشفي»', (
    tester,
  ) async {
    await render(
      tester,
      name: 'community_following_empty',
      social: _Social(followingEmpty: true),
      interact: () => openFollowing(tester),
    );
    expect(find.text('اكتشفي المجتمع'), findsOneWidget);
  });

  testWidgets('the end of the feed says so', (tester) async {
    await render(
      tester,
      name: 'community_caught_up',
      interact: () async {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -6000),
        );
      },
    );
    expect(find.text('وصلتِ إلى آخر الجديد'), findsOneWidget);
  });
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

// ── Fakes ───────────────────────────────────────────────────────────────────

class _Auth extends StateNotifier<AuthState> implements AuthNotifier {
  _Auth(User? user) : super(AuthState(user: user, isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Social implements SocialRepository {
  _Social({this.followingEmpty = false});

  final bool followingEmpty;
  int followingCalls = 0;

  @override
  Future<Result<PaginatedData<Content>>> feed({
    String? cursor,
    int limit = 20,
  }) async => Success(
    PaginatedData(
      items: [
        _post('d1', _atelier, 'تشكيلة الخريف وصلت ✨ قطع مطرّزة يدوياً'),
        _post('d2', _lina, 'إطلالة العيد — فستان من أتيليه رحاف'),
        _post('d3', _sara, 'لون السنة على الشفاه 💄'),
      ],
      pageInfo: const PageInfo(page: 1),
    ),
  );

  @override
  Future<Result<PaginatedData<TimelineEntry>>> following({
    String? cursor,
    int limit = 20,
  }) async {
    followingCalls++;
    if (followingEmpty) return Success(PaginatedData.empty<TimelineEntry>());
    return Success(
      PaginatedData(
        items: [
          ResharedContentEntry(
            ContentReshare(
              id: 'r1',
              resharer: _lina,
              content: _post('f1', _atelier, 'فستان سهرة بلون الشمبانيا'),
              resharedAt: DateTime.now().subtract(const Duration(hours: 2)),
              note: 'بحبها كتير!',
            ),
          ),
          OwnContentEntry(_post('f2', _sara, 'تنسيق بسيط ليوم العمل')),
        ],
        pageInfo: const PageInfo(page: 1),
      ),
    );
  }

  @override
  Future<Result<List<StoryGroup>>> storiesTray() async => Success([
    StoryGroup(stories: [_story('s1', _atelier)], allSeen: false),
    StoryGroup(stories: [_story('s2', _lina)], allSeen: false),
    StoryGroup(stories: [_story('s3', _sara)], allSeen: true),
  ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Fixtures ────────────────────────────────────────────────────────────────

final _meUser = User(
  id: 'u-me',
  name: 'ريم الأحمد',
  username: 'reem.ahmad',
  phone: '',
  createdAt: DateTime(2026, 1, 1),
);

final _lina = User(
  id: 'u-lina',
  name: 'لينا حداد',
  username: 'lina.h',
  phone: '',
  createdAt: DateTime(2026, 1, 1),
);

final _sara = User(
  id: 'u-sara',
  name: 'سارة',
  username: 'sara',
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
  createdAt: DateTime(2026, 1, 1),
);

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

Content _story(String id, User author) => Content(
  id: id,
  author: author,
  authorKind: author.isSeller
      ? ContentAuthorKind.seller
      : ContentAuthorKind.customer,
  format: ContentFormat.story,
  status: ContentStatus.published,
  moderationState: ContentModerationState.active,
  visibility: ContentVisibility.public,
  createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  media: const [MediaItem(url: 'https://example.invalid/story.jpg')],
);
