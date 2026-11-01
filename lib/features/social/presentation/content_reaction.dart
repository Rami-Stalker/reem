import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/shared/entities/reaction_count.dart';
import 'package:ohara/features/social/domain/entities/content.dart';

/// What a reaction does to a card the instant she makes it, and what to send.
///
/// [glyph] is the reaction she chose, or null to take hers back. The server
/// toggles — the same glyph again removes it — so clearing sends the one she
/// has. The optimistic card moves the count, her glyph and the summary; the
/// server's answer then settles all three.
({Content optimistic, String? wire}) applyReaction(
  Content before,
  String? glyph,
) {
  final had = before.viewer.reactionGlyph;
  final delta = (glyph != null ? 1 : 0) - (had != null ? 1 : 0);
  final wireNext = glyph == null ? null : DsReactions.toWire(glyph);
  final optimistic = before.copyWith(
    viewer: before.viewer.copyWith(
      isLiked: glyph != null,
      myReaction: wireNext,
      clearReaction: wireNext == null,
      reactionSummary: shiftReaction(before.viewer.reactionSummary, had, glyph),
    ),
    counts: before.counts.copyWith(
      likes: (before.counts.likes + delta).clamp(0, 1 << 30),
    ),
  );
  final wire = glyph == null
      ? (had == null ? null : DsReactions.toWire(had))
      : wireNext;
  return (optimistic: optimistic, wire: wire);
}

/// A summary with one reaction moved from [from] to [to].
List<ReactionCount> shiftReaction(
  List<ReactionCount> summary,
  String? from,
  String? to,
) {
  final counts = {for (final r in summary) r.emoji: r.count};
  if (from != null) counts[from] = (counts[from] ?? 1) - 1;
  if (to != null) counts[to] = (counts[to] ?? 0) + 1;
  final list = [
    for (final e in counts.entries)
      if (e.value > 0) ReactionCount(emoji: e.key, count: e.value),
  ]..sort((a, b) => b.count.compareTo(a.count));
  return list.take(3).toList();
}
