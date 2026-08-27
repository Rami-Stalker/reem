import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/story.dart';

import 'package:reem/features/create/domain/repositories/create_repository.dart';

class CreateStoryUseCase {
  const CreateStoryUseCase(this._repository);
  final CreateRepository _repository;

  Future<Result<Story>> call({
    required String mediaUrl,
    MediaType type = MediaType.image,
    String? link,
  }) =>
      _repository.createStory(mediaUrl: mediaUrl, type: type, link: link);
}
