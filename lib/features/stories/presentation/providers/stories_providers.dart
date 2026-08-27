import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/stories/data/datasources/impl/stories_remote_datasource_impl.dart';
import 'package:reem/features/stories/data/datasources/stories_remote_datasource.dart';
import 'package:reem/features/stories/data/repositories/stories_repository_impl.dart';
import 'package:reem/features/stories/domain/repositories/stories_repository.dart';
import 'package:reem/features/stories/domain/usecases/stories_usecases.dart';
import 'package:reem/features/stories/presentation/providers/stories_notifier.dart';
import 'package:reem/features/stories/presentation/providers/stories_state.dart';

final storiesRemoteDataSourceProvider = Provider<StoriesRemoteDataSource>(
  (ref) => StoriesRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final storiesRepositoryProvider = Provider<StoriesRepository>(
  (ref) => StoriesRepositoryImpl(ref.watch(storiesRemoteDataSourceProvider)),
);

final getStoriesUseCaseProvider =
    Provider((ref) => GetStoriesUseCase(ref.watch(storiesRepositoryProvider)));
final recordStoryViewUseCaseProvider = Provider(
    (ref) => RecordStoryViewUseCase(ref.watch(storiesRepositoryProvider)));
final reactToStoryUseCaseProvider =
    Provider((ref) => ReactToStoryUseCase(ref.watch(storiesRepositoryProvider)));
final removeStoryReactionUseCaseProvider = Provider(
    (ref) => RemoveStoryReactionUseCase(ref.watch(storiesRepositoryProvider)));
final getStoryAnalyticsUseCaseProvider = Provider(
    (ref) => GetStoryAnalyticsUseCase(ref.watch(storiesRepositoryProvider)));
final getStoryViewersUseCaseProvider = Provider(
    (ref) => GetStoryViewersUseCase(ref.watch(storiesRepositoryProvider)));

final storiesNotifierProvider =
    StateNotifierProvider<StoriesNotifier, StoriesState>(
  (ref) => StoriesNotifier(
    getStories: ref.watch(getStoriesUseCaseProvider),
  )..load(),
);
