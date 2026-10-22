import 'package:reem/l10n/app_localizations.dart';

/// Content types in her language.
///
/// The types are a server registry (`post`, `reel`, `flash_offer`…) whose
/// names are written in English for operators. Shown as they came, the
/// composer offered «Post · Reel · Story» and the studio listed a row called
/// «flash_offer».
extension ContentTypeLabels on AppLocalizations {
  /// One kind, as a chip in the composer. A type added on the server before
  /// the app knows it keeps the server's name rather than disappearing.
  String contentTypeName(String key, {required String fallback}) =>
      switch (key) {
        'product_post' || 'post' => contentTypePost,
        'reel' => contentTypeReel,
        'story' => contentTypeStory,
        'flash_offer' => contentTypeFlashOffer,
        'collection' => contentTypeCollection,
        'live_stream' => contentTypeLiveStream,
        _ => fallback,
      };

  /// The same kind as a row heading in the studio, where it is counted.
  String contentTypeRow(String key) => switch (key) {
    'product_post' || 'post' => studioFormatPost,
    'reel' => reelsTitle,
    'story' => studioFormatStory,
    'flash_offer' => studioFormatFlashOffers,
    'collection' => studioFormatCollections,
    'live_stream' => studioFormatLiveStreams,
    _ => studioFormatOther,
  };
}
