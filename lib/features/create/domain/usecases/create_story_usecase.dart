import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/story.dart';

import '../repositories/create_repository.dart';

class CreateStoryUseCase {
  const CreateStoryUseCase(this._repository);
  final CreateRepository _repository;

  Future<Result<Story>> call({
    required String mediaUrl,
    String? link,
  }) =>
      _repository.createStory(mediaUrl: mediaUrl, link: link);
}
