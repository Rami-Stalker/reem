import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/datasources/home_content_datasource.dart';
import '../../data/datasources/impl/home_content_mock_datasource.dart';
import '../../data/repositories/home_content_repository_impl.dart';
import '../../domain/repositories/home_content_repository.dart';
import '../../domain/usecases/get_home_content_usecase.dart';
import 'home_content_notifier.dart';
import 'home_content_state.dart';

/// Swap point: replace [HomeContentMockDataSource] with a remote
/// implementation (e.g. `HomeContentRemoteDataSourceImpl(ref.watch(dioProvider))`)
/// and nothing else in the home feature needs to change.
final homeContentDataSourceProvider = Provider<HomeContentDataSource>(
  (ref) => const HomeContentMockDataSource(),
);

final homeContentRepositoryProvider = Provider<HomeContentRepository>(
  (ref) => HomeContentRepositoryImpl(
    source: ref.watch(homeContentDataSourceProvider),
  ),
);

final getHomeContentUseCaseProvider = Provider(
  (ref) => GetHomeContentUseCase(ref.watch(homeContentRepositoryProvider)),
);

final homeContentNotifierProvider =
    StateNotifierProvider<HomeContentNotifier, HomeContentState>(
  (ref) => HomeContentNotifier(ref.watch(getHomeContentUseCaseProvider))..load(),
);
