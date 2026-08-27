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
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { StoriesService } from './stories.service';
import { ReactStoryDto } from './dto/react-story.dto';

/**
 * Customer-facing story consumption + reactions.
 *
 * The rail itself is public — a visitor watches stories without an account.
 * Recording a view and reacting are not: both write a row keyed by the user,
 * so they stay behind the global guard and the client should skip them while
 * signed out.
 */
@Controller('stories')
export class StoriesController {
  constructor(private readonly stories: StoriesService) {}

  @OptionalAuth()
  @Get()
  list(@CurrentUser('id') userId?: string) {
    return this.stories.list(userId);
  }

  @Post(':id/view')
  @HttpCode(HttpStatus.OK)
  view(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.stories.recordView(userId, id);
  }

  @Post(':id/react')
  @HttpCode(HttpStatus.OK)
  react(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: ReactStoryDto,
  ) {
    return this.stories.react(userId, id, dto.emoji);
  }

  @Delete(':id/react')
  @HttpCode(HttpStatus.OK)
  unreact(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.stories.unreact(userId, id);
  }
}
