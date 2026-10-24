import 'package:ohara/features/discovery/domain/entities/product_collection.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The Arabic heading over a collection page.
///
/// [ProductCollectionX.title] stays English: it is part of a domain enum with
/// no locale, and it travels into logs and analytics. The collection screen
/// used to show it verbatim, so tapping «عرض الكل» under «الأكثر مبيعاً»
/// opened a page headed "Best Sellers". Resolved here instead, the way
/// `AdminSectionTitle` resolves the console's section names.
extension ProductCollectionTitle on ProductCollection {
  String titleOf(AppLocalizations l10n) => switch (this) {
    ProductCollection.trending => l10n.trending,
    ProductCollection.featured => l10n.collectionFeatured,
    ProductCollection.mostLoved => l10n.collectionMostLoved,
    ProductCollection.topRated => l10n.collectionTopRated,
    ProductCollection.bestSelling => l10n.bestSeller,
    ProductCollection.newArrivals => l10n.newArrivals,
    ProductCollection.recommended => l10n.recommended,
    ProductCollection.deals => l10n.collectionDeals,
  };
}
