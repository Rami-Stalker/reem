import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/models/post_model.dart';
import 'package:reem/core/shared/models/story_model.dart';
import 'package:reem/features/create/data/datasources/create_remote_datasource.dart';

final class CreateRemoteDataSourceImpl extends BaseRemoteDataSource
    implements CreateRemoteDataSource {
  const CreateRemoteDataSourceImpl(super.dio);

  @override
  Future<PostModel> createPost({
    required String caption,
    required String productId,
  }) async {
    final json = await postJson(
      ApiEndpoints.posts,
      body: {'caption': caption, 'product_id': productId},
    );
    final postData = json['post'] is Map<String, dynamic>
        ? json['post'] as Map<String, dynamic>
        : json;
    return PostModel.fromJson(postData);
  }

  @override
  Future<StoryModel> createStory({
    required String mediaUrl,
    String? link,
  }) async {
    final body = <String, dynamic>{'media_url': mediaUrl};
    if (link != null) body['link'] = link;

    final json = await postJson(ApiEndpoints.stories, body: body);
    final storyJson = json['story'] is Map<String, dynamic>
        ? json['story'] as Map<String, dynamic>
        : json;
    return StoryModel.fromJson(storyJson);
  }
}
