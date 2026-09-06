import 'package:equatable/equatable.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/features/visual_search/domain/entities/visual_search_session.dart';

/// What the screen is doing right now.
///
/// A phase rather than a pair of booleans, because the four are genuinely
/// exclusive and the screen looks completely different in each. Uploading
/// shows a progress ring over her photograph; analysing shows the same
/// photograph with a shimmer where the chips will land; refining leaves the
/// results in place and dims them.
enum VisualSearchPhase {
  /// Nothing picked yet.
  idle,

  /// Bytes on the wire. [VisualSearchState.uploadProgress] is meaningful here.
  uploading,

  /// Uploaded; the server is describing it and searching.
  analysing,

  /// Results on screen.
  ready,

  /// A typed sentence is being folded on; the previous results stay visible.
  refining,
}

/// The visual search screen, as one value.
class VisualSearchState extends Equatable {
  const VisualSearchState({
    this.phase = VisualSearchPhase.idle,
    this.bootstrap = VisualSearchBootstrap.empty,
    this.session,
    this.selectedRegionId,
    this.uploadProgress = 0,
    this.isLoadingBootstrap = false,
    this.failure,
    this.failedRefinement,
  });

  static const initial = VisualSearchState(isLoadingBootstrap: true);

  final VisualSearchPhase phase;
  final VisualSearchBootstrap bootstrap;
  final VisualSearchSession? session;

  /// Which item of a look she is browsing. Null means the first region.
  final String? selectedRegionId;

  /// 0–1 while [phase] is [VisualSearchPhase.uploading].
  final double uploadProgress;

  final bool isLoadingBootstrap;
  final Failure? failure;

  /// The sentence that failed, kept so "retry" has something to retry rather
  /// than making her type it again.
  final String? failedRefinement;

  bool get isBusy =>
      phase == VisualSearchPhase.uploading ||
      phase == VisualSearchPhase.analysing ||
      phase == VisualSearchPhase.refining;

  bool get hasSession => session != null;

  /// True when the whole feature has nothing indexed to compare against. The
  /// screen says so plainly rather than offering an upload that cannot answer.
  bool get isIndexEmpty => !bootstrap.ready && !isLoadingBootstrap;

  VisualRegion? get selectedRegion {
    final regions = session?.regions ?? const <VisualRegion>[];
    if (regions.isEmpty) return null;
    if (selectedRegionId == null) return regions.first;
    for (final region in regions) {
      if (region.id == selectedRegionId) return region;
    }
    return regions.first;
  }

  VisualSearchState copyWith({
    VisualSearchPhase? phase,
    VisualSearchBootstrap? bootstrap,
    VisualSearchSession? session,
    String? selectedRegionId,
    double? uploadProgress,
    bool? isLoadingBootstrap,
    Failure? failure,
    String? failedRefinement,
    bool clearFailure = false,
    bool clearSession = false,
    bool clearSelectedRegion = false,
  }) => VisualSearchState(
    phase: phase ?? this.phase,
    bootstrap: bootstrap ?? this.bootstrap,
    session: clearSession ? null : (session ?? this.session),
    selectedRegionId: clearSelectedRegion
        ? null
        : (selectedRegionId ?? this.selectedRegionId),
    uploadProgress: uploadProgress ?? this.uploadProgress,
    isLoadingBootstrap: isLoadingBootstrap ?? this.isLoadingBootstrap,
    failure: clearFailure ? null : (failure ?? this.failure),
    failedRefinement: clearFailure
        ? null
        : (failedRefinement ?? this.failedRefinement),
  );

  @override
  List<Object?> get props => [
    phase,
    bootstrap,
    session,
    selectedRegionId,
    uploadProgress,
    isLoadingBootstrap,
    failure,
    failedRefinement,
  ];
}
