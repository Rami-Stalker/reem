import 'package:equatable/equatable.dart';

/// One reaction and how many chose it — a row of «❤️😍🔥» beside a counter.
class ReactionCount extends Equatable {
  const ReactionCount({required this.emoji, required this.count});

  final String emoji;
  final int count;

  /// Reads the server's `reaction_summary`; anything malformed is skipped.
  static List<ReactionCount> listFromJson(Object? raw) => [
    if (raw is List)
      for (final item in raw)
        if (item is Map &&
            item['emoji'] is String &&
            (item['emoji'] as String).isNotEmpty)
          ReactionCount(
            emoji: item['emoji'] as String,
            count: (item['count'] as num?)?.toInt() ?? 0,
          ),
  ];

  static List<Map<String, Object>> listToJson(List<ReactionCount> list) => [
    for (final r in list) {'emoji': r.emoji, 'count': r.count},
  ];

  @override
  List<Object?> get props => [emoji, count];
}

/// The glyph she reacted with, from a payload's `is_reacted`/`is_liked` and
/// `my_reaction` — null when she has none, ❤️ for the plain heart.
String? reactionGlyphFromJson(
  Map<String, dynamic> json, {
  String flag = 'is_reacted',
}) {
  if (json[flag] != true) return null;
  final emoji = json['my_reaction'];
  return emoji is String && emoji.isNotEmpty ? emoji : '❤️';
}
