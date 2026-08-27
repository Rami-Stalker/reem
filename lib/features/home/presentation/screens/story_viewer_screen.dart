import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/entities/story.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  final List<Story> stories;
  final int initialIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  double _progress = 0;
  Timer? _timer;
  bool _isPaused = false;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _startProgress();
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _startProgress() {
    _timer?.cancel();
    _progress = 0;
    
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_isPaused && _isVisible) {
        setState(() {
          _progress += 0.05; // 2 seconds per story (50ms * 40 = 2000ms)
          if (_progress >= 1) {
            _nextStory();
          }
        });
      }
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _progress = 0;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (_progress > 0.1) {
      setState(() {
        _progress = 0;
      });
    } else if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _progress = 0;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _isPaused = true;
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _isPaused = false;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (details.primaryVelocity! > 0) {
      _previousStory();
    } else if (details.primaryVelocity! < 0) {
      _nextStory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStory = widget.stories[_currentIndex];
    final colors = context.dsColors;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Story image
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: currentStory.coverUrl ?? '',
              fit: BoxFit.cover,
              placeholder: (_, _) => const ColoredBox(color: Colors.black),
              errorWidget: (_, _, _) => Center(
                child: Icon(Icons.broken_image_outlined,
                    color: colors.onSurfaceVariant, size: 48),
              ),
            ),
          ),

          // Gradient overlay at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Progress bars and header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(DsSpacing.md),
              child: Column(
                children: [
                  // Progress bars
                  Row(
                    children: List.generate(
                      widget.stories.length,
                      (index) => Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 2),
                          child: _ProgressBar(
                            progress: index < _currentIndex
                                ? 1
                                : index == _currentIndex
                                    ? _progress
                                    : 0,
                            isActive: index == _currentIndex,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: DsSpacing.md),

                  // Header with user info
                  Row(
                    children: [
                      DsAvatar(
                        imageUrl: currentStory.user.imageUrl,
                        name: currentStory.user.name,
                        size: 40,
                        hasRing: true,
                      ),
                      const SizedBox(width: DsSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStory.user.username,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: DsTypography.semiBold,
                                fontSize: DsTypography.labelLarge,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _formatTimeAgo(currentStory.createdAt),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: DsTypography.labelSmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close button
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Reply/input area at bottom
          Positioned(
            bottom: DsSpacing.lg,
            left: DsSpacing.md,
            right: DsSpacing.md,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.md,
                      vertical: DsSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: DsRadius.borderFull,
                    ),
                    child: Text(
                      'Send a message',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: DsTypography.bodyMedium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: DsSpacing.sm),
                GestureDetector(
                  onTap: () {
                    // Like story
                  },
                  child: Container(
                    padding: const EdgeInsets.all(DsSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_border_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: DsSpacing.sm),
                GestureDetector(
                  onTap: () {
                    // Share story
                  },
                  child: Container(
                    padding: const EdgeInsets.all(DsSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Touch areas for navigation
          Positioned.fill(
            child: GestureDetector(
              onTapDown: _onTapDown,
              onTapUp: _onTapUp,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              behavior: HitTestBehavior.translucent,
              child: Row(
                children: [
                  // Left area - previous
                  Expanded(
                    child: GestureDetector(
                      onTap: _previousStory,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Right area - next
                  Expanded(
                    child: GestureDetector(
                      onTap: _nextStory,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.isActive,
  });

  final double progress;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: DsRadius.borderFull,
      child: Container(
        height: 3,
        color: Colors.white.withValues(alpha: 0.3),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
              borderRadius: DsRadius.borderFull,
            ),
          ),
        ),
      ),
    );
  }
}