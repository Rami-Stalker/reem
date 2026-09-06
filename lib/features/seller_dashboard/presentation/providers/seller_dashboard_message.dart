import 'package:reem/l10n/app_localizations.dart';

/// A failure of the seller dashboard, named rather than spelled out.
///
/// Mirrors `AuthMessage`: a notifier has no `BuildContext`, so an English
/// sentence parked in its state is permanently English.
enum SellerDashboardMessage {
  loadFailed;

  String resolve(AppLocalizations l10n) => switch (this) {
        SellerDashboardMessage.loadFailed => l10n.sellerDashboardLoadFailed,
      };
}
