// «مناسباتي», pinned where it can silently drift.
//
// The plan, the countdown and the repeat warning are the server's and are
// tested there — 23 unit tests over the arithmetic and 5 integration tests
// against Postgres. What is worth pinning *here* is the client's half of the
// contracts that cross the wire, because each fails quietly:
//
//   1. the decoder, which must be total, must read a bare date as a *local*
//      day, and must skip a step this build does not know;
//   2. the edit payload, where an emptied field has to travel as null or the
//      server keeps the old value;
//   3. the routes, where `new` must not be read as an occasion id and the
//      countdown's deep link must land on the occasion;
//   4. the detail page, which must draw the server's plan and send the one
//      write a manual step makes.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/router/app_router_provider.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/occasions/data/datasources/occasions_remote_datasource.dart';
import 'package:ohara/features/occasions/data/models/occasion_models.dart';
import 'package:ohara/features/occasions/domain/entities/occasion.dart';
import 'package:ohara/features/occasions/presentation/providers/occasions_providers.dart';
import 'package:ohara/features/occasions/presentation/screens/occasion_detail_screen.dart';
import 'package:ohara/features/occasions/presentation/widgets/occasion_labels.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _ar = gen.lookupAppLocalizations(const Locale('ar'));

/// What `serializeOccasion` sends for a wedding twelve days out with a look
/// that is one piece short and a salon request awaiting confirmation.
Map<String, dynamic> _wire({List<Map<String, dynamic>>? repeats}) => {
  'id': 'oc-1',
  'title': 'عرس سارة',
  'kind': 'WEDDING',
  'kind_label': 'عرس',
  'date': '2026-11-04',
  'starts_at_time': '19:30',
  'location': 'صالة الشام',
  'circle': 'أهل زوجي',
  'note': null,
  'days_left': 12,
  'is_past': false,
  'reminders_enabled': true,
  'look_occasion': 'wedding',
  'look': {
    'id': 'look-1',
    'title': 'إطلالة العرس',
    'is_complete': false,
    'missing_slots': [
      {'slot': 'SHOES', 'label': 'حذاء'},
    ],
    'items': [],
  },
  'appointment': null,
  'steps': [
    {'key': 'look', 'state': 'DONE', 'manual': false, 'urgent': false, 'count': null},
    {'key': 'pieces', 'state': 'TODO', 'manual': false, 'urgent': false, 'count': 1},
    {'key': 'salon', 'state': 'TODO', 'manual': false, 'urgent': false, 'count': null},
    {'key': 'gift', 'state': 'TODO', 'manual': true, 'urgent': false, 'count': null},
  ],
  'progress': {'done': 1, 'total': 4},
  'next_step': 'pieces',
  'repeats': repeats ?? [],
};

