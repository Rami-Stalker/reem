import 'package:ohara/features/reputation/data/models/reputation_models.dart';
import 'package:ohara/features/reputation/domain/entities/fit_entities.dart';

/// What she changes on «مقاساتي». Every field is sent: the screen shows the
/// whole profile, so an emptied height means "clear it".
class FitProfileDraft {
  const FitProfileDraft({
    this.heightCm,
    this.usualSize,
    this.shareOnReviews = true,
  });

  final int? heightCm;
  final String? usualSize;
  final bool shareOnReviews;

  Map<String, dynamic> toJson() => {
    'height_cm': heightCm,
    'usual_size': usualSize,
    'share_on_reviews': shareOnReviews,
  };
}

/// What she adds to a product review under «تقييمات من بمقاسي».
class ReviewFitDraft {
  const ReviewFitDraft({this.fit, this.photoUrls = const [], this.shareFit});

  final ReviewFit? fit;
  final List<String> photoUrls;

  /// Null leaves it to her profile's standing choice.
  final bool? shareFit;

  Map<String, dynamic> toJson() => {
    if (fit != null) 'fit': fit!.wire,
    if (photoUrls.isNotEmpty) 'photo_urls': photoUrls,
    'share_fit': ?shareFit,
  };
}

abstract interface class ReputationRemoteDataSource {
  Future<List<ReviewModel>> getProductReviews(
    String productId, {
    ReviewFilter filter = ReviewFilter.all,
  });

  Future<ReviewModel> submitProductReview({
    required String productId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
    ReviewFitDraft? fit,
  });

  Future<ProductFit> getProductFit(String productId);

  Future<FitProfile> getFitProfile();

  Future<FitProfile> saveFitProfile(FitProfileDraft draft);

  Future<MyReviewsModel> getMyReviews();

  Future<List<ReviewModel>> getSellerReviews(String sellerId);

  Future<ReviewModel> submitSellerReview({
    required String sellerId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
  });

  Future<SellerReputationSummaryModel> getSellerReputation(String sellerId);

  Future<void> requestTrustedSellerVerification({Object? evidence});
}
