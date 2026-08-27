class SearchSuggestions {
  const SearchSuggestions({
    this.products = const [],
    this.categories = const [],
  });

  final List<String> products;
  final List<String> categories;

  bool get isEmpty => products.isEmpty && categories.isEmpty;

  List<String> get combined => [
    ...categories,
    ...products.where(
      (product) => !categories.any(
        (category) => category.toLowerCase() == product.toLowerCase(),
      ),
    ),
  ];
}
