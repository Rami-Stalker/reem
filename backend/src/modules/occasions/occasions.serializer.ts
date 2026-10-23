import { serializeLook } from '../closet/closet.serializer';
import { serializeAppointment } from '../salons/salons.serializer';
import {
  RepeatWarning,
  dateKey,
  daysBetween,
  kindEntry,
  nextStep,
  planSteps,
  progressOf,
} from './occasion-plan';
import { OccasionRecord } from './occasions.service';

/**
 * The wire shape of an occasion.
 *
 * The look and the appointment are embedded in **their own features' shapes**
 * — `serializeLook` and `serializeAppointment` — rather than a summary of
 * each. The client already decodes both, so it decodes them here with the
 * same functions, and a look shown on an occasion can never disagree with the
 * same look shown in the closet.
 *
 * The plan (`steps`, `progress`, `next_step`) and the countdown (`days_left`)
 * are the server's. The client draws them; it does not work them out, for the
 * same reason the salon's `can_cancel` is the server's: two implementations
 * of "is the salon step done" would eventually disagree.
 */
export function serializeOccasion(
  occasion: OccasionRecord,
  context: { today: string; repeats?: RepeatWarning[] },
) {
  const date = dateKey(occasion.date);
  const daysLeft = daysBetween(context.today, date);
  const entry = kindEntry(occasion.kind);

  const steps = planSteps({
    kind: occasion.kind,
    daysLeft,
    look: occasion.look
      ? { missingCount: occasion.look.items.filter((item) => !item.closetItemId).length }
      : null,
    appointment: occasion.appointment,
    doneSteps: occasion.doneSteps,
  });

  return {
    id: occasion.id,
    title: occasion.title,
    kind: occasion.kind,
    kind_label: entry.labelAr,
    date,
    starts_at_time: occasion.startsAtTime,
    location: occasion.location,
    circle: occasion.circle,
    note: occasion.note,
    days_left: daysLeft,
    is_past: daysLeft < 0,
    reminders_enabled: occasion.remindersEnabled,
    /** The lexicon occasion to offer looks for first. */
    look_occasion: entry.lookOccasion,
    look: occasion.look ? serializeLook(occasion.look) : null,
    appointment: occasion.appointment ? serializeAppointment(occasion.appointment) : null,
    steps: steps.map((step) => ({
      key: step.key,
      state: step.state,
      manual: step.manual,
      urgent: step.urgent,
      count: step.count ?? null,
    })),
    progress: progressOf(steps),
    next_step: nextStep(steps)?.key ?? null,
    /** Only on the detail route; the list does not compute it. */
    repeats: (context.repeats ?? []).map((warning) => ({
      occasion_id: warning.occasionId,
      title: warning.title,
      date: warning.date,
      upcoming: warning.upcoming,
      same_look: warning.sameLook,
      pieces: warning.pieces.map((piece) => ({
        id: piece.id,
        title: piece.title,
        slot: piece.slot,
      })),
    })),
    created_at: occasion.createdAt.toISOString(),
    updated_at: occasion.updatedAt.toISOString(),
  };
}
