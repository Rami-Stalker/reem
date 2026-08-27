import 'package:reem/l10n/app_localizations.dart';

/// A success outcome from the auth flow, named rather than spelled out.
///
/// A notifier has no `BuildContext`, so it cannot localise. Putting an English
/// sentence in the state would have made every auth toast permanently English —
/// the state carries the *meaning* and the screen renders it in the current
/// locale.
enum AuthMessage {
  codeSent,
  verificationComplete,
  phoneVerified,
  passwordChanged,
  passwordUpdatedSignInAgain,
  accountUpdated,
  deviceUpdated,
  verificationSubmitted;

  String resolve(AppLocalizations l10n) => switch (this) {
        AuthMessage.codeSent => l10n.codeSent,
        AuthMessage.verificationComplete => l10n.verificationComplete,
        AuthMessage.phoneVerified => l10n.phoneVerified,
        AuthMessage.passwordChanged => l10n.passwordChanged,
        AuthMessage.passwordUpdatedSignInAgain =>
          l10n.passwordUpdatedSignInAgain,
        AuthMessage.accountUpdated => l10n.accountUpdated,
        AuthMessage.deviceUpdated => l10n.deviceUpdated,
        AuthMessage.verificationSubmitted => l10n.verificationSubmitted,
      };
}
