import { AppointmentStatus, OccasionKind, OutfitSlot } from '@prisma/client';
import { normaliseArabic } from '../ai-stylist/understanding/stylist-lexicon';

/**
 * «مناسباتي», as arithmetic.
 *
 * Everything an occasion *says* about itself — how many days are left, what is
 * still to do, whether to ring her phone today, whether she already wore this
 * outfit in front of these people — is computed here from the row and the two
 * things it points at. No Prisma, no Nest, no clock of its own: the caller
 * hands in "today", which is what lets `occasion-plan.spec.ts` walk a wedding
 * from three weeks out to the morning after without waiting for any of it.
 *
 * The rule this file exists to keep: **nothing in the plan is stored if it can
 * be observed.** A salon step that read a stored "booked" flag would go on
 * saying "booked" after the salon cancelled. Reading the appointment's status
 * every time is what keeps the checklist honest.
 */

// ── Kinds ───────────────────────────────────────────────────────────────────

export interface OccasionKindEntry {
  kind: OccasionKind;
  /** For notifications. The client labels kinds from its own ARB bundles. */
  labelAr: string;
  /**
   * The stylist-lexicon occasion its look should be built for. The client
   * sorts her looks by it in the picker, so a wedding offers the wedding looks
   * first. Null where no lexicon occasion fits.
   */
  lookOccasion: string | null;
  /** Whether "book the salon" belongs on this day's checklist. */
  wantsSalon: boolean;
  /** Whether "the gift" does. */
  wantsGift: boolean;
}

/**
 * What each kind of day asks of her.
 *
 * Conservative on purpose. A checklist that tells her to book a salon before
 * a work dinner is a checklist she learns to ignore, and then it is ignored on
 * the day it mattered.
 */
export const OCCASION_KINDS: readonly OccasionKindEntry[] = [
  { kind: OccasionKind.WEDDING, labelAr: 'عرس', lookOccasion: 'wedding', wantsSalon: true, wantsGift: true },
  { kind: OccasionKind.ENGAGEMENT, labelAr: 'خطوبة', lookOccasion: 'engagement', wantsSalon: true, wantsGift: true },
  { kind: OccasionKind.HENNA, labelAr: 'سهرة حنّة', lookOccasion: 'evening', wantsSalon: true, wantsGift: false },
  { kind: OccasionKind.EID, labelAr: 'العيد', lookOccasion: 'eid', wantsSalon: true, wantsGift: true },
  { kind: OccasionKind.BIRTHDAY, labelAr: 'عيد ميلاد', lookOccasion: 'birthday', wantsSalon: false, wantsGift: true },
  { kind: OccasionKind.GRADUATION, labelAr: 'تخرّج', lookOccasion: 'graduation', wantsSalon: true, wantsGift: true },
  { kind: OccasionKind.EVENING, labelAr: 'سهرة', lookOccasion: 'evening', wantsSalon: true, wantsGift: false },
  { kind: OccasionKind.FAMILY_VISIT, labelAr: 'زيارة عائلية', lookOccasion: 'daily', wantsSalon: false, wantsGift: false },
  { kind: OccasionKind.WORK, labelAr: 'مناسبة عمل', lookOccasion: 'work', wantsSalon: false, wantsGift: false },
  { kind: OccasionKind.TRAVEL, labelAr: 'سفر', lookOccasion: 'travel', wantsSalon: false, wantsGift: false },
  { kind: OccasionKind.OTHER, labelAr: 'مناسبة', lookOccasion: null, wantsSalon: false, wantsGift: false },
];

const KIND_BY_KEY = new Map(OCCASION_KINDS.map((entry) => [entry.kind, entry]));

export function kindEntry(kind: OccasionKind): OccasionKindEntry {
  return KIND_BY_KEY.get(kind) ?? KIND_BY_KEY.get(OccasionKind.OTHER)!;
}

// ── The calendar ────────────────────────────────────────────────────────────

/**
 * How far either side of today she may write an occasion down.
 *
 * The past is allowed on purpose: «لبستها بعرس سارة» is the record the repeat
 * warning reads, and it is most often written after the fact. The bounds only
 * exist to refuse a mistyped year.
 */
