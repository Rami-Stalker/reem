import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/rooms/data/datasources/rooms_remote_datasource.dart';
import 'package:reem/features/rooms/domain/entities/room.dart';
import 'package:reem/features/rooms/presentation/providers/rooms_providers.dart';

/// "أضيفيها لغرفة" — from a product page.
///
/// The entry point that makes Rooms part of browsing rather than a place she
/// has to remember. Two taps: which room, which question.
///
/// The second tap is the one that matters and the one a cart does not have. A
/// piece is not added to a room, it is *proposed as an answer to a question* —
/// and being made to say which question is what stops a room silently becoming
/// a basket with a nicer name.
class ProposeToRoomSheet extends ConsumerStatefulWidget {
  const ProposeToRoomSheet({
    super.key,
    required this.offerId,
    this.offerVariantId,
    this.productTitle,
  });

  final String offerId;
  final String? offerVariantId;
  final String? productTitle;

  @override
  ConsumerState<ProposeToRoomSheet> createState() => _ProposeToRoomSheetState();
}

class _ProposeToRoomSheetState extends ConsumerState<ProposeToRoomSheet> {
  Room? _room;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(roomsProvider);

    return Padding(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: roomsAsync.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: DsLoadingIndicator()),
        ),
        error: (_, _) => const SizedBox(
          height: 160,
          child: DsErrorState(message: 'ما قدرنا نجيب غرفك.'),
        ),
        data: (rooms) {
          final open = rooms
              .where(
                (room) =>
                    room.status != RoomStatus.purchased &&
                    room.status != RoomStatus.archived,
              )
              .toList(growable: false);

          if (open.isEmpty) return _NoRooms(offerId: widget.offerId);
          return _room == null
              ? _PickRoom(
                  rooms: open,
                  onPick: (room) => setState(() => _room = room),
                )
              : _PickDecision(
                  room: _room!,
                  busy: _busy,
                  onBack: () => setState(() => _room = null),
                  onPick: _propose,
                );
        },
      ),
    );
  }

  Future<void> _propose(RoomDecision decision) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref
          .read(roomActionsProvider)
          .propose(
            _room!.id,
            decision.id,
            offerId: widget.offerId,
            offerVariantId: widget.offerVariantId,
          );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('اقترحناها لـ«${decision.title}»')),
      );
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(const SnackBar(content: Text('ما نجح الاقتراح.')));
    }
  }
}

class _PickRoom extends StatelessWidget {
  const _PickRoom({required this.rooms, required this.onPick});

  final List<Room> rooms;
  final ValueChanged<Room> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('لأي غرفة؟', style: context.dsText.sectionTitle),
        const SizedBox(height: DsSpacing.sm),
        for (final room in rooms)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              room.kind == RoomKind.gift
                  ? Icons.card_giftcard_rounded
                  : Icons.meeting_room_rounded,
            ),
            title: Text(room.title),
            subtitle: Text(room.occasionLabel ?? room.kind.label),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => onPick(room),
          ),
      ],
    );
  }
}

class _PickDecision extends ConsumerStatefulWidget {
  const _PickDecision({
    required this.room,
    required this.busy,
    required this.onBack,
    required this.onPick,
  });

  final Room room;
  final bool busy;
  final VoidCallback onBack;
  final ValueChanged<RoomDecision> onPick;

  @override
  ConsumerState<_PickDecision> createState() => _PickDecisionState();
}

class _PickDecisionState extends ConsumerState<_PickDecision> {
  bool _creating = false;

  @override
  Widget build(BuildContext context) {
    final open = widget.room.decisions
        .where((decision) => !decision.isSkipped)
        .toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: widget.onBack,
            ),
            Expanded(
              child: Text('جواب لأي سؤال؟', style: context.dsText.sectionTitle),
            ),
          ],
        ),
        Text(
          // Said once, because the distinction is the feature and it is
          // unfamiliar.
          'القطعة بتنضاف كاقتراح — ما بتنشترى لحدّ ما تختاريها.',
          style: context.dsText.sectionSubtitle,
        ),
        const SizedBox(height: DsSpacing.sm),

        if (widget.busy)
          const Padding(
            padding: EdgeInsets.all(DsSpacing.lg),
            child: Center(child: DsLoadingIndicator()),
          )
        else ...[
          for (final decision in open)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(decision.title),
              subtitle: Text(
                decision.settled ? 'محسوم' : '${decision.live.length} اقتراح',
              ),
              trailing: const Icon(Icons.add_rounded),
              onTap: () => widget.onPick(decision),
            ),

          const Divider(),
          _creating
              ? const Padding(
                  padding: EdgeInsets.all(DsSpacing.md),
                  child: Center(child: DsLoadingIndicator()),
                )
              : TextButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('سؤال جديد'),
                  onPressed: _createDecision,
                ),
        ],
      ],
    );
  }

  Future<void> _createDecision() async {
    final title = await DsDialog.prompt(
      context,
      title: 'سؤال جديد',
      hintText: 'مثلاً: الحذاء',
      confirmLabel: 'ضيفي',
      cancelLabel: 'إلغاء',
      maxLength: 80,
    );

    if (title == null || title.isEmpty || !mounted) {
      return;
    }
    setState(() => _creating = true);

    await ref
        .read(roomActionsProvider)
        .addDecision(widget.room.id, title: title);

    // The room is refetched by the action, so the new question appears in the
    // list above and she picks it — one extra tap, and no guessing about which
    // decision the server created.
    if (mounted) setState(() => _creating = false);
  }
}

class _NoRooms extends ConsumerWidget {
  const _NoRooms({required this.offerId});

  final String offerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ما عندك غرف مفتوحة', style: context.dsText.sectionTitle),
        const SizedBox(height: DsSpacing.xs),
        Text(
          'الغرفة مساحة لقرار شراء — بتجمّعي فيها الخيارات وبتقرّري.',
          style: context.dsText.bodyMuted,
        ),
        const SizedBox(height: DsSpacing.md),
        DsButton(
          label: 'افتحي غرفة وضيفيها',
          onPressed: () => _createAndPropose(context, ref),
        ),
      ],
    );
  }

  Future<void> _createAndPropose(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(roomActionsProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // One room, one question, and the piece proposed into it — the shortest
    // path from a product page to the model, so a first-time user meets the
    // idea rather than a form.
    final room = await actions.create(const RoomDraft(title: 'تسوّق'));
    await actions.addDecision(room.id, title: 'الخيارات');

    final fresh = await ref.read(roomsDataSourceProvider).room(room.id);
    final decision = fresh.decisions.firstOrNull;
    if (decision == null) return;

    await actions.propose(room.id, decision.id, offerId: offerId);
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('فتحنالك غرفة وحطّينا القطعة فيها')),
    );
  }
}
