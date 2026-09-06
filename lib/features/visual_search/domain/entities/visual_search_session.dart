import 'package:equatable/equatable.dart';
import 'package:reem/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:reem/features/visual_search/domain/entities/visual_match.dart';
import 'package:reem/features/visual_search/domain/entities/visual_understanding.dart';

/// Where the photograph came from. Recorded for analytics; the pipeline treats
/// every source identically.
enum VisualSearchSource {
  camera,
  gallery,
  screenshot,
  shared,
  catalog;

  String get wire => switch (this) {
    VisualSearchSource.camera => 'CAMERA',
    VisualSearchSource.gallery => 'GALLERY',
    VisualSearchSource.screenshot => 'SCREENSHOT',
    VisualSearchSource.shared => 'SHARED',
    VisualSearchSource.catalog => 'CATALOG',
  };
}

/// How a region inside the photograph was found.
///
/// Surfaced to the UI because the three are not equally trustworthy. A
/// [VisualRegionDetector.layout] band is a geometric guess about a full-length
/// photograph — the top is above the skirt is above the shoes — and the screen
/// presents it as "شفت كمان" rather than asserting it. A
/// [VisualRegionDetector.vision] region is an actual detection.
enum VisualRegionDetector {
  whole,
  layout,
  vision;

  static VisualRegionDetector fromWire(String? value) => switch (value) {
    'LAYOUT' => VisualRegionDetector.layout,
    'VISION' => VisualRegionDetector.vision,
    _ => VisualRegionDetector.whole,
  };

  /// True when the region is a guess the screen should hedge about.
  bool get isInferred => this == VisualRegionDetector.layout;
}

/// A rectangle over the uploaded photograph, in 0–1 coordinates.
class VisualBox extends Equatable {
  const VisualBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  static const full = VisualBox(x: 0, y: 0, w: 1, h: 1);

  final double x;
  final double y;
  final double w;
  final double h;

  bool get isWholeFrame => x <= 0.001 && y <= 0.001 && w >= 0.999 && h >= 0.999;

  @override
  List<Object?> get props => [x, y, w, h];
}

/// One item found in the photograph, and the products that match it.
class VisualRegion extends Equatable {
  const VisualRegion({
    required this.id,
    required this.detector,
    required this.label,
    required this.box,
    required this.confidence,
    required this.matches,
    this.slot,
    this.slotLabel,
  });

  final String id;
  final VisualRegionDetector detector;
  final String label;
  final VisualBox box;

  /// 0–1. Shown for an inferred region so a guess reads as a guess.
  final double confidence;

  final String? slot;
  final String? slotLabel;
  final List<VisualMatch> matches;

  VisualRegion withMatches(List<VisualMatch> next) => VisualRegion(
    id: id,
    detector: detector,
    label: label,
    box: box,
    confidence: confidence,
    matches: next,
    slot: slot,
    slotLabel: slotLabel,
  );

  @override
  List<Object?> get props => [id, detector, label, box, confidence, matches];
}

/// One typed sentence she added after the photograph.
class VisualRefinement extends Equatable {
  const VisualRefinement({required this.text, required this.at});

  final String text;
  final DateTime? at;

  @override
  List<Object?> get props => [text, at];
}

/// A whole search-by-image, and everything that followed from it.
class VisualSearchSession extends Equatable {
  const VisualSearchSession({
    required this.id,
    required this.status,
    required this.source,
    required this.understanding,
    required this.brief,
    required this.regions,
    required this.refinements,
    required this.createdAt,
    this.queryImageUrl,
    this.imageExpiresAt,
    this.engine,
    this.notice,
  });

  final String id;
  final String status;
  final String source;

  /// The private URL of her uploaded photograph — fetchable only with her own
  /// session, and **null once the retention clock has run**. The search still
  /// works then: the descriptor is not the photograph. The screen falls back to
  /// showing the chips rather than a broken image.
  final String? queryImageUrl;
  final DateTime? imageExpiresAt;

  final VisualUnderstanding understanding;

  /// The merged brief — what the picture said plus every sentence since.
  /// Deliberately the *stylist's* [StyleBrief], because it is the same thing.
  final StyleBrief brief;

  final List<VisualRegion> regions;
  final List<VisualRefinement> refinements;

  /// Which engine read the image: the deterministic descriptor, or a model.
  final String? engine;

  /// Set when there is nothing to show, saying which kind of nothing it is.
  final String? notice;

  final DateTime createdAt;

  /// The matches for the frame as a whole, or of the first region — what the
  /// simple single-garment case renders.
  List<VisualMatch> get primaryMatches =>
      regions.isEmpty ? const [] : regions.first.matches;

  /// True when the photograph was read as a full look worth splitting up.
  bool get isOutfit =>
      regions.length > 1 ||
      (regions.isNotEmpty && regions.first.detector != VisualRegionDetector.whole);

  int get totalMatches =>
      regions.fold(0, (sum, region) => sum + region.matches.length);

  VisualSearchSession copyWithRegions(List<VisualRegion> next) =>
      VisualSearchSession(
        id: id,
        status: status,
        source: source,
        understanding: understanding,
        brief: brief,
        regions: next,
        refinements: refinements,
        createdAt: createdAt,
        queryImageUrl: queryImageUrl,
        imageExpiresAt: imageExpiresAt,
        engine: engine,
        notice: notice,
      );

  @override
  List<Object?> get props => [id, status, regions, refinements, notice];
}

/// What the empty screen needs before she has picked anything.
class VisualSearchBootstrap extends Equatable {
  const VisualSearchBootstrap({
    required this.ready,
    required this.engine,
    required this.indexedProducts,
    required this.activeProducts,
    required this.maxImageBytes,
    required this.uploadMaxEdge,
    required this.imageRetentionHours,
    required this.privacyNote,
    required this.tryOn,
    required this.recent,
    required this.prompts,
  });

  static const empty = VisualSearchBootstrap(
    ready: false,
    engine: '',
    indexedProducts: 0,
    activeProducts: 0,
    maxImageBytes: 8 * 1024 * 1024,
    uploadMaxEdge: 1024,
    imageRetentionHours: 24,
    privacyNote: '',
    tryOn: TryOnCapability.unavailable,
    recent: [],
    prompts: [],
  );

  /// False until the server has described some product photographs. The screen
  /// says so rather than showing an empty result page.
  final bool ready;
  final String engine;
  final int indexedProducts;
  final int activeProducts;

  /// Server-declared, so a policy change does not need an app release.
  final int maxImageBytes;

  /// What the client should resample to before uploading.
  final int uploadMaxEdge;

  final int imageRetentionHours;
  final String privacyNote;

  final TryOnCapability tryOn;
  final List<VisualSearchSession> recent;
  final List<String> prompts;

  @override
  List<Object?> get props => [ready, indexedProducts, tryOn, recent];
}

/// Whether virtual try-on can actually do anything.
///
/// There is no mock behind it: with no provider configured the server answers
/// 503 and the screen renders [message] instead of a button that leads nowhere.
class TryOnCapability extends Equatable {
  const TryOnCapability({
    required this.available,
    required this.provider,
    required this.retentionHours,
    this.message,
  });

  static const unavailable = TryOnCapability(
    available: false,
    provider: 'none',
    retentionHours: 2,
  );

  final bool available;
  final String provider;
  final int retentionHours;
  final String? message;

  @override
  List<Object?> get props => [available, provider, retentionHours, message];
}
