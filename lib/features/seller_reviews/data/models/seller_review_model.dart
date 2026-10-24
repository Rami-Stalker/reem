import 'package:ohara/features/seller_reviews/domain/entities/seller_review.dart';

/// Parses `/reputation/seller/reviews`.
abstract final class SellerReviewMapper {
  static SellerReviewDesk deskFromJson(Map<String, dynamic> json) =>
      SellerReviewDesk(
        reviews: [
          for (final row in (json['data'] as List? ?? const []).whereType<Map>())
            fromJson(row.cast<String, dynamic>()),
        ],
        unanswered: (json['unanswered'] as num?)?.toInt() ?? 0,
      );

  static SellerReviewItem fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final product =
        (json['product'] as Map?)?.cast<String, dynamic>() ?? const {};

    return SellerReviewItem(
      id: json['id'] as String,
      target: ReviewTarget.fromWire(json['target_type'] as String?),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      author: ReviewAuthor(
        name: user['name'] as String? ?? '',
        imageUrl: user['image_url'] as String?,
      ),
      title: json['title'] as String?,
      body: json['body'] as String?,
      verifiedPurchase: json['verified_purchase'] as bool? ?? false,
      productTitle: product['title'] as String?,
      productImage: product['image'] as String?,
      reply: json['seller_reply'] as String?,
      repliedAt: DateTime.tryParse(
        json['seller_replied_at'] as String? ?? '',
      )?.toLocal(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}
