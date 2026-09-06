import 'package:reem/l10n/app_localizations.dart';

/// An outcome of editing a profile, named rather than spelled out.
///
/// Mirrors `AuthMessage`: a notifier has no `BuildContext`, so an English
/// sentence parked in its state is permanently English.
enum EditProfileMessage {
  updated;

  String resolve(AppLocalizations l10n) => switch (this) {
    EditProfileMessage.updated => l10n.profileUpdated,
  };
}
