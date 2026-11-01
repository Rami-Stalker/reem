import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_decode.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/core/shared/entities/story.dart';
import 'package:ohara/core/shared/services/share_service.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:ohara/features/social/presentation/providers/social_providers.dart';
import 'package:ohara/features/social/presentation/widgets/content_audience_sheet.dart';
import 'package:ohara/features/social/presentation/widgets/report_sheet.dart';
import 'package:ohara/features/social/presentation/widgets/tagged_pieces_sheet.dart';
import 'package:ohara/features/stories/presentation/providers/stories_providers.dart';

/// Arguments for the story viewer route (passed via GoRouter `extra`).
class StoryViewerArgs {
  final List<Story> stories;
  final int initialIndex;
  const StoryViewerArgs({required this.stories, this.initialIndex = 0});
}

/// The same reactions offered on posts, reels and comments — see
/// [DsReactions]; one list, so a new reaction appears everywhere at once.
const _reactions = DsReactions.all;

/// A clip is held for as long as it runs, up to this. A story that claimed a
/// ten-minute video would otherwise hold the viewer for ten minutes.
const Duration _maxVideoDwell = Duration(seconds: 30);

/// One picture or clip inside a story. A story may carry several, and each
/// one gets its own segment of the progress bar.
class _Frame {
  const _Frame(this.story, this.media);

  final Story story;
  final MediaItem media;
}

enum _StoryAction { audience, copyLink, share, mute, report, delete }

