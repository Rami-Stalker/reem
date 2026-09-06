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

  /// Everything a boutique has marked down — what "عرض الكل" under «عروض
  /// سريعة» means. That link used to open the best-sellers shelf, which is a
  /// different set of pieces entirely: a shopper following a discount landed
  /// on full-price merchandise.
  deals,
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
    ProductCollection.deals => 'deals',
  };

  /// The English name, kept for logs and analytics. What the shopper reads is
  /// [ProductCollectionTitle.titleOf] — this used to head the collection page
  /// itself, which put "Best Sellers" at the top of an Arabic screen.
  String get title => switch (this) {
    ProductCollection.trending => 'Trending Now',
    ProductCollection.featured => 'Featured',
    ProductCollection.mostLoved => 'Most Loved',
    ProductCollection.topRated => 'Top Rated',
    ProductCollection.bestSelling => 'Best Sellers',
    ProductCollection.newArrivals => 'New Arrivals',
    ProductCollection.recommended => 'Recommended for You',
    ProductCollection.deals => 'All Deals',
  };

  static ProductCollection fromKey(String key) =>
      ProductCollection.values.firstWhere(
        (c) => c.key == key,
        orElse: () => ProductCollection.trending,
      );
}
