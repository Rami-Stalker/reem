import 'package:flutter/material.dart';
import '../../../home/data/datasources/dummy_data.dart';
import 'story_item.dart';

class StoriesSection extends StatelessWidget {
  const StoriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 115,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 14),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          return StoryItem(story: stories[index]);
        },
      ),
    );
  }
}