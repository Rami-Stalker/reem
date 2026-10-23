import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import {
  CreateOccasionDto,
  ListOccasionsDto,
  SetStepDto,
  UpdateOccasionDto,
} from './dto/occasions.dto';
import { OccasionRecord, OccasionsService } from './occasions.service';
import { serializeOccasion } from './occasions.serializer';

/**
 * `/occasions` — «مناسباتي».
 *
 * Every route is authenticated and scoped to the caller. Who she is seeing on
 * Thursday, and in what, is as private as her wardrobe, and there is no route
 * by which anyone else — a friend, a salon, a seller — reads it.
 */
@SelfScoped(
  'an occasion belongs to one woman; every query is scoped to her id, and the look and appointment it links are checked to be hers',
)
@Controller('occasions')
export class OccasionsController {
  constructor(private readonly occasions: OccasionsService) {}

  @Get()
  async list(@CurrentUser('id') userId: string, @Query() dto: ListOccasionsDto) {
    const rows = await this.occasions.list(userId, dto.scope ?? 'upcoming');
    const today = this.occasions.today();
    return rows.map((row) => serializeOccasion(row, { today }));
  }

  @Get(':id')
  async detail(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.withRepeats(await this.occasions.require(userId, id));
  }

  @Post()
  async create(@CurrentUser('id') userId: string, @Body() dto: CreateOccasionDto) {
    const occasion = await this.occasions.create(userId, {
      title: dto.title,
      kind: dto.kind,
      date: dto.date,
      startsAtTime: dto.starts_at_time,
      location: dto.location,
      circle: dto.circle,
      note: dto.note,
      lookId: dto.look_id,
      appointmentId: dto.appointment_id,
      remindersEnabled: dto.reminders_enabled,
    });
    return this.withRepeats(occasion);
  }

  @Patch(':id')
  async update(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateOccasionDto,
  ) {
    const occasion = await this.occasions.update(userId, id, {
      title: dto.title,
      kind: dto.kind,
      date: dto.date,
      startsAtTime: dto.starts_at_time,
      location: dto.location,
      circle: dto.circle,
      note: dto.note,
      lookId: dto.look_id,
      appointmentId: dto.appointment_id,
      remindersEnabled: dto.reminders_enabled,
    });
    // Answered with the warning, because choosing a look is exactly the
    // moment it is worth hearing that her cousins saw it in June.
    return this.withRepeats(occasion);
  }

  /**
   * Tick or untick a step only she can see.
   *
   * `PUT` because it sets a state rather than toggling one: a retried request
   * on a bad connection leaves the gift ticked, not unticked again.
   */
  @Put(':id/steps/:key')
  async setStep(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('key') key: string,
    @Body() dto: SetStepDto,
  ) {
    return this.withRepeats(await this.occasions.setStep(userId, id, key, dto.done));
  }

  @Delete(':id')
  async remove(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    await this.occasions.remove(userId, id);
    return { deleted: true };
  }

  private async withRepeats(occasion: OccasionRecord) {
    const repeats = await this.occasions.repeatsFor(occasion);
    return serializeOccasion(occasion, { today: this.occasions.today(), repeats });
  }
}
