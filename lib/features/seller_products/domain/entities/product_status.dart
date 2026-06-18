enum ProductStatus { draft, active, outOfStock, archived }

extension ProductStatusX on ProductStatus {
  /// The API/enum value used when WRITING (uppercase, matches the backend
  /// Prisma enum). Responses come back lowercased and are parsed by [fromWire].
  String get wire => switch (this) {
        ProductStatus.draft => 'DRAFT',
        ProductStatus.active => 'ACTIVE',
        ProductStatus.outOfStock => 'OUT_OF_STOCK',
        ProductStatus.archived => 'ARCHIVED',
      };

  String get label => switch (this) {
        ProductStatus.draft => 'Draft',
        ProductStatus.active => 'Active',
        ProductStatus.outOfStock => 'Out of Stock',
        ProductStatus.archived => 'Archived',
      };

  static ProductStatus fromWire(String? value) =>
      switch ((value ?? '').toLowerCase()) {
        'active' => ProductStatus.active,
        'out_of_stock' => ProductStatus.outOfStock,
        'archived' => ProductStatus.archived,
        _ => ProductStatus.draft,
      };
}
