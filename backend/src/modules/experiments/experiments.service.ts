import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  ExperimentEventKind,
  ExperimentStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { CONTROL, assign, parseVariants } from './kernel/assignment';
import { ALPHA, Arm, MIN_SUBJECTS, compare } from './kernel/significance';

/** How long a running experiment's definition may be cached. */
const TTL_MS = 30_000;

interface Running {
  id: string;
  key: string;
  variants: { key: string; weight: number }[];
  metric: string;
}

@Injectable()
export class ExperimentsService {
  private readonly logger = new Logger(ExperimentsService.name);

  private cache: Map<string, Running> = new Map();
  private loadedAt = 0;
  private loading: Promise<void> | null = null;

  constructor(private readonly prisma: PrismaService) {}

  // ── Serving ──────────────────────────────────────────────────────────────

  /**
   * Which arm this subject is in.
   *
   * Never throws and never blocks on anything that can fail: an experiment
   * that is stopped, missing, misconfigured or unreachable all return the
   * control, which is what the customer would have seen anyway. A feature
   * flag that can break the page it is flagging is worse than no flag.
   */
  async variantFor(experimentKey: string, subjectKey: string): Promise<string> {
    if (!subjectKey) return CONTROL;

    try {
      await this.ensureLoaded();
    } catch {
      return CONTROL;
    }

    const experiment = this.cache.get(experimentKey);
    if (!experiment) return CONTROL;
    return assign(experiment.key, subjectKey, experiment.variants);
  }

  /**
   * Every running experiment's answer for one subject, for a client that
   * wants them in one round trip.
   */
  async allFor(subjectKey: string): Promise<Record<string, string>> {
    if (!subjectKey) return {};
    try {
      await this.ensureLoaded();
    } catch {
      return {};
    }

    const out: Record<string, string> = {};
    for (const experiment of this.cache.values()) {
      out[experiment.key] = assign(
        experiment.key,
        subjectKey,
        experiment.variants,
      );
    }
    return out;
  }

  /**
   * Records that a subject actually saw her arm.
   *
   * Assignment is not exposure, and the difference is the commonest way an
   * experiment reports a result it never measured: a variant behind a screen
   * nobody reached has no data, and counting everybody assigned to it as
   * having seen it drags its rate towards zero.
   *
   * Idempotent by unique key — a screen that renders twice is one exposure.
   */
  async recordExposure(experimentKey: string, subjectKey: string) {
    const experiment = await this.running(experimentKey);
    if (!experiment || !subjectKey) return { recorded: false };

    const variant = assign(experiment.key, subjectKey, experiment.variants);
    return this.write(experiment.id, subjectKey, variant, {
      kind: ExperimentEventKind.EXPOSURE,
      // Empty, never null: the unique key that makes this idempotent cannot
      // do its job over a nullable column. See the schema note.
      metric: '',
    });
  }

  /** Records that she did the thing the experiment is about. */
  async recordConversion(
    experimentKey: string,
    subjectKey: string,
    options: { metric?: string; value?: Money } = {},
  ) {
    const experiment = await this.running(experimentKey);
    if (!experiment || !subjectKey) return { recorded: false };

    const variant = assign(experiment.key, subjectKey, experiment.variants);
    return this.write(experiment.id, subjectKey, variant, {
      kind: ExperimentEventKind.CONVERSION,
      metric: options.metric ?? experiment.metric,
      value: options.value,
    });
  }

  // ── Reading ──────────────────────────────────────────────────────────────

  /**
   * What the experiment has found so far, and how much of it to believe.
   *
   * Rates are conversions over *exposures*, never over assignments. The
   * comparison against control carries its own interval and refuses to report
   * a p-value on a thin sample — see `significance.ts` for why a screen that
   * shows only a tick teaches people to stop the test on noise.
   */
  async results(experimentId: string) {
    const experiment = await this.prisma.experiment.findUnique({
      where: { id: experimentId },
    });
    if (!experiment) throw new NotFoundException('Experiment not found');

    const variants = parseVariants(experiment.variants) ?? [];

    const rows = await this.prisma.experimentEvent.groupBy({
      by: ['variant', 'kind'],
      where: { experimentId },
      _count: { _all: true },
    });

    const arms = new Map<string, Arm>(
      variants.map((variant) => [
        variant.key,
        { key: variant.key, subjects: 0, conversions: 0 },
      ]),
    );
    for (const row of rows) {
      const arm = arms.get(row.variant);
      if (!arm) continue;
      if (row.kind === ExperimentEventKind.EXPOSURE) {
        arm.subjects = row._count._all;
      } else {
        arm.conversions = row._count._all;
      }
    }

    const control = arms.get(CONTROL) ?? {
      key: CONTROL,
      subjects: 0,
      conversions: 0,
    };

    return {
      id: experiment.id,
      key: experiment.key,
      name: experiment.name,
      hypothesis: experiment.hypothesis,
      status: experiment.status.toLowerCase(),
      metric: experiment.metric,
      started_at: experiment.startsAt.toISOString(),
      ended_at: experiment.endsAt?.toISOString() ?? null,
      arms: variants.map((variant) => {
        const arm = arms.get(variant.key)!;
        const comparison =
          variant.key === CONTROL
            ? null
            : compare(control, arm);
        return {
          variant: variant.key,
          weight: variant.weight,
          exposed: arm.subjects,
          converted: arm.conversions,
          rate:
            arm.subjects > 0
              ? Number((arm.conversions / arm.subjects).toFixed(4))
              : null,
          lift_points: comparison?.liftPoints ?? null,
          p_value: comparison?.pValue ?? null,
          interval_points: comparison?.intervalPoints ?? null,
          readable: comparison?.readable ?? arm.subjects >= MIN_SUBJECTS,
        };
      }),
      // Said plainly, on the same screen as the numbers, because the numbers
      // do not say it for themselves.
      reading_guidance:
        `تُقرأ النتيجة مرّة واحدة بعد بلوغ الحجم المخطَّط له (${MIN_SUBJECTS} على الأقل ` +
        `لكل مجموعة). مراجعتها يومياً حتى تصبح "دالّة" عند ${ALPHA} تُنتج نتيجة من الضجيج.`,
    };
  }

