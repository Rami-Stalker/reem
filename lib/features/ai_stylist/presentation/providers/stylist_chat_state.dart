import 'package:equatable/equatable.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_message.dart';

/// The stylist screen, as one value.
///
/// [isSending] is separate from a general loading flag on purpose: the
/// transcript stays fully readable and fully scrollable while a turn is in
/// flight, and only the composer and the typing indicator react to it.
class StylistChatState extends Equatable {
  final String? conversationId;
  final List<StylistMessage> messages;

  /// Everything the thread has established so far — what the chips show.
  final StyleBrief brief;

  /// Opening suggestions, replaced by the last turn's follow-ups once the
  /// conversation is under way.
  final List<String> suggestions;

  final bool isLoading;
  final bool isSending;
  final Failure? failure;

  /// The last message that failed to send, kept so "retry" has something to
  /// retry rather than making her type it again.
  final String? failedMessage;

  const StylistChatState({
    this.conversationId,
    this.messages = const [],
    this.brief = StyleBrief.empty,
    this.suggestions = const [],
    this.isLoading = false,
    this.isSending = false,
    this.failure,
    this.failedMessage,
  });

  static const initial = StylistChatState(isLoading: true);

  bool get isEmpty => messages.isEmpty;
  bool get canSend => !isSending;

  /// The prompts under the composer: the last turn's follow-ups while talking,
  /// the opening suggestions before that.
  List<String> get activeSuggestions {
    for (final message in messages.reversed) {
      if (!message.isFromUser && message.followUps.isNotEmpty) {
        return message.followUps;
      }
    }
    return suggestions;
  }

  StylistChatState copyWith({
    String? conversationId,
    List<StylistMessage>? messages,
    StyleBrief? brief,
    List<String>? suggestions,
    bool? isLoading,
    bool? isSending,
    Failure? failure,
    bool clearFailure = false,
    String? failedMessage,
    bool clearFailedMessage = false,
  }) {
    return StylistChatState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      brief: brief ?? this.brief,
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      failure: clearFailure ? null : (failure ?? this.failure),
      failedMessage:
          clearFailedMessage ? null : (failedMessage ?? this.failedMessage),
    );
  }

  @override
  List<Object?> get props => [
        conversationId,
        messages,
        brief,
        suggestions,
        isLoading,
        isSending,
        failure,
        failedMessage,
      ];
}
