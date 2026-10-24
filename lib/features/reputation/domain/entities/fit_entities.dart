import 'package:equatable/equatable.dart';

/// «تقييمات من بمقاسي» — how a piece fit, and who it fit.

/// How it fit, as the woman who wore it says. Mirrors the server's
/// `ReviewFit`.
enum ReviewFit {
  runsSmall('RUNS_SMALL'),
  trueToSize('TRUE_TO_SIZE'),
  runsLarge('RUNS_LARGE');

  const ReviewFit(this.wire);

  final String wire;

  static ReviewFit? fromWire(Object? value) {
    for (final fit in ReviewFit.values) {
      if (fit.wire == value) return fit;
    }
    return null;
  }
}

/// The three counts behind a fit summary. `enough` is the server's floor:
/// below it the counts are shown as counts and no verdict is drawn.
class FitTally extends Equatable {
  const FitTally({
    this.runsSmall = 0,
    this.trueToSize = 0,
    this.runsLarge = 0,
    this.total = 0,
    this.enough = false,
    this.verdict,
  });

  final int runsSmall;
  final int trueToSize;
  final int runsLarge;
  final int total;
  final bool enough;

  /// The fit a majority gave, when there is a majority and enough voices.
  final ReviewFit? verdict;

  int countOf(ReviewFit fit) => switch (fit) {
    ReviewFit.runsSmall => runsSmall,
    ReviewFit.trueToSize => trueToSize,
    ReviewFit.runsLarge => runsLarge,
  };

  @override
  List<Object?> get props => [
    runsSmall,
    trueToSize,
    runsLarge,
    total,
    enough,
    verdict,
  ];
}

/// How a product fits, overall and for women like her.
class ProductFit extends Equatable {
  const ProductFit({
    this.overall = const FitTally(),
    this.hasProfile = false,
    this.nearMe,
    this.nearMeReviews = 0,
    this.suggestedSize,
    this.photosCount = 0,
  });

  final FitTally overall;

  /// Whether she has told Ohara her size. False means «من بمقاسي» has nothing
  /// to compare against yet, which the page answers with the profile.
  final bool hasProfile;

  /// Null unless [hasProfile].
  final FitTally? nearMe;
  final int nearMeReviews;

  /// «البنات اللي بمقاسك اشتروا L», when enough of them agree.
  final String? suggestedSize;
  final int photosCount;

  bool get isEmpty => overall.total == 0 && photosCount == 0;

  @override
  List<Object?> get props => [
    overall,
    hasProfile,
    nearMe,
    nearMeReviews,
    suggestedSize,
    photosCount,
  ];
}

/// «مقاساتي» — her height and usual size. Hers alone; never shown to anyone
/// as it is stored.
class FitProfile extends Equatable {
  const FitProfile({
    this.heightCm,
    this.usualSize,
    this.shareOnReviews = true,
    this.sizes = const [],
  });

  final int? heightCm;
  final String? usualSize;

  /// Whether her reviews carry her height band and size by default.
  final bool shareOnReviews;

  /// The sizes the server accepts, for the picker.
  final List<String> sizes;

  bool get isSet => heightCm != null || usualSize != null;

  @override
  List<Object?> get props => [heightCm, usualSize, shareOnReviews, sizes];
}

/// Which reviews a product page is showing.
enum ReviewFilter {
  all(null),
  nearMe('near_me'),
  photos('photos');

  const ReviewFilter(this.wire);

  final String? wire;
}
