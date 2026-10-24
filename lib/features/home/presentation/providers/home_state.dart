import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/entities/post.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/story.dart';

import 'package:ohara/features/discovery/domain/entities/product_collection.dart';

/// Independent state for one product-collection rail (own loading + error).
class HomeSection extends Equatable {
  const HomeSection({
    this.isLoading = true,
    this.products = const [],
    this.error,
  });

  final bool isLoading;
  final List<Product> products;
  final String? error;

  bool get hasItems => products.isNotEmpty;
  bool get hasError => error != null;

  /// True when loading finished and there is genuinely nothing to show.
  bool get isEmpty => !isLoading && products.isEmpty && error == null;

  HomeSection copyWith({
    bool? isLoading,
    List<Product>? products,
    String? error,
    bool clearError = false,
  }) {
    return HomeSection(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [isLoading, products, error];
}

/// Aggregate home state: a map of independent collection sections plus the
/// social content (stories + feed).
class HomeState extends Equatable {
  const HomeState({
    this.sections = const {},
    this.stories = const [],
    this.storiesLoading = false,
    this.feed = const [],
    this.feedLoading = false,
  });

  final Map<ProductCollection, HomeSection> sections;
  final List<Story> stories;
  final bool storiesLoading;
  final List<Post> feed;
  final bool feedLoading;

  HomeSection sectionOf(ProductCollection collection) =>
      sections[collection] ?? const HomeSection();

  HomeState copyWith({
    Map<ProductCollection, HomeSection>? sections,
    List<Story>? stories,
    bool? storiesLoading,
    List<Post>? feed,
    bool? feedLoading,
  }) {
    return HomeState(
      sections: sections ?? this.sections,
      stories: stories ?? this.stories,
      storiesLoading: storiesLoading ?? this.storiesLoading,
      feed: feed ?? this.feed,
      feedLoading: feedLoading ?? this.feedLoading,
    );
  }

  @override
  List<Object?> get props =>
      [sections, stories, storiesLoading, feed, feedLoading];
}
