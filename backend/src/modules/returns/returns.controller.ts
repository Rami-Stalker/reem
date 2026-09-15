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

import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import {
  ApproveReturnDto,
  CreateReturnDto,
  EscalateReturnDto,
  ReceiveReturnDto,
  RejectReturnDto,
  SellerReturnsQueryDto,
} from './dto/return.dto';
import { ReturnsService } from './returns.service';

/**
 * Returns and exchanges — Q56 P1, Q67 P1, Q37 P2.
 *
 * The routes are grouped by who presses them, because that is what decides
 * both the permission and the wording: the customer asks and withdraws, the
 * seller accepts, refuses and receives, and only the platform pays. There is
 * no route that lets a seller refund herself and none that lets a customer
 * declare her own refund due.
 *
 * The customer half declares nothing the guard could check — whether she may
 * see a return depends on whose order it came from — so the service is handed
 * the whole `AuthUser` and decides per row. Undeclared, that half was refused
 * outright: she could not list her returns, open one, or ask for one.
 */
@SelfScoped(
  'the customer routes pass the whole AuthUser to the service, which resolves every return through the order that produced it and refuses one that is not hers',
)
@Controller('returns')
export class ReturnsController {
  constructor(private readonly returns: ReturnsService) {}

  // ── The customer ─────────────────────────────────────────────────────

  /**
   * What this parcel can still send back, and why not where it cannot.
   *
   * Read before the form is shown, so an excluded line is greyed out with its
   * reason instead of being refused after she has typed everything.
   */
  @Get('eligibility/:sellerOrderId')
  eligibility(
    @CurrentUser() user: AuthUser,
    @Param('sellerOrderId', ParseUUIDPipe) sellerOrderId: string,
  ) {
    return this.returns.eligibility(user, sellerOrderId);
  }

  /** Her own returns, newest first. */
  @Get()
  mine(@CurrentUser('id') userId: string) {
    return this.returns.listForCustomer(userId);
  }

  @Post()
  request(@CurrentUser() user: AuthUser, @Body() dto: CreateReturnDto) {
    return this.returns.request(user, {
      sellerOrderId: dto.seller_order_id,
      reason: dto.reason,
      reasonNote: dto.reason_note,
      evidence: dto.evidence,
      items: dto.items.map((line) => ({
        orderItemId: line.order_item_id,
        quantity: line.quantity,
      })),
    });
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  cancel(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.returns.cancel(user, id);
  }

  /** Q107 — she disagrees with a refusal and asks for a human. */
  @Post(':id/escalate')
  @HttpCode(HttpStatus.OK)
  escalate(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: EscalateReturnDto,
  ) {
    return this.returns.escalate(user, id, dto.subject);
  }

  // ── The seller ───────────────────────────────────────────────────────

  @Get('seller')
  @Roles(
    UserRole.SELLER,
    UserRole.SUPPORT,
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPER_ADMIN,
  )
  sellerQueue(
    @CurrentUser('id') sellerId: string,
    @Query() query: SellerReturnsQueryDto,
  ) {
    return this.returns.listForSeller(sellerId, query.status);
  }

  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  @Roles(
    UserRole.SELLER,
    UserRole.SUPPORT,
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPER_ADMIN,
  )
  approve(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ApproveReturnDto,
  ) {
    return this.returns.approve(user, id, {
      shippingBorneBy: dto.shipping_borne_by,
      note: dto.note,
    });
  }

  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @Roles(
    UserRole.SELLER,
    UserRole.SUPPORT,
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPER_ADMIN,
  )
  reject(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectReturnDto,
  ) {
    return this.returns.reject(user, id, dto.reason);
  }

  /** The goods are on their way back. */
  @Post(':id/in-transit')
  @HttpCode(HttpStatus.OK)
  @Roles(
    UserRole.SELLER,
    UserRole.SUPPORT,
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPER_ADMIN,
  )
  inTransit(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.returns.markInTransit(user, id);
  }

  /** She has them in her hands again — the refund becomes due from here. */
  @Post(':id/receive')
  @HttpCode(HttpStatus.OK)
  @Roles(
    UserRole.SELLER,
    UserRole.SUPPORT,
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPER_ADMIN,
  )
  receive(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReceiveReturnDto,
  ) {
    return this.returns.receive(user, id, {
      restock: dto.restock,
      note: dto.note,
    });
  }

  /** Q37 — resolved by swapping the goods rather than paying them back. */
  @Post(':id/exchange')
  @HttpCode(HttpStatus.OK)
  @Roles(
    UserRole.SELLER,
    UserRole.SUPPORT,
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPER_ADMIN,
  )
  exchange(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.returns.exchange(user, id);
  }

  /** «تم الاستبدال» — the replacement reached her. */
  @Post(':id/exchange-delivered')
  @HttpCode(HttpStatus.OK)
  @Roles(
    UserRole.SELLER,
    UserRole.SUPPORT,
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPER_ADMIN,
  )
  exchangeDelivered(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.returns.completeExchange(user, id);
  }

  // ── The platform ─────────────────────────────────────────────────────

  /**
   * Pays a received return out by hand.
   *
   * The sweep does this on its own schedule; this route is for the cases
   * somebody is chasing, and for the ones the sweep could not settle.
   */
  @Post(':id/settle')
  @HttpCode(HttpStatus.OK)
  @Roles(
    UserRole.SUPER_ADMIN,
    UserRole.FINANCE_ADMIN,
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPPORT_ADMIN,
  )
  settle(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.returns.settle(user, id);
  }

  // Kept last: a bare `:id` would otherwise swallow `/seller` above.
  @Get(':id')
  detail(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.returns.detail(user, id);
  }
}
