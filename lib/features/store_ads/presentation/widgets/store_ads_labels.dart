import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/shared/value_objects/money_format.dart';
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/presentation/providers/store_ads_providers.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// Every word «مركز الإعلانات» says about a tier, a placement or a refusal,
/// in one place so the plans page and the composer never disagree.
extension AdTierLabels on AdTier {
  String label(AppLocalizations l10n) => switch (this) {
    AdTier.free => l10n.adTierFree,
    AdTier.silver => l10n.adTierSilver,
    AdTier.gold => l10n.adTierGold,
    AdTier.diamond => l10n.adTierDiamond,
  };

  /// The jewel for a paid plan; null for free, which wears no badge.
  DsTier? get jewel => switch (this) {
    AdTier.free => null,
    AdTier.silver => DsTier.silver,
    AdTier.gold => DsTier.gold,
    AdTier.diamond => DsTier.diamond,
  };
}

extension AdPlacementLabels on AdPlacement {
  String label(AppLocalizations l10n) => switch (this) {
    AdPlacement.search => l10n.adPlacementSearch,
    AdPlacement.category => l10n.adPlacementCategory,
    AdPlacement.feedTop => l10n.adPlacementFeedTop,
    AdPlacement.homeSpotlight => l10n.adPlacementHomeSpotlight,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    AdPlacement.search => l10n.adPlacementSearchHint,
    AdPlacement.category => l10n.adPlacementCategoryHint,
    AdPlacement.feedTop => l10n.adPlacementFeedTopHint,
    AdPlacement.homeSpotlight => l10n.adPlacementHomeSpotlightHint,
  };

  IconData get icon => switch (this) {
    AdPlacement.search => Icons.manage_search_rounded,
    AdPlacement.category => Icons.grid_view_rounded,
    AdPlacement.feedTop => Icons.push_pin_rounded,
    AdPlacement.homeSpotlight => Icons.auto_awesome_rounded,
  };
}

extension AdSuggestionReasonLabels on AdSuggestionReason {
  String label(AppLocalizations l10n) => switch (this) {
    AdSuggestionReason.lovedNotBought => l10n.adsReasonLoved,
    AdSuggestionReason.bestSeller => l10n.adsReasonBest,
    AdSuggestionReason.hiddenGem => l10n.adsReasonHidden,
    AdSuggestionReason.freshPick => l10n.adsReasonFresh,
  };
}

extension AdCampaignStatusLabels on AdCampaign {
  String statusLabel(AppLocalizations l10n) {
    if (hasEnded || status == AdCampaignStatus.ended) {
      return l10n.adsStatusEnded;
    }
    return switch (status) {
      AdCampaignStatus.active =>
        isLive ? l10n.adsStatusLive : l10n.adsStatusScheduled,
      AdCampaignStatus.paused => l10n.adsStatusPaused,
      AdCampaignStatus.unpaid => l10n.adsStatusUnpaid,
      AdCampaignStatus.pending => l10n.adsStatusScheduled,
      AdCampaignStatus.ended => l10n.adsStatusEnded,
    };
  }

  DsTone get statusTone {
    if (hasEnded) return DsTone.neutral;
    return switch (status) {
      AdCampaignStatus.active => isLive ? DsTone.positive : DsTone.info,
      AdCampaignStatus.paused => DsTone.caution,
      AdCampaignStatus.unpaid => DsTone.critical,
      _ => DsTone.neutral,
    };
  }
}

/// What to tell her when the server said no.
String adFailureMessage(AppLocalizations l10n, Failure failure) =>
    switch (adFailureKind(failure)) {
      AdFailureKind.insufficientBalance => l10n.adsErrorBalance,
      AdFailureKind.campaignLimit => l10n.adsErrorLimit,
      AdFailureKind.feedPostRequired => l10n.adsErrorFeedPost,
      AdFailureKind.planLocked => l10n.adsErrorLocked,
      AdFailureKind.storeNotVerified => l10n.adsErrorNotVerified,
      AdFailureKind.paymentMethodUnavailable => l10n.adsErrorMethodUnavailable,
      AdFailureKind.purchaseInProgress => l10n.adsErrorPurchaseInProgress,
      AdFailureKind.purchaseClosed => l10n.adsErrorPurchaseClosed,
      AdFailureKind.referenceRequired => l10n.adsErrorReferenceRequired,
      AdFailureKind.other => failure.displayMessage,
    };

/// A whole number of Syrian pounds, the way the seller console prints money.
String formatSyp(int amount) => amount.toDouble().sypFull;
