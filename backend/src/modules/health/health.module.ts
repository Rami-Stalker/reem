import {
  Controller,
  Get,
  Logger,
  Module,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { PrismaService } from '../../prisma/prisma.service';

@Controller('health')
class HealthController {
  private readonly logger = new Logger(HealthController.name);

  constructor(private readonly prisma: PrismaService) {}

  // Readiness probe: confirms the process is up AND that PostgreSQL is
  // reachable, so load balancers / orchestrators don't route to a node that
  // can't serve the database.
  @Public()
  @Get()
  async check() {
    const timestamp = new Date().toISOString();
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
    return { status: 'ok', database: 'up', timestamp };
  }
}

@Module({ controllers: [HealthController] })
export class HealthModule {}
