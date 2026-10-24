import 'package:equatable/equatable.dart';
import 'package:ohara/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';

enum StylistRole { user, assistant, system }

/// How the turn arrived. Only [text] is produced today; the others exist so
/// voice and image search slot in without reshaping the transcript.
enum StylistModality { text, voice, image }

/// One turn in the conversation, with whatever it produced attached.
///
/// The cards hang off the assistant turn that chose them rather than off the
/// conversation, so scrolling back shows what was recommended *at that point*,
/// not the latest answer pasted over the history.
class StylistMessage extends Equatable {
  final String id;
  final String conversationId;
  final StylistRole role;
  final StylistModality modality;
  final String content;

  final StyleBrief? brief;

  /// Which engine wrote it — the rules, or a model. Null on her own turns.
  final String? engine;
  final int? latencyMs;

  final List<StylistRecommendation> recommendations;
  final StylistOutfit? outfit;

  /// Tappable next steps, so she is never left facing a blank composer.
  final List<String> followUps;

  final DateTime createdAt;

  /// True while the turn is in flight — an optimistic bubble that has not yet
  /// been acknowledged by the server.
  final bool isPending;

  const StylistMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.modality = StylistModality.text,
    this.brief,
    this.engine,
    this.latencyMs,
    this.recommendations = const [],
    this.outfit,
    this.followUps = const [],
    this.isPending = false,
  });

  bool get isFromUser => role == StylistRole.user;
  bool get hasResults => recommendations.isNotEmpty || outfit != null;

  /// The optimistic bubble shown the instant she hits send. Replaced by the
  /// server's row when the turn returns.
  factory StylistMessage.pending(String conversationId, String content) {
    return StylistMessage(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: conversationId,
      role: StylistRole.user,
      content: content,
      createdAt: DateTime.now(),
      isPending: true,
    );
  }

  StylistMessage copyWithRecommendation(StylistRecommendation updated) {
    return StylistMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: createdAt,
      modality: modality,
      brief: brief,
      engine: engine,
      latencyMs: latencyMs,
      recommendations: [
        for (final item in recommendations)
          if (item.id == updated.id) updated else item,
      ],
      outfit: outfit,
      followUps: followUps,
      isPending: isPending,
    );
  }

  StylistMessage copyWith({StylistOutfit? outfit}) {
    return StylistMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: createdAt,
      modality: modality,
      brief: brief,
      engine: engine,
      latencyMs: latencyMs,
      recommendations: recommendations,
      outfit: outfit ?? this.outfit,
      followUps: followUps,
      isPending: isPending,
    );
  }

  @override
  List<Object?> get props => [id, role, content, recommendations, outfit, isPending];
}
