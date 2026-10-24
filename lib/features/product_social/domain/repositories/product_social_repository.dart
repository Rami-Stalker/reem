import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/discovery/domain/entities/product_page.dart';
import 'package:ohara/features/product_social/domain/entities/product_engagement.dart';

/// Likes, bookmarks, picks, shares and reports on a product.
///
/// Every write is a desired state rather than a toggle, so a tap replayed
/// after a dropped connection lands where she left it instead of undoing
/// itself.
abstract interface class ProductSocialRepository {
  Future<Result<Map<String, ProductEngagement>>> engagement(List<String> ids);

  Future<Result<int>> setLiked(String productId, {required bool liked});

  Future<Result<void>> setSaved(String productId, {required bool saved});

  Future<Result<int>> setPicked(
    String productId, {
    required bool picked,
    String? note,
  });

  Future<Result<int>> recordShare(String productId);

  Future<Result<void>> report(String productId, String reason, {String? detail});

  Future<Result<ProductPage>> picksOf(String userId, {int page});
}
