import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AuthUser, CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AdminService } from './admin.service';
import {
  AdminListQueryDto,
  CreateCommissionRuleDto,
  UpdateCommissionLedgerDto,
  UpdateModerationCaseDto,
  UpdateProductAdminDto,
  UpdateReportDto,
  UpdateSupportTicketDto,
  UpdateUserAdminDto,
  UpsertSystemSettingDto,
} from './dto/admin.dto';

@Roles(UserRole.SUPER_ADMIN, UserRole.ADMIN, UserRole.SUPPORT)
@Controller('admin')
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('stats')
  stats() {
    return this.admin.stats();
  }

  @Get('orders')
  orders(@Query() query: AdminListQueryDto) {
    return this.admin.orders(query);
  }

  @Get('products')
  products(@Query() query: AdminListQueryDto) {
    return this.admin.products(query);
  }

  @Patch('products/:id')
  updateProduct(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProductAdminDto,
  ) {
    return this.admin.updateProduct(id, dto);
  }

  @Get('users')
  users(@Query() query: AdminListQueryDto) {
    return this.admin.users(query);
  }

  @Patch('users/:id')
  updateUser(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateUserAdminDto,
  ) {
    return this.admin.updateUser(id, dto);
  }

  @Get('sellers')
  sellers(@Query() query: AdminListQueryDto) {
    return this.admin.sellers(query);
  }

  @Get('analytics')
  analytics() {
    return this.admin.analytics();
  }

  @Get('financials')
  financials() {
    return this.admin.financials();
  }

  @Get('commissions')
  commissions() {
    return this.admin.commissions();
  }

  @Post('commissions/rules')
  @HttpCode(HttpStatus.CREATED)
  createCommissionRule(@Body() dto: CreateCommissionRuleDto) {
    return this.admin.createCommissionRule(dto);
  }

  @Patch('commissions/:id')
  updateCommissionLedger(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCommissionLedgerDto,
  ) {
    return this.admin.updateCommissionLedger(id, dto);
  }

  @Get('support')
  support() {
    return this.admin.support();
  }

  @Patch('support/:id')
  updateSupport(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateSupportTicketDto,
  ) {
    return this.admin.updateSupportTicket(id, dto);
  }

  @Get('moderation')
  moderation() {
    return this.admin.moderation();
  }

  @Patch('moderation/:id')
  updateModeration(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateModerationCaseDto,
  ) {
    return this.admin.updateModeration(id, dto);
  }

  @Get('reports')
  reports() {
    return this.admin.reports();
  }

  @Patch('reports/:id')
  updateReport(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateReportDto,
  ) {
    return this.admin.updateReport(id, dto);
  }

  @Get('audit-logs')
  auditLogs() {
    return this.admin.auditLogs();
  }

  @Get('system-settings')
  systemSettings() {
    return this.admin.systemSettings();
  }

  @Post('system-settings')
  @HttpCode(HttpStatus.OK)
  upsertSystemSetting(
    @CurrentUser() user: AuthUser,
    @Body() dto: UpsertSystemSettingDto,
  ) {
    return this.admin.upsertSystemSetting(user.id, dto);
  }
}
