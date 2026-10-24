// Renders Ohara Visual Shopping to PNGs so the design can be eyeballed without
// a session, a camera or a running backend. Not an assertion test — it writes
// `build/visual/visual_search_*.png` and is meant to be run on demand.
//
//   flutter test test/visual_search_visual_preview_test.dart
//
// The repository is faked from `test/fixtures/visual_search_session.json`,
// captured by `backend/prisma/demo/capture-visual-fixtures.ts` from a real
// indexing pass over the seeded shop. So the product titles, the prices, the
// sellers, the Arabic reasons and — the thing this feature lives or dies on —
// the similarity percentages are all values the pipeline actually produced.
// None of it is mock text invented to make the layout look good.
//
// The two cases that matter most are the honest-failure ones, and they are
// covered here deliberately: the screen when nothing has been indexed yet, and
// the screen when the search genuinely found nothing.
import 'dart:convert';
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
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:ohara/features/visual_search/data/models/visual_search_models.dart';
import 'package:ohara/features/visual_search/domain/entities/visual_match.dart';
import 'package:ohara/features/visual_search/domain/entities/visual_search_session.dart';
import 'package:ohara/features/visual_search/domain/repositories/visual_search_repository.dart';
import 'package:ohara/features/visual_search/presentation/providers/visual_search_providers.dart';
import 'package:ohara/features/visual_search/presentation/screens/visual_search_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();
late final Map<String, dynamic> _fixture;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _stubPlatformChannels();
    await _loadFonts();
    _fixture =
        jsonDecode(
              File('test/fixtures/visual_search_session.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the empty search-by-image screen in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Preview(themeMode: mode));
      await _settle(tester);
      await _capture(tester, 'visual_search_intro_${mode.name}');
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the matches for an uploaded photo in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Preview(themeMode: mode, withSession: true));
      await _settle(tester);
      await _capture(tester, 'visual_search_results_${mode.name}');
    });
  }

  testWidgets('renders the screen while the catalogue is still being indexed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // The honest not-ready state. It must read as "come back shortly", never
    // as an empty result page, because those are different problems.
    await tester.pumpWidget(const _Preview(themeMode: ThemeMode.light, ready: false));
    await _settle(tester);
    await _capture(tester, 'visual_search_not_indexed');
  });

  testWidgets('renders a search that genuinely found nothing', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(themeMode: ThemeMode.light, withSession: true, empty: true),
    );
    await _settle(tester);
    await _capture(tester, 'visual_search_no_match');
  });
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.themeMode,
    this.withSession = false,
    this.ready = true,
    this.empty = false,
  });

  final ThemeMode themeMode;
  final bool withSession;
  final bool ready;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        visualSearchRepositoryProvider.overrideWithValue(
          _FixtureRepository(ready: ready, empty: empty),
        ),
      ],
      child: MaterialApp(
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
        home: RepaintBoundary(
          key: _captureKey,
          // A session id makes the screen open straight onto results, which is
          // the state worth photographing; the picker cannot be driven in a
          // widget test because it is an OS sheet.
          child: VisualSearchScreen(
            sessionId: withSession ? _sessionId : null,
          ),
        ),
      ),
    );
  }
}

String get _sessionId =>
    (_fixture['session'] as Map<String, dynamic>)['id'] as String;

/// Replays the captured server responses.
class _FixtureRepository implements VisualSearchRepository {
  _FixtureRepository({required this.ready, required this.empty});

  final bool ready;
  final bool empty;

  Map<String, dynamic> _section(String key) =>
      Map<String, dynamic>.from(_fixture[key] as Map);

  VisualSearchSession _session() {
    final json = _section('session');
    if (!empty) return sessionFromJson(json);

    // The same session with its matches taken away, and the notice the server
    // sends when the catalogue was searched and had nothing close enough.
    final regions = (json['regions'] as List)
        .map((region) => {...(region as Map), 'matches': const []})
        .toList();
    return sessionFromJson({
      ...json,
      'regions': regions,
      'notice': 'ما لقيت شي قريب كفاية من هالصورة. جرّبي صورة أوضح، أو وصفيلي شو بتدوّري عليه.',
    });
  }

  @override
  Future<Result<VisualSearchBootstrap>> bootstrap() async {
    final json = _section('bootstrap');
    return Success(bootstrapFromJson({...json, 'ready': ready}));
  }

  @override
  Future<Result<VisualSearchSession>> search({
    required Uint8List bytes,
    required String filename,
    required VisualSearchSource source,
    String? note,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(1);
    return Success(_session());
  }

  @override
  Future<Result<VisualSearchSession>> refine({
    required String sessionId,
    required String text,
  }) async => Success(_session());

  @override
  Future<Result<List<VisualSearchSession>>> sessions({int limit = 20}) async =>
      const Success([]);

  @override
  Future<Result<VisualSearchSession>> session(String id) async =>
      Success(_session());

  @override
  Future<Result<void>> forget(String id) async => const Success(null);

  @override
  Future<Result<StylistFeedback>> sendFeedback({
    required String resultId,
    required StylistFeedback feedback,
  }) async => Success(feedback);

  @override
  Future<Result<List<VisualMatch>>> similarTo(
    String productId, {
    int limit = 8,
    int? maxPriceSyp,
    bool sameCategory = false,
  }) async {
    final regions = _section('session')['regions'] as List;
    final matches = (regions.first as Map)['matches'];
    return Success(matchesFromJson(matches));
  }

  @override
  Future<Result<TryOnCapability>> tryOnCapability() async =>
      Success(tryOnCapabilityFromJson(_section('bootstrap')['try_on'] as Map<String, dynamic>?));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
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