export const MAX_DAYS_BACK = 730;
export const MAX_DAYS_AHEAD = 1095;

/** `YYYY-MM-DD` of an instant, in the local reckoning. */
export function localDate(instant: Date, offsetMinutes: number): string {
  return new Date(instant.getTime() + offsetMinutes * 60_000)
    .toISOString()
    .slice(0, 10);
}

/** The local hour of an instant, 0–23. */
export function localHour(instant: Date, offsetMinutes: number): number {
  return new Date(instant.getTime() + offsetMinutes * 60_000).getUTCHours();
}

/** A `@db.Date` column as Prisma returns it (UTC midnight) → `YYYY-MM-DD`. */
export function dateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

/** `YYYY-MM-DD` → the UTC-midnight `Date` a `@db.Date` column stores. */
export function dateFromKey(key: string): Date {
  return new Date(`${key}T00:00:00.000Z`);
}

/** Whole days from `from` to `to`, both `YYYY-MM-DD`. Negative when past. */
export function daysBetween(from: string, to: string): number {
  return Math.round(
    (dateFromKey(to).getTime() - dateFromKey(from).getTime()) / 86_400_000,
  );
}

/** `from` plus `days`, as `YYYY-MM-DD`. */
export function addDays(from: string, days: number): string {
  return dateKey(new Date(dateFromKey(from).getTime() + days * 86_400_000));
}

// ── The countdown ───────────────────────────────────────────────────────────

/**
 * The marks the countdown rings at, in days before.
 *
 * Three, and each one is there for a decision she still has time to make:
 *
 *  - **7** — choose the look, and order anything it is missing. Delivery in
 *    Syria is days, not hours, and a dress ordered at three days is a dress
 *    that may arrive the morning after.
 *  - **3** — book the salon before the good hours are gone.
 *  - **1** — tomorrow.
 *
 * Not more. A countdown that rings every day is a countdown she mutes, and a
 * muted channel stays muted for the next wedding too.
 */
export const REMINDER_STAGES = [7, 3, 1] as const;

/**
 * The stage today falls in: the smallest mark at or beyond `daysLeft`.
 * Null when the day is past, or further off than the first mark.
 */
export function dueStage(daysLeft: number): number | null {
  if (daysLeft < 0) return null;
  let due: number | null = null;
  for (const stage of REMINDER_STAGES) {
    if (stage >= daysLeft && (due === null || stage < due)) due = stage;
  }
  return due;
}

/**
 * Whether today's sweep owes her a reminder.
 *
 * `lastStage` is the smallest mark already behind her. It is set to the
 * current stage when the occasion is written down, so a wedding entered five
 * days ahead waits for the three-day mark rather than ringing at once about a
 * one-week mark she has already passed — she knows it is in five days; she
 * just typed it.
 */
export function shouldRemind(daysLeft: number, lastStage: number | null): number | null {
  const stage = dueStage(daysLeft);
  if (stage === null) return null;
  if (lastStage !== null && lastStage <= stage) return null;
  return stage;
}

/**
 * The hours a countdown may arrive in, local.
 *
 * These notifications are sent TRANSACTIONAL, so the platform's quiet-hours
 * policy does not hold them back — rightly, since she asked for them. That
 * makes the hour this file's job: a "one week to go" is never worth waking
 * her for, and an hourly sweep that ran at three in the morning would do
 * exactly that.
 */
export const SENDING_HOURS = { from: 10, until: 21 } as const;

export function withinSendingHours(now: Date, offsetMinutes: number): boolean {
  const hour = localHour(now, offsetMinutes);
  return hour >= SENDING_HOURS.from && hour < SENDING_HOURS.until;
}

// ── The plan ────────────────────────────────────────────────────────────────

export type StepKey = 'look' | 'pieces' | 'salon' | 'gift';
export type StepState = 'TODO' | 'WAITING' | 'DONE';

/** The steps she ticks herself, because nothing on the server can see them. */
export const MANUAL_STEPS: readonly StepKey[] = ['gift'];

