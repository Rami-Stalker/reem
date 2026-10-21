// The one visual rule phase three turns on, checked where only a render can
// check it: the notes strip must disappear completely when Reem has nothing to
// say, and a caution must never be buried under the reasons to buy.
//
//   flutter test test/intelligence_notes_test.dart
//
// Fixtures in `test/fixtures/intelligence_notes.json` are verbatim captures of
// real `/intelligence/products/:id/notes` responses for a real seeded shopper,
// so the sentences here are the ones the arithmetic actually produced.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/intelligence/domain/entities/intelligence_note.dart';
import 'package:reem/features/intelligence/domain/entities/size_fit.dart';
import 'package:reem/features/intelligence/domain/repositories/intelligence_repository.dart';
import 'package:reem/features/intelligence/presentation/providers/intelligence_providers.dart';
import 'package:reem/features/intelligence/presentation/widgets/product_intelligence_notes.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

late final Map<String, dynamic> _fixture;

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

List<IntelligenceNote> _notesFrom(Map<String, dynamic> row) {
  final rows = row['notes'];
  if (rows is! List) return const [];
  return rows.whereType<Map<String, dynamic>>().map((note) {
    final evidence = note['evidence'];
    return IntelligenceNote(
      code: note['code'] as String? ?? '',
      tone: NoteTone.parse(note['tone'] as String?),
      ar: note['ar'] as String? ?? '',
      evidence: evidence is Map<String, dynamic> ? evidence : const {},
    );
  }).toList(growable: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _stubPlatformChannels();
    _fixture =
        jsonDecode(
              File('test/fixtures/intelligence_notes.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  testWidgets('nothing to say means nothing on the page', (tester) async {
    await tester.pumpWidget(_Preview(notes: const []));
    await tester.pump();

    // Not an empty state, not a header, not a skeleton — nothing. Most
    // products for most shoppers land here, and reserving space on every
    // product page for a section that usually has no content is how a good
    // idea makes a page worse.
    expect(find.text('ملاحظات إلك'), findsNothing);
    expect(find.byType(SurfaceCard), findsNothing);
  });

  testWidgets('real notes render with their sentences intact', (tester) async {
    final rich = (_fixture['rich'] as List).first as Map<String, dynamic>;
    final notes = _notesFrom(rich);
    expect(notes, isNotEmpty, reason: 'the fixture should carry real notes');

    await tester.pumpWidget(_Preview(notes: notes));
    await tester.pump();

    expect(find.text('ملاحظات إلك'), findsOneWidget);
    for (final note in notes) {
      expect(
        find.text(note.ar),
        findsOneWidget,
        reason: 'the sentence the server wrote must reach the screen verbatim',
      );
    }
  });

  testWidgets('a caution is shown first and shown differently', (tester) async {
    // The rule that matters most: if Reem is about to say she already owns
    // one, that must not sit under three reasons to buy.
    const notes = [
      IntelligenceNote(
        code: 'ALREADY_OWN_SIMILAR',
        tone: NoteTone.caution,
        ar: 'عندك «فستان كحلي طويل» وهي قريبة كتير من هاي.',
        evidence: {},
      ),
      IntelligenceNote(
        code: 'TRUSTED_SELLER',
        tone: NoteTone.inform,
        ar: 'من متجر سبق واشتريتي منه.',
        evidence: {},
      ),
    ];

    await tester.pumpWidget(_Preview(notes: notes));
    await tester.pump();

    final caution = tester.getTopLeft(find.text(notes.first.ar));
    final other = tester.getTopLeft(find.text(notes.last.ar));
    expect(
      caution.dy,
      lessThan(other.dy),
      reason: 'a warning below the sales copy is a warning nobody reads',
    );

    // And it is weighted differently, so it does not read as one more bullet.
    final cautionStyle = tester.widget<Text>(find.text(notes.first.ar)).style;
    final informStyle = tester.widget<Text>(find.text(notes.last.ar)).style;
    expect(cautionStyle?.fontWeight, isNot(equals(informStyle?.fontWeight)));
  });

  testWidgets('only a note that leads somewhere looks tappable', (tester) async {
    const notes = [
      IntelligenceNote(
        code: 'BETTER_VALUE',
        tone: NoteTone.inform,
        ar: 'في قطعة قريبة منها أرخص بـ25%.',
        evidence: {'productId': '11111111-1111-1111-1111-111111111111'},
      ),
      IntelligenceNote(
        code: 'TRUSTED_SELLER',
        tone: NoteTone.inform,
        ar: 'من متجر سبق واشتريتي منه.',
        evidence: {},
      ),
    ];

    await tester.pumpWidget(_Preview(notes: notes));
    await tester.pump();

    // One chevron, for the one note that goes somewhere. A row that looks
    // interactive and does nothing is worse than a plain sentence.
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('a failure is silence, not a red box', (tester) async {
    await tester.pumpWidget(
      _Preview(notes: const [], fail: true),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // These notes enhance a page that works without them.
    expect(find.byType(SurfaceCard), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.notes, this.fail = false});

  final List<IntelligenceNote> notes;
  final bool fail;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        intelligenceRepositoryProvider.overrideWithValue(
          _FixtureRepository(rows: notes, fail: fail),
        ),
      ],
      child: MaterialApp(
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
        home: const Scaffold(
          body: SingleChildScrollView(
            child: ProductIntelligenceNotes(
              productId: '00000000-0000-0000-0000-000000000001',
            ),
          ),
        ),
      ),
    );
  }
}

class _FixtureRepository implements IntelligenceRepository {
  const _FixtureRepository({required this.rows, required this.fail});

  /// Named `rows` rather than `notes` because the interface method is called
  /// `notes` and a field cannot share the name.
  final List<IntelligenceNote> rows;
  final bool fail;

  @override
  Future<Result<List<IntelligenceNote>>> notes(String productId) async {
    if (fail) throw Exception('the server is having a bad day');
    return Success(rows);
  }
  @override
  Future<Result<List<SizeFit>>> sizeFit(String productId) async =>
      const Success([]);
}
