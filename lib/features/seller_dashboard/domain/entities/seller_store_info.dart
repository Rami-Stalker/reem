import 'package:equatable/equatable.dart';

class SellerStoreInfo extends Equatable {
  const SellerStoreInfo({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.logoUrl,
    required this.coverUrl,
    required this.isVerified,
    required this.rating,
    required this.reviewsCount,
    required this.totalRevenue,
    required this.totalOrders,
    required this.productsCount,
    required this.followersCount,
    required this.storeScore,
    required this.memberSince,
    required this.subscriptionPlan,
    required this.withdrawableBalance,
  });

  final String id;
  final String name;
  final String tagline;
  final String description;
  final String logoUrl;
  final String coverUrl;
  final bool isVerified;
  final double rating;
  final int reviewsCount;
  final double totalRevenue;
  final int totalOrders;
  final int productsCount;
  final int followersCount;
  final int storeScore;
  final DateTime memberSince;
  final String subscriptionPlan;
  final double withdrawableBalance;

  @override
  List<Object?> get props => [id, name, rating, storeScore];
}
