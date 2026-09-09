import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  AssignCourierDto,
  CourierDayQueryDto,
  CourierPositionDto,
  DeliverShipmentDto,
  FailDeliveryDto,
} from './dto/shipment.dto';
import { ShipmentsService } from './shipments.service';

/**
 * Shipment tracking and the courier's own screens.
 *
 * Q123 puts «تتبع الشحنة وتطبيق المندوب» in the launch-critical column, and
 * Q63 P1 has the courier updating status «عبر رابط أو تطبيق بسيط» — so the
 * courier routes are deliberately few and blunt: see today's parcels, pick up,
 * head out, delivered, or failed with a reason.
 */
@Controller('shipments')
export class ShipmentsController {
  constructor(private readonly shipments: ShipmentsService) {}

  // ── Customer tracking (Q64, Q68 P1) ──────────────────────────────────

  /**
   * Public on purpose: a tracking code is the credential. Guests may buy
   * (Q46 P1), so requiring a login to follow a parcel would strand them.
   */
  @Get('track/:trackingCode')
  @Public()
  track(@Param('trackingCode') trackingCode: string) {
    return this.shipments.track(trackingCode);
  }

  // ── Courier app (Q55) ────────────────────────────────────────────────
  //
  // Authority here is the `Courier` row linked to the account, checked by
  // `requireCourier` on every one of these calls — not a role. The role list
  // that used to sit on them (SELLER, SUPPORT, OPERATIONS_ADMIN) added
  // nothing, since a seller or a support agent without a courier row is
  // refused anyway, and it cost a great deal: a delivery rider could only be
  // given an account by making her SUPPORT, which is a privileged role — the
  // support console, the recovery desk and a TOTP enrolment demanded at boot,
  // handed out to move parcels.

  /** «يشوف طلباته لليوم». */
  @Get('courier/today')
  today(
    @CurrentUser('id') userId: string,
    @Query() query: CourierDayQueryDto,
  ) {
    return this.shipments.assignmentsFor(
      userId,
      query.date ? new Date(query.date) : new Date(),
    );
  }

  /** «يؤكد استلام الطلب من البائع». */
  @Post(':id/pick-up')
  @HttpCode(HttpStatus.OK)
  pickUp(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.shipments.pickUp(id, userId);
  }

  @Post(':id/out-for-delivery')
  @HttpCode(HttpStatus.OK)
  outForDelivery(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CourierPositionDto,
  ) {
    return this.shipments.outForDelivery(id, userId, dto);
  }

  /** «يغيّر حالة الشحنة» + «يسجّل مبلغ التحصيل» + «صورة إثبات تسليم». */
  @Post(':id/deliver')
  @HttpCode(HttpStatus.OK)
  deliver(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: DeliverShipmentDto,
  ) {
    return this.shipments.deliver({
      shipmentId: id,
      courierUserId: userId,
      collected: dto.collected,
      proofImageUrl: dto.proof_image_url,
      recipientNote: dto.recipient_note,
      latitude: dto.latitude,
      longitude: dto.longitude,
    });
  }

  /** «يسجّل سبب فشل التسليم». */
  @Post(':id/fail')
  @HttpCode(HttpStatus.OK)
  fail(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: FailDeliveryDto,
  ) {
    return this.shipments.failAttempt(id, userId, dto.reason, dto.note);
  }

  // ── Operations ───────────────────────────────────────────────────────

  @Post(':id/assign')
  @HttpCode(HttpStatus.OK)
  @Roles(UserRole.SUPER_ADMIN, UserRole.OPERATIONS_ADMIN)
  assign(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: AssignCourierDto,
    @CurrentUser('id') actorId: string,
  ) {
    return this.shipments.assign(id, dto.courier_id, actorId);
  }
}