/// The one story viewer.
///
/// There used to be two — this one behind the route, and a second, thinner
/// copy under `features/home/` that the stories rail pushed directly. Opening
/// the same story from the rail and from a deep link gave you two different
/// screens: one recorded the view and offered reactions, the other did
/// neither, and they did not even share a progress bar. The rail now comes
/// here, and the duplicate is gone.
///
/// What it does, for the two people who open it:
///
///  * **Watching somebody's story** — pictures and clips (a clip is timed by
///    its own length, not a fixed five seconds), every frame of a multi-frame
///    story, the bar for the current woman only, a tap on the reading-start
///    side to go back, a swipe across to the next woman and down to close.
///    Her reaction is remembered and a second tap takes it back. «…» copies
///    the link, shares it, quiets the account, or reports the story.
///  * **Watching her own** — no reaction bar (she does not react to herself);
///    «شوهدت من قبل» instead, and «حذف الستوري» in the menu, for a shopper
///    as much as for a boutique.
///
/// Held still while she presses, while a sheet is open over it, and while
/// the app is in the background — a story that ran out while she answered a
/// call is a story she missed.
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  final List<Story> stories;
  final int initialIndex;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// How long a picture is held before advancing.
  static const Duration _dwell = Duration(seconds: 5);

  late final AnimationController _progress;
  late List<_Frame> _frames;
  int _index = 0;

  /// Why the story is standing still. Any reason holds it; it runs again
  /// only when every reason is gone.
  final Set<String> _holds = {};

  /// A clip's bar waits for the decoder to say how long the clip is.
  bool _awaitingVideo = false;

  final Map<String, String?> _myReactions = {};
  final Set<String> _viewed = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _frames = _framesOf(widget.stories);
    for (final story in widget.stories) {
      _myReactions[story.id] = story.myReaction;
    }
    _index = _firstFrameOf(
      widget.initialIndex.clamp(
        0,
        widget.stories.isEmpty ? 0 : widget.stories.length - 1,
      ),
    );
    _progress = AnimationController(vsync: this, duration: _dwell)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progress.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _release('app');
    } else {
      _hold('app');
    }
  }

  // ── The playlist ──────────────────────────────────────────────────────────

  static List<_Frame> _framesOf(List<Story> stories) => [
    for (final story in stories)
      for (final media in story.media) _Frame(story, media),
  ];

  /// The first frame of the story at [storyIndex] in the original list.
  int _firstFrameOf(int storyIndex) {
    if (widget.stories.isEmpty) return 0;
    final id = widget.stories[storyIndex].id;
    final at = _frames.indexWhere((frame) => frame.story.id == id);
    return at < 0 ? 0 : at;
  }

  _Frame? get _current =>
      _frames.isEmpty ? null : _frames[_index.clamp(0, _frames.length - 1)];

  /// The run of frames by the woman currently playing — what the bar shows.
  (int start, int end) get _authorRun {
    final authorId = _current?.story.user.id;
    var start = _index;
    var end = _index;
    while (start > 0 && _frames[start - 1].story.user.id == authorId) {
      start--;
    }
    while (end < _frames.length - 1 &&
        _frames[end + 1].story.user.id == authorId) {
      end++;
    }
    return (start, end);
  }

  bool _isMine(Story story) =>
      story.user.id == ref.read(authNotifierProvider).user?.id;

  // ── Playback ──────────────────────────────────────────────────────────────

  void _begin() {
    if (!mounted) return;
    final frame = _current;
    if (frame == null) return;
    _trackView(frame.story);
    _progress.reset();
    if (frame.media.isVideo) {
      // Started by `_onVideoReady`, timed by the clip itself.
      _awaitingVideo = true;
      return;
    }
    _awaitingVideo = false;
    _progress.duration = _dwell;
    if (_holds.isEmpty) _progress.forward();
  }

  void _onVideoReady(Duration length) {
    if (!mounted || !_awaitingVideo) return;
    _awaitingVideo = false;
    final dwell = length <= Duration.zero
        ? _dwell
        : (length > _maxVideoDwell ? _maxVideoDwell : length);
    _progress.duration = dwell;
    if (_holds.isEmpty) _progress.forward();
  }

  void _hold(String reason) {
    final wasRunning = _holds.isEmpty;
    _holds.add(reason);
    if (wasRunning) {
      _progress.stop();
      if (mounted) setState(() {});
    }
  }

  void _release(String reason) {
    if (!_holds.remove(reason) || _holds.isNotEmpty) return;
    if (!_awaitingVideo && !_progress.isCompleted) _progress.forward();
    if (mounted) setState(() {});
  }

  /// Holds the story while [action] runs — a sheet, a dialog — and lets it
  /// run again after.
  Future<T> _heldWhile<T>(Future<T> Function() action) async {
    _hold('sheet');
    try {
      return await action();
    } finally {
      _release('sheet');
    }
  }

  void _goTo(int index) {
    if (_frames.isEmpty) return;
    if (index < 0) {
      // Before the first frame: start it again rather than closing.
      _begin();
      return;
    }
    if (index >= _frames.length) {
      _close();
      return;
    }
    setState(() => _index = index);
    _begin();
  }

  void _next() => _goTo(_index + 1);
  void _prev() => _goTo(_index - 1);

  /// The next woman's first frame, or the previous woman's.
  void _jumpAuthor({required bool forward}) {
    final (start, end) = _authorRun;
    if (forward) {
      _goTo(end + 1);
      return;
    }
    if (start == 0) {
      _goTo(0);
      return;
    }
    final previousAuthor = _frames[start - 1].story.user.id;
    var at = start - 1;
    while (at > 0 && _frames[at - 1].story.user.id == previousAuthor) {
      at--;
    }
    _goTo(at);
  }

  void _close() {
    if (mounted) Navigator.of(context).maybePop();
  }

  void _trackView(Story story) {
    if (!_viewed.add(story.id)) return;
    // A view is keyed by the woman; a visitor has nobody to key it by, and
    // her own story does not count towards her own numbers.
    if (!ref.read(authNotifierProvider).isAuthenticated || _isMine(story)) {
      return;
    }
    unawaited(ref.read(recordStoryViewUseCaseProvider).call(story.id));
  }

  // ── What she does ─────────────────────────────────────────────────────────

  Future<bool> _signedIn() => _heldWhile(
    () => requireAuthenticatedUser(
      context,
      ref,
      title: context.l10n.signInToInteract,
      message: context.l10n.signInToInteractBody,
    ),
  );

  Future<void> _react(String emoji) async {
    final story = _current?.story;
    if (story == null) return;
    if (!await _signedIn() || !mounted) return;

    final before = _myReactions[story.id];
    final removing = before == emoji;
    setState(() => _myReactions[story.id] = removing ? null : emoji);
    unawaited(HapticFeedback.selectionClick());

    final result = removing
        ? await ref.read(removeStoryReactionUseCaseProvider).call(story.id)
        : await ref.read(reactToStoryUseCaseProvider).call(story.id, emoji);
    if (!mounted) return;
    if (result case Error(:final failure)) {
      setState(() => _myReactions[story.id] = before);
      DsSnackbar.error(context, failure.message);
    }
  }

  Future<void> _openProduct(String productId) =>
      _closeThenOpen(RoutePaths.productDetailsOf(productId));

  Future<void> _openProfile(String userId) async {
    if (userId.isEmpty) return;
    await _closeThenOpen(RoutePaths.userProfileOf(userId));
  }

  /// Closes the viewer, then opens [location] — in that order, one after the
  /// other.
  ///
  /// The viewer closes first — it is opened both as a route and as a plain
  /// page from the home rail — so back from the page returns to wherever the
  /// stories were opened rather than into a finished story. It used to pop
  /// and push in the same instant, and the router settled on the pop: «تسوّقي
  /// القطعة» closed the story and went nowhere. The push now waits for the
  /// pop to land.
  Future<void> _closeThenOpen(String location) async {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    _hold('leaving');
    await navigator.maybePop();
    await WidgetsBinding.instance.endOfFrame;
    unawaited(router.push(location));
  }

  Future<void> _audience(Story story) => _heldWhile(
    () => showContentAudienceSheet(
      context,
      contentId: story.id,
      onOpenProfile: _openProfile,
    ),
  );

  Future<void> _menu() async {
    final story = _current?.story;
    if (story == null) return;
    final l10n = context.l10n;
    final mine = _isMine(story);

    final action = await _heldWhile(
      () => DsBottomSheet.choose<_StoryAction>(
        context,
        choices: [
          if (mine)
            DsSheetChoice(
              value: _StoryAction.audience,
              label: l10n.audienceTitle,
              icon: Icons.visibility_outlined,
            ),
          DsSheetChoice(
            value: _StoryAction.share,
            label: l10n.contentShare,
            icon: Icons.ios_share_rounded,
          ),
          DsSheetChoice(
            value: _StoryAction.copyLink,
            label: l10n.postMenuCopyLink,
            icon: Icons.link_rounded,
          ),
          if (!mine)
            DsSheetChoice(
              value: _StoryAction.mute,
              label: l10n.postMenuMuteAuthor(story.user.name),
              icon: Icons.person_off_outlined,
            ),
          if (mine)
            DsSheetChoice(
              value: _StoryAction.delete,
              label: l10n.storyMenuDelete,
              icon: Icons.delete_outline_rounded,
              destructive: true,
            )
          else
            DsSheetChoice(
              value: _StoryAction.report,
              label: l10n.storyMenuReport,
              icon: Icons.flag_outlined,
              destructive: true,
            ),
        ],
      ),
    );
    if (action == null || !mounted) return;

    final repository = ref.read(socialRepositoryProvider);
    switch (action) {
      case _StoryAction.audience:
        await _audience(story);

      case _StoryAction.share:
        await _heldWhile(
          () => ShareService.post(
            context: context,
            postId: story.id,
            authorName: story.user.name,
            imageUrl: story.cover?.isVideo == true ? null : story.coverUrl,
          ),
        );

      case _StoryAction.copyLink:
        await Clipboard.setData(
          ClipboardData(text: ShareService.postUrl(story.id)),
        );
        if (mounted) DsSnackbar.success(context, l10n.linkCopied);

      case _StoryAction.mute:
        if (!await _signedIn() || !mounted) return;
        final result = await repository.muteAuthor(story.user.id);
        if (!mounted) return;
        switch (result) {
          case Success():
            DsSnackbar.success(
              context,
              l10n.postMenuMuteAuthorDone(story.user.name),
            );
            _dropWhere((frame) => frame.story.user.id == story.user.id);
          case Error(:final failure):
            DsSnackbar.error(context, failure.message);
        }

      case _StoryAction.report:
        if (!await _signedIn() || !mounted) return;
        await _heldWhile(
          () => showReportSheet(
            context,
            submit: (reason) => repository.report(story.id, reason),
            submitDetailed: (reason, detail) =>
                repository.report(story.id, reason, detail: detail),
          ),
        );

      case _StoryAction.delete:
        final confirmed = await _heldWhile(
          () => DsDialog.confirm(
            context,
            title: l10n.storyDeleteTitle,
            message: l10n.storyDeleteBody,
            confirmLabel: l10n.delete,
            cancelLabel: l10n.cancel,
            icon: Icons.delete_outline_rounded,
            destructive: true,
          ),
        );
        if (!confirmed || !mounted) return;
        final result = await repository.deleteOwn(story.id);
        if (!mounted) return;
        switch (result) {
          case Success():
            DsSnackbar.success(context, l10n.storyDeleted);
            // Whoever opened the viewer holds a list with this story in it;
            // the rails reload rather than keep a ring onto nothing.
            ref.invalidate(storiesTrayProvider);
            ref.invalidate(userStoriesProvider(story.user.id));
            _dropWhere((frame) => frame.story.id == story.id);
          case Error(:final failure):
            DsSnackbar.error(context, failure.message);
        }
    }
  }

  /// Takes frames out of the playlist — a story she deleted, or every story
  /// by an account she just muted — and carries on from where they were.
  void _dropWhere(bool Function(_Frame frame) test) {
    final kept = [
      for (final frame in _frames)
        if (!test(frame)) frame,
    ];
    if (kept.isEmpty) {
      _close();
      return;
    }
    // The first frame after the dropped run takes its place.
    var next = _index;
    for (var i = 0; i < _index; i++) {
      if (test(_frames[i])) next--;
    }
    setState(() {
      _frames = kept;
      _index = next.clamp(0, kept.length - 1);
    });
    _begin();
  }

  // ── Drawing ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final frame = _current;
    if (frame == null) {
      return const Scaffold(
        backgroundColor: DsColors.mediaGround,
        body: SizedBox.shrink(),
      );
    }
    final story = frame.story;
    final mine = _isMine(story);
    final width = MediaQuery.sizeOf(context).width;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final (start, end) = _authorRun;
    final productId = story.productId;
    final held = _holds.contains('press');

    return Scaffold(
      backgroundColor: DsColors.mediaGround,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              // "Back" is on the side she starts reading from — the right in
              // Arabic, the left in English.
              final x = details.globalPosition.dx;
              final back = rtl ? x > width * 2 / 3 : x < width / 3;
              back ? _prev() : _next();
            },
            onLongPressStart: (_) => _hold('press'),
            onLongPressEnd: (_) => _release('press'),
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v.abs() < 250) return;
              // A swipe towards the reading end moves to the next woman.
              final towardsStart = rtl ? v > 0 : v < 0;
              _jumpAuthor(forward: towardsStart);
            },
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 400) _close();
            },
            child: frame.media.isVideo
                ? DsVideoPlayer(
                    key: ValueKey('story-${story.id}-${frame.media.url}'),
                    url: frame.media.url,
                    thumbnailUrl: frame.media.thumbnailUrl,
                    blurHash: frame.media.blurHash,
                    loop: false,
                    showControls: false,
                    paused: _holds.isNotEmpty,
                    onReady: _onVideoReady,
                  )
                : CachedNetworkImage(
                    imageUrl: frame.media.url,
                    // A story is a phone-camera photograph shown at phone
                    // width, and the viewer holds the next one ready while
                    // this one plays.
                    memCacheWidth: MediaDecode.widthFor(context, width),
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        const Center(child: DsLoadingIndicator()),
                    errorWidget: (_, _, _) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: DsColors.onMediaMuted,
                        size: DsSizes.iconXl,
                      ),
                    ),
                  ),
          ),
          // A scrim at each end so the chrome stays legible over a bright photo.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: DsGradients.imageScrimTop),
            ),
          ),
          SafeArea(
            child: AnimatedOpacity(
              // Pressing to hold also clears the chrome, so she can look at
              // the photograph itself.
              opacity: held ? 0 : 1,
              duration: DsMotion.fast,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.sm,
                  vertical: DsSpacing.xs,
                ),
                child: Column(
                  children: [
                    _ProgressBar(
                      count: end - start + 1,
                      index: _index - start,
                      controller: _progress,
                    ),
                    DsGaps.vSm,
                    _Header(
                      story: story,
                      showSound: frame.media.isVideo,
                      onOpenAuthor: () => _openProfile(story.user.id),
                      onMore: _menu,
                      onClose: _close,
                    ),
                    const Spacer(),
                    if (story.products.length > 1) ...[
                      // Several pieces: the list of them, the story held
                      // while she looks, and closed before the piece opens.
                      _Pill(
                        icon: Icons.shopping_bag_outlined,
                        label: context.l10n.storyShopPieces(
                          story.products.length,
                        ),
                        onTap: () => _heldWhile(
                          () => TaggedPiecesSheet.show(
                            context,
                            story.products,
                            onOpen: (product) => _openProduct(product.id),
                          ),
                        ),
                      ),
                      DsGaps.vSm,
                    ] else if (productId != null) ...[
                      _Pill(
                        icon: Icons.shopping_bag_outlined,
                        label: context.l10n.storyShopThis,
                        onTap: () => _openProduct(productId),
                      ),
                      DsGaps.vSm,
                    ],
                    if (mine)
                      _Pill(
                        icon: Icons.visibility_outlined,
                        label: context.l10n.audienceTitle,
                        onTap: () => _audience(story),
                      )
                    else
                      _ReactionBar(
                        selected: _myReactions[story.id],
                        onReact: _react,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.count,
    required this.index,
    required this.controller,
  });

  final int count;
  final int index;
  final AnimationController controller;

  static const double _trackHeight = 3;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        // -1 marks the frame currently playing, so it animates rather than
        // sitting at a fixed fill.
        final value = i < index
            ? 1.0
            : i > index
            ? 0.0
            : -1.0;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxxs),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DsRadius.xs),
              child: value == -1
                  ? AnimatedBuilder(
                      animation: controller,
                      builder: (_, _) => _track(controller.value),
                    )
                  : _track(value),
            ),
          ),
        );
      }),
    );
  }

  Widget _track(double value) => LinearProgressIndicator(
    value: value,
    minHeight: _trackHeight,
    backgroundColor: DsColors.onMediaFaint,
    valueColor: const AlwaysStoppedAnimation(DsColors.onMedia),
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.story,
    required this.showSound,
    required this.onOpenAuthor,
    required this.onMore,
    required this.onClose,
  });

  final Story story;
  final bool showSound;
  final VoidCallback onOpenAuthor;
  final VoidCallback onMore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DsAvatar(
          imageUrl: story.user.imageUrl,
          name: story.user.name,
          size: DsSizes.avatarSm,
          onTap: onOpenAuthor,
        ),
        DsGaps.hSm,
        Expanded(
          child: GestureDetector(
            onTap: onOpenAuthor,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story.user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.labelStrong.tint(DsColors.onMedia),
                ),
                Text(
                  formatRelativeTime(context.l10n, story.createdAt),
                  style: context.dsText.caption.tint(DsColors.onMediaMuted),
                ),
              ],
            ),
          ),
        ),
        if (showSound)
          ValueListenableBuilder<bool>(
            valueListenable: dsVideoSessionMuted,
            builder: (context, muted, _) => IconButton(
              tooltip: muted ? context.l10n.a11yUnmute : context.l10n.a11yMute,
              icon: Icon(
                muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: DsColors.onMedia,
              ),
              onPressed: () => dsVideoSessionMuted.value = !muted,
            ),
          ),
        IconButton(
          tooltip: context.l10n.a11yMore,
          icon: const Icon(Icons.more_horiz_rounded, color: DsColors.onMedia),
          onPressed: onMore,
        ),
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(DsIcons.close, color: DsColors.onMedia),
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// A glass pill over the bottom of the story — «تسوّقي القطعة», or
/// «شوهدت من قبل» on her own.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: DsSpacing.pillPadding,
          decoration: BoxDecoration(
            color: DsColors.mediaPlate,
            borderRadius: DsRadius.borderFull,
            border: Border.all(color: DsColors.onMediaFaint),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: DsSizes.iconSm, color: DsColors.onMedia),
              DsGaps.hXs,
              Text(
                label,
                style: context.dsText.labelStrong.tint(DsColors.onMedia),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({required this.selected, required this.onReact});

  final String? selected;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.xs),
      padding: DsSpacing.pillPadding,
      decoration: BoxDecoration(
        color: DsColors.mediaPlate,
        borderRadius: DsRadius.borderFull,
        border: Border.all(color: DsColors.onMediaFaint),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final e in _reactions)
            Semantics(
              button: true,
              selected: selected == e,
              label: DsReactions.label(context.l10n, e),
              child: GestureDetector(
                onTap: () => onReact(e),
                child: AnimatedScale(
                  duration: DsMotion.fast,
                  curve: DsMotion.softSpring,
                  scale: selected == e ? 1.4 : 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.xxs,
                    ),
                    child: Text(e, style: context.dsText.sectionTitle),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
