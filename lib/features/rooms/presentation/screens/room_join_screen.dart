import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/rooms/presentation/providers/rooms_providers.dart';

/// Where a shared room invite lands.
///
/// The share button has existed since Rooms shipped: it asks the server for a
/// slug and copies `reem://rooms/join/<slug>` to the clipboard, with a message
/// promising that whoever opens it can advise and vote. Nothing opened it.
/// There was no URL scheme registered on either platform and no route for the
/// path, so the one link the app hands out went nowhere — while the endpoint
/// behind it, and the client method that calls it, were both already written.
///
/// This is the destination. It redeems the slug once, then *replaces* itself
/// with the room, so the back gesture from the room leaves the app rather than
/// returning to a spinner that would try to join a second time.
class RoomJoinScreen extends ConsumerStatefulWidget {
  const RoomJoinScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<RoomJoinScreen> createState() => _RoomJoinScreenState();
}

/// The invite could not be redeemed.
///
/// `_error` is a flag, not a message: the screen always shows the same Arabic
/// sentence, because the client cannot tell a revoked invite from an expired
/// one and guessing would be worse than saying what she can do. This exists so
/// the "no slug at all" case has something to set that is not an English
/// string pretending to be copy — which is what it was, and what the
/// localisation check rightly objected to.
enum _JoinFailure { noSlug }

class _RoomJoinScreenState extends ConsumerState<RoomJoinScreen> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    // After the first frame: `go` during a build is a re-entrant navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) => _join());
  }

  Future<void> _join() async {
    if (widget.slug.isEmpty) {
      setState(() => _error = _JoinFailure.noSlug);
      return;
    }
    try {
      final room = await ref.read(roomActionsProvider).join(widget.slug);
      if (!mounted) {
        return;
      }
      context.pushReplacement(RoutePaths.roomOf(room.id));
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.dsColors.background,
      appBar: ReemAppBar(title: context.l10n.roomsRoomTitle),
      body: _error == null
          ? const Center(child: DsLoadingIndicator())
          : DsErrorState(
              // An invite can be revoked, or simply be old. Saying which is
              // not something the client can know, so it says what she can do.
              message: context.l10n.roomsInviteFailed,
              onRetry: () {
                setState(() => _error = null);
                _join();
              },
            ),
    );
  }
}
