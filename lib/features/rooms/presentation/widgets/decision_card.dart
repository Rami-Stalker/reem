import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/rooms/domain/entities/room.dart';
import 'package:ohara/features/rooms/presentation/providers/rooms_providers.dart';

/// One question, with the answers competing for it.
///
/// The widget that carries the whole idea. A cart line shows a product, a price
/// and a stepper; this shows a *question*, several answers side by side, what
/// the room thinks of each, and one button that settles it. The candidates are
/// laid out horizontally on purpose — they are alternatives to be compared, not
/// a list to be totalled.
class DecisionCard extends ConsumerWidget {
  const DecisionCard({
    super.key,
    required this.room,
    required this.decision,
    this.collapsed = false,
  });

  final Room room;
  final RoomDecision decision;

  /// The settled form, shown under «محسومة».
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(decision.title, style: context.dsText.cardTitle),
                    if (decision.isSuggested) ...[
                      const SizedBox(width: DsSpacing.xs),
                      // The room proposed this, she did not. Marked quietly so
                      // it reads as an offer rather than an obligation.
                      Text(
                        context.l10n.roomsSuggestion,
                        style: context.dsText.micro.tint(
                          colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _StatusPill(decision: decision),
            ],
          ),

          if (decision.isSkipped) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              context.l10n.roomsDecidedAgainst,
              style: context.dsText.caption.tint(colors.onSurfaceVariant),
            ),
          ] else ...[
            if (decision.pickCount > 1) ...[
              DsGaps.vXxxs,
              Text(
                context.l10n.roomsNeedsPieces(decision.pickCount),
                style: context.dsText.caption,
              ),
            ],

            // What the room thinks — never a verdict.
            if (!decision.consensus.silent && decision.live.length > 1) ...[
              const SizedBox(height: DsSpacing.xs),
              Text(
                decision.consensus.contested
                    ? context.l10n.roomsOpinionsSplit
                    : context.l10n.roomsMajorityLeans,
                style: context.dsText.caption.tint(
                  decision.consensus.contested
                      ? colors.warning
                      : colors.primary,
                ),
              ),
            ],

            const SizedBox(height: DsSpacing.sm),

            if (decision.candidates.isEmpty)
              _EmptyDecision(room: room, decision: decision)
            else
              SizedBox(
                height: collapsed ? 118 : 208,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: collapsed
                      ? decision.chosen.length
                      : decision.candidates.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: DsSpacing.xs),
                  itemBuilder: (context, index) {
                    final candidate = collapsed
                        ? decision.chosen[index]
                        : decision.candidates[index];
                    return CandidateTile(
                      room: room,
                      decision: decision,
                      candidate: candidate,
                      compact: collapsed,
                      isLeader: decision.consensus.leaderId == candidate.id,
                    );
                  },
                ),
              ),

            if (!collapsed) ...[
              const SizedBox(height: DsSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DsButton(
                      label: context.l10n.roomsAddOption,
                      size: DsButtonSize.sm,
                      variant: DsButtonVariant.secondary,
                      onPressed: () => context.push(RoutePaths.keywordSearch),
                    ),
                  ),
                  // Offered only where there is something to compare: two live
                  // options and no answer yet. That is precisely the state the
                  // compare view exists for, and putting it anywhere else would
                  // be a button that opens an empty screen.
                  if (decision.isContest) ...[
                    const SizedBox(width: DsSpacing.xs),
                    Expanded(
                      child: DsButton(
                        label: context.l10n.roomsCompare,
                        size: DsButtonSize.sm,
                        variant: DsButtonVariant.secondary,
                        onPressed: () => context.push(
                          RoutePaths.roomCompareOf(room.id, decision.id),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: DsSpacing.xs),
                  Expanded(
                    child: DsButton(
                      // A real outcome, and the one a cart cannot record.
                      //
                      // Shown to everybody; the server refuses it for anyone
                      // without the deciding role. Hiding it here would need the
                      // viewer's own id, which this widget does not have and
                      // should not start carrying just to grey out a button.
                      label: context.l10n.roomsWantNothing,
                      size: DsButtonSize.sm,
                      variant: DsButtonVariant.secondary,
                      onPressed: () => ref
                          .read(roomActionsProvider)
                          .skipDecision(room.id, decision.id),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.decision});

  final RoomDecision decision;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    final (label, color) = switch (decision.status) {
      DecisionStatus.resolved => (
        context.l10n.roomsStatusSettled,
        colors.success,
      ),
      DecisionStatus.skipped => (
        context.l10n.roomsStatusSkipped,
        colors.onSurfaceVariant,
      ),
      DecisionStatus.open =>
        decision.remaining > 0 && decision.candidates.isNotEmpty
            ? (context.l10n.roomsStatusNotChosen, colors.warning)
            : (context.l10n.roomsStatusOpen, colors.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DsRadius.pill),
      ),
      child: Text(label, style: context.dsText.micro.tint(color)),
    );
  }
}

class _EmptyDecision extends StatelessWidget {
  const _EmptyDecision({required this.room, required this.decision});

  final Room room;
  final RoomDecision decision;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DsRadius.sm),
        color: colors.surfaceVariant.withValues(alpha: 0.4),
      ),
      child: Column(
        children: [
          Text(context.l10n.roomsNoOptions, style: context.dsText.caption),
          const SizedBox(height: DsSpacing.xs),
          DsButton(
            label: context.l10n.roomsFindPiece,
            size: DsButtonSize.sm,
            isExpanded: false,
            onPressed: () => context.push(RoutePaths.keywordSearch),
          ),
        ],
      ),
    );
  }
}

