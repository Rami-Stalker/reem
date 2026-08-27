/// The lifecycle of a seller's listing.
///
/// This mirrors the backend `OfferStatus`: a listing belongs to a seller, so
/// its state is a property of their offer, not of the shared catalogue entry.
/// `pendingReview` and `paused` were added when offers replaced per-seller
/// products — a new seller's listing is reviewed before it goes public (Q39),
/// and a seller can pause a listing without archiving it.
enum ProductStatus { draft, pendingReview, active, outOfStock, paused, archived }

extension ProductStatusX on ProductStatus {
  /// The value used when WRITING (uppercase, matching the Prisma enum).
  /// Responses come back lowercased and are parsed by [fromWire].
  String get wire => switch (this) {
        ProductStatus.draft => 'DRAFT',
        ProductStatus.pendingReview => 'PENDING_REVIEW',
        ProductStatus.active => 'ACTIVE',
        ProductStatus.outOfStock => 'OUT_OF_STOCK',
        ProductStatus.paused => 'PAUSED',
        ProductStatus.archived => 'ARCHIVED',
      };

  String get label => switch (this) {
        ProductStatus.draft => 'مسودّة',
        ProductStatus.pendingReview => 'قيد المراجعة',
        ProductStatus.active => 'معروض',
        ProductStatus.outOfStock => 'نفد المخزون',
        ProductStatus.paused => 'موقوف مؤقتاً',
        ProductStatus.archived => 'مؤرشف',
      };

  bool get isLive => this == ProductStatus.active;

  static ProductStatus fromWire(String? value) =>
      switch ((value ?? '').toLowerCase().replaceAll('_', '')) {
        'pendingreview' => ProductStatus.pendingReview,
        'active' => ProductStatus.active,
        'outofstock' => ProductStatus.outOfStock,
        'paused' => ProductStatus.paused,
        'archived' => ProductStatus.archived,
        _ => ProductStatus.draft,
      };
}
