import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/domain/pagination/paginated_data.dart';
import 'package:reem/core/errors/failure_exception.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/presentation/providers/paginated_notifier.dart';
import 'package:reem/core/presentation/state/paginated_state.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/social/data/datasources/impl/social_remote_datasource_impl.dart';
import 'package:reem/features/social/data/datasources/social_remote_datasource.dart';
import 'package:reem/features/social/data/repositories/social_repository_impl.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/domain/entities/content_analytics.dart';
import 'package:reem/features/social/domain/entities/content_audience.dart';
import 'package:reem/features/social/domain/repositories/social_repository.dart';
import 'package:reem/features/social/presentation/providers/composer_notifier.dart';
import 'package:reem/features/social/presentation/providers/content_comments_notifier.dart';
import 'package:reem/features/social/presentation/providers/content_feed_notifier.dart';

// ── Wiring ──────────────────────────────────────────────────────────────────

final socialRemoteDataSourceProvider = Provider<SocialRemoteDataSource>(
  (ref) => SocialRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepositoryImpl(ref.watch(socialRemoteDataSourceProvider)),
);

/// Whether the signed-in account publishes as a boutique.
///
/// The composer asks the registry what this role may publish, so this decides
/// which half of the registry it sees — not what the UI looks like.
final publishesAsSellerProvider = Provider<bool>((ref) {
  final role = ref.watch(
    authNotifierProvider.select((state) => state.user?.role),
  );
  return role == UserRole.seller || role == UserRole.admin;
});

// ── Feeds ───────────────────────────────────────────────────────────────────

/// Which feed a screen is showing.
enum SocialFeedKind { discover, following, reels, saved }

/// The three feeds and the saved shelf, one notifier family.
///
/// `autoDispose` deliberately: a feed she has left should not keep a page of
/// decoded images alive, and coming back to it should show what is there now
/// rather than what was there an hour ago.
final contentFeedProvider = StateNotifierProvider.autoDispose
    .family<ContentFeedNotifier, PaginatedState<Content>, SocialFeedKind>((
      ref,
      kind,
    ) {
      final repository = ref.watch(socialRepositoryProvider);
      Future<Result<PaginatedData<Content>>> fetch(PageRequest request) {
        return switch (kind) {
          SocialFeedKind.discover => repository.feed(
            cursor: request.cursor,
            limit: request.limit,
          ),
          SocialFeedKind.following => repository.following(
            cursor: request.cursor,
            limit: request.limit,
          ),
          SocialFeedKind.reels => repository.reels(
            cursor: request.cursor,
            limit: request.limit,
          ),
          SocialFeedKind.saved => repository.saved(
            cursor: request.cursor,
            limit: request.limit,
          ),
        };
      }

      return ContentFeedNotifier(
        repository,
        fetch,
        // A reel is a full screen of video; ten is already more than she will
        // watch before the next page loads.
        pageSize: kind == SocialFeedKind.reels ? 10 : 20,
      )..load();
    });

/// «نساء يرتدينها» on a product page.
final productContentProvider = StateNotifierProvider.autoDispose
    .family<ContentFeedNotifier, PaginatedState<Content>, String>((
      ref,
      productId,
    ) {
      final repository = ref.watch(socialRepositoryProvider);
      return ContentFeedNotifier(
        repository,
        (request) => repository.byProduct(
          productId,
          cursor: request.cursor,
          limit: request.limit,
        ),
        pageSize: 12,
      )..load();
    });

/// Somebody's page: what she published, and what she added.
final userTimelineProvider = StateNotifierProvider.autoDispose
    .family<PaginatedNotifier<TimelineEntry>, PaginatedState<TimelineEntry>, String>((
      ref,
      userId,
    ) {
      final repository = ref.watch(socialRepositoryProvider);
      return PaginatedNotifier<TimelineEntry>(
        (request) => repository.userTimeline(
          userId,
          cursor: request.cursor,
          limit: request.limit,
        ),
      )..load();
    });

