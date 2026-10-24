import 'package:equatable/equatable.dart';

import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/salons/domain/entities/appointment.dart';

/// What kind of day it is. Mirrors the server's `OccasionKind` exactly.
enum OccasionKind {
  wedding('WEDDING'),
  engagement('ENGAGEMENT'),
  henna('HENNA'),
  eid('EID'),
  birthday('BIRTHDAY'),
  graduation('GRADUATION'),
  evening('EVENING'),
  familyVisit('FAMILY_VISIT'),
  work('WORK'),
  travel('TRAVEL'),
  other('OTHER');

  const OccasionKind(this.wire);

  final String wire;

  static OccasionKind fromWire(String? value) {
    for (final kind in OccasionKind.values) {
      if (kind.wire == value) return kind;
    }
    return OccasionKind.other;
  }
}

/// One thing on the checklist. The server decides which steps a day has and
/// where each one stands; the screen draws them.
enum OccasionStepKey {
  look,
  pieces,
  salon,
  gift;

  static OccasionStepKey? fromWire(String? value) => switch (value) {
    'look' => OccasionStepKey.look,
    'pieces' => OccasionStepKey.pieces,
    'salon' => OccasionStepKey.salon,
    'gift' => OccasionStepKey.gift,
    _ => null,
  };

  String get wire => name;
}

enum OccasionStepState {
  todo,

  /// She has acted and is waiting — a salon booking not yet confirmed.
  waiting,
  done;

  static OccasionStepState fromWire(String? value) => switch (value) {
    'DONE' => OccasionStepState.done,
    'WAITING' => OccasionStepState.waiting,
    _ => OccasionStepState.todo,
  };
}

class OccasionStep extends Equatable {
  const OccasionStep({
    required this.key,
    required this.state,
    this.manual = false,
    this.urgent = false,
    this.count,
  });

  final OccasionStepKey key;
  final OccasionStepState state;

  /// She ticks it herself — only the gift.
  final bool manual;

  /// Still to do, and the time for it is running out.
  final bool urgent;

  /// For [OccasionStepKey.pieces]: how many pieces the look still needs.
  final int? count;

  bool get isDone => state == OccasionStepState.done;

  @override
  List<Object?> get props => [key, state, manual, urgent, count];
}

/// A statement piece the same people have already seen.
class RepeatPiece extends Equatable {
  const RepeatPiece({required this.id, required this.title});

  final String id;
  final String title;

  @override
  List<Object?> get props => [id];
}

/// «ما لبستيه قدّامهم» — another occasion with the same people where this
/// outfit, or a piece of it, appears.
class OccasionRepeat extends Equatable {
  const OccasionRepeat({
    required this.occasionId,
    required this.title,
    required this.date,
    this.upcoming = false,
    this.sameLook = false,
    this.pieces = const [],
  });

  final String occasionId;
  final String title;
  final DateTime date;

  /// Planned for an occasion that has not happened yet.
  final bool upcoming;
  final bool sameLook;
  final List<RepeatPiece> pieces;

  @override
  List<Object?> get props => [occasionId, sameLook, pieces];
}

/// One day she is getting ready for.
class Occasion extends Equatable {
  const Occasion({
    required this.id,
    required this.title,
    required this.kind,
    required this.date,
    required this.daysLeft,
    this.startsAtTime,
    this.location,
    this.circle,
    this.note,
    this.remindersEnabled = true,
    this.lookOccasion,
    this.look,
    this.appointment,
    this.steps = const [],
    this.doneCount = 0,
    this.totalCount = 0,
    this.nextStep,
    this.repeats = const [],
  });

  final String id;
  final String title;
  final OccasionKind kind;

  /// The calendar day, as a local date with no time.
  final DateTime date;

  /// Whole days from her today, as the server counts them. Negative when
  /// past.
  final int daysLeft;

  /// `HH:mm`, when she knows it.
  final String? startsAtTime;
  final String? location;

  /// Who will be there.
  final String? circle;
  final String? note;
  final bool remindersEnabled;

  /// The closet occasion whose looks the picker offers first.
  final String? lookOccasion;

  final ClosetLook? look;
  final Appointment? appointment;

  final List<OccasionStep> steps;
  final int doneCount;
  final int totalCount;
  final OccasionStepKey? nextStep;

  /// Only on the detail payload.
  final List<OccasionRepeat> repeats;

  bool get isPast => daysLeft < 0;
  bool get isReady => totalCount > 0 && doneCount == totalCount;
  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;

  OccasionStep? step(OccasionStepKey key) {
    for (final step in steps) {
      if (step.key == key) return step;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    title,
    kind,
    date,
    daysLeft,
    startsAtTime,
    location,
    circle,
    note,
    remindersEnabled,
    look?.id,
    appointment?.id,
    appointment?.status,
    steps,
    repeats,
  ];
}
