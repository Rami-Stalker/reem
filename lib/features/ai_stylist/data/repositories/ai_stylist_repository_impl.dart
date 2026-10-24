import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/ai_stylist/data/datasources/ai_stylist_remote_datasource.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:ohara/features/ai_stylist/domain/repositories/ai_stylist_repository.dart';

class AiStylistRepositoryImpl with RepositoryHandler implements AiStylistRepository {
  const AiStylistRepositoryImpl(this.remote);

  final AiStylistRemoteDataSource remote;

  @override
  Future<Result<StylistBootstrap>> bootstrap() => guard(remote.bootstrap);

  @override
  Future<Result<List<StylistConversation>>> conversations({int limit = 20}) =>
      guard(() => remote.conversations(limit: limit));

  @override
  Future<Result<StylistConversation>> conversation(String id) =>
      guard(() => remote.conversation(id));

  @override
  Future<Result<StylistTurn>> startConversation({String? title, String? message}) =>
      guard(() => remote.startConversation(title: title, message: message));

  @override
  Future<Result<StylistTurn>> sendMessage({
    required String conversationId,
    required String content,
  }) =>
      guard(
        () => remote.sendMessage(
          conversationId: conversationId,
          content: content,
        ),
        operation: 'stylist turn',
      );

  @override
  Future<Result<void>> archiveConversation(String id) =>
      guard(() => remote.archiveConversation(id));

  @override
  Future<Result<StylistOutfit?>> buildOutfit(OutfitRequest request) =>
      guard(() => remote.buildOutfit(request), operation: 'outfit build');

  @override
  Future<Result<List<StylistOutfit>>> outfits({StylistOutfitStatus? status}) =>
      guard(() => remote.outfits(status: status));

  @override
  Future<Result<StylistOutfit>> outfit(String id) => guard(() => remote.outfit(id));

  @override
  Future<Result<StylistOutfit>> setOutfitStatus(
    String id,
    StylistOutfitStatus status,
  ) =>
      guard(() => remote.setOutfitStatus(id, status));

  @override
  Future<Result<StylistFeedback>> sendFeedback({
    required String recommendationId,
    required StylistFeedback feedback,
  }) =>
      guard(
        () => remote.sendFeedback(
          recommendationId: recommendationId,
          feedback: feedback,
        ),
      );

  @override
  Future<Result<StylePreferences>> preferences() => guard(remote.preferences);

  @override
  Future<Result<StylePreferences>> updatePreferences(PreferencesPatch patch) =>
      guard(() => remote.updatePreferences(patch));

  @override
  Future<Result<StylePreferences>> refreshPreferences() =>
      guard(remote.refreshPreferences);
}
