import 'package:ohara/core/shared/models/comment_model.dart';

import 'package:ohara/features/social_posts/domain/entities/comment_page.dart';

class CommentPageModel extends CommentPage {
  const CommentPageModel({
    required super.items,
    required super.page,
    required super.hasNextPage,
  });

  factory CommentPageModel.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List? ?? [])
        .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['pagination'] as Map<String, dynamic>? ?? const {};
    return CommentPageModel(
      items: items,
      page: meta['page'] as int? ?? 1,
      hasNextPage: meta['has_next_page'] as bool? ?? false,
    );
  }
}
