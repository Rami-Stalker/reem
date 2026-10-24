// Renders the AI Stylist to PNGs so the design can be eyeballed without a
// session or a running backend. Not an assertion test — it writes
// `build/visual/ai_stylist_*.png` and is meant to be run on demand.
//
//   flutter test test/ai_stylist_visual_preview_test.dart
//
// The repository is faked from `test/fixtures/stylist_turn.json`, which is a
// verbatim capture of a real server response — so what these images show is
// the real copy, the real prices and the real product titles, not mock text
// invented to make the layout look good.
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
import 'package:ohara/features/ai_stylist/data/models/stylist_models.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:ohara/features/ai_stylist/domain/repositories/ai_stylist_repository.dart';
import 'package:ohara/features/ai_stylist/presentation/providers/ai_stylist_providers.dart';
import 'package:ohara/features/ai_stylist/presentation/screens/ai_stylist_screen.dart';
import 'package:ohara/features/ai_stylist/presentation/screens/style_preferences_screen.dart';
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
    _fixture = jsonDecode(
      File('test/fixtures/stylist_turn.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the stylist welcome in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Preview(themeMode: mode));
      await _settle(tester);
      await _capture(tester, 'ai_stylist_welcome_${mode.name}');
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders a product answer in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Preview(themeMode: mode));
      await _settle(tester);

      // Send the sentence the feature was specified against; the fake answers
      // with the captured server response.
      await tester.enterText(
        find.byType(TextField),
        'عندي مناسبة بعد أسبوع وأريد فستانًا أنيقًا ومحتشمًا بميزانية 500 ألف',
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await _settle(tester);
      await _capture(tester, 'ai_stylist_answer_${mode.name}');
    });
  }

  testWidgets('renders a complete outfit', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Preview(themeMode: ThemeMode.light));
    await _settle(tester);

    await tester.enterText(
      find.byType(TextField),
      'أريد فستانًا أسود مع حقيبة وحذاء مناسبين',
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await _settle(tester);
    await _capture(tester, 'ai_stylist_outfit');
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the taste preferences in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(themeMode: mode, screen: const StylePreferencesScreen()),
      );
      await _settle(tester);
      await _capture(tester, 'ai_stylist_preferences_${mode.name}');
    });
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.themeMode, this.screen = const AiStylistScreen()});

  final ThemeMode themeMode;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        aiStylistRepositoryProvider.overrideWithValue(_FixtureRepository()),
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
        home: RepaintBoundary(key: _captureKey, child: screen),
      ),
    );
  }
}

/// Replays the captured server responses.
///
/// It picks its answer from what she typed — outfit sentence in, outfit turn
/// out — so the preview exercises the same branching the real screen does.
class _FixtureRepository implements AiStylistRepository {
  Map<String, dynamic> _section(String key) =>
      Map<String, dynamic>.from(_fixture[key] as Map);

  StylistTurn _turnFor(String message) {
    if (message.contains('حقيبة') || message.contains('إطلالة')) {
      return turnFromJson(_section('outfit_turn'));
    }
    if (message.contains('هدية')) return turnFromJson(_section('gift_turn'));
    return turnFromJson(_section('turn'));
  }

  @override
  Future<Result<StylistBootstrap>> bootstrap() async =>
      Success(bootstrapFromJson(_section('bootstrap')));

  @override
  Future<Result<StylistTurn>> startConversation({
    String? title,
    String? message,
  }) async =>
      Success(_turnFor(message ?? ''));

  @override
  Future<Result<StylistTurn>> sendMessage({
    required String conversationId,
    required String content,
  }) async =>
      Success(_turnFor(content));

  @override
  Future<Result<StylistConversation>> conversation(String id) async =>
      Success(conversationFromJson(_section('turn')['conversation'] as Map<String, dynamic>));

  @override
  Future<Result<List<StylistConversation>>> conversations({int limit = 20}) async =>
      const Success([]);

  @override
  Future<Result<void>> archiveConversation(String id) async =>
      const Success(null);

  @override
  Future<Result<StylistOutfit?>> buildOutfit(OutfitRequest request) async {
    final outfit = (_section('outfit_turn')['message'] as Map)['outfit'];
    return Success(
      outfit is Map ? outfitFromJson(Map<String, dynamic>.from(outfit)) : null,
    );
  }

  @override
  Future<Result<List<StylistOutfit>>> outfits({StylistOutfitStatus? status}) async =>
      const Success([]);

  @override
  Future<Result<StylistOutfit>> outfit(String id) async {
    final outfit = (_section('outfit_turn')['message'] as Map)['outfit'] as Map;
    return Success(outfitFromJson(Map<String, dynamic>.from(outfit)));
  }

  @override
  Future<Result<StylistOutfit>> setOutfitStatus(
    String id,
    StylistOutfitStatus status,
  ) =>
      outfit(id);

  @override
  Future<Result<StylistFeedback>> sendFeedback({
    required String recommendationId,
    required StylistFeedback feedback,
  }) async =>
      Success(feedback);

  @override
  Future<Result<StylePreferences>> preferences() async => Success(
        preferencesFromJson(
          Map<String, dynamic>.from(_section('bootstrap')['preferences'] as Map),
        ),
      );

  @override
  Future<Result<StylePreferences>> updatePreferences(PreferencesPatch patch) =>
      preferences();

  @override
  Future<Result<StylePreferences>> refreshPreferences() => preferences();
}

/// Lets the bootstrap future resolve and every entrance animation finish.
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
