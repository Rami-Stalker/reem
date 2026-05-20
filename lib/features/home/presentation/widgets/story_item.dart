import 'package:flutter/material.dart';
import '../../../stories/data/models/story_model.dart';
import '../../../../core/theme/app_theme.dart';

class StoryItem extends StatelessWidget {
  final StoryModel story;

  const StoryItem({
    super.key,
    required this.story,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary,
                  AppColors.primary,
                ],
              ),
            ),
            child: CircleAvatar(
              radius: 34,
              backgroundColor: Colors.white,
              child: story.isAdd
                  ? const Icon(
                      Icons.add,
                      size: 34,
                      color: AppColors.primary,
                    )
                  : CircleAvatar(
                      radius: 31,
                      backgroundImage:
                          NetworkImage(story.image),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(story.name),
        ],
      ),
    );
  }
}