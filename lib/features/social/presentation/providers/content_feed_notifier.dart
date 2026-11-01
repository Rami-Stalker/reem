import 'package:ohara/core/presentation/providers/paginated_notifier.dart';
import 'package:ohara/core/presentation/state/paginated_state.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/domain/repositories/social_repository.dart';
import 'package:ohara/features/social/presentation/content_reaction.dart';

typedef ContentFeedState = PaginatedState<Content>;

/// A feed of content, with interactions that answer immediately.
///
/// The optimistic update is not a flourish. On a Syrian mobile connection the
/// round trip for a like is often over a second, and a heart that fills a
/// second after the tap reads as a broken button — so she gets the state she
/// asked for at once, and it is corrected from the server's answer when it
/// arrives. A failure puts it back exactly as it was and says so, rather than
/// leaving her looking at a like that did not happen.
///
/// Generic over the row type because two feeds hold different rows: most hold
/// bare [Content], the following feed holds [TimelineEntry]s — a post, or a
/// post somebody added to her page. Every gesture addresses the *content*, so
/// a post and a reshare of it in the same list move together.
abstract class InteractiveFeedNotifier<T> extends PaginatedNotifier<T> {
  InteractiveFeedNotifier(this._repository, super.fetch, {super.pageSize});

  final SocialRepository _repository;

  /// The piece a row shows.
  Content contentOf(T item);

  /// The same row, showing [content] instead.
  T withContent(T item, Content content);

  /// A stable identity for the row, so «تراجع» never restores a duplicate.
  String keyOf(T item);

  @override
  String? identityOf(T item) => keyOf(item);

  /// Replace every row showing [contentId], leaving the rest of the list
  /// identical so Flutter rebuilds those rows rather than the page.
  void _patch(String contentId, Content Function(Content) update) {
    if (!mounted) return;
    var changed = false;
    final items = [
      for (final item in state.items)
        if (contentOf(item).id == contentId) ...[
          () {
            changed = true;
            return withContent(item, update(contentOf(item)));
          }(),
        ] else
          item,
    ];
    if (changed) state = state.copyWith(items: items);
  }

  Content? _find(String contentId) {
    for (final item in state.items) {
      final content = contentOf(item);
      if (content.id == contentId) return content;
    }
    return null;
  }

  static int _bounded(int value) => value.clamp(0, 1 << 30);

  Future<void> toggleLike(String contentId) async {
    final before = _find(contentId);
    if (before == null) return;

    final liked = !before.viewer.isLiked;
    _patch(
      contentId,
      (item) => item.copyWith(
        viewer: item.viewer.copyWith(isLiked: liked),
        counts: item.counts.copyWith(
          likes: _bounded(item.counts.likes + (liked ? 1 : -1)),
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

  /// A reaction from the bar or the heart; [glyph] null takes hers back.
  Future<void> react(String contentId, String? glyph) async {
    final before = _find(contentId);
    if (before == null) return;
    final change = applyReaction(before, glyph);
    _patch(contentId, (_) => change.optimistic);
    final result = await _repository.react(contentId, emoji: change.wire);
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

  /// Returns whether the piece is now saved, so the screen can offer to file
  /// it into a collection only when the save really happened.
  Future<bool> toggleSave(String contentId) async {
    final before = _find(contentId);
    if (before == null) return false;

    final saved = !before.viewer.isSaved;
    _patch(
      contentId,
      (item) => item.copyWith(
        viewer: item.viewer.copyWith(isSaved: saved),
        counts: item.counts.copyWith(
          saves: _bounded(item.counts.saves + (saved ? 1 : -1)),
        ),
      ),
    );

    final result = await _repository.toggleSave(contentId);
    switch (result) {
      case Success(:final data):
        _patch(contentId, (item) => item.copyWith(viewer: data));
        return data.isSaved;
      case Error():
        _patch(
          contentId,
          (item) => item.copyWith(viewer: before.viewer, counts: before.counts),
        );
        return before.viewer.isSaved;
    }
  }

  /// «أضيفي إلى صفحتي» — and taking it back off.
  ///
  /// Returns null on success and the failure's message otherwise, so the
  /// screen can say why nothing changed.
  Future<String?> toggleReshare(String contentId, {String? note}) async {
    final before = _find(contentId);
    if (before == null) return null;

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
              // Counted only when the state really moved, so a reshare the
              // server already had does not add a phantom share.
              shares: data == before.viewer.isReshared
                  ? item.counts.shares
                  : _bounded(item.counts.shares + (data ? 1 : -1)),
            ),
          ),
        );
        return null;
      case Error(:final failure):
        _patch(contentId, (item) => item.copyWith(viewer: before.viewer));
        return failure.message;
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
          comments: _bounded(item.counts.comments + delta),
        ),
      ),
    );
  }

  /// Takes out every row whose content matches [test] — one post she is not
  /// interested in, or every post of an account she hid — and says where each
  /// stood, so «تراجع» can put them back.
  List<(int, T)> removeWhere(bool Function(Content content) test) {
    if (!mounted) return const [];
    final removed = <(int, T)>[];
    final kept = <T>[];
    for (var i = 0; i < state.items.length; i++) {
      final item = state.items[i];
      if (test(contentOf(item))) {
        removed.add((i, item));
      } else {
        kept.add(item);
      }
    }
    if (removed.isNotEmpty) state = state.copyWith(items: kept);
    return removed;
  }

  void restore(List<(int, T)> removed) {
    if (removed.isEmpty || !mounted) return;
    final items = [...state.items];
    final present = {for (final item in items) keyOf(item)};
    for (final (index, item) in removed) {
      if (!present.add(keyOf(item))) continue;
      items.insert(index.clamp(0, items.length), item);
    }
    state = state.copyWith(items: items);
  }

  /// Her own edit, as the server now has it. An edit that sent the piece
  /// back to review keeps it in her list — it is hers, and the card says so.
  void replace(Content updated) => _patch(updated.id, (_) => updated);

  /// Content that has just been taken down, or that she deleted, leaves the
  /// list rather than sitting there un-tappable — every row showing it.
  void drop(String contentId) => removeWhere((item) => item.id == contentId);
}

/// The feeds whose rows are the content itself: discover, reels, saved, a
/// product's rail, one woman's reels.
class ContentFeedNotifier extends InteractiveFeedNotifier<Content> {
  ContentFeedNotifier(super.repository, super.fetch, {super.pageSize});

  @override
  Content contentOf(Content item) => item;

  @override
  Content withContent(Content item, Content content) => content;

  @override
  String keyOf(Content item) => item.id;
}

/// A feed of timeline entries — the following feed, where a post can arrive
/// because its author posted it or because a woman she follows added it.
class TimelineFeedNotifier extends InteractiveFeedNotifier<TimelineEntry> {
  TimelineFeedNotifier(super.repository, super.fetch, {super.pageSize});

  @override
  Content contentOf(TimelineEntry item) => item.content;

  @override
  TimelineEntry withContent(TimelineEntry item, Content content) =>
      switch (item) {
        OwnContentEntry() => OwnContentEntry(content),
        ResharedContentEntry(:final reshare) => ResharedContentEntry(
          ContentReshare(
            id: reshare.id,
            resharer: reshare.resharer,
            content: content,
            resharedAt: reshare.resharedAt,
            note: reshare.note,
          ),
        ),
      };

  @override
  String keyOf(TimelineEntry item) => item.entryId;
}
