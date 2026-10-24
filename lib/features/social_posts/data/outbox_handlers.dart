import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/core/sync/outbox_intent.dart';

/// The engagement kinds the outbox knows how to settle.
abstract final class EngagementIntents {
  static const like = 'post.like';
  static const save = 'post.save';
}

/// Reconciles a queued like or save against the server.
///
/// It reads `/posts/:id` rather than trusting the queue, because the like
/// endpoint is a toggle: an intent that actually landed but whose response was
/// lost would, on replay, undo itself. Reading first turns a dangerous replay
/// into a safe no-op.
final class PostEngagementOutboxHandler extends BaseRemoteDataSource
    implements OutboxHandler {
  PostEngagementOutboxHandler(super.dio, {required this.kind})
    : assert(
        kind == EngagementIntents.like || kind == EngagementIntents.save,
        'this handler settles likes and saves only',
      );

  @override
  final String kind;

  bool get _isLike => kind == EngagementIntents.like;

  @override
  Future<bool?> readState(String entityId) async {
    // A missing or unreadable field means "we do not know", which the drain
    // reads as defer. Answering `false` here would silently flip her post.
    final json = await getJson(ApiEndpoints.postById(entityId));
    final value = json[_isLike ? 'is_liked' : 'is_saved'];
    return value is bool ? value : null;
  }

  @override
  Future<void> toggle(String entityId) async {
    await postJson(
      _isLike
          ? ApiEndpoints.postLike(entityId)
          : ApiEndpoints.postSave(entityId),
    );
  }
}
