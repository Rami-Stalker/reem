import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/errors/error_mapper.dart';
import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/social/data/models/content_model.dart';
import 'package:ohara/features/social/domain/entities/content.dart';

/// What a moderator is looking at.
///
/// `reported` first because it is the only one somebody is waiting on. Posts,
/// reels and stories go live without review, so the queue is reactive: what
/// was reported or flagged by the word screen, and everything else by format.
enum AdminContentFilter {
  reported,
  all,
  posts,
  reels,
  stories,
  customers,
  sellers,
  removed;

  /// The query the server understands. The admin list speaks the `/admin`
  /// envelope (`items` / `has_more`), not the customer one.
  Map<String, dynamic> get query => switch (this) {
    AdminContentFilter.reported => {'reported': true},
    AdminContentFilter.posts => {'content_type': 'product_post'},
    AdminContentFilter.reels => {'content_type': 'reel'},
    AdminContentFilter.stories => {'content_type': 'story'},
    AdminContentFilter.removed => {'status': 'REMOVED'},
    AdminContentFilter.customers => {'author_kind': 'CUSTOMER'},
    AdminContentFilter.sellers => {'author_kind': 'SELLER'},
    AdminContentFilter.all => const {},
  };
}

/// One row of the queue: the piece, and what it is in the queue for.
///
/// Kept beside [Content] rather than inside it, because report counts and
/// reasons are moderator-only and must never become part of the public shape.
class AdminContentItem {
  const AdminContentItem({
    required this.content,
    this.reportsCount = 0,
    this.reportReasons = const [],
    this.autoFlagged = false,
    this.removalReason,
  });

  factory AdminContentItem.fromJson(Map<String, dynamic> json) {
    final content = ContentModel.fromJson(json);
    return AdminContentItem(
      content: content,
      reportsCount: (json['reports_count'] as num?)?.toInt() ?? 0,
      reportReasons: (json['open_report_reasons'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      autoFlagged: json['auto_flagged'] == true,
      removalReason: content.removalReason,
    );
  }

  final Content content;
  final int reportsCount;
  final List<String> reportReasons;
  final bool autoFlagged;
  final String? removalReason;

  bool get isRemoved => content.isRemoved;
  bool get hasReports => reportsCount > 0 && !isRemoved;

  AdminContentItem afterRemoval(String reason) => AdminContentItem(
    content: content.copyWith(
      status: ContentStatus.removed,
      moderationState: ContentModerationState.removed,
    ),
    reportsCount: reportsCount,
    removalReason: reason,
  );

  AdminContentItem afterReinstate() => AdminContentItem(
    content: content.copyWith(
      status: content.publishedAt != null
          ? ContentStatus.published
          : ContentStatus.draft,
      moderationState: ContentModerationState.active,
    ),
  );

  AdminContentItem afterDismiss() => AdminContentItem(content: content);
}

/// Which decision a moderator made, so the screen can say it back to her.
enum AdminContentDecision { removed, reinstated, kept }

class AdminContentState {
  const AdminContentState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.items = const [],
    this.filter = AdminContentFilter.reported,
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
    this.pending = 0,
    this.busyIds = const {},
    this.error,
  });

  final bool isLoading;
  final bool isLoadingMore;
  final List<AdminContentItem> items;
  final AdminContentFilter filter;
  final int page;
  final bool hasMore;
  final int total;

  /// How many live pieces have an unanswered report against them.
  final int pending;

  /// Rows with a decision in flight. Their buttons are disabled so a second
  /// tap cannot send a second takedown.
  final Set<String> busyIds;

  /// A failure to *load*. A failed decision is returned to the caller and
  /// shown as a message instead, so it is never silently swallowed by a list
  /// that already has rows on screen.
  final String? error;

