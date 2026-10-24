import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/discovery/data/datasources/discovery_signals.dart';
import 'package:ohara/features/discovery/domain/entities/sponsored_product.dart';

final discoverySignalsProvider = Provider<DiscoverySignals>(
  (ref) => DiscoverySignals(ref.watch(dioProvider)),
);

/// The paid slots that came back with the first page of a listing.
///
/// Keyed `search:<query>` or `category:<slug>`. Written by the listing's own
/// paging provider when page one arrives, so the slots and the results are
/// always from the same request — a second request just for the adverts would
/// count every impression twice.
final sponsoredSlotsProvider = StateProvider.autoDispose
    .family<List<SponsoredProduct>, String>((ref, key) => const []);

String searchSponsoredKey(String query) => 'search:${query.trim()}';
String categorySponsoredKey(String slug) => 'category:${slug.toLowerCase()}';
