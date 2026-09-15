import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/discovery/presentation/providers/collection_notifier.dart';
import 'package:reem/features/discovery/presentation/providers/collection_state.dart';
import 'package:reem/features/product_social/data/datasources/product_social_remote_datasource.dart';
import 'package:reem/features/product_social/data/repositories/product_social_repository_impl.dart';
import 'package:reem/features/product_social/domain/entities/product_engagement.dart';
import 'package:reem/features/product_social/domain/repositories/product_social_repository.dart';

// ── Wiring ──────────────────────────────────────────────────────────────────

final productSocialRepositoryProvider = Provider<ProductSocialRepository>(
  (ref) => ProductSocialRepositoryImpl(
    ProductSocialRemoteDataSource(ref.watch(dioProvider)),
  ),
);

// ── Engagement ──────────────────────────────────────────────────────────────

/// One shelf of product engagement for the whole app.
///
/// A product is on screen in many places at once — a department page, the
/// «وصل حديثاً» feed, the product page she opens from either. If each card
/// kept its own heart, liking a dress on the department page and opening it
/// would show an empty heart on the product page. So the state lives here,
/// keyed by product id, and every card reads its own entry with `select`.
///
/// Rebuilt when the signed-in account changes: whether *she* liked a piece is
/// a fact about one account, and the previous one's hearts must not linger.
final productEngagementProvider =
    StateNotifierProvider<
      ProductEngagementNotifier,
      Map<String, ProductEngagement>
    >((ref) {
      ref.watch(authNotifierProvider.select((s) => s.user?.id));
      final notifier = ProductEngagementNotifier(
        ref.watch(productSocialRepositoryProvider),
      );
      ref.onDispose(notifier.cancelPending);
      return notifier;
    });

/// What one card reads. Falls back to the tallies the product was served
/// with until the store has an entry.
final productEngagementOfProvider = Provider.family<ProductEngagement?, String>(
  (ref, productId) => ref.watch(
    productEngagementProvider.select((all) => all[productId]),
  ),
);

/// How a write settled, so the card can say the right thing.
enum EngagementOutcome { applied, needsAccount, failed }

class ProductEngagementNotifier
    extends StateNotifier<Map<String, ProductEngagement>> {
  ProductEngagementNotifier(this._repository) : super(const {});

  final ProductSocialRepository _repository;

  /// Ids waiting for the batch read, and the timer that flushes them.
  final Set<String> _pending = {};
  final Set<String> _requested = {};
  Timer? _flush;

  /// The server caps a batch at sixty — two pages of a grid.
  static const _batchSize = 60;

  /// Cards call this as they are built. Seeding is synchronous (the card
  /// paints its tallies immediately); the read of *her* state is gathered
  /// across one frame's worth of cards and asked for in a single request.
  void seed(Iterable<Product> products) {
    var next = state;
    for (final product in products) {
      if (product.id.isEmpty) continue;
      if (!next.containsKey(product.id)) {
        next = {...next, product.id: ProductEngagement.fromProduct(product)};
      }
      if (!_requested.contains(product.id)) _pending.add(product.id);
    }
    if (!identical(next, state)) state = next;
    if (_pending.isNotEmpty) {
      _flush ??= Timer(const Duration(milliseconds: 60), _load);
    }
  }

  /// Forget her state for [productIds] and read it again — after the page
  /// behind them was refreshed.
  void refresh(Iterable<String> productIds) {
    for (final id in productIds) {
      _requested.remove(id);
      _pending.add(id);
    }
    _flush ??= Timer(const Duration(milliseconds: 60), _load);
  }

  void cancelPending() {
    _flush?.cancel();
    _flush = null;
  }

  Future<void> _load() async {
    _flush = null;
    final ids = _pending.toList(growable: false);
    _pending.clear();
    _requested.addAll(ids);

    for (var start = 0; start < ids.length; start += _batchSize) {
      final chunk = ids.sublist(
        start,
        (start + _batchSize).clamp(0, ids.length),
      );
      final result = await _repository.engagement(chunk);
      if (!mounted) return;
      if (result case Success(:final data)) {
        state = {...state, ...data};
      } else {
        // Asked again the next time one of these cards is built.
        _requested.removeAll(chunk);
      }
    }
  }

  ProductEngagement _of(String productId) =>
      state[productId] ?? const ProductEngagement();

  void _put(String productId, ProductEngagement value) =>
      state = {...state, productId: value};

  Future<EngagementOutcome> setLiked(String productId, bool liked) async {
    final before = _of(productId);
    if (before.isLiked == liked) return EngagementOutcome.applied;
    _put(
      productId,
      before.copyWith(
        isLiked: liked,
        likes: (before.likes + (liked ? 1 : -1)).clamp(0, 1 << 30),
      ),
    );
    final result = await _repository.setLiked(productId, liked: liked);
    if (!mounted) return EngagementOutcome.failed;
    switch (result) {
      case Success(:final data):
        _put(productId, _of(productId).copyWith(likes: data));
        return EngagementOutcome.applied;
      case Error():
        _put(productId, before);
        return EngagementOutcome.failed;
    }
  }

  Future<EngagementOutcome> setSaved(String productId, bool saved) async {
    final before = _of(productId);
    if (before.isSaved == saved) return EngagementOutcome.applied;
    _put(productId, before.copyWith(isSaved: saved));
    final result = await _repository.setSaved(productId, saved: saved);
    if (!mounted) return EngagementOutcome.failed;
    if (result case Error()) {
      _put(productId, before);
      return EngagementOutcome.failed;
    }
    return EngagementOutcome.applied;
  }

  Future<EngagementOutcome> setPicked(
    String productId,
    bool picked, {
    String? note,
  }) async {
    final before = _of(productId);
    _put(
      productId,
      before.copyWith(
        isPicked: picked,
        picks: before.isPicked == picked
            ? before.picks
            : (before.picks + (picked ? 1 : -1)).clamp(0, 1 << 30),
      ),
    );
    final result = await _repository.setPicked(
      productId,
      picked: picked,
      note: note,
    );
    if (!mounted) return EngagementOutcome.failed;
    switch (result) {
      case Success(:final data):
        _put(productId, _of(productId).copyWith(picks: data));
        return EngagementOutcome.applied;
      case Error():
        _put(productId, before);
        return EngagementOutcome.failed;
    }
  }

  /// After she went through with the OS share sheet.
  Future<void> recordShare(String productId) async {
    final before = _of(productId);
    _put(productId, before.copyWith(shares: before.shares + 1));
    final result = await _repository.recordShare(productId);
    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        _put(productId, _of(productId).copyWith(shares: data));
      case Error():
        // The share happened; only the tally did not.
        _put(productId, _of(productId).copyWith(shares: before.shares));
    }
  }

  /// The comment sheet reports what it committed.
  void adjustComments(String productId, int delta) {
    if (delta == 0) return;
    final before = _of(productId);
    _put(
      productId,
      before.copyWith(
        comments: (before.comments + delta).clamp(0, 1 << 30),
      ),
    );
  }
}

// ── Her picks ───────────────────────────────────────────────────────────────

/// The pieces a woman added to her page, a page at a time.
///
/// A collection like any other, so her page can show it in the same three
/// shapes a department does.
final userPicksProvider = StateNotifierProvider.autoDispose
    .family<CollectionNotifier, CollectionState, String>((ref, userId) {
      final repository = ref.watch(productSocialRepositoryProvider);
      return CollectionNotifier(
        (page) => repository.picksOf(userId, page: page),
      )..load();
    });
