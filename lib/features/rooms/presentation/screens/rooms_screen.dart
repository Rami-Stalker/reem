import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/rooms/data/datasources/rooms_remote_datasource.dart';
import 'package:ohara/features/rooms/domain/entities/room.dart';
import 'package:ohara/features/rooms/presentation/l10n/room_labels.dart';
import 'package:ohara/features/rooms/presentation/providers/rooms_providers.dart';

/// غرفي — the intents she is shopping inside.
///
/// This screen replaces the cart tab. What it lists is not things she is about
/// to buy but questions she is in the middle of, each with how close it is to
/// being answered — which is the difference the whole feature turns on.
class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final roomsAsync = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(title: context.l10n.roomsMyRooms),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposer(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.roomsNewRoom),
      ),
      body: roomsAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.roomsLoadFailed,
          onRetry: () => ref.invalidate(roomsProvider),
        ),
        data: (rooms) => rooms.isEmpty
            ? _Empty(onCreate: () => _openComposer(context, ref))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(roomsProvider),
                child: ListView.separated(
                  // The floating rail's height reaches here as the page's
                  // bottom inset; an explicit `padding` opts out of the
                  // automatic version, so it is added back by hand — and an
                  // extended FAB's worth on top, so the last room is not
                  // sitting under «غرفة جديدة».
                  padding: EdgeInsets.fromLTRB(
                    DsSpacing.md,
                    DsSpacing.md,
                    DsSpacing.md,
                    DsSpacing.md +
                        DsSpacing.massive +
                        MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: rooms.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: DsSpacing.sm),
                  itemBuilder: (context, index) => RoomCard(
                    room: rooms[index],
                    onTap: () =>
                        context.push(RoutePaths.roomOf(rooms[index].id)),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _openComposer(BuildContext context, WidgetRef ref) async {
    final draft = await showModalBottomSheet<RoomDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const RoomComposerSheet(),
    );
    if (draft == null || !context.mounted) return;

    final room = await ref.read(roomActionsProvider).create(draft);
    if (!context.mounted) return;
    unawaited(context.push(RoutePaths.roomOf(room.id)));
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return DsEmptyState(
      icon: Icons.meeting_room_outlined,
      title: context.l10n.roomsEmptyTitle,
      // Says what a room is *for* rather than what it contains, because the
      // idea is unfamiliar and "0 items" would teach her it is a cart.
      message: context.l10n.roomsEmptyBody,
      actionLabel: context.l10n.roomsOpenFirst,
      onAction: onCreate,
    );
  }
}

