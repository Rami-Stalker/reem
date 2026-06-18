import 'package:flutter/material.dart';

import '../../../../../core/shared/entities/loyalty.dart';
import '../../../../../core/shared/entities/media.dart';
import '../../../../../core/shared/entities/product.dart';
import '../../../../../core/shared/entities/user.dart';
import '../../../domain/entities/achievement.dart';
import '../../../domain/entities/followed_store.dart';
import '../../../domain/entities/orders_overview.dart';
import '../../../domain/entities/profile_overview.dart';
import '../../../domain/entities/referral.dart';
import '../profile_overview_datasource.dart';

/// Front-end-first mock of the profile-centre overview. Polished, deterministic
/// sample data so the profile is fully alive before the backend ships these
/// surfaces. Swap for a remote implementation when endpoints exist.
final class ProfileOverviewMockDataSource implements ProfileOverviewDataSource {
  const ProfileOverviewMockDataSource();

  static const _latency = Duration(milliseconds: 600);

  static String _img(String seed, {int w = 600, int h = 750}) =>
      'https://picsum.photos/seed/$seed/$w/$h';

  @override
  Future<ProfileOverview> getOverview() async {
    await Future<void>.delayed(_latency);

    return ProfileOverview(
      completionSteps: const [
        ProfileCompletionStep(label: 'Add a profile photo', done: true),
        ProfileCompletionStep(label: 'Verify your phone', done: true),
        ProfileCompletionStep(label: 'Add a delivery address', done: true),
        ProfileCompletionStep(label: 'Add a payment method', done: false),
        ProfileCompletionStep(label: 'Set your style preferences', done: false),
      ],
      achievements: const [
        Achievement(id: 'a1', label: 'First order', description: 'Placed your very first Reem order.', icon: Icons.shopping_bag_rounded, earned: true),
        Achievement(id: 'a2', label: 'Trendsetter', description: 'Shared 5 looks your friends loved.', icon: Icons.auto_awesome_rounded, earned: true),
        Achievement(id: 'a3', label: 'Loyal one year', description: 'A whole year of beautiful finds.', icon: Icons.verified_rounded, earned: true),
        Achievement(id: 'a4', label: 'Big spender', description: 'Reached \$2,000 in lifetime orders.', icon: Icons.diamond_rounded, earned: false),
        Achievement(id: 'a5', label: 'Top reviewer', description: 'Write 10 helpful reviews.', icon: Icons.rate_review_rounded, earned: false),
        Achievement(id: 'a6', label: 'Super referrer', description: 'Invite 5 friends who shop.', icon: Icons.group_add_rounded, earned: false),
      ],
      orders: const OrdersOverview(
        pending: 1,
        processing: 2,
        delivered: 18,
        cancelled: 1,
      ),
      followedStores: [
        FollowedStore(id: 's1', name: 'Atelier Rose', logoUrl: _img('logo-s1', w: 200, h: 200), isVerified: true, newCount: 3),
        FollowedStore(id: 's2', name: 'Maison Lumière', logoUrl: _img('logo-s2', w: 200, h: 200), isVerified: true, newCount: 1),
        FollowedStore(id: 's4', name: 'Velvet Petals', logoUrl: _img('logo-s4', w: 200, h: 200), isVerified: true),
        FollowedStore(id: 's3', name: 'Bloom & Co', logoUrl: _img('logo-s3', w: 200, h: 200), newCount: 5),
      ],
      recentlyViewed: _recentlyViewed,
      reviewsCount: 12,
      averageRating: 4.8,
      referral: const Referral(
        code: 'REEM-LAYLA',
        invited: 3,
        earnedPoints: 1500,
        rewardHint: 'You both get 500 pts on their first order',
      ),
      loyalty: const LoyaltySummary(
        points: 2450,
        tier: LoyaltyTier.gold,
        nextTier: LoyaltyTier.platinum,
        pointsToNextTier: 550,
        availableCoupons: 4,
        rewardHint: '550 pts until Platinum — and a free gift wrap',
        lifetimePoints: 8200,
        redeemedCount: 9,
      ),
    );
  }

  static final _seller = User(
    id: 's1',
    name: 'Atelier Rose',
    username: 'atelier_rose',
    phone: '',
    role: UserRole.seller,
    isVerified: true,
    createdAt: DateTime(2023, 3, 14),
  );

  static Product _product({
    required String id,
    required String title,
    required double price,
    double? oldPrice,
    String category = 'general',
  }) {
    return Product(
      id: id,
      seller: _seller,
      title: title,
      description: 'A piece you recently admired.',
      category: category,
      price: price,
      oldPrice: oldPrice,
      stock: 24,
      media: [MediaItem(url: _img('prof-$id'))],
      rating: 4.7,
      reviewsCount: 120,
      createdAt: DateTime(2024, 12, 1),
    );
  }

  static final _recentlyViewed = <Product>[
    _product(id: 'pv1', title: 'Silk Slip Dress', price: 189, oldPrice: 240, category: 'dress'),
    _product(id: 'pv2', title: 'Oud Eau de Parfum', price: 95, category: 'fragrance'),
    _product(id: 'pv3', title: 'Mini Shoulder Bag', price: 129, oldPrice: 170, category: 'bags'),
    _product(id: 'pv4', title: 'Pearl Drop Earrings', price: 49, category: 'jewelry'),
    _product(id: 'pv5', title: 'Satin Bow Mules', price: 110, category: 'shoes'),
  ];
}