/// One woman's reels, for the reels tab on her page.
final userReelsProvider = StateNotifierProvider.autoDispose
    .family<ContentFeedNotifier, PaginatedState<Content>, String>((
      ref,
      userId,
    ) {
      final repository = ref.watch(socialRepositoryProvider);
      return ContentFeedNotifier(
        repository,
        (request) => repository.byAuthor(
          userId,
          contentType: 'reel',
          cursor: request.cursor,
          limit: request.limit,
        ),
        pageSize: 12,
      )..load();
    });

/// One woman's live stories — the ring on her avatar and the stories tab.
final userStoriesProvider = FutureProvider.autoDispose
    .family<List<StoryGroup>, String>((ref, userId) async {
      final result = await ref.watch(socialRepositoryProvider).storiesOf(userId);
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });

/// Her own content, in every state — including what is under review and what
/// was taken down. The only place either is visible to her.
final myContentProvider = StateNotifierProvider.autoDispose<
  PaginatedNotifier<Content>,
  PaginatedState<Content>
>((ref) {
  final repository = ref.watch(socialRepositoryProvider);
  return PaginatedNotifier<Content>(
    (request) => repository.mine(page: request.page, limit: request.limit),
  )..load();
});

/// The live story tray.
final storiesTrayProvider = FutureProvider.autoDispose<List<StoryGroup>>((
  ref,
) async {
  final result = await ref.watch(socialRepositoryProvider).storiesTray();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw FailureException(failure),
  };
});

// ── Composer ────────────────────────────────────────────────────────────────

final composerProvider =
    StateNotifierProvider.autoDispose<ComposerNotifier, ComposerState>((ref) {
      return ComposerNotifier(
        ref.watch(socialRepositoryProvider),
        isSeller: ref.watch(publishesAsSellerProvider),
      )..load();
    });

// ── Comments ────────────────────────────────────────────────────────────────

final contentCommentsProvider = StateNotifierProvider.autoDispose
    .family<ContentCommentsNotifier, ContentCommentsState, String>((
      ref,
      contentId,
    ) {
      return ContentCommentsNotifier(
        ref.watch(socialRepositoryProvider),
        contentId,
      )..load();
    });

// ── A boutique's numbers ────────────────────────────────────────────────────

final contentFormatPerformanceProvider =
    FutureProvider.autoDispose<List<ContentFormatPerformance>>((ref) async {
      final result = await ref
          .watch(socialRepositoryProvider)
          .formatPerformance();
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });

final reshareSummaryProvider = FutureProvider.autoDispose<ReshareSummary>((
  ref,
) async {
  final result = await ref.watch(socialRepositoryProvider).reshareSummary();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw FailureException(failure),
  };
});

final promotersProvider =
    FutureProvider.autoDispose<PaginatedData<ContentPromoter>>((ref) async {
      final result = await ref.watch(socialRepositoryProvider).promoters();
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });

final contentAnalyticsProvider = FutureProvider.autoDispose
    .family<ContentAnalytics, String>((ref, contentId) async {
      final result = await ref
          .watch(socialRepositoryProvider)
          .analyticsFor(contentId);
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });

/// One piece, on its own — what a shared link opens.
///
/// `autoDispose` like every other read here: a post she arrived at from a
/// message and then left should not be held, and coming back to it should show
/// its current counts rather than the ones it had when the link was sent.
final contentByIdProvider = FutureProvider.autoDispose
    .family<Content, String>((ref, contentId) async {
      final result = await ref.watch(socialRepositoryProvider).byId(contentId);
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });

/// «شوهدت من قبل» — who watched one of her own pieces. Owner only.
final contentAudienceProvider = FutureProvider.autoDispose
    .family<ContentAudience, String>((ref, contentId) async {
      final result = await ref
          .watch(socialRepositoryProvider)
          .audience(contentId);
      return switch (result) {
        Success(:final data) => data,
        Error(:final failure) => throw FailureException(failure),
      };
    });