  AdminContentState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    List<AdminContentItem>? items,
    AdminContentFilter? filter,
    int? page,
    bool? hasMore,
    int? total,
    int? pending,
    Set<String>? busyIds,
    String? error,
    bool clearError = false,
  }) {
    return AdminContentState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      items: items ?? this.items,
      filter: filter ?? this.filter,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      pending: pending ?? this.pending,
      busyIds: busyIds ?? this.busyIds,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// The moderation queue, and the three decisions that can be made from it:
/// remove, restore, and keep (close the reports, leave it up).
///
/// This talks to Dio directly rather than through `SocialRepository`: the
/// admin routes speak a different envelope (`items` / `has_more`) from every
/// customer read, and threading that difference through the shared repository
/// would mean every social method growing a flag for a caller it never has.
class AdminContentNotifier extends StateNotifier<AdminContentState> {
  AdminContentNotifier(this._ref) : super(const AdminContentState());

  final Ref _ref;
  static const _pageSize = 30;

  Future<void> load() => _fetch(page: 1);

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await _fetch(page: state.page + 1);
  }

  Future<void> _fetch({required int page}) async {
    final filter = state.filter;
    state = page == 1
        ? state.copyWith(isLoading: true, clearError: true)
        : state.copyWith(isLoadingMore: true);
    try {
      final response = await _ref
          .read(dioProvider)
          .get<Map<String, dynamic>>(
            ApiEndpoints.adminContent,
            queryParameters: {
              'page': page,
              'limit': _pageSize,
              ...filter.query,
            },
          );
      // The filter changed while this page was in flight.
      if (!mounted || filter != state.filter) return;
      final body = response.data ?? const {};
      final fetched = (body['items'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminContentItem.fromJson)
          .toList(growable: false);
      // A row can shift pages while a moderator acts on earlier ones; never
      // show it twice.
      final seen = {for (final item in state.items) item.content.id};
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        page: page,
        items: page == 1
            ? fetched
            : [
                ...state.items,
                ...fetched.where((item) => !seen.contains(item.content.id)),
              ],
        hasMore: body['has_more'] == true,
        total: (body['total'] as num?)?.toInt() ?? 0,
        pending: (body['pending'] as num?)?.toInt() ?? 0,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: _message(error),
      );
    }
  }

  void setFilter(AdminContentFilter filter) {
    if (filter == state.filter) return;
    state = state.copyWith(
      filter: filter,
      items: const [],
      page: 1,
      hasMore: false,
    );
    load();
  }

  /// Take it down, with the reason she will be told. Returns `null` on
  /// success, or the message to show.
  Future<String?> remove(String contentId, String reason) => _decide(
    contentId,
    ApiEndpoints.adminContentRemove(contentId),
    {'reason': reason},
    (item) => item.afterRemoval(reason),
    leavesFilter: (filter) => filter == AdminContentFilter.reported,
  );

  Future<String?> reinstate(String contentId, String reason) => _decide(
    contentId,
    ApiEndpoints.adminContentReinstate(contentId),
    {'reason': reason},
    (item) => item.afterReinstate(),
    leavesFilter: (filter) => filter == AdminContentFilter.removed,
  );

  /// Keep it: every open report is closed and it stays up.
  Future<String?> keep(String contentId, {String? note}) => _decide(
    contentId,
    ApiEndpoints.adminContentDismissReports(contentId),
    {if (note != null && note.isNotEmpty) 'note': note},
    (item) => item.afterDismiss(),
    leavesFilter: (filter) => filter == AdminContentFilter.reported,
  );

  /// One decision, applied to the row in place.
  ///
  /// Patched rather than reloaded: a reload throws away the pages she has
  /// scrolled through and the place she was in them. Pull to refresh resyncs.
  Future<String?> _decide(
    String contentId,
    String path,
    Map<String, dynamic> body,
    AdminContentItem Function(AdminContentItem item) after, {
    required bool Function(AdminContentFilter filter) leavesFilter,
  }) async {
    if (state.busyIds.contains(contentId)) return null;
    state = state.copyWith(busyIds: {...state.busyIds, contentId});
    try {
      await _ref.read(dioProvider).post<dynamic>(path, data: body);
      if (!mounted) return null;
      final before = state.items
          .where((item) => item.content.id == contentId)
          .firstOrNull;
      final wasPending = before?.hasReports ?? false;
      final leaves = leavesFilter(state.filter);
      final items = [
        for (final item in state.items)
          if (item.content.id != contentId) item else if (!leaves) after(item),
      ];
      final updated = items
          .where((item) => item.content.id == contentId)
          .firstOrNull;
      final stillPending = updated?.hasReports ?? false;
      state = state.copyWith(
        items: items,
        total: leaves ? (state.total > 0 ? state.total - 1 : 0) : state.total,
        pending: wasPending && !stillPending
            ? (state.pending > 0 ? state.pending - 1 : 0)
            : state.pending,
        busyIds: {...state.busyIds}..remove(contentId),
      );
      return null;
    } catch (error) {
      if (!mounted) return null;
      state = state.copyWith(busyIds: {...state.busyIds}..remove(contentId));
      return _message(error);
    }
  }

  String _message(Object error) =>
      error is DioException ? ErrorMapper.fromDio(error).message : '$error';
}

final adminContentProvider =
    StateNotifierProvider.autoDispose<AdminContentNotifier, AdminContentState>(
      (ref) => AdminContentNotifier(ref)..load(),
    );
