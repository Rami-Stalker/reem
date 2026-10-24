import 'package:ohara/core/shared/entities/comment.dart';

class CommentPage {
  final List<Comment> items;
  final int page;
  final bool hasNextPage;

  const CommentPage({
    required this.items,
    required this.page,
    required this.hasNextPage,
  });
}
