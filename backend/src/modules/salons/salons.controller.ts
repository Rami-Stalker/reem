import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { AppPermission } from '../../common/permissions';
import { AppointmentsService } from './appointments.service';
import {
  AppointmentQueryDto,
  AvailabilityQueryDto,
  CancelAppointmentDto,
  CreateAppointmentDto,
  CreateClosureDto,
  OpenDaysQueryDto,
  ReplyToReviewDto,
  ReviewAppointmentDto,
  SalonNoteDto,
  SalonQueryDto,
  SetWorkingHoursDto,
  UpsertSalonDto,
  UpsertSalonServiceDto,
} from './dto/salons.dto';
import { SalonAvailabilityService } from './salon-availability.service';
import { SalonsService } from './salons.service';
import { AuthorizationPolicy } from '../../common/authorization/authorization.types';

/**
 * Running a salon: the menu, the hours, the queue, the answers.
 *
 * Declared once rather than repeated on nine handlers, because a policy copied
 * nine times is a policy that will be edited eight times.
 */
const MANAGE_SALON: AuthorizationPolicy = {
  action: 'manage',
  resource: 'salon',
  roles: [UserRole.SELLER, UserRole.ADMIN, UserRole.SUPER_ADMIN],
  permissions: [AppPermission.salonManage],
};

/** Making and holding a booking. Every customer holds this. */
const OWN_APPOINTMENT: AuthorizationPolicy = {
  action: 'book',
  resource: 'appointment',
  roles: [UserRole.CUSTOMER, UserRole.SELLER, UserRole.ADMIN],
  permissions: [AppPermission.appointmentBook],
};

/**
 * «الصالونات والجمال» — the customer's half.
 *
 * Reading is open to a guest, exactly as the catalogue is. That is not a
 * convenience: a woman looking for somewhere to have her hair done is
 * comparing salons before she has any reason to make an account, and a
 * directory behind a sign-in wall is a directory nobody browses. Booking needs
 * a session, because an appointment is a promise between two named people.
 */
@SelfScoped(
  'the directory is public reading; a booking names the caller and is scoped to her',
)
@Controller('salons')
export class SalonsController {
  constructor(
    private readonly salons: SalonsService,
    private readonly availability: SalonAvailabilityService,
    private readonly appointments: AppointmentsService,
  ) {}

  // ── Browsing ─────────────────────────────────────────────────────────────

  @OptionalAuth()
  @Get()
  list(@Query() query: SalonQueryDto) {
    return this.salons.list(query);
  }

  /**
   * The filter sheet's vocabulary and the localities it can offer.
   *
   * Declared before `:id` — a literal segment placed after a parameter is
   * swallowed by it, which is how `/salons/categories` becomes "a salon whose
   * id is the word categories".
   */
  @OptionalAuth()
  @Get('categories')
  categories() {
    return this.salons.categories();
  }

  @OptionalAuth()
  @Get('areas')
  areas() {
    return this.salons.areas();
  }

  /** Her own salon's management view. Also before `:id`, for the same reason. */
  @Authorize(MANAGE_SALON)
  @Get('mine')
  mine(@CurrentUser('id') userId: string) {
    return this.salons.mine(userId);
  }

  @OptionalAuth()
  @Get(':id')
  detail(@Param('id') id: string, @CurrentUser('id') viewerId?: string) {
    // Not `ParseUUIDPipe`: a salon is reachable by its slug too, which is what
    // a shared link carries.
    return this.salons.detail(id, viewerId);
  }

  @OptionalAuth()
  @Get(':id/reviews')
  reviews(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() page: PaginationDto,
  ) {
    return this.salons.reviews(id, page.page, page.limit);
  }

  /**
   * Free times for one service on one day.
   *
   * Open to a guest on purpose: seeing that a salon has nothing free on
   * Thursday is part of choosing it, and asking her to sign in to find that
   * out would be asking her to sign in to be disappointed.
   */
  @OptionalAuth()
  @Get(':id/availability')
  async availabilityFor(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: AvailabilityQueryDto,
  ) {
    const slots = await this.availability.slotsFor(
      id,
      query.service_id,
      query.date,
    );
    return {
      date: query.date,
      slots: slots.map((slot) => ({
        time: slot.time,
        starts_at: slot.startsAt.toISOString(),
        ends_at: slot.endsAt.toISOString(),
      })),
    };
  }

  /** The day strip: which of the next few days have anything at all. */
  @OptionalAuth()
  @Get(':id/open-days')
  openDays(
    @Param('id', ParseUUIDPipe) id: string,
    @Query() query: OpenDaysQueryDto,
  ) {
    return this.availability
      .openDays(id, query.service_id, query.days)
      .then((days) => ({ days }));
  }

  // ── Booking ──────────────────────────────────────────────────────────────

