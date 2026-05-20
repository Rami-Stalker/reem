import 'package:flutter/material.dart';
import 'network_image.dart';

class PostCard extends StatelessWidget {
  final String userAvatar;
  final String userName;
  final String content;
  final String? image;
  final String timeAgo;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final int likesCount;
  final int commentsCount;

  const PostCard({
    super.key,
    required this.userAvatar,
    required this.userName,
    required this.content,
    this.image,
    required this.timeAgo,
    this.onLike,
    this.onComment,
    this.likesCount = 0,
    this.commentsCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(userAvatar),
                  radius: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(
                  timeAgo,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                )
              ],
            ),
            const SizedBox(height: 12),
            Text(content, style: const TextStyle(fontSize: 15)),
            if (image != null) ...[
              const SizedBox(height: 12),
              NetworkImageWidget(
                url: image!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: onLike,
                  icon: const Icon(Icons.favorite_border),
                ),
                Text('$likesCount'),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onComment,
                  icon: const Icon(Icons.comment_outlined),
                ),
                Text('$commentsCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}