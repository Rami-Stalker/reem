import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';

import 'package:reem/features/home/data/datasources/home_content_datasource.dart';
import 'package:reem/features/home/data/datasources/impl/home_content_remote_datasource.dart';
import 'package:reem/features/home/data/repositories/home_content_repository_impl.dart';
import 'package:reem/features/home/domain/repositories/home_content_repository.dart';
import 'package:reem/features/home/domain/usecases/get_home_content_usecase.dart';
import 'package:reem/features/home/presentation/providers/home_content_notifier.dart';
import 'package:reem/features/home/presentation/providers/home_content_state.dart';

/// The home page reads from the server.
///
/// It used to read from a mock that shipped to production — see
/// [HomeContentRemoteDataSource] for what that meant. The mock is kept in the
/// tree for widget previews and tests; nothing in the app builds it.
final homeContentDataSourceProvider = Provider<HomeContentDataSource>(
  (ref) => HomeContentRemoteDataSource(ref.watch(dioProvider)),
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
