import 'package:flutter/foundation.dart';

/// Something she asked for that has not reached the server yet.
///
/// The important design choice is in the name of one field: [desired]. This is
/// **not** a stored HTTP request waiting to be replayed. `POST /posts/:id/like`
/// is a *toggle* — replaying one that actually succeeded, but whose response
/// was lost, would un-like the post. So the queue records the end state she
/// wanted, and reconciles against the server when it can reach it.
///
/// That also makes coalescing trivial and correct: five taps on a heart while
/// she is in a lift are one intent, whose `desired` is whatever the fifth tap
/// asked for.
@immutable
class OutboxIntent {
  const OutboxIntent({
    required this.kind,
    required this.entityId,
    required this.desired,
    required this.createdAt,
    this.attempts = 0,
    this.lastAttemptAt,
  });

  /// Which handler owns this — `post.like`, `post.save`, `product.favorite`.
  final String kind;

  final String entityId;

  /// The state she asked for. `true` = liked/saved/favourited.
  final bool desired;

  final DateTime createdAt;
  final int attempts;
  final DateTime? lastAttemptAt;

  /// One intent per entity per kind. Two taps on the same heart are one row.
  String get key => '$kind:$entityId';

  OutboxIntent attempted(DateTime at) => OutboxIntent(
        kind: kind,
        entityId: entityId,
        desired: desired,
        createdAt: createdAt,
        attempts: attempts + 1,
        lastAttemptAt: at,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'entity_id': entityId,
        'desired': desired,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
        'last_attempt_at': lastAttemptAt?.toIso8601String(),
      };

  /// Null rather than throwing: a queue entry written by an older build must
  /// be dropped, never allowed to crash the drain that would clear it.
  static OutboxIntent? tryFromJson(Map<String, dynamic> json) {
    final kind = json['kind'];
    final entityId = json['entity_id'];
    final desired = json['desired'];
    final createdAt = DateTime.tryParse('${json['created_at']}');
    if (kind is! String || entityId is! String || desired is! bool) return null;
    if (createdAt == null) return null;
    return OutboxIntent(
      kind: kind,
      entityId: entityId,
      desired: desired,
      createdAt: createdAt,
      attempts: json['attempts'] is int ? json['attempts'] as int : 0,
      lastAttemptAt: DateTime.tryParse('${json['last_attempt_at']}'),
    );
  }

  @override
  String toString() => '$key → $desired (attempt $attempts)';
}

/// What a drain did with one intent.
enum OutboxOutcome {
  /// The server now agrees with her. Remove it.
  settled,

  /// Could not reach the server. Keep it and try again later.
  deferred,

  /// The server refused, or we gave up. Remove it and tell her.
  abandoned,
}

/// Knows how to reconcile one kind of intent.
///
/// Two methods because the toggle API forces it: to decide whether to act, the
/// handler must first learn where the server currently stands.
abstract interface class OutboxHandler {
  /// The `kind` this handles.
  String get kind;

  /// The entity's current state on the server. Null when it could not be
  /// read — which the drain treats as "try again", not as "false".
  Future<bool?> readState(String entityId);

  /// Flips the entity. Called only when [readState] disagreed with [desired].
  Future<void> toggle(String entityId);
}
