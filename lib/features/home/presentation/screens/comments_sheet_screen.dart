import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/features/home/presentation/widgets/comment_input_card.dart';

import '../../../../core/design_system/design_system.dart';
import '../providers/comments_provider.dart';
import '../widgets/comment_tile.dart';

class CommentsSheetScreen extends ConsumerStatefulWidget {
  const CommentsSheetScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<CommentsSheetScreen> createState() =>
      _CommentsSheetScreenState();
}

class _CommentsSheetScreenState extends ConsumerState<CommentsSheetScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(commentsNotifierProvider.notifier).loadComments(widget.postId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final state = ref.watch(commentsNotifierProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .95,
      minChildSize: .40,
      maxChildSize: .95,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DsRadius.xxxl),
          ),
          boxShadow: context.luxuryShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: DsSpacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: DsRadius.borderFull,
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(DsSpacing.lg),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: DsTypography.titleLarge,
                      fontWeight: DsTypography.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${state.comments.length}',
                    style: TextStyle(
                      fontSize: DsTypography.bodyMedium,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Comments list
            Flexible(
              child: state.isLoading && state.comments.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: colors.error,
                            size: 48,
                          ),
                          const SizedBox(height: DsSpacing.md),
                          Text(
                            state.error!,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                          const SizedBox(height: DsSpacing.lg),
                          PrimaryButton(
                            label: 'Retry',
                            onPressed: () => ref
                                .read(commentsNotifierProvider.notifier)
                                .loadComments(widget.postId),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.lg,
                      ),
                      itemCount:
                          state.comments.length + (state.isLoading ? 1 : 0),
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: DsSpacing.md),
                      itemBuilder: (context, index) {
                        if (index == state.comments.length) {
                          return const Padding(
                            padding: EdgeInsets.all(DsSpacing.xl),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return CommentTile(comment: state.comments[index]);
                      },
                    ),
            ),

            const Divider(height: 1),

            // Comment input
            CommnetInputBar(colors: colors, postId: widget.postId),
          ],
        ),
      ).animate().slideY(begin: 0.3, duration: 400.ms).fadeIn(duration: 300.ms),
    );
  }
}
