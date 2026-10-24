import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_message.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:ohara/features/ai_stylist/domain/repositories/ai_stylist_repository.dart';
import 'package:ohara/features/ai_stylist/presentation/providers/stylist_chat_state.dart';

/// Drives one stylist conversation.
///
/// The turn is optimistic in one direction only: her bubble appears the
/// instant she sends, because that is her own text and cannot be wrong. The
/// reply is never optimistic — no placeholder cards, no guessed answer — since
/// everything on that side has to come from the catalogue.
class StylistChatNotifier extends StateNotifier<StylistChatState> {
  StylistChatNotifier(this._repository, {String? conversationId})
      : super(StylistChatState.initial) {
    _load(conversationId);
  }

  final AiStylistRepository _repository;

  /// Which load is current. A load that finishes after a newer one started —
  /// the constructor's bootstrap outrun by [ask]'s — must not overwrite it,
  /// least of all after her question has been answered, when a stale seed
  /// brief would replace the chips of the answer she is reading.
  int _generation = 0;

  Future<void> _load(String? conversationId) async {
    final generation = ++_generation;
    if (conversationId == null) {
      // A fresh screen: fetch the opening prompts, but do not create a
      // conversation row until she actually says something.
      final result = await _repository.bootstrap();
      if (!mounted || generation != _generation) return;
      state = switch (result) {
        Success(:final data) => state.copyWith(
            isLoading: false,
            suggestions: data.prompts,
            brief: data.seedBrief,
            clearFailure: true,
          ),
        Error(:final failure) =>
          state.copyWith(isLoading: false, failure: failure),
      };
      return;
    }

    final result = await _repository.conversation(conversationId);
    if (!mounted || generation != _generation) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
          isLoading: false,
          conversationId: data.id,
          messages: data.messages,
          brief: data.brief ?? state.brief,
          clearFailure: true,
        ),
      Error(:final failure) => state.copyWith(isLoading: false, failure: failure),
    };
  }

  Future<void> send(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final conversationId = state.conversationId;
    final pending = StylistMessage.pending(conversationId ?? '', trimmed);

    state = state.copyWith(
      messages: [...state.messages, pending],
      isSending: true,
      clearFailure: true,
      clearFailedMessage: true,
    );

    final result = conversationId == null
        ? await _repository.startConversation(message: trimmed)
        : await _repository.sendMessage(
            conversationId: conversationId,
            content: trimmed,
          );

    if (!mounted) return;

    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          conversationId: data.conversation.id,
          // Swap the optimistic bubble for the server's row, then append the
          // reply — so ids are real and feedback has something to post to.
          messages: [
            ...state.messages.where((message) => message.id != pending.id),
            data.userMessage,
            data.assistantMessage,
          ],
          brief: data.brief,
          isSending: false,
        );
      case Error(:final failure):
        // Her bubble stays on screen, marked failed, with the text preserved
        // for retry. Dropping it would look like the app ate her message.
        state = state.copyWith(
          isSending: false,
          failure: failure,
          failedMessage: trimmed,
        );
    }
  }

  /// Re-sends the turn that failed.
  Future<void> retry() async {
    final failed = state.failedMessage;
    if (failed == null) return;
    state = state.copyWith(
      messages: state.messages.where((message) => !message.isPending).toList(),
      clearFailure: true,
      clearFailedMessage: true,
    );
    await send(failed);
  }

  /// Records what she did with a card, and reflects it immediately.
  ///
  /// The optimistic update is safe here in a way an optimistic *answer* would
  /// not be: it changes only how her own action is drawn, and a failure simply
  /// puts the card back the way it was.
  Future<void> react(
    StylistRecommendation recommendation,
    StylistFeedback feedback,
  ) async {
    final previous = recommendation.feedback;
    _applyFeedback(recommendation.id, feedback);

    final result = await _repository.sendFeedback(
      recommendationId: recommendation.id,
      feedback: feedback,
    );

    if (!mounted) return;
    if (result case Error()) _applyFeedback(recommendation.id, previous);
  }

  void _applyFeedback(String recommendationId, StylistFeedback feedback) {
    state = state.copyWith(
      messages: [
        for (final message in state.messages)
          _withFeedback(message, recommendationId, feedback),
      ],
    );
  }

  StylistMessage _withFeedback(
    StylistMessage message,
    String recommendationId,
    StylistFeedback feedback,
  ) {
    final target = message.recommendations
        .where((item) => item.id == recommendationId)
        .firstOrNull;
    if (target == null) return message;
    return message.copyWithRecommendation(target.copyWith(feedback: feedback));
  }

  /// Saves a look from inside the conversation.
  Future<void> saveOutfit(StylistOutfit outfit) async {
    final result = await _repository.setOutfitStatus(
      outfit.id,
      StylistOutfitStatus.saved,
    );
    if (!mounted) return;
    if (result case Success(:final data)) {
      state = state.copyWith(
        messages: [
          for (final message in state.messages)
            message.outfit?.id == data.id ? message.copyWith(outfit: data) : message,
        ],
      );
    }
  }

  /// Abandons the thread and starts over, keeping the opening prompts.
  Future<void> startNewConversation() async {
    state = StylistChatState.initial;
    await _load(null);
  }

  /// A fresh conversation that opens with [question] — the way in from
  /// Discover, where she asked before she arrived.
  ///
  /// Starts clean even if this notifier is still holding a conversation from
  /// earlier (it is kept alive for a few minutes), because a new question
  /// asked from somewhere else is not a follow-up to that one.
  Future<void> ask(String question) async {
    if (question.trim().isEmpty) return;
    await startNewConversation();
    if (!mounted) return;
    await send(question);
  }
}