export function isManualStep(key: string): key is StepKey {
  return (MANUAL_STEPS as readonly string[]).includes(key);
}

export interface PlanStep {
  key: StepKey;
  state: StepState;
  /** She ticks it by hand. */
  manual: boolean;
  /** Still to do, and the time for it is running out. */
  urgent: boolean;
  /** For `pieces`: how many slots the look still wants from the shop. */
  count?: number;
}

export interface PlanInput {
  kind: OccasionKind;
  daysLeft: number;
  look: { missingCount: number } | null;
  appointment: { status: AppointmentStatus } | null;
  doneSteps: readonly string[];
}

/**
 * When each step becomes urgent, in days before.
 *
 * `pieces` is the earliest because it is the only one that depends on a
 * courier. The rest depend on her.
 */
const URGENT_WITHIN: Record<StepKey, number> = {
  pieces: 5,
  salon: 3,
  look: 2,
  gift: 2,
};

/**
 * The checklist for one occasion, in the order she should do it.
 *
 * Look first, because everything else hangs off it: the pieces are what the
 * look is missing, and a salon books more easily when she knows what she is
 * wearing. A past occasion has no plan — there is nothing left to get ready.
 */
export function planSteps(input: PlanInput): PlanStep[] {
  if (input.daysLeft < 0) return [];
  const entry = kindEntry(input.kind);
  const steps: PlanStep[] = [];

  const push = (key: StepKey, state: StepState, extra: Partial<PlanStep> = {}) =>
    steps.push({
      key,
      state,
      manual: isManualStep(key),
      urgent: state === 'TODO' && input.daysLeft <= URGENT_WITHIN[key],
      ...extra,
    });

  push('look', input.look ? 'DONE' : 'TODO');

  // Only when the look really does want something from the shop. A step that
  // appeared ticked for a look that never lacked anything would be noise.
  if (input.look && input.look.missingCount > 0) {
    push('pieces', 'TODO', { count: input.look.missingCount });
  }

  if (entry.wantsSalon) push('salon', salonState(input.appointment));

  if (entry.wantsGift) push('gift', input.doneSteps.includes('gift') ? 'DONE' : 'TODO');

  return steps;
}

/**
 * A booking the salon has not confirmed yet is neither done nor to do: she
 * has acted, and is waiting. A cancelled or missed one is to do again —
 * which is the case a stored flag would have got wrong.
 */
function salonState(appointment: { status: AppointmentStatus } | null): StepState {
  switch (appointment?.status) {
    case AppointmentStatus.CONFIRMED:
    case AppointmentStatus.COMPLETED:
      return 'DONE';
    case AppointmentStatus.PENDING:
      return 'WAITING';
    default:
      return 'TODO';
  }
}

export function progressOf(steps: readonly PlanStep[]): { done: number; total: number } {
  return {
    done: steps.filter((step) => step.state === 'DONE').length,
    total: steps.length,
  };
}

/** The first thing still to do, or null when she is ready. */
export function nextStep(steps: readonly PlanStep[]): PlanStep | null {
  return steps.find((step) => step.state === 'TODO') ?? null;
}

// ── The reminder's words ────────────────────────────────────────────────────

const ARABIC_DIGITS = new Intl.NumberFormat('ar-SY');

/** «غداً», «بعد يومين», «بعد ٣ أيام», «بعد ٧ أيام». */
export function whenPhrase(daysLeft: number): string {
  if (daysLeft <= 0) return 'اليوم';
  if (daysLeft === 1) return 'غداً';
  if (daysLeft === 2) return 'بعد يومين';
  // Arabic counts 3–10 with a plural noun and 11+ with a singular one.
  const noun = daysLeft <= 10 ? 'أيام' : 'يوماً';
  return `بعد ${ARABIC_DIGITS.format(daysLeft)} ${noun}`;
}

/**
 * The notification for one countdown mark.
 *
 * The title says when; the body says the one thing worth doing next. Never a
 * list — a push is read on a lock screen in a second and a half — and never a
 * product: the countdown is hers, and an occasion she wrote down is not an
 * advertising slot.
 */
