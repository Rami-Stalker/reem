import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/discovery/domain/entities/product_collection.dart';
import 'package:reem/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:reem/features/home/data/datasources/home_remote_datasource.dart';
import 'package:reem/features/home/data/datasources/impl/home_remote_datasource_impl.dart';
import 'package:reem/features/home/data/repositories/home_repository_impl.dart';
import 'package:reem/features/home/domain/repositories/home_repository.dart';
import 'package:reem/features/home/domain/usecases/get_feed_usecase.dart';
import 'package:reem/features/home/domain/usecases/get_stories_usecase.dart';
import 'package:reem/features/home/presentation/providers/home_notifier.dart';
import 'package:reem/features/home/presentation/providers/home_state.dart';

/// Product collections shown on the home feed, in display order.
const homeCollections = <ProductCollection>[
  ProductCollection.recommended,
  ProductCollection.trending,
  ProductCollection.newArrivals,
  ProductCollection.bestSelling,
  ProductCollection.featured,
  ProductCollection.mostLoved,
  ProductCollection.topRated,
];

// ── Home (social feed + stories) infrastructure ─────────────────────────────

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>(
  (ref) => HomeRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepositoryImpl(remote: ref.watch(homeRemoteDataSourceProvider)),
);

final getFeedUseCaseProvider =
    Provider((ref) => GetFeedUseCase(ref.watch(homeRepositoryProvider)));

final getStoriesUseCaseProvider =
    Provider((ref) => GetStoriesUseCase(ref.watch(homeRepositoryProvider)));

/// Aggregates the home page's collections + social content. Reuses the
/// discovery use cases so product fetching stays in one place.
final homeNotifierProvider =
    StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(
    collections: homeCollections,
    getCollection: ref.watch(getCollectionUseCaseProvider),
    getRecommended: ref.watch(getRecommendedUseCaseProvider),
    getFeed: ref.watch(getFeedUseCaseProvider),
    getStories: ref.watch(getStoriesUseCaseProvider),
  )..load();
});
