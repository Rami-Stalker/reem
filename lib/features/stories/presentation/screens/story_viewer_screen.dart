import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/shared/entities/story.dart';
import 'package:reem/features/stories/presentation/providers/stories_providers.dart';

/// Arguments for the story viewer route (passed via GoRouter `extra`).
class StoryViewerArgs {
  final List<Story> stories;
  final int initialIndex;
  const StoryViewerArgs({required this.stories, this.initialIndex = 0});
}

const _reactions = ['❤️', '🔥', '😍', '👏', '😮', '🎉'];

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
  late final AnimationController _progress;
  late int _index;
  String? _myReaction;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((status) {
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
        backgroundColor: Colors.black,
        body: SizedBox.shrink(),
      );
    }
    final story = widget.stories[_index];
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
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
            child: Image.network(
              story.media.first.url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 48),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  _ProgressBar(
                    count: widget.stories.length,
                    index: _index,
                    controller: _progress,
                  ),
                  const SizedBox(height: 10),
                  _Header(story: story, onClose: () => Navigator.of(context).maybePop()),
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

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        double value;
        if (i < index) {
          value = 1;
        } else if (i > index) {
          value = 0;
        } else {
          value = -1; // animated
        }
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: value == -1
                  ? AnimatedBuilder(
                      animation: controller,
                      builder: (_, __) => LinearProgressIndicator(
                        value: controller.value,
                        minHeight: 3,
                        backgroundColor: Colors.white24,
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : LinearProgressIndicator(
                      value: value,
                      minHeight: 3,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
            ),
          ),
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.story, required this.onClose});

  final Story story;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundImage:
              (story.user.imageUrl != null && story.user.imageUrl!.isNotEmpty)
                  ? NetworkImage(story.user.imageUrl!)
                  : null,
          child: (story.user.imageUrl == null || story.user.imageUrl!.isEmpty)
              ? const Icon(Icons.person, size: 18)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            story.user.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final e in _reactions)
            GestureDetector(
              onTap: () => onReact(e),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                scale: selected == e ? 1.4 : 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(e, style: const TextStyle(fontSize: 26)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