export function reminderCopy(
  title: string,
  daysLeft: number,
  next: PlanStep | null,
): { title: string; body: string } {
  const heading = `«${title}» ${whenPhrase(daysLeft)}`;
  switch (next?.key) {
    case 'look':
      return { title: heading, body: 'اختاري إطلالتكِ من خزانتكِ قبل ما يضيق الوقت.' };
    case 'pieces':
      return {
        title: heading,
        body: 'إطلالتكِ ناقصها قطع — اطلبيها الآن حتى توصل بالوقت.',
      };
    case 'salon':
      return { title: heading, body: 'احجزي موعد الصالون قبل ما تمتلئ المواعيد.' };
    case 'gift':
      return { title: heading, body: 'لا تنسي الهدية.' };
    default:
      return { title: heading, body: 'كل شي جاهز ✨' };
  }
}

// ── «ما لبستيه قدّامهم» ──────────────────────────────────────────────────────

/** `circle`, as the repeat warning compares it. Null when there is none. */
export function circleKeyOf(circle: string | null | undefined): string | null {
  if (!circle) return null;
  const key = normaliseArabic(circle).slice(0, 80);
  return key.length ? key : null;
}

/**
 * The pieces whose second appearance in front of the same people is noticed.
 *
 * The dress, the abaya, the coat — what someone describes when they describe
 * what she wore. Shoes, bags and jewellery repeat for everyone and a warning
 * about them would be a warning she learns to dismiss.
 */
export const STATEMENT_SLOTS: ReadonlySet<OutfitSlot> = new Set([
  OutfitSlot.DRESS,
  OutfitSlot.ABAYA,
  OutfitSlot.OUTERWEAR,
  OutfitSlot.TOP,
  OutfitSlot.BOTTOM,
]);

export interface WornPiece {
  id: string;
  title: string;
  slot: OutfitSlot;
}

export interface OccasionOutfit {
  id: string;
  title: string;
  date: string;
  lookId: string | null;
  circleKey: string | null;
  pieces: readonly WornPiece[];
}

export interface RepeatWarning {
  occasionId: string;
  title: string;
  date: string;
  /** Planned for, or worn at, an occasion that has not happened yet. */
  upcoming: boolean;
  /** The very same look. */
  sameLook: boolean;
  /** The statement pieces the two outfits share. */
  pieces: WornPiece[];
}

/**
 * Where else these people have seen — or are about to see — this outfit.
 *
 * Matches on the circle she named, never on a guess: two occasions with no
 * circle are not assumed to share an audience, because a warning that fires
 * between a work dinner and her cousin's henna is wrong, and one wrong warning
 * teaches her to ignore the right ones.
 *
 * Both directions in time. Wearing a dress to the wedding on the 20th that
 * she has already planned for her sister-in-law's engagement on the 12th is
 * the case worth catching *before* either day.
 */
export function findRepeats(
  target: OccasionOutfit,
  others: readonly OccasionOutfit[],
  today: string,
): RepeatWarning[] {
  if (!target.circleKey || (!target.lookId && target.pieces.length === 0)) return [];

  const targetPieces = new Map(
    target.pieces
      .filter((piece) => STATEMENT_SLOTS.has(piece.slot))
      .map((piece) => [piece.id, piece]),
  );

  const warnings: RepeatWarning[] = [];
  for (const other of others) {
    if (other.id === target.id || other.circleKey !== target.circleKey) continue;

    const sameLook = !!target.lookId && other.lookId === target.lookId;
    const shared = other.pieces.filter((piece) => targetPieces.has(piece.id));
    if (!sameLook && shared.length === 0) continue;

    warnings.push({
      occasionId: other.id,
      title: other.title,
      date: other.date,
      upcoming: other.date >= today,
      sameLook,
      pieces: shared.map((piece) => targetPieces.get(piece.id)!),
    });
  }

  // Nearest first: the occasion closest to this one is the one they will
  // remember.
  return warnings.sort(
    (a, b) =>
      Math.abs(daysBetween(target.date, a.date)) -
      Math.abs(daysBetween(target.date, b.date)),
  );
}
