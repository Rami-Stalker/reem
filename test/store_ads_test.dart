import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/features/store_ads/data/models/store_ads_mapper.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';

/// «إعلانات المتاجر» on the client: the wire shapes the API sends, and the
/// plan rules the composer uses to show a lock before the server refuses.
void main() {
  group('plan rules', () {
    test('a placement names the lowest plan that can buy it', () {
      expect(AdPlacement.search.minimumTier, AdTier.free);
      expect(AdPlacement.feedTop.minimumTier, AdTier.silver);
      expect(AdPlacement.homeSpotlight.minimumTier, AdTier.gold);
    });

    test('targeting raises the plan a campaign needs', () {
      const byPlace = AdAudience(targeted: true, governorates: ['حلب']);
      const byInterest = AdAudience(targeted: true, followers: true);
      expect(byPlace.requiredTier(AdPlacement.search), AdTier.silver);
      expect(byInterest.requiredTier(AdPlacement.search), AdTier.gold);
      expect(byInterest.requiredTier(AdPlacement.feedTop), AdTier.gold);
    });

    test('a targeted audience that names nobody is everyone', () {
      const empty = AdAudience(targeted: true);
      expect(empty.isEffectivelyTargeted, isFalse);
      expect(
        StoreAdsMapper.audienceToJson(empty),
        {'type': 'everyone'},
        reason: 'the server would treat it as everyone; say so on the wire',
      );
    });
  });

  group('wire shapes', () {
    test('a quote reads its price, reach and refusal', () {
      final quote = StoreAdsMapper.quote({
        'tier': 'free',
        'allowed': false,
        'refusal': 'placement_locked',
        'required_tier': 'gold',
        'price': {
          'days': 7,
          'daily_rate': 4000,
          'list_price': 28000,
          'discount': 0,
          'total': 28000,
          'credit_applied': 0,
          'to_pay': 28000,
          'currency': 'SYP',
        },
        'reach': {'shoppers': 31, 'total_shoppers': 56},
        'competing_campaigns': 2,
        'share_of_voice': 0.42,
      });
      expect(quote.allowed, isFalse);
      expect(quote.refusal, AdRefusal.placementLocked);
      expect(quote.requiredTier, AdTier.gold);
      expect(quote.price.toPay, 28000);
      expect(quote.reachShare, closeTo(31 / 56, 1e-9));
      expect(quote.needsFeedPost, isFalse, reason: 'not a feed placement');
    });

    test('a feed quote with no post of hers cannot launch', () {
      final quote = StoreAdsMapper.quote({
        'tier': 'silver',
        'allowed': true,
        'price': const <String, dynamic>{},
        'reach': const <String, dynamic>{},
        'feed_post': null,
      });
      expect(quote.needsFeedPost, isTrue);
      expect(quote.canLaunch, isFalse);
    });

    test('a campaign reads money given as {amount, currency}', () {
      final c = StoreAdsMapper.campaign({
        'id': 'p1',
        'placement': 'home_spotlight',
        'status': 'active',
        'is_live': true,
        'fee': {'amount': '22400.0000', 'currency': 'SYP'},
        'credit_applied': {'amount': '22400.0000', 'currency': 'SYP'},
        'starts_at': '2026-10-29T12:00:00.000Z',
        'ends_at': '2026-11-05T12:00:00.000Z',
        'audience': {'type': 'targeted', 'governorates': ['دمشق']},
        'product': {'title': 'عباية', 'image_url': null},
        'impressions': 120,
        'clicks': 9,
        'reach': 80,
        'attributed_orders': 2,
        'attributed_revenue': {'amount': '45000.0000', 'currency': 'SYP'},
      });
      expect(c.placement, AdPlacement.homeSpotlight);
      expect(c.fee, 22400);
      expect(c.creditApplied, 22400);
      expect(c.audience.governorates, ['دمشق']);
      expect(c.attributedRevenue, 45000);
    });

    test('plans read the current tier and its credit', () {
      final view = StoreAdsMapper.plans({
        'current': {
          'tier': 'gold',
          'credit_granted': 80000,
          'credit_used': 22400,
          'credit_remaining': 57600,
          'active_campaigns': 1,
          'max_active_campaigns': 6,
        },
        'plans': [
          {
            'tier': 'gold',
            'price': 60000,
            'credit': 80000,
            'discount_percent': 20,
            'max_active_campaigns': 6,
            'placements': ['search', 'category', 'feed_top', 'home_spotlight'],
            'targeting': 'full',
            'serving_weight': 3,
            'notifies_followers': true,
            'featured_store': true,
          },
        ],
        'recommendation': null,
      });
      expect(view.current.tier, AdTier.gold);
      expect(view.current.creditProgress, closeTo(57600 / 80000, 1e-9));
      expect(view.allows(AdPlacement.homeSpotlight), isTrue);
      expect(view.currentPlan!.bonusCredit, 20000);
    });
  });
}
