import {
  Controller,
  Get,
  Logger,
  Module,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Public } from '../../common/decorators/public.decorator';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Liveness and readiness are different questions, and answering both with one
 * endpoint is how a database blip turns into an outage.
 *
 * A liveness probe asks "is this process wedged, should I kill it?". A
 * readiness probe asks "can this process serve traffic right now?". The single
 * `/health` here answered the readiness question and was the obvious thing to
 * point a liveness probe at — so a thirty-second Postgres failover would have
 * had the orchestrator restart every API process, discarding warm connections
 * and in-flight requests at exactly the moment the platform was already
 * struggling. The right response to an unreachable database is to stop taking
 * traffic and keep running.
 *
 * `/health` keeps its old shape and meaning so nothing that already points at
 * it changes behaviour.
 */
@Controller('health')
class HealthController {
  private readonly logger = new Logger(HealthController.name);
  private readonly startedAt = Date.now();

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /** Readiness. Unchanged: 200 with the database up, 503 without it. */
  @Public()
  @Get()
  async check() {
    return this.readiness();
  }

  /**
   * Liveness. Deliberately touches nothing but this process.
   *
   * It answers 200 whenever the event loop is still turning, which is the only
   * thing a restart would actually fix. Point the orchestrator's
   * `livenessProbe` here and its `readinessProbe` at `/health/ready`.
   */
  @Public()
  @Get('live')
  live() {
    return {
      status: 'ok',
      uptime_seconds: Math.floor((Date.now() - this.startedAt) / 1000),
      timestamp: new Date().toISOString(),
    };
  }

  /** Readiness, by its own name. */
  @Public()
  @Get('ready')
  async ready() {
    return this.readiness();
  }

  /**
   * What is actually deployed here.
   *
   * The first question during an incident is "which build is this?", and
   * answering it by SSH-ing to a host and reading a file is how the wrong
   * answer gets believed. Nothing secret: a version, a commit, an environment
   * name. `null` where the build did not stamp it, rather than a fabricated
   * value that reads as fact.
   */
  @Public()
  @Get('version')
  version() {
    return {
      version: process.env.APP_VERSION ?? null,
      commit: process.env.GIT_COMMIT ?? null,
      environment: this.config.get<string>('nodeEnv') ?? null,
      node: process.version,
      started_at: new Date(this.startedAt).toISOString(),
    };
  }

  private async readiness() {
    const timestamp = new Date().toISOString();
    const began = Date.now();
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch (error) {
      this.logger.error(
        'Health check failed: database unreachable',
        error instanceof Error ? error.stack : String(error),
      );
      throw new ServiceUnavailableException({
        status: 'error',
        database: 'down',
        timestamp,
      });
    }
    return {
      status: 'ok',
      database: 'up',
      // Round-trip time to Postgres. A readiness probe that only reports
      // reachable/unreachable says nothing while the database is up but
      // grinding, which is the shape most real incidents take.
      database_latency_ms: Date.now() - began,
      timestamp,
    };
  }
}

@Module({ controllers: [HealthController] })
export class HealthModule {}