void main() {
  group('decoding an occasion', () {
    test('the full payload decodes, look included', () {
      final occasion = occasionFromJson(_wire());

      expect(occasion.kind, OccasionKind.wedding);
      expect(occasion.daysLeft, 12);
      expect(occasion.look?.title, 'إطلالة العرس');
      expect(occasion.steps.map((step) => step.key), [
        OccasionStepKey.look,
        OccasionStepKey.pieces,
        OccasionStepKey.salon,
        OccasionStepKey.gift,
      ]);
      expect(occasion.step(OccasionStepKey.pieces)?.count, 1);
      expect(occasion.step(OccasionStepKey.gift)?.manual, isTrue);
      expect(occasion.nextStep, OccasionStepKey.pieces);
      expect(occasion.progress, 0.25);
      expect(occasion.isReady, isFalse);
    });

    test('a bare date is a local day, not UTC midnight', () {
      // `DateTime.parse('2026-11-04')` is UTC, and shown in Damascus it is
      // still the 4th — but anywhere west of Greenwich it would be the 3rd.
      final occasion = occasionFromJson(_wire());
      expect(occasion.date.isUtc, isFalse);
      expect(occasion.date, DateTime(2026, 11, 4));
      expect(occasionDateToWire(occasion.date), '2026-11-04');
    });

    test('an empty payload decodes rather than throwing', () {
      final occasion = occasionFromJson(const {});
      expect(occasion.kind, OccasionKind.other);
      expect(occasion.steps, isEmpty);
      expect(occasion.look, isNull);
      expect(occasion.remindersEnabled, isTrue);
    });

    test('a step this build does not know is skipped, not misread', () {
      final occasion = occasionFromJson({
        ..._wire(),
        'steps': [
          {'key': 'henna_artist', 'state': 'TODO'},
          {'key': 'look', 'state': 'DONE'},
        ],
      });
      expect(occasion.steps.map((step) => step.key), [OccasionStepKey.look]);
    });

    test('a repeat warning decodes with its pieces', () {
      final occasion = occasionFromJson(
        _wire(
          repeats: [
            {
              'occasion_id': 'oc-0',
              'title': 'خطوبة لينا',
              'date': '2026-06-12',
              'upcoming': false,
              'same_look': false,
              'pieces': [
                {'id': 'p-1', 'title': 'فستان زيتي', 'slot': 'DRESS'},
              ],
            },
          ],
        ),
      );
      final repeat = occasion.repeats.single;
      expect(repeat.title, 'خطوبة لينا');
      expect(repeat.sameLook, isFalse);
      expect(repeat.pieces.single.title, 'فستان زيتي');
    });
  });

  group('the payloads', () {
    final draft = OccasionDraft(
      title: '  عرس سارة ',
      kind: OccasionKind.wedding,
      date: DateTime(2026, 11, 4),
      location: '   ',
      circle: 'أهل زوجي',
    );

    test('a new occasion omits what she left empty', () {
      final json = draft.toCreateJson();
      expect(json['title'], 'عرس سارة');
      expect(json['kind'], 'WEDDING');
      expect(json['date'], '2026-11-04');
      expect(json.containsKey('location'), isFalse);
      expect(json['circle'], 'أهل زوجي');
    });

    test('an edit sends an emptied field as null, so the server clears it', () {
      final json = draft.toUpdateJson();
      expect(json.containsKey('location'), isTrue);
      expect(json['location'], isNull);
      expect(json['starts_at_time'], isNull);
    });
  });

  group('the routes', () {
    test('the countdown notification opens the occasion', () {
      final path = deepLinkPath(Uri.parse('reem://occasions/oc-1'));
      expect(path, '/occasions/oc-1');
      expect(path, RoutePaths.occasionOf('oc-1'));
    });

    test('new and edit are their own paths', () {
      expect(RoutePaths.occasionNew, '/occasions/new');
      expect(RoutePaths.occasionEditOf('oc-1'), '/occasions/oc-1/edit');
    });
  });

  group('the words', () {
    test('every kind has a name and an icon', () {
      for (final kind in OccasionKind.values) {
        expect(OccasionLabels.kind(_ar, kind), isNotEmpty);
        expect(OccasionLabels.icon(kind), isNotNull);
        expect(OccasionKind.fromWire(kind.wire), kind);
      }
    });

    test('the countdown reads naturally in Arabic', () {
      expect(OccasionLabels.countdown(_ar, -3), 'مضت');
      expect(OccasionLabels.countdown(_ar, 0), 'اليوم');
      expect(OccasionLabels.countdown(_ar, 1), 'بكرا');
      expect(OccasionLabels.countdown(_ar, 2), 'بعد يومين');
      expect(OccasionLabels.countdown(_ar, 5), 'بعد 5 أيام');
      expect(OccasionLabels.countdown(_ar, 14), 'بعد 14 يوماً');
    });

    test('every step in every state has a title', () {
      for (final key in OccasionStepKey.values) {
        for (final state in OccasionStepState.values) {
          final step = OccasionStep(key: key, state: state, count: 2);
          expect(OccasionLabels.stepTitle(_ar, step), isNotEmpty);
        }
      }
    });
  });

  group('the detail page', () {
    testWidgets('draws the plan and the repeat warning, and ticks the gift', (
      tester,
    ) async {
      final api = _FakeOccasions(
        occasionFromJson(
          _wire(
            repeats: [
              {
                'occasion_id': 'oc-0',
                'title': 'خطوبة لينا',
                'date': '2026-06-12',
                'same_look': true,
                'pieces': [],
              },
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [occasionsDataSourceProvider.overrideWithValue(api)],
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
            home: const OccasionDetailScreen(occasionId: 'oc-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_ar.occasionInDays(12)), findsOneWidget);
      expect(find.text(_ar.occasionRepeatTitle('أهل زوجي')), findsOneWidget);
      expect(find.textContaining(_ar.occasionRepeatSameLook), findsOneWidget);
      expect(find.text(_ar.occasionStepPieces(1)), findsOneWidget);
      expect(find.text(_ar.occasionStepSalon), findsOneWidget);

      final gift = find.byType(Checkbox);
      await tester.ensureVisible(gift);
      await tester.pumpAndSettle();
      await tester.tap(gift);
      await tester.pumpAndSettle();

      expect(api.steps, [(OccasionStepKey.gift, true)]);
    });
  });
}

/// Serves one occasion and records the manual-step writes.
final class _FakeOccasions implements OccasionsRemoteDataSource {
  _FakeOccasions(this._occasion);

  final Occasion _occasion;
  final steps = <(OccasionStepKey, bool)>[];

  @override
  Future<Occasion> occasion(String id) async => _occasion;

  @override
  Future<Occasion> setStep(
    String id,
    OccasionStepKey key, {
    required bool done,
  }) async {
    steps.add((key, done));
    return _occasion;
  }

  @override
  Future<List<Occasion>> occasions({required bool upcoming}) async => [
    _occasion,
  ];

  @override
  Future<Occasion> create(OccasionDraft draft) => throw UnimplementedError();

  @override
  Future<Occasion> update(String id, OccasionDraft draft) =>
      throw UnimplementedError();

  @override
  Future<Occasion> setLook(String id, String? lookId) =>
      throw UnimplementedError();

  @override
  Future<Occasion> setAppointment(String id, String? appointmentId) =>
      throw UnimplementedError();

  @override
  Future<Occasion> setRemindersEnabled(String id, bool enabled) =>
      throw UnimplementedError();

  @override
  Future<void> remove(String id) => throw UnimplementedError();
}
