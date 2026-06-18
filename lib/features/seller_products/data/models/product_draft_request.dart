import '../../domain/entities/product_draft.dart';
import '../../domain/entities/product_status.dart';

/// Serialises a [ProductDraft] to the backend's snake_case contract.
class ProductDraftRequest {
  const ProductDraftRequest(this.draft);

  final ProductDraft draft;

  Map<String, dynamic> _base() => {
        'title': draft.title,
        'description': draft.description,
        'category': draft.category,
        'price': draft.price,
        if (draft.oldPrice != null) 'old_price': draft.oldPrice,
        'stock': draft.stock,
        'status': draft.status.wire,
        'is_featured': draft.isFeatured,
        'show_in_feed': draft.showInFeed,
        'media': draft.media
            .map((m) => {'url': m.url, 'type': m.isVideo ? 'video' : 'image'})
            .toList(),
      };

  /// Create payload — variants are accepted inline on creation.
  Map<String, dynamic> toCreateJson() => {
        ..._base(),
        if (draft.variants.isNotEmpty)
          'variants': draft.variants
              .map((v) => {
                    'name': v.name,
                    if (v.sku != null && v.sku!.isNotEmpty) 'sku': v.sku,
                    if (v.price != null) 'price': v.price,
                    'stock': v.stock,
                  })
              .toList(),
      };

  /// Update payload — gallery is replaced; variants are managed separately.
  Map<String, dynamic> toUpdateJson() => _base();
}
