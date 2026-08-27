import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/models/post_model.dart';
import 'package:reem/core/shared/models/story_model.dart';

abstract interface class CreateRemoteDataSource {
  Future<PostModel> createPost({
    required String caption,
    required String productId,
  });

  Future<StoryModel> createStory({
    required String mediaUrl,
    MediaType type = MediaType.image,
    String? link,
  });
}
