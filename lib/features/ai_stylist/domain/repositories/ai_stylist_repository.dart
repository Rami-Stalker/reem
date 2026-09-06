import 'package:reem/core/result/result.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_recommendation.dart';

/// A brief assembled from controls rather than typed.
///
/// The "بناء إطلالة" screen posts one of these when she picks an occasion and
/// a budget instead of writing a sentence. It runs through exactly the same
/// retrieval and ranking a parsed message does — there is one pipeline, and
/// this is its other door.
class OutfitRequest {
  final String? occasion;
  final List<String> slots;
  final num? budgetMin;
  final num? budgetMax;
  final List<String> colours;
  final String? clothingSize;
  final String? shoeSize;
  final String? modesty;
  final List<String> personas;
  final int? recipientAge;
  final bool? forSelf;
  final int? maxPieces;

  const OutfitRequest({
    this.occasion,
    this.slots = const [],
    this.budgetMin,
    this.budgetMax,
    this.colours = const [],
    this.clothingSize,
    this.shoeSize,
    this.modesty,
    this.personas = const [],
    this.recipientAge,
    this.forSelf,
    this.maxPieces,
  });
}

/// Her stated preferences, as a patch. A null field means "leave it alone",
/// which is what lets one screen edit one thing.
class PreferencesPatch {
  final String? modesty;
  final List<String>? personas;
  final List<String>? favouriteColours;
  final List<String>? avoidedColours;
  final List<String>? preferredCategorySlugs;
  final List<String>? avoidedCategorySlugs;
  final String? clothingSize;
  final String? shoeSize;
  final num? budgetMin;
  final num? budgetMax;

  const PreferencesPatch({
    this.modesty,
    this.personas,
    this.favouriteColours,
    this.avoidedColours,
    this.preferredCategorySlugs,
    this.avoidedCategorySlugs,
    this.clothingSize,
    this.shoeSize,
    this.budgetMin,
    this.budgetMax,
  });
}

abstract interface class AiStylistRepository {
  /// Everything an empty stylist screen needs, in one request.
  Future<Result<StylistBootstrap>> bootstrap();

  Future<Result<List<StylistConversation>>> conversations({int limit});

  Future<Result<StylistConversation>> conversation(String id);

  /// Opens a thread, optionally asking the first question in the same call —
  /// because "open and ask" is one action for her.
  Future<Result<StylistTurn>> startConversation({String? title, String? message});

  Future<Result<StylistTurn>> sendMessage({
    required String conversationId,
    required String content,
  });

  Future<Result<void>> archiveConversation(String id);

  Future<Result<StylistOutfit?>> buildOutfit(OutfitRequest request);

  Future<Result<List<StylistOutfit>>> outfits({StylistOutfitStatus? status});

  Future<Result<StylistOutfit>> outfit(String id);

  Future<Result<StylistOutfit>> setOutfitStatus(
    String id,
    StylistOutfitStatus status,
  );

  /// Records what she did with a card. Feeds both the answer's own quality
  /// record and her taste profile.
  Future<Result<StylistFeedback>> sendFeedback({
    required String recommendationId,
    required StylistFeedback feedback,
  });

  Future<Result<StylePreferences>> preferences();

  Future<Result<StylePreferences>> updatePreferences(PreferencesPatch patch);

  /// Recomputes the behaviour-derived half of the profile.
  Future<Result<StylePreferences>> refreshPreferences();
}
