import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/story.dart';

abstract interface class CreateRepository {
  Future<Result<Post>> createPost({
    required String caption,
    required String productId,
  });

  Future<Result<Story>> createStory({
    required String mediaUrl,
    MediaType type = MediaType.image,
    String? link,
  });
}