/// One candidate.
///
/// Carries what a person deciding actually looks at: the piece, its tally, and
/// whether it is still buyable. The vote buttons are on the tile because voting
/// is the cheap gesture that keeps a shared room alive, and burying it behind a
/// detail screen would mean nobody does it.
class CandidateTile extends ConsumerWidget {
  const CandidateTile({
    super.key,
    required this.room,
    required this.decision,
    required this.candidate,
    this.compact = false,
    this.isLeader = false,
  });

  final Room room;
  final RoomDecision decision;
  final RoomCandidate candidate;
  final bool compact;
  final bool isLeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final actions = ref.read(roomActionsProvider);

    return Opacity(
      opacity: candidate.isRejected ? 0.45 : 1,
      child: SizedBox(
        width: compact ? 96 : 150,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DsRadius.sm),
                    child: candidate.image == null
                        ? Container(color: colors.surfaceVariant)
                        : AuthorizedMediaImage(
                            url: candidate.image!,
                            fallback: Container(color: colors.surfaceVariant),
                          ),
                  ),
                  if (candidate.isChosen)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: colors.success,
                        size: 20,
                      ),
                    )
                  else if (isLeader && !decision.consensus.contested)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.star_rounded,
                        color: colors.warning,
                        size: 18,
                      ),
                    ),
                  if (!candidate.available)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: colors.error.withValues(alpha: 0.9),
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          context.l10n.roomsDone,
                          textAlign: TextAlign.center,
                          style: context.dsText.micro.tint(colors.onError),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            DsGaps.vXxs,
            Text(
              candidate.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.dsText.micro,
            ),
            if (candidate.price != null)
              Text(candidate.price!.format(), style: context.dsText.priceSmall),

            if (!compact) ...[
              DsGaps.vXxxs,
              Row(
                children: [
                  _VoteButton(
                    icon: Icons.thumb_up_outlined,
                    count: candidate.votesUp,
                    onTap: () => actions.vote(room.id, candidate.id, 1),
                  ),
                  const SizedBox(width: DsSpacing.xs),
                  _VoteButton(
                    icon: Icons.thumb_down_outlined,
                    count: candidate.votesDown,
                    onTap: () => actions.vote(room.id, candidate.id, -1),
                  ),
                ],
              ),
              DsGaps.vXxs,
              if (candidate.isChosen)
                DsButton(
                  label: context.l10n.roomsRestore,
                  size: DsButtonSize.sm,
                  variant: DsButtonVariant.secondary,
                  onPressed: () => actions.unchoose(room.id, candidate.id),
                )
              else if (!candidate.isRejected)
                DsButton(
                  // The moment an intention becomes a purchase — a separate,
                  // named act, never a side effect of adding.
                  label: context.l10n.roomsChooseThis,
                  size: DsButtonSize.sm,
                  onPressed: candidate.available
                      ? () => actions.choose(room.id, candidate.id)
                      : null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DsRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: colors.onSurfaceVariant),
            if (count > 0) ...[
              DsGaps.hXxxs,
              Text('$count', style: context.dsText.micro),
            ],
          ],
        ),
      ),
    );
  }
}
