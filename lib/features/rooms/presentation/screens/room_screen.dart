import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/rooms/domain/entities/room.dart';
import 'package:reem/features/rooms/presentation/l10n/room_labels.dart';
import 'package:reem/features/rooms/presentation/providers/rooms_providers.dart';
import 'package:reem/features/rooms/presentation/widgets/decision_card.dart';

/// One room: the decisions, and how close they are to being answered.
///
/// The screen is a list of *questions*, not of products. Each question carries
/// its candidates, what the room thinks of them, and one visible way to settle
/// it. The buy button lives at the bottom and stays disabled until every
/// required question is answered — with the reasons named, because "you cannot
/// buy yet" without saying why is the least useful sentence a shopping app can
/// produce.
class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final roomAsync = ref.watch(roomProvider(roomId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ReemAppBar(
        title: roomAsync.maybeWhen(
          data: (room) => room.title,
          orElse: () => context.l10n.roomsRoomTitle,
        ),
        actions: [
          roomAsync.maybeWhen(
            data: (room) => IconButton(
              tooltip: context.l10n.roomsShareRoom,
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => _share(context, ref, room),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: roomAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.roomsRoomFailed,
          onRetry: () => ref.invalidate(roomProvider(roomId)),
        ),
        data: (room) => _Body(room: room),
      ),
      bottomNavigationBar: roomAsync.maybeWhen(
        data: (room) => _BuyBar(room: room),
        orElse: () => null,
      ),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref, Room room) async {
    final slug =
        room.shareSlug ?? await ref.read(roomActionsProvider).share(room.id);
    if (slug == null || !context.mounted) return;

    await Clipboard.setData(ClipboardData(text: 'reem://rooms/join/$slug'));
    if (!context.mounted) return;
    DsSnackbar.show(
      context,
      // Said plainly, because it is the guarantee that makes sharing safe.
      message: context.l10n.roomsLinkCopied,
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = room.decisions.where((d) => !d.settled && !d.isSkipped);
    final settled = room.decisions.where((d) => d.settled || d.isSkipped);

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.md),
      children: [
        _RoomHeader(room: room),
        const SizedBox(height: DsSpacing.md),

        if (room.decisions.isEmpty)
          DsEmptyState(
            icon: Icons.help_outline_rounded,
            title: context.l10n.roomsNoDecisionsTitle,
            message: context.l10n.roomsNoDecisionsBody,
            actionLabel: context.l10n.roomsAddDecision,
            onAction: () => _addDecision(context, ref),
          )
        else ...[
          for (final decision in open)
            Padding(
              padding: const EdgeInsets.only(bottom: DsSpacing.sm),
              child: DecisionCard(room: room, decision: decision),
            ),

          if (settled.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.md),
            Text(context.l10n.roomsSettled, style: context.dsText.sectionTitle),
            const SizedBox(height: DsSpacing.xs),
            for (final decision in settled)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.sm),
                child: DecisionCard(
                  room: room,
                  decision: decision,
                  collapsed: true,
                ),
              ),
          ],

          const SizedBox(height: DsSpacing.md),
          DsButton(
            label: context.l10n.roomsAddDecision,
            variant: DsButtonVariant.secondary,
            icon: Icons.add_rounded,
            onPressed: () => _addDecision(context, ref),
          ),
        ],

        const SizedBox(height: DsSpacing.xxl),
      ],
    );
  }

  Future<void> _addDecision(BuildContext context, WidgetRef ref) async {
    final title = await DsDialog.prompt(
      context,
      title: context.l10n.roomsNewDecision,
      message: context.l10n.roomsNewDecisionHelp,
      hintText: context.l10n.roomsNewDecisionHint,
      confirmLabel: context.l10n.roomsAdd,
      cancelLabel: context.l10n.roomsCancel,
      maxLength: 80,
    );

    if (title == null || title.isEmpty) {
      return;
    }
    await ref.read(roomActionsProvider).addDecision(room.id, title: title);
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final readiness = room.readiness;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  room.occasionLabel ?? room.kind.labelOf(context.l10n),
                  style: context.dsText.labelStrong.tint(colors.primary),
                ),
              ),
              if (room.isSurprise)
                Text(
                  context.l10n.roomsSurprise,
                  style: context.dsText.micro.tint(colors.onSurfaceVariant),
                ),
            ],
          ),
          if (room.recipientName != null) ...[
            DsGaps.vXxxs,
            Text(
              context.l10n.roomsForRecipient(room.recipientName!),
              style: context.dsText.caption,
            ),
          ],

          if (readiness != null) ...[
            const SizedBox(height: DsSpacing.sm),
            DsMeter(
              value: readiness.progress,
              weight: DsMeterWeight.regular,
              color: readiness.ready ? colors.success : colors.primary,
              track: colors.surfaceVariant,
            ),
            const SizedBox(height: DsSpacing.xs),
            Text(
              switch (readiness) {
                RoomReadiness(ready: true) => context.l10n.roomsAllSettled,
                // Nothing required to count — say what is missing instead of
                // «0 of 0 decisions settled».
                RoomReadiness(totalRequired: 0, :final blockers)
                    when blockers.isNotEmpty =>
                  blockers.first.labelOf(context.l10n),
                _ => context.l10n.roomsSettledOf(
                  readiness.settledRequired,
                  readiness.totalRequired,
                ),
              },
              style: context.dsText.caption,
            ),
          ],

          if (room.budgetMax != null) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              context.l10n.roomsBudgetUpTo(room.budgetMax!.format()),
              style: context.dsText.caption,
            ),
          ],

          if (room.members.length > 1) ...[
            const SizedBox(height: DsSpacing.sm),
            Wrap(
              spacing: DsSpacing.xs,
              children: [
                for (final member in room.members)
                  DsChip(label: '${member.name ?? '—'} · ${member.roleLabel}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The bottom bar.
///
/// Disabled until the room is ready, and it says what is missing rather than
/// simply greying out — the blockers come from the server's own readiness
/// kernel, so the sentence here and the refusal there are the same rule.
class _BuyBar extends ConsumerWidget {
  const _BuyBar({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final readiness = room.readiness;
    final plan = room.plan;

    if (room.decisions.isEmpty) return const SizedBox.shrink();

    final blocker = readiness?.blockers.firstOrNull;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (blocker != null)
              Padding(
                padding: const EdgeInsets.only(bottom: DsSpacing.xs),
                child: Text(
                  blocker.labelOf(context.l10n),
                  textAlign: TextAlign.center,
                  style: context.dsText.caption.tint(colors.onSurfaceVariant),
                ),
              ),
            DsButton(
              label: plan != null
                  ? context.l10n.roomsSeePlan
                  : context.l10n.roomsPreparePlan,
              icon: Icons.checklist_rounded,
              onPressed: readiness?.ready == true
                  ? () => _openPlan(context, ref)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPlan(BuildContext context, WidgetRef ref) async {
    try {
      if (room.plan == null) {
        await ref.read(roomActionsProvider).drawPlan(room.id);
      }
      if (!context.mounted) return;
      unawaited(context.push(RoutePaths.roomPlanOf(room.id)));
    } catch (_) {
      if (!context.mounted) return;
      DsSnackbar.show(context, message: context.l10n.roomsDecisionsStillOpen);
    }
  }
}
