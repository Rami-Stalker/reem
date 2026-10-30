import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/presentation/widgets/store_ads_labels.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// The jewel a boutique's plan earns on shopper-facing cards — «متجر ماسي».
/// Null for a free boutique, which wears no badge.
DsTier? storeTierJewel(String? wire) =>
    wire == null ? null : AdTier.fromWire(wire).jewel;

String storeTierLabel(AppLocalizations l10n, String? wire) =>
    l10n.storeTierBadge(AdTier.fromWire(wire).label(l10n));
