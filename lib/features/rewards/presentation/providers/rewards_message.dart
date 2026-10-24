import 'package:ohara/l10n/app_localizations.dart';

/// An outcome of the rewards hub, named rather than spelled out.
///
/// Same reasoning as `AuthMessage`, which this deliberately mirrors: a
/// notifier has no `BuildContext`, so an English sentence stored in its state
/// is permanently English. The state carries the *meaning*; the screen renders
/// it in the current locale.
enum RewardsMessage {
  offlineHint,
  offlineRetry,
  codeInvalid,
  codeApplied,
  notEnoughPoints,
  redeemed,
  noCashback,
  cashbackConverted;

  String resolve(AppLocalizations l10n) => switch (this) {
        RewardsMessage.offlineHint => l10n.rewardsOfflineHint,
        RewardsMessage.offlineRetry => l10n.rewardsOfflineRetry,
        RewardsMessage.codeInvalid => l10n.rewardsCodeInvalid,
        RewardsMessage.codeApplied => l10n.rewardsCodeApplied,
        RewardsMessage.notEnoughPoints => l10n.rewardsNotEnoughPoints,
        RewardsMessage.redeemed => l10n.rewardsRedeemed,
        RewardsMessage.noCashback => l10n.rewardsNoCashback,
        RewardsMessage.cashbackConverted => l10n.rewardsCashbackConverted,
      };
}
