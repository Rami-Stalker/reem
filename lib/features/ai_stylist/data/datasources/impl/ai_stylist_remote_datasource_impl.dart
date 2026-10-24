import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/ai_stylist/data/datasources/ai_stylist_remote_datasource.dart';
import 'package:ohara/features/ai_stylist/data/models/stylist_models.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:ohara/features/ai_stylist/domain/repositories/ai_stylist_repository.dart';

final class AiStylistRemoteDataSourceImpl extends BaseRemoteDataSource
    implements AiStylistRemoteDataSource {
  const AiStylistRemoteDataSourceImpl(super.dio);

  @override
  Future<StylistBootstrap> bootstrap() async {
    final json = await getJson(ApiEndpoints.stylistBootstrap);
    return bootstrapFromJson(json);
  }

  @override
  Future<List<StylistConversation>> conversations({int limit = 20}) async {
    final list = await getList(
      ApiEndpoints.stylistConversations,
      query: {'limit': limit},
    );
    return list
        .whereType<Map>()
        .map((item) => conversationFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<StylistConversation> conversation(String id) async {
    final json = await getJson(ApiEndpoints.stylistConversation(id));
    return conversationFromJson(json);
  }

  @override
  Future<StylistTurn> startConversation({String? title, String? message}) async {
    final json = await postJson(
      ApiEndpoints.stylistConversations,
      body: {
        if (title != null && title.isNotEmpty) 'title': title,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );

    // Opening a thread without an opening message answers with the bare
    // conversation, so there is no turn to decode.
    if (json['message'] == null) {
      final conversation = conversationFromJson(json);
      return StylistTurn(
        conversation: conversation,
        userMessage: messageFromJson(const {}),
        assistantMessage: messageFromJson(const {}),
        brief: briefFromJson(null),
      );
    }
    return turnFromJson(json);
  }

  @override
  Future<StylistTurn> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final json = await postJson(
      ApiEndpoints.stylistMessages(conversationId),
      body: {'content': content},
    );
    return turnFromJson(json);
  }

  @override
  Future<void> archiveConversation(String id) =>
      deleteRequest(ApiEndpoints.stylistConversation(id));

  @override
  Future<StylistOutfit?> buildOutfit(OutfitRequest request) async {
    final json = await postJson(
      ApiEndpoints.stylistOutfits,
      body: {
        if (request.occasion != null) 'occasion': request.occasion,
        if (request.slots.isNotEmpty) 'slots': request.slots,
        if (request.budgetMin != null) 'budget_min': request.budgetMin,
        if (request.budgetMax != null) 'budget_max': request.budgetMax,
        if (request.colours.isNotEmpty) 'colours': request.colours,
        if (request.clothingSize != null || request.shoeSize != null)
          'sizes': {
            if (request.clothingSize != null) 'clothing': request.clothingSize,
            if (request.shoeSize != null) 'shoes': request.shoeSize,
          },
        if (request.modesty != null) 'modesty': request.modesty,
        if (request.personas.isNotEmpty) 'personas': request.personas,
        if (request.recipientAge != null) 'recipient_age': request.recipientAge,
        if (request.forSelf != null) 'for_self': request.forSelf,
        if (request.maxPieces != null) 'max_pieces': request.maxPieces,
      },
    );

    // The catalogue may simply not hold a complete look at that budget; the
    // server says so with a null outfit and a sentence rather than an error.
    final outfit = json['outfit'];
    if (outfit is! Map) return null;
    return outfitFromJson(Map<String, dynamic>.from(outfit));
  }

  @override
  Future<List<StylistOutfit>> outfits({StylistOutfitStatus? status}) async {
    final list = await getList(
      ApiEndpoints.stylistOutfits,
      query: {if (status != null) 'status': status.wire},
    );
    return list
        .whereType<Map>()
        .map((item) => outfitFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<StylistOutfit> outfit(String id) async {
    final json = await getJson(ApiEndpoints.stylistOutfit(id));
    return outfitFromJson(json);
  }

  @override
  Future<StylistOutfit> setOutfitStatus(
    String id,
    StylistOutfitStatus status,
  ) async {
    final json = await patchJson(
      ApiEndpoints.stylistOutfit(id),
      body: {'status': status.wire},
    );
    return outfitFromJson(json);
  }

  @override
  Future<StylistFeedback> sendFeedback({
    required String recommendationId,
    required StylistFeedback feedback,
  }) async {
    final json = await postJson(
      ApiEndpoints.stylistRecommendationFeedback(recommendationId),
      body: {'feedback': feedback.wire},
    );
    return StylistFeedback.fromWire(json['feedback']?.toString());
  }

  @override
  Future<StylePreferences> preferences() async {
    final json = await getJson(ApiEndpoints.stylistPreferences);
    return preferencesFromJson(json);
  }

  @override
  Future<StylePreferences> updatePreferences(PreferencesPatch patch) async {
    final json = await patchJson(
      ApiEndpoints.stylistPreferences,
      body: {
        if (patch.modesty != null) 'modesty': patch.modesty,
        if (patch.personas != null) 'personas': patch.personas,
        if (patch.favouriteColours != null)
          'favourite_colours': patch.favouriteColours,
        if (patch.avoidedColours != null) 'avoided_colours': patch.avoidedColours,
        if (patch.preferredCategorySlugs != null)
          'preferred_category_slugs': patch.preferredCategorySlugs,
        if (patch.avoidedCategorySlugs != null)
          'avoided_category_slugs': patch.avoidedCategorySlugs,
        if (patch.clothingSize != null || patch.shoeSize != null)
          'sizes': {
            if (patch.clothingSize != null) 'clothing': patch.clothingSize,
            if (patch.shoeSize != null) 'shoes': patch.shoeSize,
          },
        if (patch.budgetMin != null) 'budget_min': patch.budgetMin,
        if (patch.budgetMax != null) 'budget_max': patch.budgetMax,
      },
    );
    return preferencesFromJson(json);
  }

  @override
  Future<StylePreferences> refreshPreferences() async {
    final json = await postJson(ApiEndpoints.stylistPreferencesRefresh);
    return preferencesFromJson(json);
  }
}
