/// Static, server-backed product collections. The [key] matches the backend
/// `/discovery/collections/:key` contract.
enum ProductCollection {
  trending,
  featured,
  mostLoved,
  topRated,
  bestSelling,
  newArrivals,
  recommended,
}

extension ProductCollectionX on ProductCollection {
  String get key => switch (this) {
        ProductCollection.trending => 'trending',
        ProductCollection.featured => 'featured',
        ProductCollection.mostLoved => 'most_loved',
        ProductCollection.topRated => 'top_rated',
        ProductCollection.bestSelling => 'best_selling',
        ProductCollection.newArrivals => 'new_arrivals',
        ProductCollection.recommended => 'recommended',
      };

  String get title => switch (this) {
        ProductCollection.trending => 'Trending Now',
        ProductCollection.featured => 'Featured',
        ProductCollection.mostLoved => 'Most Loved',
        ProductCollection.topRated => 'Top Rated',
        ProductCollection.bestSelling => 'Best Sellers',
        ProductCollection.newArrivals => 'New Arrivals',
        ProductCollection.recommended => 'Recommended for You',
      };

  static ProductCollection fromKey(String key) =>
      ProductCollection.values.firstWhere(
        (c) => c.key == key,
        orElse: () => ProductCollection.trending,
      );
}