/// One room, as a card.
///
/// Leads with readiness rather than with a count of things: "قطعة وحدة وبتخلص"
/// is what she wants to know, and a basket count cannot say it.
class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, this.onTap});

  final Room room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final readiness = room.readiness;

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DsRadius.sm),
            child: SizedBox(
              width: 64,
              height: 64,
              child: room.coverUrl == null
                  ? Container(
                      color: colors.surfaceVariant,
                      alignment: Alignment.center,
                      child: Icon(
                        _iconFor(room.kind),
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : AuthorizedMediaImage(
                      url: room.coverUrl!,
                      fallback: Container(color: colors.surfaceVariant),
                    ),
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.cardTitle,
                      ),
                    ),
                    if (room.isGroup)
                      Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                          DsGaps.hXxxs,
                          Text(
                            '${room.membersCount}',
                            style: context.dsText.micro,
                          ),
                        ],
                      ),
                  ],
                ),
                Text(
                  room.occasionLabel ?? room.kind.labelOf(context.l10n),
                  style: context.dsText.caption,
                ),
                const SizedBox(height: DsSpacing.xs),

                if (readiness != null) ...[
                  DsMeter(
                    value: readiness.progress,
                    weight: DsMeterWeight.thin,
                    color: readiness.ready ? colors.success : colors.primary,
                    track: colors.surfaceVariant,
                  ),
                  DsGaps.vXxs,
                  Text(
                    _readinessLine(context, readiness, room),
                    style: context.dsText.micro.tint(
                      readiness.ready
                          ? colors.success
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The sentence a basket count cannot produce.
  String _readinessLine(
    BuildContext context,
    RoomReadiness readiness,
    Room room,
  ) {
    if (room.status == RoomStatus.purchased) return context.l10n.roomsPurchased;
    if (readiness.ready) return context.l10n.roomsReadyToBuy;

    final open = readiness.totalRequired - readiness.settledRequired;
    if (open == 1) return context.l10n.roomsOneDecisionLeft;
    if (open > 1) return context.l10n.roomsOpenDecisions(open);
    return context.l10n.roomsSuggestionCount(room.candidatesCount);
  }

  IconData _iconFor(RoomKind kind) => switch (kind) {
    RoomKind.gift => Icons.card_giftcard_rounded,
    RoomKind.group => Icons.people_rounded,
    RoomKind.occasion => Icons.celebration_rounded,
    RoomKind.solo => Icons.meeting_room_rounded,
  };
}

/// Opening a room.
///
/// Asks for the intent first — what is this for — because that is what the room
/// is, and because naming an occasion lets the server seed the questions it
/// implies. A cart asks for nothing, which is why it can never help.
class RoomComposerSheet extends ConsumerStatefulWidget {
  const RoomComposerSheet({super.key});

  @override
  ConsumerState<RoomComposerSheet> createState() => _RoomComposerSheetState();
}

class _RoomComposerSheetState extends ConsumerState<RoomComposerSheet> {
  final _title = TextEditingController();
  final _recipient = TextEditingController();
  RoomKind _kind = RoomKind.solo;
  String? _occasion;

  @override
  void dispose() {
    _title.dispose();
    _recipient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _title.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: DsSpacing.lg,
        right: DsSpacing.lg,
        top: DsSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + DsSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.roomsNewRoom, style: context.dsText.sectionTitle),
          Text(
            context.l10n.roomsShoppingFor,
            style: context.dsText.sectionSubtitle,
          ),
          const SizedBox(height: DsSpacing.md),

          DsInputField(
            controller: _title,
            label: context.l10n.roomsRoomName,
            hint: context.l10n.roomsRoomNameHint,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: DsSpacing.md),

          Text(context.l10n.roomsRoomKind, style: context.dsText.labelStrong),
          const SizedBox(height: DsSpacing.xs),
          Wrap(
            spacing: DsSpacing.xs,
            children: [
              for (final kind in RoomKind.values)
                DsChip(
                  label: kind.labelOf(context.l10n),
                  selected: _kind == kind,
                  onTap: () => setState(() => _kind = kind),
                ),
            ],
          ),

          if (_kind == RoomKind.gift) ...[
            const SizedBox(height: DsSpacing.md),
            DsInputField(
              controller: _recipient,
              label: context.l10n.roomsGiftFor,
            ),
          ],

          const SizedBox(height: DsSpacing.md),
          Text(
            context.l10n.roomsOccasionOptional,
            style: context.dsText.labelStrong,
          ),
          Text(
            // The payoff worth advertising: naming an occasion means the room
            // opens already knowing what that occasion needs.
            context.l10n.roomsOccasionHelp,
            style: context.dsText.micro,
          ),
          const SizedBox(height: DsSpacing.xs),
          Wrap(
            spacing: DsSpacing.xs,
            runSpacing: DsSpacing.xs,
            children: [
              for (final key in roomOccasionCodes)
                DsChip(
                  label: roomOccasionLabel(context.l10n, key),
                  selected: _occasion == key,
                  onTap: () =>
                      setState(() => _occasion = _occasion == key ? null : key),
                ),
            ],
          ),

          const SizedBox(height: DsSpacing.lg),
          DsButton(
            label: context.l10n.roomsOpenRoom,
            onPressed: canSave
                ? () => Navigator.of(context).pop(
                    RoomDraft(
                      title: _title.text.trim(),
                      kind: _kind,
                      occasion: _occasion,
                      recipientName: _recipient.text.trim(),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