  async list() {
    const rows = await this.prisma.experiment.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return rows.map((row) => ({
      id: row.id,
      key: row.key,
      name: row.name,
      status: row.status.toLowerCase(),
      metric: row.metric,
      variants: row.variants,
      starts_at: row.startsAt.toISOString(),
      ends_at: row.endsAt?.toISOString() ?? null,
    }));
  }

  // ── Writing ──────────────────────────────────────────────────────────────

  async create(input: {
    key: string;
    name: string;
    hypothesis?: string | null;
    metric: string;
    variants: unknown;
    startsAt: Date;
    endsAt?: Date | null;
    actorId: string;
  }) {
    const variants = parseVariants(input.variants);
    if (!variants) {
      throw new BadRequestException(
        'Variants must be at least two distinct arms with non-negative weights, one of them "control"',
      );
    }

    const experiment = await this.prisma.experiment.create({
      data: {
        key: input.key,
        name: input.name,
        hypothesis: input.hypothesis ?? null,
        metric: input.metric,
        variants: variants as unknown as Prisma.InputJsonValue,
        startsAt: input.startsAt,
        endsAt: input.endsAt ?? null,
        createdById: input.actorId,
      },
    });

    this.invalidate();
    return { id: experiment.id, key: experiment.key };
  }

  /**
   * Moves an experiment between states.
   *
   * Going back to `RUNNING` after it has been stopped is refused. The results
   * of a test that was paused and restarted are two tests' worth of subjects
   * measured under different conditions, reported as one — and nothing in the
   * data afterwards says so.
   */
  async setStatus(experimentId: string, status: ExperimentStatus) {
    const experiment = await this.prisma.experiment.findUnique({
      where: { id: experimentId },
    });
    if (!experiment) throw new NotFoundException('Experiment not found');

    if (
      experiment.status === ExperimentStatus.STOPPED &&
      status === ExperimentStatus.RUNNING
    ) {
      throw new BadRequestException(
        'A stopped experiment cannot be restarted — start a new one, so the two runs are not reported as one',
      );
    }

    await this.prisma.experiment.update({
      where: { id: experimentId },
      data: { status },
    });
    this.invalidate();
    return this.results(experimentId);
  }

  invalidate(): void {
    this.loadedAt = 0;
  }

  // ── internals ────────────────────────────────────────────────────────────

  /**
   * Records one event, once.
   *
   * An upsert rather than an insert-and-swallow-the-duplicate. Catching a
   * unique violation looks equivalent and is not: in PostgreSQL a failed
   * statement aborts the whole transaction, so a swallowed conflict leaves
   * every later statement in that transaction failing too — including the
   * caller's own work, which had nothing to do with this. Expressing "record
   * this once" as an upsert means the second call is a no-op instead of an
   * error somebody has to survive.
   *
   * The update is deliberately empty. A second exposure is not new
   * information, and overwriting `occurredAt` with it would move the
   * measurement to whenever the screen last re-rendered.
   */
  private async write(
    experimentId: string,
    subjectKey: string,
    variant: string,
    event: {
      kind: ExperimentEventKind;
      metric: string;
      value?: Money;
    },
  ) {
    const before = await this.prisma.experimentEvent.findUnique({
      where: {
        experimentId_subjectKey_kind_metric: {
          experimentId,
          subjectKey,
          kind: event.kind,
          metric: event.metric,
        },
      },
      select: { id: true },
    });

    if (before) return { recorded: false, variant };

    await this.prisma.experimentEvent.upsert({
      where: {
        experimentId_subjectKey_kind_metric: {
          experimentId,
          subjectKey,
          kind: event.kind,
          metric: event.metric,
        },
      },
      create: {
        experimentId,
        subjectKey,
        variant,
        kind: event.kind,
        metric: event.metric,
        value: event.value?.toPrisma() ?? null,
        currency: event.value?.currency ?? null,
      },
      update: {},
    });

    return { recorded: true, variant };
  }

  private async running(key: string): Promise<Running | null> {
    try {
      await this.ensureLoaded();
    } catch {
      return null;
    }
    return this.cache.get(key) ?? null;
  }

  private async ensureLoaded(): Promise<void> {
    if (Date.now() - this.loadedAt < TTL_MS) return;
    this.loading ??= this.load().finally(() => {
      this.loading = null;
    });
    await this.loading;
  }

  private async load(): Promise<void> {
    const now = new Date();
    const rows = await this.prisma.experiment.findMany({
      where: {
        status: ExperimentStatus.RUNNING,
        startsAt: { lte: now },
        OR: [{ endsAt: null }, { endsAt: { gt: now } }],
      },
    });

    const cache = new Map<string, Running>();
    for (const row of rows) {
      const variants = parseVariants(row.variants);
      if (!variants) {
        // A misconfigured experiment does not get to serve a broken split; it
        // simply is not running, and everybody sees the control.
        this.logger.warn(`Experiment ${row.key} has unusable variants`);
        continue;
      }
      cache.set(row.key, {
        id: row.id,
        key: row.key,
        variants,
        metric: row.metric,
      });
    }

    this.cache = cache;
    this.loadedAt = Date.now();
  }
}

/** Re-exported so callers do not reach into the kernel for the one constant. */
export { CONTROL };
