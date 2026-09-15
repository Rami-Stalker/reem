import 'package:reem/core/presentation/providers/paginated_notifier.dart';
import 'package:reem/core/presentation/state/paginated_state.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/domain/repositories/social_repository.dart';

typedef ContentFeedState = PaginatedState<Content>;

/// A feed of content, with interactions that answer immediately.
///
/// The optimistic update is not a flourish. On a Syrian mobile connection the
/// round trip for a like is often over a second, and a heart that fills a
/// second after the tap reads as a broken button — so she gets the state she
/// asked for at once, and it is corrected from the server's answer when it
/// arrives. A failure puts it back exactly as it was and says so, rather than
/// leaving her looking at a like that did not happen.
class ContentFeedNotifier extends PaginatedNotifier<Content> {
  ContentFeedNotifier(this._repository, PageFetcher<Content> fetch, {super.pageSize})
    : super(fetch);

  final SocialRepository _repository;

  /// Replace one card in place, leaving the rest of the list identical so
  /// Flutter rebuilds one row rather than the page.
  void _patch(String contentId, Content Function(Content) update) {
    var changed = false;
    final items = [
      for (final item in state.items)
        if (item.id == contentId) ...[
          () {
            changed = true;
            return update(item);
          }(),
        ] else
          item,
    ];
    if (changed) state = state.copyWith(items: items);
  }

  Content? _find(String contentId) {
    for (final item in state.items) {
      if (item.id == contentId) return item;
    }
    return null;
  }

  Future<void> toggleLike(String contentId) async {
    final before = _find(contentId);
    if (before == null) return;

    final liked = !before.viewer.isLiked;
    _patch(
      contentId,
      (item) => item.copyWith(
        viewer: item.viewer.copyWith(isLiked: liked),
        counts: item.counts.copyWith(
          likes: (item.counts.likes + (liked ? 1 : -1)).clamp(0, 1 << 30),
        ),
      ),
    );

    final result = await _repository.react(contentId);
    switch (result) {
      case Success(:final data):
        // The server's numbers win: she may have liked it on another device,
        // and a local guess that disagrees is a number she will see change for
        // no reason on the next refresh.
        _patch(contentId, (item) => item.copyWith(viewer: data));
      case Error():
        _patch(
          contentId,
          (item) => item.copyWith(viewer: before.viewer, counts: before.counts),
        );
    }
  }

  Future<void> toggleSave(String contentId) async {
    final before = _find(contentId);
    if (before == null) return;

    final saved = !before.viewer.isSaved;
    _patch(
      contentId,
      (item) => item.copyWith(
        viewer: item.viewer.copyWith(isSaved: saved),
        counts: item.counts.copyWith(
          saves: (item.counts.saves + (saved ? 1 : -1)).clamp(0, 1 << 30),
        ),
      ),
    );

    final result = await _repository.toggleSave(contentId);
    switch (result) {
      case Success(:final data):
        _patch(contentId, (item) => item.copyWith(viewer: data));
      case Error():
        _patch(
          contentId,
          (item) => item.copyWith(viewer: before.viewer, counts: before.counts),
        );
    }
  }

  /// «أضيفي إلى صفحتي» — and taking it back off.
  Future<bool> toggleReshare(String contentId, {String? note}) async {
    final before = _find(contentId);
    if (before == null) return false;

    final adding = !before.viewer.isReshared;
    _patch(
      contentId,
      (item) => item.copyWith(viewer: item.viewer.copyWith(isReshared: adding)),
    );

    final result = adding
        ? await _repository.reshare(contentId, note: note)
        : await _repository.unreshare(contentId);

    switch (result) {
      case Success(:final data):
        _patch(
          contentId,
          (item) => item.copyWith(
            viewer: item.viewer.copyWith(isReshared: data),
            counts: item.counts.copyWith(
              shares: (item.counts.shares + (data ? 1 : -1)).clamp(0, 1 << 30),
            ),
          ),
        );
        return data;
      case Error():
        _patch(contentId, (item) => item.copyWith(viewer: before.viewer));
        return before.viewer.isReshared;
    }
  }

  /// After she shares to WhatsApp. Counted, but not a reshare — nothing was
  /// added to anybody's page.
  Future<void> recordShare(String contentId) async {
    final result = await _repository.recordShare(contentId);
    if (result case Success(:final data)) {
      _patch(contentId, (item) => item.copyWith(viewer: data));
    }
  }

  /// The comment sheet reports what it committed, so the count under the card
  /// stays right without refetching the feed.
  void adjustComments(String contentId, int delta) {
    if (delta == 0) return;
    _patch(
      contentId,
      (item) => item.copyWith(
        counts: item.counts.copyWith(
          comments: (item.counts.comments + delta).clamp(0, 1 << 30),
        ),
      ),
    );
  }

  /// Takes out every card matching [test] — one post she is not interested
  /// in, or every post of an account she hid — and says where each stood, so
  /// «تراجع» can put them back.
  List<(int, Content)> removeWhere(bool Function(Content item) test) {
    final removed = <(int, Content)>[];
    final kept = <Content>[];
    for (var i = 0; i < state.items.length; i++) {
      final item = state.items[i];
      if (test(item)) {
        removed.add((i, item));
      } else {
        kept.add(item);
      }
    }
    if (removed.isNotEmpty) state = state.copyWith(items: kept);
    return removed;
  }

  void restore(List<(int, Content)> removed) {
    if (removed.isEmpty) return;
    final items = [...state.items];
    for (final (index, item) in removed) {
      if (items.any((existing) => existing.id == item.id)) continue;
      items.insert(index.clamp(0, items.length), item);
    }
    state = state.copyWith(items: items);
  }

  /// Content that has just been taken down, or that she deleted, leaves the
  /// list rather than sitting there un-tappable.
  void drop(String contentId) {
    state = state.copyWith(
      items: [
        for (final item in state.items)
          if (item.id != contentId) item,
      ],
    );
  }
}
