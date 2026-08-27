import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';

import 'package:reem/features/profile/data/datasources/impl/profile_overview_remote_datasource.dart';
import 'package:reem/features/profile/data/datasources/profile_overview_datasource.dart';
import 'package:reem/features/profile/data/repositories/profile_overview_repository_impl.dart';
import 'package:reem/features/profile/domain/repositories/profile_overview_repository.dart';
import 'package:reem/features/profile/domain/usecases/get_profile_overview_usecase.dart';
import 'package:reem/features/profile/presentation/providers/profile_overview_notifier.dart';
import 'package:reem/features/profile/presentation/providers/profile_overview_state.dart';

/// Swap point: replace [ProfileOverviewMockDataSource] with a remote
/// implementation and nothing else in the profile feature changes.
final profileOverviewDataSourceProvider = Provider<ProfileOverviewDataSource>(
  (ref) => ProfileOverviewRemoteDataSource(ref.watch(dioProvider)),
);

final profileOverviewRepositoryProvider = Provider<ProfileOverviewRepository>(
  (ref) => ProfileOverviewRepositoryImpl(
    source: ref.watch(profileOverviewDataSourceProvider),
  ),
);

final getProfileOverviewUseCaseProvider = Provider(
  (ref) => GetProfileOverviewUseCase(ref.watch(profileOverviewRepositoryProvider)),
);

final profileOverviewNotifierProvider =
    StateNotifierProvider<ProfileOverviewNotifier, ProfileOverviewState>(
  (ref) =>
      ProfileOverviewNotifier(ref.watch(getProfileOverviewUseCaseProvider))..load(),
);
