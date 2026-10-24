import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/story.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/auth/presentation/providers/auth_notifier.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_state.dart';
import 'package:reem/features/stories/domain/repositories/stories_repository.dart';
import 'package:reem/features/stories/presentation/providers/stories_providers.dart';
import 'package:reem/features/stories/presentation/screens/story_viewer_screen.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;
import 'package:reem/l10n/app_localizations_ar.dart';

/// The story viewer, for the two people who open it: somebody watching a
/// boutique's story, and the woman whose story it is.
void main() {
  final l10n = AppLocalizationsAr();

  Future<_Stories> pump(
    WidgetTester tester, {
    required List<Story> stories,
    required User me,
  }) async {
    final repo = _Stories();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => _SignedIn(me)),
          storiesRepositoryProvider.overrideWithValue(repo),
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
          home: StoryViewerScreen(stories: stories),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return repo;
  }

  testWidgets('a visitor reacts, and a second tap takes the reaction back', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      stories: [_story('s1', _shop)],
      me: _shopper,
    );

    expect(find.text('🔥'), findsOneWidget);
    expect(find.text(l10n.audienceTitle), findsNothing);
    expect(repo.viewed, ['s1'], reason: 'opening a story records the view');

    await tester.tap(find.text('🔥'));
    await tester.pump();
    expect(repo.reactions, ['s1:🔥']);

    await tester.tap(find.text('🔥'));
    await tester.pump();
    expect(repo.removed, ['s1']);
  });

  testWidgets('her own story offers «شوهدت من قبل», not reactions, and is '
      'not counted as a view', (tester) async {
    final repo = await pump(tester, stories: [_story('s1', _shop)], me: _shop);

    expect(find.text(l10n.audienceTitle), findsOneWidget);
    expect(find.text('🔥'), findsNothing);
    expect(repo.viewed, isEmpty);
  });

  testWidgets('a story that tags a piece leads to it', (tester) async {
    await pump(
      tester,
      stories: [_story('s1', _shop, productId: 'p-1')],
      me: _shopper,
    );
    expect(find.text(l10n.storyShopThis), findsOneWidget);
  });

  testWidgets('the menu on somebody else\'s story offers reporting it', (
    tester,
  ) async {
    await pump(tester, stories: [_story('s1', _shop)], me: _shopper);
    await tester.tap(find.byTooltip(l10n.a11yMore));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text(l10n.storyMenuReport), findsOneWidget);
    expect(find.text(l10n.storyMenuDelete), findsNothing);
  });

  testWidgets('the menu on her own story offers deleting it', (tester) async {
    await pump(tester, stories: [_story('s1', _shop)], me: _shop);
    await tester.tap(find.byTooltip(l10n.a11yMore));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text(l10n.storyMenuDelete), findsOneWidget);
    expect(find.text(l10n.storyMenuReport), findsNothing);
  });
}

Story _story(String id, User author, {String? productId}) => Story(
  id: id,
  user: author,
  media: const [MediaItem(url: '', type: MediaType.image)],
  productId: productId,
  expiresAt: DateTime.now().add(const Duration(hours: 20)),
  createdAt: DateTime.now().subtract(const Duration(hours: 4)),
);

final _shop = User(
  id: 's-atelier',
  name: 'أتيليه رحاف',
  username: 'atelier.rahaf',
  phone: '',
  createdAt: DateTime(2026, 1, 1),
);

final _shopper = User(
  id: 'u-me',
  name: 'ريم',
  username: 'reem',
  phone: '',
  createdAt: DateTime(2026, 1, 1),
);

class _SignedIn extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedIn(User user) : super(AuthState(user: user, isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Stories implements StoriesRepository {
  final viewed = <String>[];
  final reactions = <String>[];
  final removed = <String>[];

  @override
  Future<Result<void>> recordView(String storyId) async {
    viewed.add(storyId);
    return const Success(null);
  }

  @override
  Future<Result<void>> react(String storyId, String emoji) async {
    reactions.add('$storyId:$emoji');
    return const Success(null);
  }

  @override
  Future<Result<void>> removeReaction(String storyId) async {
    removed.add(storyId);
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
