// import 'package:flutter/material.dart';

// class CommentCard extends StatelessWidget {
//   const CommentCard({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(14),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const CircleAvatar(radius: 20),

//           const SizedBox(width: 12),

//           Expanded(
//             child: Column(
//               crossAxisAlignment:
//                   CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'سارة أحمد',
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),

//                 const SizedBox(height: 4),

//                 Row(
//                   children: List.generate(
//                     5,
//                     (_) => const Icon(
//                       Icons.star_rounded,
//                       size: 16,
//                     ),
//                   ),
//                 ),

//                 const SizedBox(height: 8),

//                 const Text(
//                   'المنتج رائع جداً وأنصح به',
//                 ),

//                 const SizedBox(height: 10),

//                 SizedBox(
//                   height: 90,
//                   child: ListView(
//                     scrollDirection: Axis.horizontal,
//                     children: List.generate(
//                       2,
//                       (_) => Container(
//                         width: 90,
//                         margin:
//                             const EdgeInsets.only(
//                           right: 8,
//                         ),
//                         decoration: BoxDecoration(
//                           borderRadius:
//                               BorderRadius.circular(16),
//                           color: Colors.grey.shade300,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),

//                 const SizedBox(height: 8),

//                 Row(
//                   children: [
//                     IconButton(
//                       onPressed: () {},
//                       icon: const Icon(
//                         Icons.favorite_border,
//                       ),
//                     ),

//                     const Text("25"),

//                     TextButton(
//                       onPressed: () {},
//                       child: const Text("رد"),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/shared/entities/comment.dart';
import 'package:reem/core/shared/models/comment_model.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({super.key, required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        CircleAvatar(
          radius: 20,
          backgroundColor: colors.surfaceVariant,
          backgroundImage: comment.user.imageUrl != null
              ? NetworkImage(comment.user.imageUrl!)
              : null,
          child: comment.user.imageUrl == null
              ? Text(
                  comment.user.name.characters.first.toUpperCase(),
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: DsTypography.bold,
                  ),
                )
              : null,
        ),

        const SizedBox(width: DsSpacing.md),

        // Comment content
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(DsSpacing.md),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: DsRadius.borderXl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.user.name,
                      style: TextStyle(
                        fontWeight: DsTypography.semiBold,
                        color: colors.onSurface,
                      ),
                    ),
                    if (comment.user.id ==
                        'current_user') // Check if current user
                      Container(
                        margin: const EdgeInsets.only(left: DsSpacing.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: DsRadius.borderFull,
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                            fontSize: DsTypography.labelSmall,
                            color: colors.primary,
                            fontWeight: DsTypography.medium,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _formatTimeAgo(comment.createdAt),
                      style: TextStyle(
                        fontSize: DsTypography.labelSmall,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DsSpacing.xs),
                
                Text(
                  comment.content,
                  style: TextStyle(color: colors.onSurface, height: 1.4),
                ),
                const SizedBox(height: DsSpacing.xs),
                Row(
                  children: List.generate(
                    5,
                    (_) => const Icon(
                      Icons.star_rounded,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(height: DsSpacing.sm),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        // Like comment
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.favorite_border_rounded,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          if (comment is CommentModel)
                            Text(
                              '${(comment as CommentModel).likesCount}',
                              style: TextStyle(
                                fontSize: DsTypography.labelSmall,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DsSpacing.md),
                    TextButton(
                      onPressed: () {
                        // Reply to comment
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: DsTypography.labelSmall,
                          color: colors.onSurfaceVariant,
                          fontWeight: DsTypography.medium,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.05);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Just now';
    }
  }
}