import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/rooms/domain/entities/room.dart';
import 'package:reem/features/rooms/presentation/providers/rooms_providers.dart';

/// المقارنة — the options side by side.
///
/// What makes this worth having over the rail on the room screen is that it
/// does the reading for her. The rows the candidates *agree* on are folded away
/// behind one line; what fills the screen is the ground the decision actually
/// turns on, most decisive first.
///
/// It never recommends. The verdict at the top names a candidate only when one
/// wins every measurable row — a fact about the options, not an opinion about
/// her taste — and the choose button is the same deliberate act it is
/// everywhere else.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({
    super.key,
    required this.roomId,
    required this.decisionId,
  });

  final String roomId;
  final String decisionId;

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  bool _showIdentical = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final key = (roomId: widget.roomId, decisionId: widget.decisionId);
    final comparisonAsync = ref.watch(roomComparisonProvider(key));
    final roomAsync = ref.watch(roomProvider(widget.roomId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ReemAppBar(
        title: comparisonAsync.maybeWhen(
          data: (comparison) => comparison.decisionTitle,
          orElse: () => 'المقارنة',
        ),
      ),
      body: comparisonAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: 'ما قدرنا نجهّز المقارنة.',
          onRetry: () => ref.invalidate(roomComparisonProvider(key)),
        ),
        data: (comparison) {
          if (!comparison.hasEnough) {
            return const DsEmptyState(
              icon: Icons.compare_arrows_rounded,
              title: 'ما في شي نقارنه',
              // A comparison of one is a product page, and she has one of those.
              message: 'المقارنة بدها خيارين على الأقل.',
            );
          }

          final decision = roomAsync.maybeWhen(
            data: (room) => room.decisions
                .where((d) => d.id == widget.decisionId)
                .firstOrNull,
            orElse: () => null,
          );

          return _Body(
            comparison: comparison,
            decision: decision,
            roomId: widget.roomId,
            showIdentical: _showIdentical,
            onToggleIdentical: () =>
                setState(() => _showIdentical = !_showIdentical),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.comparison,
    required this.decision,
    required this.roomId,
    required this.showIdentical,
    required this.onToggleIdentical,
  });

  final RoomComparison comparison;
  final RoomDecision? decision;
  final String roomId;
  final bool showIdentical;
  final VoidCallback onToggleIdentical;

  @override
  Widget build(BuildContext context) {
    final candidates = _candidatesInOrder();

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.md),
      children: [
        _Verdict(comparison: comparison),
        const SizedBox(height: DsSpacing.md),

        // The heads stay pinned to the top of the scroll rather than floating:
        // on a phone the columns are narrow enough that a sticky header would
        // cost more room than it saves.
        _Heads(candidates: candidates, comparison: comparison, roomId: roomId),
        const SizedBox(height: DsSpacing.sm),

        for (final row in comparison.differing)
          _Row(row: row, candidates: candidates),

        if (comparison.identical.isNotEmpty) ...[
          const SizedBox(height: DsSpacing.sm),
          TextButton.icon(
            icon: Icon(
              showIdentical
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            // Folded, but reachable: "they are the same on this" is still worth
            // being able to check.
            label: Text(
              showIdentical
                  ? 'خبّي المتشابه'
                  : 'متشابهين بـ${comparison.identical.length} أشياء',
            ),
            onPressed: onToggleIdentical,
          ),
          if (showIdentical)
            for (final row in comparison.identical)
              _Row(row: row, candidates: candidates, muted: true),
        ],

        const SizedBox(height: DsSpacing.xxl),
      ],
    );
  }

  /// The candidates in the order the comparison returned them, resolved against
  /// the room so the heads can show a photograph and a choose button.
  List<({String id, RoomCandidate? candidate})> _candidatesInOrder() {
    return comparison.candidateIds
        .map(
          (id) => (
            id: id,
            candidate: decision?.candidates
                .where((candidate) => candidate.id == id)
                .firstOrNull,
          ),
        )
        .toList(growable: false);
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.comparison});

  final RoomComparison comparison;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final consensus = comparison.consensus;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows_rounded, size: 18, color: colors.primary),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: Text(
                  comparison.verdict.label,
                  style: context.dsText.body,
                ),
              ),
            ],
          ),
          if (!consensus.silent) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              consensus.contested
                  ? 'الآراء بالغرفة منقسمة — ${consensus.voters} صوّتوا.'
                  : 'الغرفة مايلة لوحدة — ${consensus.voters} صوّتوا.',
              style: context.dsText.caption.tint(
                consensus.contested ? colors.warning : colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The column heads: the piece, and the way to settle it.
class _Heads extends ConsumerWidget {
  const _Heads({
    required this.candidates,
    required this.comparison,
    required this.roomId,
  });

  final List<({String id, RoomCandidate? candidate})> candidates;
  final RoomComparison comparison;
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final actions = ref.read(roomActionsProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The label gutter, matched to the rows below.
        const SizedBox(width: 92),
        for (final entry in candidates)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 0.85,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DsRadius.sm),
                      child: entry.candidate?.image == null
                          ? Container(color: colors.surfaceVariant)
                          : Image.network(
                              entry.candidate!.image!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, _, _) =>
                                  Container(color: colors.surfaceVariant),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.candidate?.title ?? '—',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.micro,
                  ),
                  if (comparison.commentCounts[entry.id] != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${comparison.commentCounts[entry.id]} تعليق',
                      style: context.dsText.micro.tint(colors.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (entry.candidate?.isChosen == true)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: colors.success,
                    )
                  else
                    DsButton(
                      label: 'هاي',
                      size: DsButtonSize.sm,
                      onPressed: entry.candidate?.available == true
                          ? () => actions.choose(roomId, entry.id)
                          : null,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One attribute, across the columns.
class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.candidates,
    this.muted = false,
  });

  final CompareRow row;
  final List<({String id, RoomCandidate? candidate})> candidates;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              row.label,
              style: context.dsText.caption.tint(
                muted ? colors.outline : colors.onSurfaceVariant,
              ),
            ),
          ),
          for (final entry in candidates)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _Cell(
                  cell: row.values[entry.id],
                  muted: muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, this.muted = false});

  final CompareCell? cell;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final best = cell?.best ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: best
          ? BoxDecoration(
              // The winner is tinted rather than badged: on a row of three
              // narrow columns a badge is bigger than the value it decorates.
              color: colors.successContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(DsRadius.sm),
            )
          : null,
      child: Text(
        cell?.display ?? '—',
        textAlign: TextAlign.center,
        style: muted
            ? context.dsText.micro.tint(colors.outline)
            : best
                ? context.dsText.captionStrong.tint(colors.success)
                : context.dsText.caption,
      ),
    );
  }
}
