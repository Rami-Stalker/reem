import 'package:flutter/material.dart';

class StoryAvatar extends StatelessWidget {
  final String imageUrl;
  final bool viewed;
  final VoidCallback? onTap;

  const StoryAvatar({
    super.key,
    required this.imageUrl,
    this.viewed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: viewed ? Colors.grey : Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
        padding: const EdgeInsets.all(3),
        child: CircleAvatar(
          radius: 28,
          backgroundImage: NetworkImage(imageUrl),
        ),
      ),
    );
  }
}