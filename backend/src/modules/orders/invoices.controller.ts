import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';

import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { InvoicesService } from './invoices.service';

/**
 * Q51 — «الاثنين»: the customer's invoice for the whole order, and one per
 * seller for their own parcel.
 *
 * Issuing is a POST because it creates a numbered document the first time;
 * every call after that returns the same one. Reading is separate so a
 * customer opening her invoice twice does not look like two issues.
 */
@SelfScoped(
  "assertMayIssue and assertMayView compare the viewer against the order's customer and the parcel's seller",
)
@Controller('invoices')
export class InvoicesController {
  constructor(private readonly invoices: InvoicesService) {}

  /** Every invoice raised against one order. */
  @Get('order/:orderId')
  list(
    @Param('orderId', ParseUUIDPipe) orderId: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: UserRole,
  ) {
    return this.invoices.listForOrder(orderId, { id: userId, role });
  }

  /** The document itself, with its lines. */
  @Get(':id')
  render(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: UserRole,
  ) {
    return this.invoices.render(id, { id: userId, role });
  }

  /**
   * Q51 — the customer's copy. Idempotent.
   *
   * The viewer is passed for the same reason it is passed to `render`: this
   * returns the document, so it is a read, and the first call being the one
   * that creates it does not make the later ones free.
   */
  @Post('order/:orderId')
  @HttpCode(HttpStatus.CREATED)
  issueForOrder(
    @Param('orderId', ParseUUIDPipe) orderId: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: UserRole,
  ) {
    return this.invoices.issueForOrder(orderId, {
      issuedById: userId,
      viewer: { id: userId, role },
    });
  }

  /** Q51 — the seller's copy, carrying the commission. Idempotent. */
  @Post('seller-order/:sellerOrderId')
  @HttpCode(HttpStatus.CREATED)
  issueForSellerOrder(
    @Param('sellerOrderId', ParseUUIDPipe) sellerOrderId: string,
    @CurrentUser('id') userId: string,
    @CurrentUser('role') role: UserRole,
  ) {
    return this.invoices.issueForSellerOrder(sellerOrderId, {
      issuedById: userId,
      viewer: { id: userId, role },
    });
  }
}
