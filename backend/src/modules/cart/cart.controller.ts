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
  UnauthorizedException,
} from '@nestjs/common';
import {
  CurrentPrincipal,
  RequestPrincipal,
} from '../../common/decorators/current-principal.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { CartOwner, CartService } from './cart.service';
import { AddCartItemDto, UpdateCartItemDto } from './dto/cart.dto';

@Authorize({ action: 'write', resource: 'cart', allowGuest: true })
@Controller('cart')
export class CartController {
  constructor(private readonly cart: CartService) {}

  @Get()
  get(@CurrentPrincipal() principal: RequestPrincipal) {
    return this.cart.getCart(this.owner(principal));
  }

  @Post('items')
  @HttpCode(HttpStatus.OK)
  add(
    @CurrentPrincipal() principal: RequestPrincipal,
    @Body() dto: AddCartItemDto,
  ) {
    return this.cart.addItem(this.owner(principal), dto);
  }

  @Patch('items/:id')
  update(
    @CurrentPrincipal() principal: RequestPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCartItemDto,
  ) {
    return this.cart.updateItem(this.owner(principal), id, dto.quantity);
  }

  @Delete('items/:id')
  @HttpCode(HttpStatus.OK)
  remove(
    @CurrentPrincipal() principal: RequestPrincipal,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.cart.removeItem(this.owner(principal), id);
  }

  @Delete()
  @HttpCode(HttpStatus.OK)
  clear(@CurrentPrincipal() principal: RequestPrincipal) {
    return this.cart.clear(this.owner(principal));
  }

  private owner(principal?: RequestPrincipal): CartOwner {
    if (principal?.kind === 'user') {
      return { kind: 'user', userId: principal.user.id };
    }
    if (principal?.kind === 'guest') {
      return { kind: 'guest', guestSessionId: principal.guest.id };
    }
    throw new UnauthorizedException('A user or guest session is required');
  }
}
