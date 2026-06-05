// import 'package:flutter/material.dart';

// class CommentInputBar extends StatelessWidget {
//   const CommentInputBar({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return SafeArea(
//       top: false,
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           border: Border(
//             top: BorderSide(
//               color: Colors.grey.shade200,
//             ), 
//           ),
//         ),
//         child: Row(
//           children: [
//             const CircleAvatar(radius: 18),

//             const SizedBox(width: 10),

//             Expanded(
//               child: TextField(
//                 decoration: InputDecoration(
//                   hintText: "اكتب تعليقاً...",
//                   border: OutlineInputBorder(
//                     borderRadius:
//                         BorderRadius.circular(24),
//                   ),
//                 ),
//               ),
//             ),

//             IconButton(
//               onPressed: () {},
//               icon: const Icon(Icons.image),
//             ),

//             IconButton(
//               onPressed: () {},
//               icon: const Icon(Icons.send),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/features/home/presentation/providers/comments_provider.dart';
import '../../../../core/design_system/design_system.dart';

class CommnetInputBar extends ConsumerStatefulWidget {
  const CommnetInputBar({super.key, required this.colors, required this.postId});
  final DsColorScheme colors;
  final String postId;

  @override
  ConsumerState<CommnetInputBar> createState() => _CommnetInputBarState();
}

class _CommnetInputBarState extends ConsumerState<CommnetInputBar> {
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    ref.read(commentsNotifierProvider.notifier).addComment(widget.postId, text);
    _commentController.clear();
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(DsSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: widget.colors.surfaceVariant,
                          borderRadius: DsRadius.borderFull,
                          border: Border.all(color: widget.colors.border),
                        ),
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(
                              color: widget.colors.onSurfaceVariant,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: DsSpacing.md,
                              vertical: DsSpacing.sm,
                            ),
                          ),
                          style: TextStyle(color: widget.colors.onSurface),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                    ),
                    const SizedBox(width: DsSpacing.sm),
                    GestureDetector(
                      onTap: _submitComment,
                      child: Container(
                        padding: const EdgeInsets.all(DsSpacing.md),
                        decoration: BoxDecoration(
                          gradient: context.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: context.softShadow,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: widget.colors.onPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
  }
}