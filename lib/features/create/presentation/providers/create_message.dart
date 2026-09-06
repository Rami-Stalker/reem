import 'package:reem/l10n/app_localizations.dart';

/// An outcome of the seller composer, named rather than spelled out.
///
/// Mirrors `AuthMessage`: a notifier has no `BuildContext`, so an English
/// sentence parked in its state is permanently English.
enum CreateMessage {
  postCreated,
  storyCreated;

  String resolve(AppLocalizations l10n) => switch (this) {
        CreateMessage.postCreated => l10n.createPostSuccess,
        CreateMessage.storyCreated => l10n.createStorySuccess,
      };
}
