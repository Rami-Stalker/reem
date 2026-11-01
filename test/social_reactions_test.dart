// Reactions on posts, reels, stories and comments, and the social fixes that
// came with them: the comment field over the keyboard, «تسوّقي القطعة» in a
// story, the story mark on a profile photo, and the rest of a post's pieces.
//
//   flutter test test/social_reactions_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/shared/entities/category.dart';
import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/reaction_count.dart';
import 'package:ohara/core/shared/entities/story.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/auth/presentation/providers/auth_notifier.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_state.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/presentation/content_reaction.dart';
import 'package:ohara/features/social/presentation/widgets/tagged_pieces_sheet.dart';
import 'package:ohara/features/social_posts/domain/entities/comment_thread.dart';
import 'package:ohara/features/social_posts/presentation/providers/comments_notifier.dart';
import 'package:ohara/features/social_posts/presentation/providers/comments_state.dart';
import 'package:ohara/features/social_posts/presentation/providers/social_posts_providers.dart';
import 'package:ohara/features/social_posts/presentation/widgets/comment_sheet.dart';
import 'package:ohara/features/stories/presentation/screens/story_viewer_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;
import 'package:ohara/l10n/app_localizations_ar.dart';

final _l10n = AppLocalizationsAr();

final _me = User(
  id: 'u-me',
  name: 'ريم',
  username: 'reem',
  phone: '+963933118204',
  createdAt: DateTime(2026),
);

Product _piece(String id) => Product(
  id: id,
  slug: id,
  title: 'قطعة $id',
  description: '',
  category: const Category(
    id: 'c',
    slug: 'dresses',
    nameAr: 'فساتين',
    nameEn: 'Dresses',
  ),
  createdAt: DateTime(2026),
);

Content _post({ContentViewerState viewer = const ContentViewerState()}) =>
    Content(
      id: 'c-1',
      author: _me,
      authorKind: ContentAuthorKind.customer,
      format: ContentFormat.post,
      status: ContentStatus.published,
      moderationState: ContentModerationState.active,
      visibility: ContentVisibility.public,
      viewer: viewer,
      counts: const ContentCounts(likes: 4),
      createdAt: DateTime(2026),
    );

class _SignedIn extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedIn() : super(AuthState(user: _me, isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Comments extends StateNotifier<CommentsState>
    implements CommentsNotifier {
  _Comments() : super(const CommentsState());

  @override
  bool get canReact => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget home, {List<dynamic> overrides = const []}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith((ref) => _SignedIn()),
    ...overrides.cast(),
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
    home: home,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });

  group('what a reaction does to a card', () {
    test('choosing one counts it, shows it and sends its glyph', () {
      final change = applyReaction(_post(), '🔥');
      expect(change.optimistic.viewer.reactionGlyph, '🔥');
      expect(change.optimistic.counts.likes, 5);
      expect(change.wire, '🔥');
      expect(change.optimistic.viewer.reactionSummary.first.emoji, '🔥');
    });

    test('the heart is sent as a plain like', () {
      final change = applyReaction(_post(), DsReactions.like);
      expect(change.wire, isNull);
      expect(change.optimistic.viewer.reactionGlyph, '❤️');
    });

    test('changing it moves the count, not adds to it', () {
      final reacted = _post(
        viewer: const ContentViewerState(
          isLiked: true,
          myReaction: '😂',
          reactionSummary: [ReactionCount(emoji: '😂', count: 1)],
        ),
      );
      final change = applyReaction(reacted, '😍');
      expect(change.optimistic.counts.likes, 4);
      expect(
        change.optimistic.viewer.reactionSummary.map((r) => r.emoji),
        ['😍'],
      );
    });

    test('taking it back sends the one she had, so the server removes it', () {
      final reacted = _post(
        viewer: const ContentViewerState(isLiked: true, myReaction: '😢'),
      );
      final change = applyReaction(reacted, null);
      expect(change.wire, '😢');
      expect(change.optimistic.viewer.reactionGlyph, isNull);
      expect(change.optimistic.counts.likes, 3);
    });
  });

  group('the reaction button', () {
    testWidgets('a tap gives a heart, a long press offers every reaction', (
      tester,
    ) async {
      final chosen = <String?>[];
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: DsReactionButton(reaction: null, onReact: chosen.add),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DsReactionButton));
      expect(chosen, [DsReactions.like]);

      await tester.longPress(find.byType(DsReactionButton));
      await tester.pumpAndSettle();
      for (final emoji in DsReactions.all) {
        expect(find.text(emoji), findsOneWidget);
      }
      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();
      expect(chosen.last, '🔥');
      expect(find.text('😢'), findsNothing, reason: 'the bar closes');
    });

    testWidgets('a tap on a reaction she left takes it back', (tester) async {
      String? last = 'unset';
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Center(
              child: DsReactionButton(
                reaction: '😍',
                onReact: (g) => last = g,
              ),
            ),
          ),
        ),
      );
      expect(find.text('😍'), findsOneWidget);
      await tester.tap(find.byType(DsReactionButton));
      expect(last, isNull);
    });
  });

  testWidgets('the comment field rides above the keyboard', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.reset);
    const thread = CommentThread.post('p-1');

    await tester.pumpWidget(
      _app(
        const Scaffold(body: SizedBox.expand()),
        overrides: [
          commentsNotifierProvider(thread).overrideWith((ref) => _Comments()),
        ],
      ),
    );
    final context = tester.element(find.byType(Scaffold));
    unawaited(showCommentSheet(context, thread));
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byType(TextField));
    final keyboardTop = 2532 / 3 - 900 / 3;
    expect(field.bottom, lessThanOrEqualTo(keyboardTop));
  });

  testWidgets('«تسوّقي القطعة» in a story opens the piece', (tester) async {
    final story = Story(
      id: 's1',
      user: _me,
      media: const [MediaItem(url: 'https://x/y.jpg', type: MediaType.image)],
      productId: 'p-42',
      expiresAt: DateTime.now().add(const Duration(hours: 5)),
      createdAt: DateTime.now(),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (c, s) => Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => c.push(
                  '/story-viewer',
                  extra: StoryViewerArgs(stories: [story]),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/story-viewer',
          builder: (c, s) => StoryViewerScreen(
            stories: (s.extra! as StoryViewerArgs).stories,
          ),
        ),
        GoRoute(
          path: '/product-details',
          builder: (c, s) =>
              Scaffold(body: Text('PIECE ${s.uri.queryParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authNotifierProvider.overrideWith((ref) => _SignedIn())],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: L10nSetup.supportedLocales,
          localizationsDelegates: const [
            gen.AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(_l10n.storyShopThis));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('PIECE p-42'), findsOneWidget);
  });

  group('a profile photo with a story', () {
    testWidgets('is marked, and plain without one', (tester) async {
      tester.view.physicalSize = const Size(1500, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: Row(
              children: [
                ProfilePortrait(name: 'أ', hasStory: true),
                ProfilePortrait(name: 'ب'),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(_l10n.profileStoryBadge), findsOneWidget);
    });
  });

  testWidgets('every piece of a post is reachable', (tester) async {
    final pieces = [_piece('a'), _piece('b'), _piece('c')];
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Center(child: MorePiecesChip(products: pieces)),
        ),
      ),
    );
    expect(find.text(_l10n.postMorePieces(2)), findsOneWidget);
    await tester.tap(find.byType(MorePiecesChip));
    await tester.pumpAndSettle();
    for (final piece in pieces) {
      expect(find.text(piece.title), findsOneWidget);
    }
  });
}
