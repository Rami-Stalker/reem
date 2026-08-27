import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/presentation/providers/core_providers.dart';
import '../../data/datasources/create_remote_datasource.dart';
import '../../data/datasources/impl/create_remote_datasource_impl.dart';
import '../../data/repositories/create_repository_impl.dart';
import '../../domain/repositories/create_repository.dart';
import '../../domain/usecases/create_post_usecase.dart';
import '../../domain/usecases/create_story_usecase.dart';
import 'create_notifier.dart';
import 'create_state.dart';

final createRemoteDataSourceProvider = Provider<CreateRemoteDataSource>(
  (ref) => CreateRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final createRepositoryProvider = Provider<CreateRepository>(
  (ref) => CreateRepositoryImpl(
    remote: ref.watch(createRemoteDataSourceProvider),
  ),
);

final createPostUseCaseProvider = Provider(
  (ref) => CreatePostUseCase(ref.watch(createRepositoryProvider)),
);

final createStoryUseCaseProvider = Provider(
  (ref) => CreateStoryUseCase(ref.watch(createRepositoryProvider)),
);

final createNotifierProvider =
    StateNotifierProvider<CreateNotifier, CreateState>((ref) {
  return CreateNotifier(
    createPostUseCase: ref.watch(createPostUseCaseProvider),
    createStoryUseCase: ref.watch(createStoryUseCaseProvider),
  );
});
