import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/social/data/models/content_model.dart';
import 'package:reem/features/social/domain/entities/content.dart';

/// What a moderator is looking at.
///
/// `reported` first because it is the only one somebody is waiting on.
enum AdminContentFilter {
  reported,
  underReview,
  all,
  customers,
  sellers,
  removed;

  /// The query the server understands. The admin list speaks the `/admin`
  /// envelope (`items` / `has_more`), not the customer one.
  Map<String, dynamic> get query => switch (this) {
    AdminContentFilter.reported => {'reported': true},
    AdminContentFilter.underReview => {'status': 'IN_REVIEW'},
    AdminContentFilter.removed => {'status': 'REMOVED'},
    AdminContentFilter.customers => {'author_kind': 'CUSTOMER'},
    AdminContentFilter.sellers => {'author_kind': 'SELLER'},
    AdminContentFilter.all => const {},
  };
}

class AdminContentState {
  const AdminContentState({
    this.isLoading = false,
    this.items = const [],
    this.filter = AdminContentFilter.reported,
    this.total = 0,
    this.pending = 0,
    this.error,
  });

  final bool isLoading;
  final List<Content> items;
  final AdminContentFilter filter;
  final int total;

  /// How many pieces have an unanswered report against them.
  final int pending;
  final String? error;

  AdminContentState copyWith({
    bool? isLoading,
    List<Content>? items,
    AdminContentFilter? filter,
    int? total,
    int? pending,
    String? error,
    bool clearError = false,
  }) {
    return AdminContentState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      filter: filter ?? this.filter,
      total: total ?? this.total,
      pending: pending ?? this.pending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// The moderation queue, and the two decisions that can be made from it.
///
/// This talks to Dio directly rather than through `SocialRepository`: the
/// admin routes speak a different envelope (`items` / `has_more`) from every
/// customer read, and threading that difference through the shared repository
/// would mean every social method growing a flag for a caller it never has.
class AdminContentNotifier extends StateNotifier<AdminContentState> {
  AdminContentNotifier(this._ref) : super(const AdminContentState());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _ref
          .read(dioProvider)
          .get<Map<String, dynamic>>(
            ApiEndpoints.adminContent,
            queryParameters: {'limit': 30, ...state.filter.query},
          );
      final body = response.data ?? const {};
      state = state.copyWith(
        isLoading: false,
        items: (body['items'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ContentModel.fromJson)
            .toList(growable: false),
        total: (body['total'] as num?)?.toInt() ?? 0,
        pending: (body['pending'] as num?)?.toInt() ?? 0,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: '$error');
    }
  }

  void setFilter(AdminContentFilter filter) {
    if (filter == state.filter) return;
    state = state.copyWith(filter: filter, items: const []);
    load();
  }

  /// Take it down, with the reason she will be told.
  ///
  /// Returns nothing: the state already carries the error, and a second
  /// channel for the same failure is a second thing to keep in step.
  Future<void> remove(String contentId, String reason) async {
    try {
      await _ref
          .read(dioProvider)
          .post<dynamic>(
            ApiEndpoints.adminContentRemove(contentId),
            data: {'reason': reason},
          );
      // Reloaded rather than patched: a takedown changes the counts in the
      // header and may move the row out of the current filter entirely.
      await load();
    } catch (error) {
      state = state.copyWith(error: '$error');
    }
  }

  Future<void> reinstate(String contentId, String reason) async {
    try {
      await _ref
          .read(dioProvider)
          .post<dynamic>(
            ApiEndpoints.adminContentReinstate(contentId),
            data: {'reason': reason},
          );
      await load();
    } catch (error) {
      state = state.copyWith(error: '$error');
    }
  }
}

final adminContentProvider =
    StateNotifierProvider.autoDispose<AdminContentNotifier, AdminContentState>(
      (ref) => AdminContentNotifier(ref)..load(),
    );
