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
  Query,
} from '@nestjs/common';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { ChatsService } from './chats.service';
import {
  BlockUserDto,
  ChatListQueryDto,
  DeleteMessageDto,
  MarkReadDto,
  MessageQueryDto,
  ReportUserDto,
  SendMessageDto,
  StartConversationDto,
} from './dto/chat.dto';

@SelfScoped(
  'ChatsService checks participation on every thread and message before it answers',
)
@Controller('chats')
export class ChatsController {
  constructor(private readonly chats: ChatsService) {}

  @Get()
  threads(
    @CurrentUser('id') userId: string,
    @Query() query: ChatListQueryDto,
  ) {
    return this.chats.threads(userId, query);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  start(
    @CurrentUser('id') userId: string,
    @Body() dto: StartConversationDto,
  ) {
    return this.chats.startConversation(userId, dto);
  }

  @Get('search')
  search(
    @CurrentUser('id') userId: string,
    @Query() query: MessageQueryDto,
  ) {
    return this.chats.search(userId, query);
  }

  /**
   * Declared after `@Get('search')` so the literal segment is matched first —
   * a UUID parameter placed above it would swallow `/chats/search`.
   */
  @Get(':id')
  thread(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.chats.thread(id, userId);
  }

  @Post('blocks/:userId')
  @HttpCode(HttpStatus.OK)
  block(
    @CurrentUser('id') userId: string,
    @Param('userId', ParseUUIDPipe) blockedId: string,
    @Body() dto: BlockUserDto,
  ) {
    return this.chats.blockUser(userId, blockedId, dto);
  }

  @Delete('blocks/:userId')
  unblock(
    @CurrentUser('id') userId: string,
    @Param('userId', ParseUUIDPipe) blockedId: string,
  ) {
    return this.chats.unblockUser(userId, blockedId);
  }

  @Get(':id/messages')
  messages(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Query() query: MessageQueryDto,
  ) {
    return this.chats.messages(id, userId, query);
  }

  @Post(':id/messages')
  @HttpCode(HttpStatus.CREATED)
  send(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: SendMessageDto,
  ) {
    return this.chats.send(id, userId, dto);
  }

  @Delete(':id/messages/:messageId')
  @HttpCode(HttpStatus.OK)
  deleteMessage(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('messageId', ParseUUIDPipe) messageId: string,
    @CurrentUser('id') userId: string,
    @Query() query: DeleteMessageDto,
  ) {
    return this.chats.deleteMessage(id, userId, messageId, query.scope);
  }

  @Patch(':id/read')
  @HttpCode(HttpStatus.OK)
  markRead(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: MarkReadDto,
  ) {
    return this.chats.markRead(id, userId, dto);
  }

  @Post(':id/reports')
  @HttpCode(HttpStatus.CREATED)
  report(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser('id') userId: string,
    @Body() dto: ReportUserDto,
  ) {
    return this.chats.reportUser(id, userId, dto);
  }
}
