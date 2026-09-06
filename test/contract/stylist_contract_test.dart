// The stylist's wire contract, checked against a real server payload.
//
// `test/fixtures/stylist_turn.json` is a verbatim capture of what
// `POST /ai/stylist/conversations/:id/messages` returned for the three
// sentences the feature was specified against, produced by running the actual
// pipeline over the seeded catalogue. So this fails if either side of the
// contract drifts — a renamed field, a Money shape that stops being
// `{amount, currency}`, a brief that stops carrying its chips.
//
// It also asserts the property the whole feature rests on: every card carries
// a real product, a real price and a reason with scoring codes behind it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reem/features/ai_stylist/data/models/stylist_models.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_message.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_recommendation.dart';

void main() {
  late Map<String, dynamic> payload;

  setUpAll(() {
    final raw = File('test/fixtures/stylist_turn.json').readAsStringSync();
    payload = jsonDecode(raw) as Map<String, dynamic>;
  });

  Map<String, dynamic> section(String key) =>
      Map<String, dynamic>.from(payload[key] as Map);

  group('a product turn', () {
    late StylistTurn turn;

    setUp(() => turn = turnFromJson(section('turn')));

    test('decodes both sides of the exchange', () {
      expect(turn.userMessage.role, StylistRole.user);
      expect(turn.userMessage.content, isNotEmpty);
      expect(turn.assistantMessage.role, StylistRole.assistant);
      expect(turn.assistantMessage.content, isNotEmpty);
      expect(turn.conversation.id, isNotEmpty);
    });

    test('carries the brief it was answered against', () {
      final brief = turn.brief;
      // "بميزانية 500 ألف" — half a million, not five hundred. Getting this
      // wrong is the parse that makes every result nonsense.
      expect(brief.budgetMax, 500000);
      expect(brief.modesty, 'MODEST');
      expect(brief.slots, contains('DRESS'));
      expect(brief.occasionLabel, isNotNull);
      // The chips the app renders come pre-labelled from the server.
      expect(brief.chips, isNotEmpty);
      expect(brief.chips.first.label, isNotEmpty);
    });

    test('every card is a real, priced, buyable product', () {
      final cards = turn.assistantMessage.recommendations;
      expect(cards, isNotEmpty);

      for (final card in cards) {
        expect(card.id, isNotEmpty);
        expect(card.product.title, isNotEmpty);
        expect(card.product.id, isNotEmpty);

        // A price that arrived as `{amount, currency}` and survived decoding.
        expect(card.displayPrice, isNotNull);
        expect(card.displayPrice!.raw, isNotEmpty);
        expect(card.displayPrice!.approximateValue, greaterThan(0));

        // The seller is named: a recommendation with no shop behind it is not
        // something she can act on.
        expect(card.product.displaySeller, isNotNull);
        expect(card.product.bestOffer, isNotNull);
        expect(card.product.inStock, isTrue);
      }
    });

    test('every card explains itself, and the prose has scoring behind it', () {
      for (final card in turn.assistantMessage.recommendations) {
        expect(card.reason, isNotEmpty);
        // The sentence is rendered from these; prose with an empty code list
        // would be an explanation nothing actually justified.
        expect(card.reasonCodes, isNotEmpty);
      }
    });

    test('offers follow-ups so the composer is never a blank box', () {
      expect(turn.assistantMessage.followUps, isNotEmpty);
    });

    test('names the engine that answered', () {
      // The deterministic path, with no model configured — the mode the
      // feature ships in and the mode the tests run in.
      expect(turn.assistantMessage.engine, 'reem-stylist-rules-v1');
    });
  });

  group('an outfit turn', () {
    late StylistTurn turn;

    setUp(() => turn = turnFromJson(section('outfit_turn')));

    test('is recognised as a look, not a product search', () {
      expect(turn.brief.intent, 'BUILD_OUTFIT');
      expect(turn.brief.isOutfitRequest, isTrue);
    });

    test('assembles distinct slots, each with a real product', () {
      final outfit = turn.assistantMessage.outfit;
      expect(outfit, isNotNull);
      expect(outfit!.items.length, greaterThanOrEqualTo(2));

      final slots = outfit.items.map((piece) => piece.slot).toList();
      expect(slots.toSet().length, slots.length,
          reason: 'the same slot must not be filled twice');

      for (final piece in outfit.items) {
        expect(piece.slotLabel, isNotEmpty);
        expect(piece.product, isNotNull);
        expect(piece.price, isNotNull);
      }
      expect(outfit.isComplete, isTrue);
    });

    test('totals what the pieces actually cost', () {
      final outfit = turn.assistantMessage.outfit!;
      expect(outfit.total, isNotNull);

      final summed = outfit.items.fold<double>(
        0,
        (sum, piece) => sum + (piece.price?.approximateValue ?? 0),
      );
      expect(outfit.total!.approximateValue, closeTo(summed, 1));
    });

    test('carries the palette it was built around', () {
      final outfit = turn.assistantMessage.outfit!;
      expect(outfit.palette, isNotEmpty);
      expect(outfit.palette.first.label, isNotEmpty);
      expect(outfit.status, StylistOutfitStatus.suggested);
    });
  });

  group('a gift turn', () {
    late StylistTurn turn;

    setUp(() => turn = turnFromJson(section('gift_turn')));

    test('reads the recipient rather than the shopper', () {
      expect(turn.brief.intent, 'FIND_GIFT');
      expect(turn.brief.forSelf, isFalse);
      expect(turn.brief.recipientAge, 25);
      expect(turn.brief.isGiftRequest, isTrue);
    });

    test('returns purchasable gifts', () {
      final cards = turn.assistantMessage.recommendations;
      expect(cards, isNotEmpty);
      for (final card in cards) {
        expect(card.product.inStock, isTrue);
        expect(card.displayPrice, isNotNull);
      }
    });
  });

  group('the bootstrap payload', () {
    test('gives the screen its prompts, vocabulary and stored preferences', () {
      final bootstrap = bootstrapFromJson(section('bootstrap'));

      expect(bootstrap.prompts, isNotEmpty);
      // The closed vocabularies come from the server, so a chip in the app can
      // never offer a value the server would refuse.
      expect(bootstrap.colours, isNotEmpty);
      expect(bootstrap.colours.first.key, isNotEmpty);
      expect(bootstrap.colours.first.label, isNotEmpty);
      expect(bootstrap.occasions, isNotEmpty);
      expect(bootstrap.slots, isNotEmpty);
      expect(bootstrap.conversations, isNotEmpty);
    });

    test('shows her what her behaviour says, not only what she declared', () {
      final derived = bootstrapFromJson(section('bootstrap')).preferences.derived;

      expect(derived, isNotNull);
      expect(derived!.maturity, isNotEmpty);
    });
  });

  group('decoding is total', () {
    test('a malformed card is skipped rather than losing the whole turn', () {
      // A chat screen that throws on one bad card loses the transcript.
      final recommendations = recommendationsFromJson([
        {'id': 'no-product-here'},
        ...(section('turn')['message'] as Map)['recommendations'] as List,
      ]);

      final expected =
          ((section('turn')['message'] as Map)['recommendations'] as List).length;
      expect(recommendations.length, expected);
    });

    test('an empty payload yields empty values, not an exception', () {
      expect(() => briefFromJson(const {}), returnsNormally);
      expect(() => messageFromJson(const {}), returnsNormally);
      expect(() => conversationFromJson(const {}), returnsNormally);
      expect(recommendationsFromJson(null), isEmpty);
      expect(briefFromJson(null).slots, isEmpty);
    });

    test('feedback round-trips through the wire form', () {
      for (final feedback in StylistFeedback.values) {
        expect(StylistFeedback.fromWire(feedback.wire), feedback);
      }
      for (final status in StylistOutfitStatus.values) {
        expect(StylistOutfitStatus.fromWire(status.wire), status);
      }
    });
  });
}
