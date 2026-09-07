import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:reem/core/observability/error_report.dart';
import 'package:reem/core/observability/error_reporter.dart';
import 'package:reem/core/sync/outbox_intent.dart';

/// The queue of things she asked for while the network was not listening.
///
/// **What belongs here, and what deliberately does not.**
///
/// Engagement — a like, a save, a favourite — belongs. It is frequent, it is
/// tapped while scrolling on a bad connection, it costs nothing if it lands a
/// minute late, and her intent is unambiguous.
///
/// Anything that moves money does not: a cart line, a checkout, a payment, a
/// refund. Those need a live confirmation, because the honest answer to "did
/// my order go through" is either yes or no, never "probably, later". Queuing
/// them would let the app tell a woman she had bought something she had not.
///
/// The queue is bounded, persisted, coalesced by entity, and gives up out
/// loud rather than retrying forever.
class Outbox {
  Outbox({
    Directory? directory,
    DateTime Function()? now,
    this.maxAttempts = 5,
    this.maxAge = const Duration(days: 3),
    this.capacity = 200,
  }) : _directory = directory,
       _now = now ?? DateTime.now;

  static const _fileName = 'reem_outbox.json';

  Directory? _directory;
  final DateTime Function() _now;

  /// After this many failed drains an intent is dropped. Five is enough to
  /// survive a bad afternoon and few enough that a permanently broken intent
  /// cannot retry forever.
  final int maxAttempts;

  /// An intent older than this is stale regardless of attempts — she has
  /// almost certainly forgotten she tapped it.
  final Duration maxAge;

  /// A ceiling, so a long offline session cannot fill the disk. The oldest go.
  final int capacity;

  final Map<String, OutboxHandler> _handlers = {};
  final Map<String, OutboxIntent> _pending = {};
  final _changes = StreamController<List<OutboxIntent>>.broadcast();

  bool _loaded = false;
  Future<void>? _draining;

  /// Intents still waiting, newest last.
  List<OutboxIntent> get pending =>
      _pending.values.toList(growable: false)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// Emits whenever the queue changes, so a "syncing" indicator can follow it.
  Stream<List<OutboxIntent>> get changes => _changes.stream;

  void register(OutboxHandler handler) => _handlers[handler.kind] = handler;

  /// Records what she wanted. Replaces any earlier intent for the same entity:
  /// only the last tap matters.
  Future<void> enqueue({
    required String kind,
    required String entityId,
    required bool desired,
  }) async {
    await _load();
    final intent = OutboxIntent(
      kind: kind,
      entityId: entityId,
      desired: desired,
      createdAt: _now(),
    );
    _pending[intent.key] = intent;
    _trim();
    ErrorReporter.leaveBreadcrumb('outbox', 'queued ${intent.key}');
    await _persist();
    _notify();
  }

  /// True when this entity has an unsent change — the UI shows a small mark.
  bool isPending(String kind, String entityId) =>
      _pending.containsKey('$kind:$entityId');

  /// The state she last asked for, or null if nothing is queued. A list
  /// rebuilt from the server can use this to keep showing her own tap.
  bool? desiredState(String kind, String entityId) =>
      _pending['$kind:$entityId']?.desired;

  /// Tries to settle everything. Safe to call often — concurrent calls share
  /// one pass, so a reconnect and an app resume arriving together do not
  /// double-send.
  Future<void> drain() {
    return _draining ??= _drain().whenComplete(() => _draining = null);
  }

  Future<void> _drain() async {
    await _load();
    if (_pending.isEmpty) return;

    for (final intent in pending) {
      final handler = _handlers[intent.kind];
      if (handler == null) {
        // A queue written by a build that had a handler this one does not.
        _pending.remove(intent.key);
        continue;
      }

      if (_isExhausted(intent)) {
        _abandon(intent, 'gave up after ${intent.attempts} attempts');
        continue;
      }

      final outcome = await _settle(handler, intent);
      switch (outcome) {
        case OutboxOutcome.settled:
          _pending.remove(intent.key);
          ErrorReporter.leaveBreadcrumb('outbox', 'settled ${intent.key}');
        case OutboxOutcome.deferred:
          _pending[intent.key] = intent.attempted(_now());
        case OutboxOutcome.abandoned:
          _abandon(intent, 'the server refused it');
      }
    }

    await _persist();
    _notify();
  }

  Future<OutboxOutcome> _settle(
    OutboxHandler handler,
    OutboxIntent intent,
  ) async {
    try {
      // Ask where the server stands before acting. This is what makes a
      // replay safe against a toggle endpoint: if her tap actually landed and
      // only the response was lost, the states already agree and we do
      // nothing rather than undoing her.
      final current = await handler.readState(intent.entityId);
      if (current == null) return OutboxOutcome.deferred;
      if (current == intent.desired) return OutboxOutcome.settled;
      await handler.toggle(intent.entityId);
      return OutboxOutcome.settled;
    } on Object catch (error, stack) {
      if (_looksTransient(error)) return OutboxOutcome.deferred;
      ErrorReporter.report(
        error,
        stack,
        severity: ErrorSeverity.warning,
        context: 'outbox could not settle ${intent.kind}',
      );
      return OutboxOutcome.abandoned;
    }
  }

  /// A connection failure means try again; anything else means the request
  /// itself is wrong and retrying will not fix it.
  bool _looksTransient(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('connection') ||
        text.contains('timeout') ||
        text.contains('network') ||
        text.contains('socket');
  }

  bool _isExhausted(OutboxIntent intent) =>
      intent.attempts >= maxAttempts ||
      _now().difference(intent.createdAt) > maxAge;

  void _abandon(OutboxIntent intent, String why) {
    _pending.remove(intent.key);
    ErrorReporter.leaveBreadcrumb('outbox', 'abandoned ${intent.key}: $why');
  }

  void _trim() {
    if (_pending.length <= capacity) return;
    final oldestFirst = pending;
    for (final intent in oldestFirst.take(_pending.length - capacity)) {
      _pending.remove(intent.key);
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(pending);
  }

  // ── Persistence ────────────────────────────────────────────────────────
  //
  // A queue that does not survive a restart is not an offline queue: the
  // commonest way to lose a connection is to have the app killed in the
  // background while you are on the metro.

  Future<Directory> _resolveDirectory() async {
    final existing = _directory;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    if (!base.existsSync()) await base.create(recursive: true);
    return _directory = base;
  }

  Future<File> _file() async =>
      File(p.join((await _resolveDirectory()).path, _fileName));

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final file = await _file();
      if (!file.existsSync()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! List) return;
      for (final entry in raw) {
        if (entry is! Map<String, dynamic>) continue;
        final intent = OutboxIntent.tryFromJson(entry);
        if (intent != null) _pending[intent.key] = intent;
      }
    } on Object catch (error) {
      // A corrupt queue costs her the taps it held. Crashing on it would cost
      // her the app.
      ErrorReporter.report(
        error,
        null,
        severity: ErrorSeverity.warning,
        context: 'outbox load',
      );
      _pending.clear();
    }
  }

  Future<void> _persist() async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode(pending.map((i) => i.toJson()).toList(growable: false)),
      );
    } on Object catch (error) {
      ErrorReporter.report(
        error,
        null,
        severity: ErrorSeverity.warning,
        context: 'outbox persist',
      );
    }
  }

  Future<void> clear() async {
    await _load();
    _pending.clear();
    await _persist();
    _notify();
  }

  void dispose() => _changes.close();
}