  @Authorize(OWN_APPOINTMENT)
  @Post(':id/appointments')
  @HttpCode(HttpStatus.CREATED)
  book(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateAppointmentDto,
  ) {
    return this.appointments.book(user, id, dto);
  }

  // ── Owning a salon ───────────────────────────────────────────────────────

  @Authorize(MANAGE_SALON)
  @Put()
  upsert(@CurrentUser() user: AuthUser, @Body() dto: UpsertSalonDto) {
    return this.salons.upsert(user, dto);
  }

  @Authorize(MANAGE_SALON)
  @Post('services')
  @HttpCode(HttpStatus.CREATED)
  createService(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpsertSalonServiceDto,
  ) {
    return this.salons.upsertService(user, null, dto);
  }

  @Authorize(MANAGE_SALON)
  @Patch('services/:serviceId')
  updateService(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: UpsertSalonServiceDto,
  ) {
    return this.salons.upsertService(user, serviceId, dto);
  }

  /** Off the menu, not out of the database — bookings point at it. */
  @Authorize(MANAGE_SALON)
  @Delete('services/:serviceId')
  @HttpCode(HttpStatus.OK)
  deactivateService(
    @Param('serviceId', ParseUUIDPipe) serviceId: string,
    @CurrentUser() user: AuthUser,
  ) {
    return this.salons.deactivateService(user, serviceId);
  }

  @Authorize(MANAGE_SALON)
  @Put('hours')
  setHours(@CurrentUser() user: AuthUser, @Body() dto: SetWorkingHoursDto) {
    return this.salons.setHours(user, dto);
  }

  @Authorize(MANAGE_SALON)
  @Post('closures')
  @HttpCode(HttpStatus.CREATED)
  addClosure(@CurrentUser() user: AuthUser, @Body() dto: CreateClosureDto) {
    return this.salons.addClosure(user, dto);
  }

  @Authorize(MANAGE_SALON)
  @Delete('closures/:date')
  @HttpCode(HttpStatus.OK)
  removeClosure(@CurrentUser() user: AuthUser, @Param('date') date: string) {
    return this.salons.removeClosure(user, date);
  }

  @Authorize(MANAGE_SALON)
  @Get(':id/queue')
  queue(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Query() query: AppointmentQueryDto,
  ) {
    return this.appointments.queue(user, id, query);
  }

  @Authorize(MANAGE_SALON)
  @Post('reviews/:reviewId/reply')
  @HttpCode(HttpStatus.OK)
  replyToReview(
    @Param('reviewId', ParseUUIDPipe) reviewId: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: ReplyToReviewDto,
  ) {
    return this.salons.replyToReview(user, reviewId, dto);
  }
}

/**
 * «حجوزاتي» — and the salon's answers to them.
 *
 * Its own controller because these are addressed by appointment rather than by
 * salon: she opens a booking from her list or from a notification and never
 * types a salon id.
 */
@SelfScoped(
  'every route resolves the appointment first and checks the caller against its customer or its salon owner',
)
@Controller('appointments')
export class AppointmentsController {
  constructor(private readonly appointments: AppointmentsService) {}

  @Authorize(OWN_APPOINTMENT)
  @Get()
  mine(
    @CurrentUser('id') userId: string,
    @Query() query: AppointmentQueryDto,
  ) {
    return this.appointments.mine(userId, query);
  }

  @Authorize(OWN_APPOINTMENT)
  @Get(':id')
  detail(@Param('id', ParseUUIDPipe) id: string, @CurrentUser() user: AuthUser) {
    return this.appointments.detail(user, id);
  }

  /** Either side may cancel. The service records which. */
  @Authorize(OWN_APPOINTMENT)
  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  cancel(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: CancelAppointmentDto,
  ) {
    return this.appointments.cancel(user, id, dto);
  }

  @Authorize(OWN_APPOINTMENT)
  @Post(':id/review')
  @HttpCode(HttpStatus.CREATED)
  review(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: ReviewAppointmentDto,
  ) {
    return this.appointments.review(user, id, dto);
  }

  // ── The salon answering ──────────────────────────────────────────────────
  //
  // Three verbs rather than one `setStatus`: each has a different legal
  // predecessor and a different notification, and a generic setter would have
  // let a salon mark a cancelled appointment complete.

  @Authorize(MANAGE_SALON)
  @Post(':id/confirm')
  @HttpCode(HttpStatus.OK)
  confirm(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: SalonNoteDto,
  ) {
    return this.appointments.confirm(user, id, dto);
  }

  @Authorize(MANAGE_SALON)
  @Post(':id/complete')
  @HttpCode(HttpStatus.OK)
  complete(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: SalonNoteDto,
  ) {
    return this.appointments.complete(user, id, dto);
  }

  @Authorize(MANAGE_SALON)
  @Post(':id/no-show')
  @HttpCode(HttpStatus.OK)
  noShow(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser,
    @Body() dto: SalonNoteDto,
  ) {
    return this.appointments.noShow(user, id, dto);
  }
}
