import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_decode.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/story.dart';
import 'package:reem/core/utils/relative_time.dart';
import 'package:reem/features/stories/presentation/providers/stories_providers.dart';

/// Arguments for the story viewer route (passed via GoRouter `extra`).
class StoryViewerArgs {
  final List<Story> stories;
  final int initialIndex;
  const StoryViewerArgs({required this.stories, this.initialIndex = 0});
}

const _reactions = ['❤️', '🔥', '😍', '👏', '😮', '🎉'];

/// The one story viewer.
///
/// There used to be two — this one behind the route, and a second, thinner
/// copy under `features/home/` that the stories rail pushed directly. Opening
/// the same story from the rail and from a deep link gave you two different
/// screens: one recorded the view and offered reactions, the other did
/// neither, and they did not even share a progress bar. The rail now comes
/// here, and the duplicate is gone.
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
    with SingleTickerProviderStateMixin {
  /// How long a single frame is held before advancing.
  static const Duration _dwell = Duration(seconds: 5);

  late final AnimationController _progress;
  late int _index;
  String? _myReaction;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _progress = AnimationController(vsync: this, duration: _dwell)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackView();
      _progress.forward();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _trackView() {
    final story = widget.stories[_index];
    ref.read(recordStoryViewUseCaseProvider).call(story.id);
  }

  void _restart() {
    setState(() => _myReaction = null);
    _progress
      ..reset()
      ..forward();
    _trackView();
  }

  void _next() {
    if (_index < widget.stories.length - 1) {
      setState(() => _index++);
      _restart();
    } else if (mounted) {
      Navigator.of(context).maybePop();
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      _restart();
    }
  }

  Future<void> _react(String emoji) async {
    setState(() => _myReaction = emoji);
    await ref
        .read(reactToStoryUseCaseProvider)
        .call(widget.stories[_index].id, emoji);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty) {
      return const Scaffold(
        backgroundColor: DsColors.mediaGround,
        body: SizedBox.shrink(),
      );
    }
    final story = widget.stories[_index];
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: DsColors.mediaGround,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTapUp: (details) {
              if (details.globalPosition.dx < width / 3) {
                _prev();
              } else {
                _next();
              }
            },
            onLongPressStart: (_) => _progress.stop(),
            onLongPressEnd: (_) => _progress.forward(),
            child: CachedNetworkImage(
              imageUrl: story.media.first.url,
              // A story is a phone-camera photograph shown at phone width, and
              // the viewer holds the next one ready while this one plays.
              memCacheWidth: MediaDecode.widthFor(context, width),
              fit: BoxFit.cover,
              placeholder: (_, _) => const Center(
                child: DsLoadingIndicator(),
              ),
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
          const DecoratedBox(
            decoration: BoxDecoration(gradient: DsGradients.imageScrimTop),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.sm,
                vertical: DsSpacing.xs,
              ),
              child: Column(
                children: [
                  _ProgressBar(
                    count: widget.stories.length,
                    index: _index,
                    controller: _progress,
                  ),
                  DsGaps.vSm,
                  _Header(
                    story: story,
                    onClose: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  _ReactionBar(selected: _myReaction, onReact: _react),
                ],
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
  const _Header({required this.story, required this.onClose});

  final Story story;
  final VoidCallback onClose;

  /// Her face and name lead to her page, as they do everywhere else. The
  /// viewer closes first — it is opened both as a route and as a plain page
  /// from the home rail — so back from her page returns to wherever the
  /// stories were opened rather than into a finished story.
  void _openAuthor(BuildContext context) {
    if (story.user.id.isEmpty) return;
    final router = GoRouter.of(context);
    Navigator.of(context).maybePop();
    router.push(RoutePaths.userProfileOf(story.user.id));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DsAvatar(
          imageUrl: story.user.imageUrl,
          name: story.user.name,
          size: DsSizes.avatarSm,
          onTap: () => _openAuthor(context),
        ),
        DsGaps.hSm,
        Expanded(
          child: GestureDetector(
            onTap: () => _openAuthor(context),
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
        IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(DsIcons.close, color: DsColors.onMedia),
          onPressed: onClose,
        ),
      ],
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
            GestureDetector(
              onTap: () => onReact(e),
              child: AnimatedScale(
                duration: DsMotion.fast,
                curve: DsMotion.softSpring,
                scale: selected == e ? 1.4 : 1,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
                  child: Text(
                    e,
                    style: context.dsText.sectionTitle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
