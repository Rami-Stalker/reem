import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/media.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/story.dart';
import 'package:ohara/features/create/data/datasources/create_remote_datasource.dart';
import 'package:ohara/features/create/domain/repositories/create_repository.dart';

class CreateRepositoryImpl with RepositoryHandler implements CreateRepository {
  const CreateRepositoryImpl({required this.remote});

  final CreateRemoteDataSource remote;

  @override
  Future<Result<Post>> createPost({
    required String caption,
    required String productId,
  }) => guard(() => remote.createPost(caption: caption, productId: productId));

  @override
  Future<Result<Story>> createStory({
    required String mediaUrl,
    MediaType type = MediaType.image,
    String? link,
  }) =>
      guard(
        () => remote.createStory(mediaUrl: mediaUrl, type: type, link: link),
      );
}
