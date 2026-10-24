import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/post.dart';

import 'package:ohara/features/discovery/domain/entities/product_collection.dart';
import 'package:ohara/features/discovery/domain/usecases/discovery_usecases.dart';
import 'package:ohara/features/home/domain/usecases/get_feed_usecase.dart';
import 'package:ohara/features/home/domain/usecases/get_stories_usecase.dart';
import 'package:ohara/features/home/presentation/providers/home_state.dart';

/// Orchestrates the home feed: fetches every product collection (each tracked
/// independently) plus stories + the social feed, in parallel.
class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier({
    required this.collections,
    required GetCollectionUseCase getCollection,
    required GetRecommendedUseCase getRecommended,
    required GetFeedUseCase getFeed,
    required GetStoriesUseCase getStories,
  }) : _getCollection = getCollection,
       _getRecommended = getRecommended,
       _getFeed = getFeed,
       _getStories = getStories,
       super(
         HomeState(
           sections: {for (final c in collections) c: const HomeSection()},
         ),
       );

  final List<ProductCollection> collections;
  final GetCollectionUseCase _getCollection;
  final GetRecommendedUseCase _getRecommended;
  final GetFeedUseCase _getFeed;
  final GetStoriesUseCase _getStories;

  static const _railSize = 12;

  Future<void> load() async {
    state = HomeState(
      sections: {
        for (final c in collections) c: const HomeSection(isLoading: true),
      },
      storiesLoading: true,
      feedLoading: true,
    );
    await Future.wait([
      for (final collection in collections) _loadCollection(collection),
      _loadStories(),
      _loadFeed(),
    ]);
  }

  Future<void> refresh() => load();

  /// Reload a single rail (e.g. its "Retry" button) without touching the rest.
  Future<void> refreshSection(ProductCollection collection) async {
    state = state.copyWith(
      sections: {
        ...state.sections,
        collection: const HomeSection(isLoading: true),
      },
    );
    await _loadCollection(collection);
  }

  Future<void> _loadCollection(ProductCollection collection) async {
    final result = collection == ProductCollection.recommended
        ? await _getRecommended(limit: _railSize)
        : await _getCollection(collection.key, limit: _railSize);

    final section = switch (result) {
      Success(:final data) => HomeSection(
        isLoading: false,
        products: data.items,
      ),
      Error(:final failure) => HomeSection(
        isLoading: false,
        error: failure.message,
      ),
    };
    state = state.copyWith(sections: {...state.sections, collection: section});
  }

  Future<void> _loadStories() async {
    final result = await _getStories();
    switch (result) {
      case Success(:final data):
        state = state.copyWith(stories: data, storiesLoading: false);
      case Error():
        state = state.copyWith(storiesLoading: false);
    }
  }

  /// Takes the posts matching [test] out of the feed and returns them with
  /// where they stood, so an «تراجع» can put each back in its place.
  ///
  /// Used by the post menu: «غير مهتمة» removes one post, hiding an account
  /// removes every post of hers on the page.
  List<(int, Post)> removeFromFeed(bool Function(Post post) test) {
    final removed = <(int, Post)>[];
    final kept = <Post>[];
    for (var i = 0; i < state.feed.length; i++) {
      final post = state.feed[i];
      if (test(post)) {
        removed.add((i, post));
      } else {
        kept.add(post);
      }
    }
    if (removed.isNotEmpty) state = state.copyWith(feed: kept);
    return removed;
  }

  /// Puts back what [removeFromFeed] took, at the positions it took them from.
  void restoreToFeed(List<(int, Post)> removed) {
    if (removed.isEmpty) return;
    final feed = [...state.feed];
    for (final (index, post) in removed) {
      if (feed.any((p) => p.id == post.id)) continue;
      feed.insert(index.clamp(0, feed.length), post);
    }
    state = state.copyWith(feed: feed);
  }

  Future<void> _loadFeed() async {
    final result = await _getFeed();
    switch (result) {
      case Success(:final data):
        state = state.copyWith(feed: data, feedLoading: false);
      case Error():
        state = state.copyWith(feedLoading: false);
    }
  }
}
