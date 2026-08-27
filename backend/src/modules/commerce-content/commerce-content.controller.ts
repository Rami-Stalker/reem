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
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CommerceContentService } from './commerce-content.service';
import {
  CommerceFeedQueryDto,
  RecordCommerceContentEventDto,
} from './dto/commerce-content.dto';

@Controller('content')
export class CommerceContentController {
  constructor(private readonly content: CommerceContentService) {}

  @Get('feed')
  feed(@Query() query: CommerceFeedQueryDto) {
    return this.content.feed(query);
  }

  @Post(':id/events')
  @HttpCode(HttpStatus.CREATED)
  recordEvent(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string | undefined,
    @Body() dto: RecordCommerceContentEventDto,
  ) {
    return this.content.recordEvent(userId, id, dto);
  }
}
