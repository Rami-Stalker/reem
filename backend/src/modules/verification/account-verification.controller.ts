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

import { AppPermission } from '../../common/permissions';
import { Authorize } from '../../common/decorators/authorize.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { SelfScoped } from '../../common/decorators/self-scoped.decorator';
import { AccountVerificationService } from './account-verification.service';
import {
  AccountVerificationQueryDto,
  ReviewAccountVerificationDto,
  SubmitAccountVerificationDto,
} from './dto/account-verification.dto';

/**
 * «توثيق الحساب» — hers.
 *
 * Every route acts on the caller's own claim, found by her user id inside the
 * service; there is no path parameter here that could name somebody else's.
 */
@SelfScoped(
  "the claim is looked up by the caller's own user id; no route names another account",
)
@Controller('account-verification')
export class AccountVerificationController {
  constructor(private readonly verification: AccountVerificationService) {}

  @Get()
  mine(@CurrentUser('id') userId: string) {
    return this.verification.mine(userId);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  submit(
    @CurrentUser('id') userId: string,
    @Body() dto: SubmitAccountVerificationDto,
  ) {
    return this.verification.submit(userId, dto);
  }

  @Delete()
  @HttpCode(HttpStatus.OK)
  withdraw(@CurrentUser('id') userId: string) {
    return this.verification.withdraw(userId);
  }
}

/**
 * The review queue.
 *
 * `user:manage` rather than a permission of its own: granting the badge is a
 * public claim Ohara makes about a real woman, and the staff who may make it
 * are the staff who may already change what an account is.
 */
@Controller('admin/account-verifications')
export class AdminAccountVerificationController {
  constructor(private readonly verification: AccountVerificationService) {}

  @Authorize({
    action: 'read',
    resource: 'account',
    permissions: [AppPermission.userManage],
  })
  @Get()
  list(@Query() query: AccountVerificationQueryDto) {
    return this.verification.list(query);
  }

  @Authorize({
    action: 'read',
    resource: 'account',
    permissions: [AppPermission.userManage],
  })
  @Get(':id')
  detail(@Param('id', ParseUUIDPipe) id: string) {
    return this.verification.detail(id);
  }

  @Authorize({
    action: 'manage',
    resource: 'account',
    permissions: [AppPermission.userManage],
  })
  @Patch(':id')
  decide(
    @CurrentUser('id') actorId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReviewAccountVerificationDto,
  ) {
    return this.verification.decide(actorId, id, dto);
  }
}
