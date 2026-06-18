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
import { FavoritesService } from './favorites.service';
import {
  AddWishlistItemDto,
  CreateWishlistCollectionDto,
  ShareWishlistDto,
} from './dto/wishlist.dto';

@Controller('favorites')
export class FavoritesController {
  constructor(private readonly favorites: FavoritesService) {}

  @Get()
  list(@CurrentUser('id') userId: string) {
    return this.favorites.list(userId);
  }

  @Get('overview')
  overview(@CurrentUser('id') userId: string) {
    return this.favorites.overview(userId);
  }

  @Post('sellers/:sellerId')
  @HttpCode(HttpStatus.CREATED)
  saveSeller(
    @Param('sellerId', ParseUUIDPipe) sellerId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.favorites.saveSeller(userId, sellerId);
  }

  @Delete('sellers/:sellerId')
  @HttpCode(HttpStatus.OK)
  removeSeller(
    @Param('sellerId', ParseUUIDPipe) sellerId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.favorites.removeSeller(userId, sellerId);
  }

  @Post('posts/:postId')
  @HttpCode(HttpStatus.CREATED)
  savePost(
    @Param('postId', ParseUUIDPipe) postId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.favorites.savePost(userId, postId);
  }

  @Delete('posts/:postId')
  @HttpCode(HttpStatus.OK)
  removePost(
    @Param('postId', ParseUUIDPipe) postId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.favorites.removePost(userId, postId);
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

  @Post(':productId')
  @HttpCode(HttpStatus.CREATED)
  add(
    @Param('productId', ParseUUIDPipe) productId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.favorites.add(userId, productId);
  }

  @Delete(':productId')
  @HttpCode(HttpStatus.OK)
  remove(
    @Param('productId', ParseUUIDPipe) productId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.favorites.remove(userId, productId);
  }

  @Public()
  @Get('shared/:token')
  publicShare(@Param('token') token: string) {
    return this.favorites.publicShare(token);
  }
}
