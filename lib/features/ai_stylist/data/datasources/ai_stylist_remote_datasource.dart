import 'package:reem/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:reem/features/ai_stylist/domain/repositories/ai_stylist_repository.dart';

abstract interface class AiStylistRemoteDataSource {
  Future<StylistBootstrap> bootstrap();

  Future<List<StylistConversation>> conversations({int limit});

  Future<StylistConversation> conversation(String id);

  Future<StylistTurn> startConversation({String? title, String? message});

  Future<StylistTurn> sendMessage({
    required String conversationId,
    required String content,
  });

  Future<void> archiveConversation(String id);

  Future<StylistOutfit?> buildOutfit(OutfitRequest request);

  Future<List<StylistOutfit>> outfits({StylistOutfitStatus? status});

  Future<StylistOutfit> outfit(String id);

  Future<StylistOutfit> setOutfitStatus(String id, StylistOutfitStatus status);

  Future<StylistFeedback> sendFeedback({
    required String recommendationId,
    required StylistFeedback feedback,
  });

  Future<StylePreferences> preferences();

  Future<StylePreferences> updatePreferences(PreferencesPatch patch);

  Future<StylePreferences> refreshPreferences();
}
