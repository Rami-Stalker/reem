import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/home_remote_datasource.dart';
import '../../data/datasources/impl/home_remote_datasource_impl.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/usecases/get_feed_usecase.dart';
import '../../domain/usecases/get_stories_usecase.dart';
import 'home_notifier.dart';
import 'home_state.dart';

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>(
  (ref) => HomeRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepositoryImpl(remote: ref.watch(homeRemoteDataSourceProvider)),
);

final getFeedUseCaseProvider = Provider(
  (ref) => GetFeedUseCase(ref.watch(homeRepositoryProvider)),
);

final getStoriesUseCaseProvider = Provider(
  (ref) => GetStoriesUseCase(ref.watch(homeRepositoryProvider)),
);

final homeNotifierProvider =
    StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(
    getFeedUseCase: ref.watch(getFeedUseCaseProvider),
    getStoriesUseCase: ref.watch(getStoriesUseCaseProvider),
  );
});
