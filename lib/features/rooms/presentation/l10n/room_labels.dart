import 'package:ohara/features/rooms/domain/entities/room.dart';
import 'package:ohara/l10n/app_localizations.dart';

/// Words for room states, kept out of the domain so they follow the locale.
extension RoomKindLabel on RoomKind {
  String labelOf(AppLocalizations l10n) => switch (this) {
    RoomKind.solo => l10n.roomsKindSolo,
    RoomKind.group => l10n.roomsKindGroup,
    RoomKind.gift => l10n.roomsKindGift,
    RoomKind.occasion => l10n.roomsKindOccasion,
  };
}

extension RoomBlockerLabel on RoomBlocker {
  /// The sentence shown on the readiness strip.
  String labelOf(AppLocalizations l10n) {
    final title = decisionTitle ?? l10n.roomsDecisionFallback;
    return switch (code) {
      'NO_DECISIONS' => l10n.roomsBlockerNoDecisions,
      'NOTHING_CHOSEN' => l10n.roomsBlockerNothingChosen,
      'DECISION_EMPTY' => l10n.roomsBlockerEmpty(title),
      'DECISION_UNRESOLVED' => l10n.roomsBlockerUnresolved(title),
      'OVER_PICK_COUNT' => l10n.roomsBlockerOverPick(title),
      'CHOSEN_UNAVAILABLE' => l10n.roomsBlockerUnavailable(title),
      _ => l10n.roomsBlockerOther,
    };
  }
}

/// Occasion codes the composer offers, in the order she sees them.
const roomOccasionCodes = [
  'wedding',
  'engagement',
  'evening',
  'eid',
  'graduation',
  'birthday',
  'work',
  'daily',
];

String roomOccasionLabel(AppLocalizations l10n, String code) => switch (code) {
  'wedding' => l10n.roomsOccasionWedding,
  'engagement' => l10n.roomsOccasionEngagement,
  'evening' => l10n.roomsOccasionEvening,
  'eid' => l10n.roomsOccasionEid,
  'graduation' => l10n.roomsOccasionGraduation,
  'birthday' => l10n.roomsOccasionBirthday,
  'work' => l10n.roomsOccasionWork,
  'daily' => l10n.roomsOccasionDaily,
  _ => code,
};
