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
import '../../../../../core/shared/entities/category.dart';
import '../../../../../core/shared/entities/seller_offer.dart';
import '../../../../../core/shared/value_objects/money.dart';

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
        ProfileCompletionStep(label: 'أضيفي صورة شخصية', done: true),
        ProfileCompletionStep(label: 'وثّقي رقم هاتفكِ', done: true),
        ProfileCompletionStep(label: 'أضيفي عنوان توصيل', done: true),
        ProfileCompletionStep(label: 'أضيفي وسيلة دفع', done: false),
        ProfileCompletionStep(label: 'حدّدي تفضيلات ذوقكِ', done: false),
      ],
      achievements: const [
        Achievement(id: 'a1', label: 'أول طلب', description: 'أتممتِ أول طلب لكِ على ريم.', icon: Icons.shopping_bag_rounded, earned: true),
        Achievement(id: 'a2', label: 'صانعة ذوق', description: 'شاركتِ 5 إطلالات أحبّتها صديقاتكِ.', icon: Icons.auto_awesome_rounded, earned: true),
        Achievement(id: 'a3', label: 'سنة من الوفاء', description: 'سنة كاملة من الاكتشافات الجميلة.', icon: Icons.verified_rounded, earned: true),
        Achievement(id: 'a4', label: 'زبونة مميّزة', description: 'بلغ مجموع طلباتكِ 9 مليون ل.س.', icon: Icons.diamond_rounded, earned: false),
        Achievement(id: 'a5', label: 'مقيّمة نشِطة', description: 'اكتبي 10 تقييمات مفيدة.', icon: Icons.rate_review_rounded, earned: false),
        Achievement(id: 'a6', label: 'سفيرة ريم', description: 'ادعي 5 صديقات يتسوّقن معكِ.', icon: Icons.group_add_rounded, earned: false),
      ],
      orders: const OrdersOverview(
        pending: 1,
        processing: 2,
        delivered: 18,
        cancelled: 1,
      ),
      followedStores: [
        FollowedStore(id: 's1', name: 'أتيليه الورد', logoUrl: _img('logo-s1', w: 200, h: 200), isVerified: true, newCount: 3),
        FollowedStore(id: 's2', name: 'دار النور', logoUrl: _img('logo-s2', w: 200, h: 200), isVerified: true, newCount: 1),
        FollowedStore(id: 's4', name: 'بتلات المخمل', logoUrl: _img('logo-s4', w: 200, h: 200), isVerified: true),
        FollowedStore(id: 's3', name: 'بستان', logoUrl: _img('logo-s3', w: 200, h: 200), newCount: 5),
      ],
      recentlyViewed: _recentlyViewed,
      reviewsCount: 12,
      averageRating: 4.8,
      referral: const Referral(
        code: 'REEM-LAYLA',
        invited: 3,
        earnedPoints: 1500,
        rewardHint: 'تحصلان معاً على 500 نقطة عند أول طلب لها',
      ),
      loyalty: const LoyaltySummary(
        points: 2450,
        tier: LoyaltyTier.gold,
        nextTier: LoyaltyTier.platinum,
        pointsToNextTier: 550,
        availableCoupons: 4,
        rewardHint: '550 نقطة تفصلكِ عن البلاتينية — وتغليف هدية مجاني',
        lifetimePoints: 8200,
        redeemedCount: 9,
      ),
    );
  }

  static final _seller = User(
    id: 's1',
    name: 'أتيليه الورد',
    username: 'atelier_alward',
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
    final offer = SellerOffer(
      id: 'offer-$id',
      seller: _seller,
      price: Money(raw: price.toStringAsFixed(0), currency: Currency.syp),
      compareAtPrice: oldPrice == null
          ? null
          : Money(raw: oldPrice.toStringAsFixed(0), currency: Currency.syp),
      stock: 24,
      status: OfferStatus.active,
    );

    return Product(
      id: id,
      slug: id,
      title: title,
      description: 'قطعة أعجبتكِ مؤخراً.',
      category: Category(
        id: category,
        slug: category,
        nameAr: category,
        nameEn: category,
      ),
      media: [MediaItem(url: _img('prof-$id'))],
      offers: [offer],
      offersCount: 1,
      priceFrom: offer.price,
      priceTo: offer.price,
      stock: 24,
      rating: 4.7,
      reviewsCount: 120,
      createdAt: DateTime(2024, 12, 1),
    );
  }

  static final _recentlyViewed = <Product>[
    _product(id: 'pv1', title: 'فستان حرير انسيابي', price: 850000, oldPrice: 1080000, category: 'فساتين'),
    _product(id: 'pv2', title: 'عطر العود', price: 430000, category: 'عطور'),
    _product(id: 'pv3', title: 'حقيبة كتف صغيرة', price: 580000, oldPrice: 765000, category: 'حقائب'),
    _product(id: 'pv4', title: 'أقراط لؤلؤ متدلّية', price: 220000, category: 'مجوهرات'),
    _product(id: 'pv5', title: 'حذاء ساتان بفيونكة', price: 495000, category: 'أحذية'),
  ];
}
