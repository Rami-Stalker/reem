import { PrismaService } from '../../../../backend/src/prisma/prisma.service';

/**
 * Where a scheduled job that runs in slices keeps its place between
 * invocations: `reem_supabase.job_progress`, outside the backend's schema.
 * A row exists only while a run is unfinished; pg_cron's continuation gate
 * reads exactly that.
 *
 * Only one invocation works on a job at a time: `acquire` takes a short lease
 * (the row's `leased_until`), and an invocation that finds a live lease leaves
 * immediately. A lease left by an isolate killed mid-slice simply expires.
 */
export class JobProgressRepository {
  constructor(private readonly prisma: PrismaService) {}

  /** The saved state (or null for a new run), or `'busy'` when another invocation holds the job. */
  async acquire<T>(job: string, leaseSeconds: number): Promise<T | null | 'busy'> {
    const claimed = await this.prisma.$queryRaw<Array<{ state: T | null }>>`
      INSERT INTO reem_supabase.job_progress (job, state, leased_until, updated_at)
      VALUES (${job}, 'null'::jsonb, now() + make_interval(secs => ${leaseSeconds}), now())
      ON CONFLICT (job) DO UPDATE
        SET leased_until = EXCLUDED.leased_until
        WHERE reem_supabase.job_progress.leased_until IS NULL
           OR reem_supabase.job_progress.leased_until < now()
      RETURNING CASE WHEN state = 'null'::jsonb THEN NULL ELSE state END AS state`;
    if (claimed.length === 0) return 'busy';
    return claimed[0].state ?? null;
  }

  async save(job: string, state: unknown): Promise<void> {
    await this.prisma.$executeRaw`
      UPDATE reem_supabase.job_progress
         SET state = ${JSON.stringify(state)}::jsonb, updated_at = now()
       WHERE job = ${job}`;
  }

  async release(job: string): Promise<void> {
    await this.prisma.$executeRaw`
      UPDATE reem_supabase.job_progress SET leased_until = NULL WHERE job = ${job}`;
  }

  async clear(job: string): Promise<void> {
    await this.prisma.$executeRaw`DELETE FROM reem_supabase.job_progress WHERE job = ${job}`;
  }
}
