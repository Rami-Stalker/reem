import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/entities/story.dart';

import '../../domain/repositories/create_repository.dart';
import '../datasources/create_remote_datasource.dart';

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
