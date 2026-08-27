import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Authorize } from '../../common/decorators/authorize.decorator';
import {
  CurrentPrincipal,
  RequestPrincipal,
} from '../../common/decorators/current-principal.decorator';
import { FavoritesService } from './favorites.service';
import {
  AddWishlistItemDto,
  CreateWishlistCollectionDto,
  ShareWishlistDto,
} from './dto/wishlist.dto';

@Controller('favorites')
export class FavoritesController {
  constructor(private readonly favorites: FavoritesService) {}

  @Authorize({ action: 'read', resource: 'favorite', allowGuest: true })
  @Get()
  list(@CurrentPrincipal() principal: RequestPrincipal) {
    return principal.kind === 'user'
      ? this.favorites.list(principal.user.id)
      : this.favorites.listGuest(principal.guest.id);
  }

  @Authorize({ action: 'read', resource: 'favorite', allowGuest: true })
  @Get('overview')
  overview(@CurrentPrincipal() principal: RequestPrincipal) {
    return principal.kind === 'user'
      ? this.favorites.overview(principal.user.id)
      : this.favorites.overviewGuest(principal.guest.id);
  }

  @Authorize({ action: 'write', resource: 'favorite', allowGuest: true })
  @Post('sellers/:sellerId')
  @HttpCode(HttpStatus.CREATED)
  saveSeller(
    @Param('sellerId', ParseUUIDPipe) sellerId: string,
    @CurrentPrincipal() principal: RequestPrincipal,
  ) {
    return principal.kind === 'user'
      ? this.favorites.saveSeller(principal.user.id, sellerId)
      : this.favorites.saveSellerGuest(principal.guest.id, sellerId);
  }

  @Authorize({ action: 'write', resource: 'favorite', allowGuest: true })
  @Delete('sellers/:sellerId')
  @HttpCode(HttpStatus.OK)
  removeSeller(
    @Param('sellerId', ParseUUIDPipe) sellerId: string,
    @CurrentPrincipal() principal: RequestPrincipal,
  ) {
    return principal.kind === 'user'
      ? this.favorites.removeSeller(principal.user.id, sellerId)
      : this.favorites.removeSellerGuest(principal.guest.id, sellerId);
  }

  @Authorize({ action: 'write', resource: 'favorite', allowGuest: true })
  @Post('posts/:postId')
  @HttpCode(HttpStatus.CREATED)
  savePost(
    @Param('postId', ParseUUIDPipe) postId: string,
    @CurrentPrincipal() principal: RequestPrincipal,
  ) {
    return principal.kind === 'user'
      ? this.favorites.savePost(principal.user.id, postId)
      : this.favorites.savePostGuest(principal.guest.id, postId);
  }

  @Authorize({ action: 'write', resource: 'favorite', allowGuest: true })
  @Delete('posts/:postId')
  @HttpCode(HttpStatus.OK)
  removePost(
    @Param('postId', ParseUUIDPipe) postId: string,
    @CurrentPrincipal() principal: RequestPrincipal,
  ) {
    return principal.kind === 'user'
      ? this.favorites.removePost(principal.user.id, postId)
      : this.favorites.removePostGuest(principal.guest.id, postId);
  }

  @Get('collections')
  collections(@CurrentUser('id') userId: string) {
    return this.favorites.collections(userId);
  }

  @Post('collections')
  @HttpCode(HttpStatus.CREATED)
  createCollection(
    @CurrentUser('id') userId: string,
    @Body() dto: CreateWishlistCollectionDto,
  ) {
    return this.favorites.createCollection(userId, dto);
  }

  @Post('collections/:collectionId/items')
  @HttpCode(HttpStatus.CREATED)
  addItem(
    @CurrentUser('id') userId: string,
    @Param('collectionId', ParseUUIDPipe) collectionId: string,
    @Body() dto: AddWishlistItemDto,
  ) {
    return this.favorites.addItem(userId, collectionId, dto);
  }

  @Delete('collections/:collectionId/items/:itemId')
  @HttpCode(HttpStatus.OK)
  removeItem(
    @CurrentUser('id') userId: string,
    @Param('collectionId', ParseUUIDPipe) collectionId: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
  ) {
    return this.favorites.removeItem(userId, collectionId, itemId);
  }

  @Post('collections/:collectionId/share')
  @HttpCode(HttpStatus.CREATED)
  share(
    @CurrentUser('id') userId: string,
    @Param('collectionId', ParseUUIDPipe) collectionId: string,
    @Body() dto: ShareWishlistDto,
  ) {
    return this.favorites.share(userId, collectionId, dto);
  }

  @Authorize({ action: 'write', resource: 'favorite', allowGuest: true })
  @Post(':productId')
  @HttpCode(HttpStatus.CREATED)
  add(
    @Param('productId', ParseUUIDPipe) productId: string,
    @CurrentPrincipal() principal: RequestPrincipal,
  ) {
    return principal.kind === 'user'
      ? this.favorites.add(principal.user.id, productId)
      : this.favorites.addGuest(principal.guest.id, productId);
  }

  @Authorize({ action: 'write', resource: 'favorite', allowGuest: true })
  @Delete(':productId')
  @HttpCode(HttpStatus.OK)
  remove(
    @Param('productId', ParseUUIDPipe) productId: string,
    @CurrentPrincipal() principal: RequestPrincipal,
  ) {
    return principal.kind === 'user'
      ? this.favorites.remove(principal.user.id, productId)
      : this.favorites.removeGuest(principal.guest.id, productId);
  }

  @Public()
  @Get('shared/:token')
  publicShare(@Param('token') token: string) {
    return this.favorites.publicShare(token);
  }
}
