import 'package:reem/l10n/app_localizations.dart';

/// An outcome of the settings flow, named rather than spelled out.
///
/// Mirrors `AuthMessage`: a notifier has no `BuildContext`, so an English
/// sentence parked in its state is permanently English.
enum SettingsMessage {
  profileUpdated;

  String resolve(AppLocalizations l10n) => switch (this) {
        SettingsMessage.profileUpdated => l10n.settingsProfileUpdated,
      };
}
