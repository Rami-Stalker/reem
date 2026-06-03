import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';

class StoryAvatar extends StatelessWidget {
  const StoryAvatar({
    super.key,
    required this.image,
    required this.username,
    this.isAddStory = false,
    this.isViewed = false,
  });

  final String image;
  final String username;
  final bool isAddStory;
  final bool isViewed;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isViewed ? null : context.storyRingGradient,
            border: isViewed
                ? Border.all(color: colors.divider, width: 2)
                : null,
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface,
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: colors.surfaceVariant,
              backgroundImage: isAddStory ? null : NetworkImage(image),
              child: isAddStory
                  ? Icon(Icons.add_rounded, color: colors.primary, size: 28)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 72,
          child: Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: DsTypography.labelSmall,
              fontWeight: DsTypography.medium,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9));
  }
}
