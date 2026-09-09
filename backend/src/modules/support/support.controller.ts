import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';

import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { OpenTicketDto, ReplyTicketDto } from './dto/support.dto';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { SupportService } from './support.service';

/**
 * «تواصلي مع الدعم» — which until now went nowhere.
 *
 * No role decorators: every signed-in account may open a conversation about
 * its own orders, and the service decides what each reader is allowed to see
 * inside one. Support staff reach the same routes with wider visibility rather
 * than through a parallel set of endpoints, so there is one definition of what
 * a ticket is.
 */
@SelfScoped(
  'SupportService decides per ticket what each reader may see; staff reach the same routes with wider visibility',
)
@Controller('support/tickets')
export class SupportController {
  constructor(private readonly support: SupportService) {}

  @Get()
  mine(@CurrentUser('id') userId: string) {
    return this.support.listMine(userId);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  open(@CurrentUser() user: AuthUser, @Body() dto: OpenTicketDto) {
    return this.support.open(user, {
      subject: dto.subject,
      body: dto.body,
      category: dto.category,
    });
  }

  @Get(':id')
  detail(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.support.detail(id, user);
  }

  @Post(':id/messages')
  @HttpCode(HttpStatus.CREATED)
  reply(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReplyTicketDto,
  ) {
    return this.support.reply(id, user, {
      body: dto.body,
      internal: dto.internal,
    });
  }

  @Post(':id/close')
  @HttpCode(HttpStatus.OK)
  close(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.support.close(id, user);
  }
}
