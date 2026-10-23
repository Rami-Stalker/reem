import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/occasions/domain/entities/occasion.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';
import 'package:reem/l10n/app_localizations.dart';

/// The words and icons «مناسباتي» draws with, in one place, so that a kind of
/// day is called the same thing on the card, the detail page and the editor.
abstract final class OccasionLabels {
  static String kind(AppLocalizations l10n, OccasionKind kind) =>
      switch (kind) {
        OccasionKind.wedding => l10n.occasionKindWedding,
        OccasionKind.engagement => l10n.occasionKindEngagement,
        OccasionKind.henna => l10n.occasionKindHenna,
        OccasionKind.eid => l10n.occasionKindEid,
        OccasionKind.birthday => l10n.occasionKindBirthday,
        OccasionKind.graduation => l10n.occasionKindGraduation,
        OccasionKind.evening => l10n.occasionKindEvening,
        OccasionKind.familyVisit => l10n.occasionKindFamilyVisit,
        OccasionKind.work => l10n.occasionKindWork,
        OccasionKind.travel => l10n.occasionKindTravel,
        OccasionKind.other => l10n.occasionKindOther,
      };

  static IconData icon(OccasionKind kind) => switch (kind) {
    OccasionKind.wedding => Icons.favorite_rounded,
    OccasionKind.engagement => Icons.diamond_rounded,
    OccasionKind.henna => Icons.spa_rounded,
    OccasionKind.eid => Icons.nightlight_round,
    OccasionKind.birthday => Icons.cake_rounded,
    OccasionKind.graduation => Icons.school_rounded,
    OccasionKind.evening => Icons.nights_stay_rounded,
    OccasionKind.familyVisit => Icons.diversity_1_rounded,
    OccasionKind.work => Icons.work_rounded,
    OccasionKind.travel => Icons.flight_takeoff_rounded,
    OccasionKind.other => Icons.celebration_rounded,
  };

  /// «اليوم», «غداً», «بعد ٥ أيام», «مضت». The count is the server's.
  static String countdown(AppLocalizations l10n, int daysLeft) =>
      switch (daysLeft) {
        < 0 => l10n.occasionPassed,
        0 => l10n.occasionToday,
        1 => l10n.occasionTomorrow,
        _ => l10n.occasionInDays(daysLeft),
      };

  /// The tone of the countdown: the closer it is with things left to do, the
  /// louder. A day that is ready is good news whatever its distance.
  static DsBadgeTone countdownTone(Occasion occasion) {
    if (occasion.isPast) return DsBadgeTone.neutral;
    if (occasion.isReady) return DsBadgeTone.success;
    if (occasion.daysLeft <= 1) return DsBadgeTone.sale;
    if (occasion.daysLeft <= 7) return DsBadgeTone.warning;
    return DsBadgeTone.info;
  }

  /// «الخميس ١٤ تشرين الثاني · ٧:٣٠ م».
  static String when(AppLocalizations l10n, Occasion occasion) {
    final date = SalonLabels.date(l10n, occasion.date);
    final time = _time(occasion);
    return time == null ? date : '$date · ${SalonLabels.time(l10n, time)}';
  }

  static DateTime? _time(Occasion occasion) {
    final parts = occasion.startsAtTime?.split(':');
    if (parts == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final day = occasion.date;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  static String stepTitle(AppLocalizations l10n, OccasionStep step) =>
      switch (step.key) {
        OccasionStepKey.look =>
          step.isDone ? l10n.occasionStepLookDone : l10n.occasionStepLook,
        OccasionStepKey.pieces => l10n.occasionStepPieces(step.count ?? 1),
        OccasionStepKey.salon => switch (step.state) {
          OccasionStepState.done => l10n.occasionStepSalonDone,
          OccasionStepState.waiting => l10n.occasionStepSalonWaiting,
          OccasionStepState.todo => l10n.occasionStepSalon,
        },
        OccasionStepKey.gift =>
          step.isDone ? l10n.occasionStepGiftDone : l10n.occasionStepGift,
      };

  /// Why the step matters, said once under it — and said more sharply when
  /// time is short.
  static String? stepHint(AppLocalizations l10n, OccasionStep step) {
    if (step.isDone) return null;
    return switch (step.key) {
      OccasionStepKey.look => l10n.occasionStepLookHint,
      OccasionStepKey.pieces =>
        step.urgent
            ? l10n.occasionStepPiecesUrgent
            : l10n.occasionStepPiecesHint,
      OccasionStepKey.salon =>
        step.state == OccasionStepState.waiting
            ? l10n.occasionStepSalonWaitingHint
            : step.urgent
            ? l10n.occasionStepSalonUrgent
            : l10n.occasionStepSalonHint,
      OccasionStepKey.gift => null,
    };
  }

  /// What the card says under the progress bar.
  static String nextUp(AppLocalizations l10n, Occasion occasion) {
    if (occasion.isReady) return l10n.occasionAllReady;
    return switch (occasion.nextStep) {
      OccasionStepKey.look => l10n.occasionNextLook,
      OccasionStepKey.pieces => l10n.occasionNextPieces,
      OccasionStepKey.salon => l10n.occasionNextSalon,
      OccasionStepKey.gift => l10n.occasionNextGift,
      // Nothing to do but wait for the salon to confirm.
      null => l10n.occasionNextWaiting,
    };
  }
}
